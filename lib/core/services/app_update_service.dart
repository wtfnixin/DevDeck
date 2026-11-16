import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import '../storage/secure_storage.dart';
import '../utils/logger.dart';

class AppReleaseInfo {
  final String version;
  final String tagName;
  final String title;
  final String changelog;
  final String apkDownloadUrl;
  final int apkSizeBytes;
  final DateTime publishedAt;

  const AppReleaseInfo({
    required this.version,
    required this.tagName,
    required this.title,
    required this.changelog,
    required this.apkDownloadUrl,
    required this.apkSizeBytes,
    required this.publishedAt,
  });

  String get formattedSize {
    if (apkSizeBytes <= 0) return '';
    final mb = apkSizeBytes / (1024 * 1024);
    return '${mb.toStringAsFixed(1)} MB';
  }
}

class DownloadProgress {
  final int receivedBytes;
  final int totalBytes;
  final double progress;

  const DownloadProgress({
    required this.receivedBytes,
    required this.totalBytes,
    required this.progress,
  });

  String get receivedMb => (receivedBytes / (1024 * 1024)).toStringAsFixed(1);
  String get totalMb => totalBytes > 0
      ? (totalBytes / (1024 * 1024)).toStringAsFixed(1)
      : '--';
  int get percentage => (progress * 100).clamp(0, 100).toInt();
}

class AppUpdateService {
  static const String githubReleasesUrl =
      'https://api.github.com/repos/wtfnixin/DevDeck/releases/latest';
  static const MethodChannel _channel = MethodChannel('devdeck/app_installer');

  AppUpdateService({
    required this.secureStorage,
    HttpClient Function()? clientFactory,
    Future<String> Function()? versionProvider,
  })  : _clientFactory = clientFactory ?? HttpClient.new,
        _versionProvider = versionProvider;

  final SecureStorage secureStorage;
  final HttpClient Function() _clientFactory;
  final Future<String> Function()? _versionProvider;

  /// Returns the currently installed application version (e.g. "1.0.41").
  Future<String> getCurrentVersion() async {
    if (_versionProvider != null) {
      return _versionProvider!();
    }
    try {
      final version = await _channel.invokeMethod<String>('getAppVersion');
      return (version != null && version.isNotEmpty) ? version : '1.0.0';
    } catch (e) {
      AppLogger.error('Failed to get app version from native channel', e);
      return '1.0.0';
    }
  }

  /// Checks GitHub for the latest release and returns [AppReleaseInfo] if a newer version is available.
  Future<AppReleaseInfo?> checkForUpdate() async {
    try {
      final currentVersion = await getCurrentVersion();
      final client = _clientFactory();
      client.connectionTimeout = const Duration(seconds: 10);

      final request = await client.getUrl(Uri.parse(githubReleasesUrl));
      request.headers.add('Accept', 'application/vnd.github.v3+json');
      request.headers.add('User-Agent', 'DevDeck-Mobile');

      final response = await request.close();
      if (response.statusCode != 200) {
        AppLogger.warning('GitHub Releases API returned status ${response.statusCode}');
        return null;
      }

      final responseBody = await response.transform(utf8.decoder).join();
      final json = jsonDecode(responseBody) as Map<String, dynamic>;

      final tagName = json['tag_name'] as String? ?? '';
      final title = json['name'] as String? ?? 'Release $tagName';
      final rawBody = json['body'] as String?;
      final publishedAtStr = json['published_at'] as String?;
      final publishedAt = publishedAtStr != null
          ? DateTime.tryParse(publishedAtStr) ?? DateTime.now()
          : DateTime.now();

      final assets = json['assets'] as List<dynamic>? ?? [];
      String? apkUrl;
      int apkSize = 0;

      for (final asset in assets) {
        if (asset is Map<String, dynamic>) {
          final name = asset['name'] as String? ?? '';
          if (name == 'DevDeck.apk' || name.endsWith('.apk')) {
            apkUrl = asset['browser_download_url'] as String?;
            apkSize = (asset['size'] as num?)?.toInt() ?? 0;
            break;
          }
        }
      }

      if (apkUrl == null || tagName.isEmpty) {
        return null;
      }

      final latestNormalized = normalizeVersion(tagName);
      final currentNormalized = normalizeVersion(currentVersion);

      if (!isVersionNewer(latestNormalized, currentNormalized)) {
        return null;
      }

      final changelog = (rawBody != null && rawBody.trim().isNotEmpty)
          ? rawBody.trim()
          : 'New updates and stability improvements for DevDeck.';

      return AppReleaseInfo(
        version: latestNormalized,
        tagName: tagName,
        title: title,
        changelog: changelog,
        apkDownloadUrl: apkUrl,
        apkSizeBytes: apkSize,
        publishedAt: publishedAt,
      );
    } catch (e) {
      AppLogger.error('Failed to check for updates from GitHub', e);
      return null;
    }
  }

