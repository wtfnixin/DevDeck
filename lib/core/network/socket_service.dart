import 'dart:async';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../storage/secure_storage.dart';
import '../utils/logger.dart';

enum ConnectionStatus {
  connecting,
  connected,
  disconnected,
  pairingRequired,
}

class SocketService {
  final SecureStorage _storage;
  io.Socket? _socket;
  
  final _statusController = StreamController<ConnectionStatus>.broadcast();
  Stream<ConnectionStatus> get statusStream => _statusController.stream;
  
  ConnectionStatus _currentStatus = ConnectionStatus.disconnected;
  ConnectionStatus get currentStatus => _currentStatus;

  SocketService(this._storage);

  void _updateStatus(ConnectionStatus status) {
    _currentStatus = status;
    _statusController.add(status);
    AppLogger.info('Connection status changed to: $status');
  }

  void connect({String? customHost, int? customPort, String? token}) {
    disconnect();

    final host = customHost ?? _storage.getHost();
    final port = customPort ?? _storage.getPort();
    final jwtToken = token ?? _storage.getAuthToken();

    if (host == null || port == null) {
      _updateStatus(ConnectionStatus.pairingRequired);
      return;
    }

    final url = 'http://$host:$port';
    AppLogger.info('Connecting to Socket.IO server at $url...');
    _updateStatus(ConnectionStatus.connecting);

    final options = io.OptionBuilder()
        .setTransports(['websocket'])
        .disableAutoConnect()
        .setAuth({'token': jwtToken})
        .setReconnectionAttempts(10)
        .setReconnectionDelay(2000)
        .enableForceNew()
        .build();

    _socket = io.io(url, options);

    _socket!.onConnect((_) {
      _updateStatus(ConnectionStatus.connected);
    });

    _socket!.onDisconnect((reason) {
      AppLogger.warning('Socket disconnected: $reason');
      _updateStatus(ConnectionStatus.disconnected);
    });

    _socket!.onConnectError((err) {
      AppLogger.error('Socket connect error: $err');
      final errMsg = err.toString().toLowerCase();
      if (errMsg.contains('authenticated') ||
          errMsg.contains('authentication') ||
          errMsg.contains('sign') ||
          errMsg.contains('auth')) {
        AppLogger.warning('Token rejected by server. Clearing invalid credentials...');
        _storage.clearPairingData();
        _updateStatus(ConnectionStatus.pairingRequired);
      } else {
        _updateStatus(ConnectionStatus.disconnected);
      }
    });

    _socket!.onReconnectAttempt((attempt) {
      AppLogger.info('Socket reconnecting, attempt: $attempt');
      _updateStatus(ConnectionStatus.connecting);
    });

    _socket!.on('connection:status', (data) {
      if (data is Map && data['status'] == 'pairingRequired') {
        _updateStatus(ConnectionStatus.pairingRequired);
      }
    });

    _socket!.connect();
  }

  void disconnect() {
    if (_socket != null) {
      _socket!.disconnect();
      _socket!.dispose();
      _socket = null;
      _updateStatus(ConnectionStatus.disconnected);
    }
  }

  void emit(String event, dynamic data, {Function(dynamic)? ack}) {
    if (_socket == null || !_socket!.connected) {
      AppLogger.warning('Cannot emit event $event: Socket not connected.');
      return;
    }
    
    if (ack != null) {
      _socket!.emitWithAck(event, data, ack: ack);
    } else {
      _socket!.emit(event, data);
    }
  }

  void on(String event, Function(dynamic) handler) {
    if (_socket == null) {
      AppLogger.warning('Cannot register listener for $event: Socket is null.');
      return;
    }
    _socket!.on(event, handler);
  }

  void off(String event) {
    if (_socket == null) return;
    _socket!.off(event);
  }

  bool get isConnected => _socket?.connected ?? false;

  /// Returns the base HTTP URL of the agent (e.g. "http://192.168.1.5:8080")
  /// Returns null if not paired yet.
  String? get agentBaseUrl {
    final host = _storage.getHost();
    final port = _storage.getPort();
    if (host == null || port == null) return null;
    return 'http://$host:$port';
  }
}
