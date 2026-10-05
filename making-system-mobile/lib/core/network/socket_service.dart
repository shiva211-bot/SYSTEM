import 'dart:async';
import 'dart:convert';

import 'package:socket_io_client/socket_io_client.dart' as io;

import '../config.dart';
import '../crypto/crypto_engine.dart';
import '../database/local_database.dart';

class SocketService {
  final LocalDatabase database;
  final CryptoEngine crypto;

  io.Socket? _socket;
  String? _token;
  Timer? _cooldownTimer;
  int cooldownRemaining = 0;
  int onlineUsers = 0;
  int activeSockets = 0;
  int totalMessages = 0;
  bool connected = false;

  final _events = StreamController<Map<String, dynamic>>.broadcast();
  Stream<Map<String, dynamic>> get events => _events.stream;

  SocketService({required this.database, required this.crypto});

  void connect(String jwt) {
    _token = jwt;
    _socket?.dispose();

    _socket = io.io(
      AppConfig.socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': jwt})
          .enableReconnection()
          .setReconnectionAttempts(0)
          .setReconnectionDelay(500)
          .setReconnectionDelayMax(10000)
          .build(),
    );

    _socket!
      ..onConnect((_) {
        connected = true;
        _events.add({'type': 'connection', 'connected': true});
      })
      ..onDisconnect((_) {
        connected = false;
        _events.add({'type': 'connection', 'connected': false});
      })
      ..on('global_message', (data) => _handleMessage('global', data))
      ..on('group_message', (data) => _handleMessage('group', data))
      ..on('direct_message', (data) => _handleMessage('direct', data))
      ..on('presence_update', (data) => _handlePresence(data))
      ..on('network_stats', (data) => _handlePresence(data))
      ..on('achievement_unlocked', (data) => _events.add({'type': 'achievement', 'data': data}))
      ..on('operation_error', (data) => _events.add({'type': 'error', 'data': data}));
  }

  void joinGlobal() => _socket?.emit('join_global');

  void joinRoom(String roomId) => _socket?.emitWithAck('join_room', {'roomId': roomId}, ack: (data) {});

  Future<void> sendGlobal(String content) async {
    await _send('send_global_message', {'content': content});
  }

  Future<void> sendGroup(String roomId, String content) async {
    await _send('send_group_message', {'roomId': roomId, 'content': content});
  }

  Future<void> sendDirect({
    required String recipientId,
    required Map<String, dynamic> recipientRsaPublic,
    required String recipientEd25519Public,
    required String plaintext,
  }) async {
    final encrypted = await crypto.encryptDirectMessage(
      plaintext: plaintext,
      receiverRsaPublic: recipientRsaPublic,
      receiverEd25519Public: recipientEd25519Public,
    );
    await _send('send_direct_message', {
      'recipientId': recipientId,
      'content': encrypted,
      'encrypted': true,
    });
  }

  Future<void> _send(String event, Map<String, dynamic> payload) async {
    if (_socket == null || !connected) {
      await database.queueMessage(event, payload);
      _events.add({'type': 'queued', 'event': event});
      return;
    }
    if (cooldownRemaining > 0) return;
    _socket!.emit(event, payload);
    _startCooldown();
  }

  void _startCooldown() {
    _cooldownTimer?.cancel();
    cooldownRemaining = AppConfig.messageCooldownSeconds;
    _events.add({'type': 'cooldown', 'seconds': cooldownRemaining});
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      cooldownRemaining--;
      _events.add({'type': 'cooldown', 'seconds': cooldownRemaining});
      if (cooldownRemaining <= 0) timer.cancel();
    });
  }

  Future<void> flushPending() async {
    if (!connected) return;
    final pending = await database.pendingMessages();
    for (final item in pending) {
      _socket?.emit(item['event'] as String, jsonDecode(item['payload'] as String));
      await database.deletePending(item['id'] as String);
    }
  }

  Future<void> _handleMessage(String channel, dynamic data) async {
    final map = data is Map ? Map<String, dynamic>.from(data) : {'content': data};
    final senderId = '${map['senderId'] ?? map['sender_id'] ?? 'unknown'}';
    final id = '${map['id'] ?? DateTime.now().microsecondsSinceEpoch}';
    final content = '${map['content'] ?? ''}';
    final storedContent = channel == 'direct' && map['encrypted'] == true
        ? _decryptOrPlaceholder(content)
        : Future.value(content);
    final visible = await storedContent;
    await database.saveMessage(id: id, channel: channel, senderId: senderId, body: visible);
    totalMessages++;
    _events.add({'type': 'message', 'channel': channel, 'data': map});
  }

  Future<String> _decryptOrPlaceholder(String content) async {
    try {
      return await crypto.decryptDirectMessage(content);
    } catch (_) {
      return '[Encrypted message]';
    }
  }

  void _handlePresence(dynamic data) {
    if (data is Map) {
      final map = Map<String, dynamic>.from(data);
      onlineUsers = (map['onlineUsers'] ?? map['online_users'] ?? onlineUsers) as int;
      activeSockets = (map['activeSockets'] ?? map['active_sockets'] ?? activeSockets) as int;
      totalMessages = (map['totalMessages'] ?? map['total_messages'] ?? totalMessages) as int;
    }
    _events.add({
      'type': 'presence',
      'onlineUsers': onlineUsers,
      'activeSockets': activeSockets,
      'totalMessages': totalMessages,
    });
  }

  Future<void> dispose() async {
    _cooldownTimer?.cancel();
    await _events.close();
    _socket?.dispose();
  }
}