  /// Downloads the APK from [downloadUrl] and saves it to [destinationPath],
  /// yielding live [DownloadProgress] events.
  Stream<DownloadProgress> downloadApk(
    String downloadUrl,
    String destinationPath,
  ) async* {
    final client = _clientFactory();
    client.connectionTimeout = const Duration(seconds: 15);

    final request = await client.getUrl(Uri.parse(downloadUrl));
    request.headers.add('User-Agent', 'DevDeck-Mobile');
    final response = await request.close();

    if (response.statusCode != 200) {
      throw HttpException('Failed to download APK (HTTP ${response.statusCode})');
    }

    final totalBytes = response.contentLength;
    int receivedBytes = 0;

    final targetFile = File(destinationPath);
    if (await targetFile.exists()) {
      await targetFile.delete();
    }
    await targetFile.create(recursive: true);

    final sink = targetFile.openWrite();

    try {
      await for (final chunk in response) {
        receivedBytes += chunk.length;
        sink.add(chunk);
        final progress = totalBytes > 0 ? (receivedBytes / totalBytes) : 0.0;
        yield DownloadProgress(
          receivedBytes: receivedBytes,
          totalBytes: totalBytes,
          progress: progress,
        );
      }
      await sink.flush();
    } finally {
      await sink.close();
    }
  }

  /// Dispatches Android system package installer intent to install the APK file.
  Future<void> installApk(String destinationPath) async {
    try {
      await _channel.invokeMethod('installApk', {'filePath': destinationPath});
    } catch (e) {
      AppLogger.error('Failed to launch APK installation intent', e);
      rethrow;
    }
  }

  /// Returns true if the user snoozed the update dialog for this specific [version].
  bool isUpdateSnoozed(String version) {
    return secureStorage.getSnoozedUpdateVersion() == version;
  }

  /// Saves the snoozed version so the dialog doesn't re-prompt during the session.
  Future<void> snoozeUpdate(String version) async {
    await secureStorage.setSnoozedUpdateVersion(version);
  }

  /// Removes leading 'v' or 'V' and trims whitespace.
  static String normalizeVersion(String v) {
    return v.trim().replaceFirst(RegExp(r'^[vV]'), '');
  }

  /// Compares two semver-like version strings (e.g. "1.0.41" vs "1.0.40").
  /// Returns true if [latest] is strictly greater than [current].
  static bool isVersionNewer(String latest, String current) {
    final lParts = _parseVersionParts(latest);
    final cParts = _parseVersionParts(current);

    final maxLen = lParts.length > cParts.length ? lParts.length : cParts.length;
    for (int i = 0; i < maxLen; i++) {
      final l = i < lParts.length ? lParts[i] : 0;
      final c = i < cParts.length ? cParts[i] : 0;
      if (l > c) return true;
      if (l < c) return false;
    }
    return false;
  }

  static List<int> _parseVersionParts(String version) {
    final clean = normalizeVersion(version).split(RegExp(r'[-+]')).first;
    return clean
        .split('.')
        .map((part) => int.tryParse(part) ?? 0)
        .toList();
  }
}

