import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import '../utils/logger.dart';

class SecureStorage {
  static const String _boxName = 'devdeck_secure_box';
  static const String _keyHost = 'paired_host';
  static const String _keyPort = 'paired_port';
  static const String _keyToken = 'auth_token';
  static const String _keyDeviceId = 'device_id';
  static const String _keyDeviceName = 'device_name';
  static const String _keyDesktopSwipeFingers = 'desktop_swipe_fingers';

  final Box _box;

  SecureStorage(this._box);

  static Future<SecureStorage> init() async {
    final box = await Hive.openBox(_boxName);
    final storage = SecureStorage(box);
    
    // Ensure unique deviceId exists
    if (storage.getDeviceId() == null) {
      final newId = const Uuid().v4();
      await storage.saveDeviceId(newId);
      AppLogger.info('Generated new client Device ID: $newId');
    }
    
    return storage;
  }

  String? getHost() => _box.get(_keyHost) as String?;
  int? getPort() => _box.get(_keyPort) as int?;
  String? getAuthToken() => _box.get(_keyToken) as String?;
  String? getDeviceId() => _box.get(_keyDeviceId) as String?;
  String? getDeviceName() => _box.get(_keyDeviceName) as String? ?? 'Flutter Client';

  Future<void> savePairingData({
    required String host,
    required int port,
    required String token,
  }) async {
    await _box.put(_keyHost, host);
    await _box.put(_keyPort, port);
    await _box.put(_keyToken, token);
    AppLogger.info('Saved connection & auth credentials to Hive.');
  }

  Future<void> saveDeviceName(String name) async {
    await _box.put(_keyDeviceName, name);
  }

  Future<void> saveDeviceId(String id) async {
    await _box.put(_keyDeviceId, id);
  }

  Future<void> clearPairingData() async {
    await _box.delete(_keyHost);
    await _box.delete(_keyPort);
    await _box.delete(_keyToken);
    AppLogger.info('Cleared pairing credentials from Hive.');
  }

  bool isPaired() {
    final host = getHost();
    final token = getAuthToken();
    return host != null && token != null;
  }

  bool getClipboardSyncEnabled() => _box.get('clipboard_sync_enabled', defaultValue: true) as bool;
  Future<void> setClipboardSyncEnabled(bool enabled) async => await _box.put('clipboard_sync_enabled', enabled);

  int getDesktopSwipeFingers() => _box.get(_keyDesktopSwipeFingers, defaultValue: 2) as int;
  Future<void> setDesktopSwipeFingers(int fingers) async => await _box.put(_keyDesktopSwipeFingers, fingers);
}
