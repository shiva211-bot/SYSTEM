import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';

class ConversationsScreen extends ConsumerWidget {
  const ConversationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Expanded(child: Text('Conversations', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800))),
              IconButton.filledTonal(
                onPressed: () => _createGroup(context, ref),
                icon: const Icon(Icons.group_add),
                tooltip: 'Create Group',
              ),
            ]),
            const SizedBox(height: 4),
            const Text('Private E2EE conversations and group rooms.'),
            const SizedBox(height: 18),
            Expanded(
              child: ListView(
                children: [
                  _section('Private', Icons.lock_outline, [
                    _conversation('Encrypted 1-on-1', 'RSA-OAEP-256 + AES-256-GCM', true),
                  ]),
                  _section('Groups', Icons.groups_outlined, [
                    ...state.conversations.map((c) => _conversation('${c['name']}', 'Group room', false)),
                    if (state.conversations.isEmpty) _empty('No groups yet. Create the first room.'),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String title, IconData icon, List<Widget> children) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [Icon(icon, size: 19), const SizedBox(width: 8), Text(title, style: const TextStyle(fontWeight: FontWeight.w800))]),
          const SizedBox(height: 8),
          ...children,
          const SizedBox(height: 18),
        ],
      );

  Widget _conversation(String title, String subtitle, bool locked) => Card(
        child: ListTile(
          leading: CircleAvatar(child: Icon(locked ? Icons.lock : Icons.groups)),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
        ),
      );

  Widget _empty(String text) => Padding(padding: const EdgeInsets.all(18), child: Text(text));

  Future<void> _createGroup(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Group'),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(labelText: 'Group name')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Create')),
        ],
      ),
    );
    controller.dispose();
    if (name != null && name.trim().isNotEmpty) ref.read(appControllerProvider).createGroup(name);
  }
}
