class NetworkStats {
  final int pingMs;
  final int totalMessages;
  final int activeSockets;
  final int onlineUsers;

  const NetworkStats({
    required this.pingMs,
    required this.totalMessages,
    required this.activeSockets,
    required this.onlineUsers,
  });
}
