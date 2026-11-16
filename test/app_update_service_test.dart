import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:devdeck/core/services/app_update_service.dart';
import 'package:devdeck/core/storage/secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

class _FakeBox implements Box {
  final Map<dynamic, dynamic> _data = {};

  @override
  dynamic get(key, {defaultValue}) => _data.containsKey(key) ? _data[key] : defaultValue;

  @override
  Future<void> put(key, value) async => _data[key] = value;

  @override
  Future<void> delete(key) async => _data.remove(key);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpClient implements HttpClient {
  _FakeHttpClient({
    this.statusCode = 200,
    this.responseBody = '{}',
  });

  final int statusCode;
  final String responseBody;

  @override
  Duration? connectionTimeout;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    return _FakeHttpClientRequest(
      statusCode: statusCode,
      responseBody: responseBody,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpClientRequest implements HttpClientRequest {
  _FakeHttpClientRequest({
    required this.statusCode,
    required this.responseBody,
  });

  final int statusCode;
  final String responseBody;
  final HttpHeaders _headers = _FakeHttpHeaders();

  @override
  HttpHeaders get headers => _headers;

  @override
  Future<HttpClientResponse> close() async {
    return _FakeHttpClientResponse(
      statusCode: statusCode,
      responseBody: responseBody,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpHeaders implements HttpHeaders {
  final Map<String, List<String>> _data = {};

  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {
    _data.putIfAbsent(name, () => []).add(value.toString());
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpClientResponse extends Stream<List<int>> implements HttpClientResponse {
  _FakeHttpClientResponse({
    required this.statusCode,
    required this.responseBody,
  });

  @override
  final int statusCode;
  final String responseBody;

  @override
  int get contentLength => utf8.encode(responseBody).length;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream.value(utf8.encode(responseBody)).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('AppUpdateService Unit Tests', () {
    test('isVersionNewer correctly compares semver numbers', () {
      expect(AppUpdateService.isVersionNewer('1.0.42', '1.0.41'), isTrue);
      expect(AppUpdateService.isVersionNewer('1.1.0', '1.0.41'), isTrue);
      expect(AppUpdateService.isVersionNewer('2.0.0', '1.99.99'), isTrue);
      expect(AppUpdateService.isVersionNewer('v1.0.42', '1.0.41'), isTrue);
      expect(AppUpdateService.isVersionNewer('1.0.42-hotfix', '1.0.41'), isTrue);

      expect(AppUpdateService.isVersionNewer('1.0.41', '1.0.41'), isFalse);
      expect(AppUpdateService.isVersionNewer('1.0.40', '1.0.41'), isFalse);
      expect(AppUpdateService.isVersionNewer('1.0.0', '1.1.0'), isFalse);
    });

    test('normalizeVersion trims and strips leading v/V', () {
      expect(AppUpdateService.normalizeVersion('v1.0.41'), '1.0.41');
      expect(AppUpdateService.normalizeVersion('V2.3.4'), '2.3.4');
      expect(AppUpdateService.normalizeVersion('  v3.0.0  '), '3.0.0');
      expect(AppUpdateService.normalizeVersion('1.2.3'), '1.2.3');
    });

    test('DownloadProgress computes megabytes and percentage accurately', () {
      const progress = DownloadProgress(
        receivedBytes: 36700160, // ~35.0 MB
        totalBytes: 73400320,   // ~70.0 MB
        progress: 0.5,
      );

      expect(progress.receivedMb, '35.0');
      expect(progress.totalMb, '70.0');
      expect(progress.percentage, 50);
    });

    test('checkForUpdate returns AppReleaseInfo when newer release with APK exists', () async {
      final fakeBox = _FakeBox();
      final secureStorage = SecureStorage(fakeBox);

      const fakeJson = '''
      {
        "tag_name": "v1.0.42",
        "name": "Release v1.0.42",
        "body": "## What is changed\\n* Added 2-finger swipe\\n* Added in-app updater",
        "published_at": "2026-11-16T12:00:00Z",
        "assets": [
          {
            "name": "DevDeck.apk",
            "browser_download_url": "https://github.com/wtfnixin/DevDeck/releases/download/v1.0.42/DevDeck.apk",
            "size": 72351744
          }
        ]
      }
      ''';

      final service = AppUpdateService(
        secureStorage: secureStorage,
        versionProvider: () async => '1.0.41',
        clientFactory: () => _FakeHttpClient(statusCode: 200, responseBody: fakeJson),
      );

      final update = await service.checkForUpdate();

      expect(update, isNotNull);
      expect(update!.version, '1.0.42');
      expect(update.tagName, 'v1.0.42');
      expect(update.title, 'Release v1.0.42');
      expect(update.apkDownloadUrl, contains('DevDeck.apk'));
      expect(update.formattedSize, '69.0 MB');
      expect(update.changelog, contains('Added 2-finger swipe'));
    });

    test('checkForUpdate returns null when release is same or older', () async {
      final fakeBox = _FakeBox();
      final secureStorage = SecureStorage(fakeBox);

      const fakeJson = '''
      {
        "tag_name": "v1.0.41",
        "name": "Release v1.0.41",
        "assets": [
          {
            "name": "DevDeck.apk",
            "browser_download_url": "https://example.com/DevDeck.apk",
            "size": 50000000
          }
        ]
      }
      ''';

      final service = AppUpdateService(
        secureStorage: secureStorage,
        versionProvider: () async => '1.0.41',
        clientFactory: () => _FakeHttpClient(statusCode: 200, responseBody: fakeJson),
      );

      final update = await service.checkForUpdate();
      expect(update, isNull);
    });

    test('snoozeUpdate records version in SecureStorage and isUpdateSnoozed honors it', () async {
      final fakeBox = _FakeBox();
      final secureStorage = SecureStorage(fakeBox);

      final service = AppUpdateService(
        secureStorage: secureStorage,
        versionProvider: () async => '1.0.40',
      );

      expect(service.isUpdateSnoozed('1.0.41'), isFalse);
      await service.snoozeUpdate('1.0.41');
      expect(service.isUpdateSnoozed('1.0.41'), isTrue);
      // New version v1.0.42 must NOT be snoozed
      expect(service.isUpdateSnoozed('1.0.42'), isFalse);
    });
  });
}
