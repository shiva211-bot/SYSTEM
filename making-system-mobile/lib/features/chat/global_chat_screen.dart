import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';

class GlobalChatScreen extends ConsumerStatefulWidget {
  const GlobalChatScreen({super.key});

  @override
  ConsumerState<GlobalChatScreen> createState() => _GlobalChatScreenState();
}

class _GlobalChatScreenState extends ConsumerState<GlobalChatScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool loadingMore = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(() {
      if (_scrollController.position.pixels <= 160 && !loadingMore) {
        loadingMore = true;
        ref.read(appControllerProvider).loadOlderMessages().whenComplete(() {
          if (mounted) setState(() => loadingMore = false);
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider);
    final messages = state.messages.where((m) => m['channel'] == 'global').toList();
    return SafeArea(
      child: Column(
        children: [
          _header(state),
          if (state.cooldown > 0) _cooldown(state.cooldown),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => state.refreshTelemetry(),
              child: ListView.builder(
                controller: _scrollController,
                reverse: true,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final message = messages[messages.length - 1 - index];
                  return _messageTile(message);
                },
              ),
            ),
          ),
          _composer(state),
        ],
      ),
    );
  }

  Widget _header(dynamic state) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
        child: Row(
          children: [
            const Expanded(
              child: Text('Global Chat', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800)),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(99),
                color: Colors.green.withValues(alpha: .12),
              ),
              child: Row(children: [
                Container(width: 7, height: 7, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                const SizedBox(width: 7),
                Text('${state.onlineUsers} online'),
              ]),
            ),
          ],
        ),
      );

  Widget _cooldown(int seconds) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 4),
        child: LinearProgressIndicator(value: 1 - (seconds / 10)),
      );

  Widget _messageTile(Map<String, dynamic> message) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${message['senderId'] ?? message['sender_id'] ?? 'user'}', style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 5),
            Text('${message['content'] ?? message['body'] ?? ''}'),
          ]),
        ),
      );

  Widget _composer(dynamic state) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                maxLength: 16000,
                minLines: 1,
                maxLines: 4,
                decoration: const InputDecoration(hintText: 'Write to global chat…', counterText: ''),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: state.cooldown > 0 ? null : () async {
                final text = _controller.text;
                _controller.clear();
                await ref.read(appControllerProvider).sendGlobal(text);
              },
              icon: const Icon(Icons.send),
            ),
          ],
        ),
      );

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
