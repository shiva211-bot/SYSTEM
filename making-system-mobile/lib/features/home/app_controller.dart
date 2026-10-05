import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../core/crypto/crypto_engine.dart';
import '../../core/database/local_database.dart';
import '../../core/network/api_client.dart';
import '../../core/network/socket_service.dart';
import '../../core/storage/key_vault.dart';

class AppController extends ChangeNotifier {
  final KeyVault vault;
  final CryptoEngine crypto;
  final LocalDatabase database;
  final SocketService socket;
  final ApiClient api;

  StreamSubscription<Map<String, dynamic>>? _eventsSub;
  int tabIndex = 0;
  bool initialized = false;
  String? error;
  String? userId;
  String username = 'Anonymous';
  int rankPoints = 0;
  int currency = 0;
  int onlineUsers = 0;
  int activeSockets = 0;
  int totalMessages = 0;
  int cooldown = 0;
  int messageOffset = 0;
  List<Map<String, dynamic>> leaderboard = [];
  List<Map<String, dynamic>> conversations = [];
  List<Map<String, dynamic>> messages = [];
  List<String> achievements = ['First Login'];
  String title = 'Newcomer';
  DateTime? pingAt;
  int pingMs = 0;

  AppController({
    required this.vault,
    required this.crypto,
    required this.database,
    required this.socket,
    required this.api,
  });

  Future<void> initialize() async {
    if (initialized) return;
    try {
      await crypto.ensureIdentity();
      messages = await database.recentMessages(limit: 50);
      messageOffset = messages.length;
      final token = await vault.read('auth.jwt');
      final compileToken = const String.fromEnvironment('JWT_TOKEN');
      final activeToken = token?.isNotEmpty == true ? token! : compileToken;
      if (activeToken.isNotEmpty) {
        api.token = activeToken;
        userId = _subjectFromJwt(activeToken);
        socket.connect(activeToken);
        socket.joinGlobal();
        _eventsSub = socket.events.listen(_onSocketEvent);
        await refreshTelemetry();
      }
      initialized = true;
    } catch (e) {
      error = e.toString();
      initialized = true;
    }
    notifyListeners();
  }

  void setTab(int index) {
    tabIndex = index;
    notifyListeners();
    if (index == 2) refreshLeaderboard();
    if (index == 3) refreshTelemetry();
  }


  Future<void> loadOlderMessages() async {
    final older = await database.recentMessages(limit: 50, offset: messageOffset);
    if (older.isEmpty) return;
    messages = [...messages, ...older];
    messageOffset += older.length;
    notifyListeners();
  }

  Future<void> sendGlobal(String text) async {
    if (text.trim().isEmpty) return;
    await socket.sendGlobal(text.trim());
    cooldown = socket.cooldownRemaining;
    notifyListeners();
  }

  Future<void> refreshLeaderboard() async {
    if (api.token == null) return;
    try {
      final data = await api.getList('/api/v1/leaderboard?limit=50');
      leaderboard = data.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      notifyListeners();
    } catch (e) {
      error = e.toString();
      notifyListeners();
    }
  }

  Future<void> refreshTelemetry() async {
    if (api.token == null) return;
    try {
      final start = DateTime.now();
      final data = await api.getJson('/api/v1/system');
      pingMs = DateTime.now().difference(start).inMilliseconds;
      pingAt = DateTime.now();
      onlineUsers = (data['onlineUsers'] ?? socket.onlineUsers) as int;
      activeSockets = (data['activeSockets'] ?? socket.activeSockets) as int;
      totalMessages = (data['totalMessages'] ?? socket.totalMessages) as int;
      final user = await api.getJson('/api/v1/users/${userId ?? 'me'}');
      username = '${user['username'] ?? username}';
      rankPoints = (user['rankPoints'] ?? rankPoints) as int;
      currency = (user['currency'] ?? currency) as int;
      notifyListeners();
    } catch (_) {
      onlineUsers = socket.onlineUsers;
      activeSockets = socket.activeSockets;
      totalMessages = socket.totalMessages;
      pingMs = pingAt == null ? 0 : pingMs;
      notifyListeners();
    }
  }

  Future<String> exportPublicKey() => crypto.exportPublicIdentity();

  Future<String> exportPrivateBackup(String passphrase) => crypto.exportEncryptedPrivateBackup(passphrase);

  void createGroup(String name) {
    if (name.trim().isEmpty) return;
    conversations = [
      ...conversations,
      {'id': 'local-${DateTime.now().millisecondsSinceEpoch}', 'name': name.trim(), 'type': 'group'},
    ];
    notifyListeners();
  }

  void _onSocketEvent(Map<String, dynamic> event) {
    switch (event['type']) {
      case 'cooldown':
        cooldown = event['seconds'] as int;
        break;
      case 'presence':
        onlineUsers = event['onlineUsers'] as int;
        activeSockets = event['activeSockets'] as int;
        totalMessages = event['totalMessages'] as int;
        break;
      case 'message':
        final data = Map<String, dynamic>.from(event['data'] as Map);
        messages = [
          {'channel': event['channel'], ...data},
          ...messages,
        ];
        break;
      case 'achievement':
        achievements = [...achievements, '${event['data']}'];
        break;
      case 'error':
        error = '${event['data']}';
        break;
    }
    notifyListeners();
  }

  String? _subjectFromJwt(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      final normalized = base64Url.normalize(parts[1]);
      final payload = jsonDecode(utf8.decode(base64Url.decode(normalized))) as Map<String, dynamic>;
      return payload['sub']?.toString() ?? payload['userId']?.toString();
    } catch (_) {
      return null;
    }
  }

  @override
  void dispose() {
    _eventsSub?.cancel();
    socket.dispose();
    database.close();
    super.dispose();
  }
}
