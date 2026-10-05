import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appControllerProvider);
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: state.refreshTelemetry,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
          children: [
            const Text('System & Profile', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            _identityCard(context, state),
            const SizedBox(height: 12),
            _telemetryCard(state),
            const SizedBox(height: 12),
            _walletCard(state),
            const SizedBox(height: 12),
            _achievementsCard(state),
            const SizedBox(height: 12),
            _keysCard(context, ref),
          ],
        ),
      ),
    );
  }

  Widget _identityCard(BuildContext context, dynamic state) => Card(
        child: ListTile(
          leading: CircleAvatar(radius: 25, child: Text(state.username.isEmpty ? 'U' : state.username.substring(0, 1).toUpperCase())),
          title: Text(state.username, style: const TextStyle(fontWeight: FontWeight.w800)),
          subtitle: Text('Selected title: ${state.title}'),
          trailing: const Icon(Icons.verified_user_outlined),
        ),
      );

  Widget _telemetryCard(dynamic state) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Live network telemetry', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _metric('Ping', '${state.pingMs} ms'),
                _metric('Total Messages', '${state.totalMessages}'),
                _metric('Active Sockets', '${state.activeSockets}'),
                _metric('Online Users', '${state.onlineUsers}'),
              ],
            ),
          ]),
        ),
      );

  Widget _metric(String label, String value) => Container(
        width: 145,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), color: const Color(0xFF171922)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 12)),
          const SizedBox(height: 5),
          Text(value, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
        ]),
      );

  Widget _walletCard(dynamic state) => Card(
        child: ListTile(
          leading: const Icon(Icons.account_balance_wallet_outlined),
          title: const Text('Wallet Balance'),
          subtitle: Text('Rank points: ${state.rankPoints}'),
          trailing: Text('¤${state.currency}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        ),
      );

  Widget _achievementsCard(dynamic state) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Unlocked Achievements', style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: state.achievements.map<Widget>((a) => Chip(label: Text(a))).toList()),
          ]),
        ),
      );

  Widget _keysCard(BuildContext context, WidgetRef ref) => Card(
        child: Column(children: [
          const ListTile(
            leading: Icon(Icons.key_outlined),
            title: Text('Key Export'),
            subtitle: Text('Export the public identity or an encrypted private backup.'),
          ),
          ButtonBar(
            children: [
              OutlinedButton.icon(
                onPressed: () async {
                  final value = await ref.read(appControllerProvider).exportPublicKey();
                  await Clipboard.setData(ClipboardData(text: value));
                  if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Public identity copied')));
                },
                icon: const Icon(Icons.public),
                label: const Text('Copy public key'),
              ),
              FilledButton.icon(
                onPressed: () => _privateBackup(context, ref),
                icon: const Icon(Icons.download),
                label: const Text('Export backup'),
              ),
            ],
          ),
        ]),
      );

  Future<void> _privateBackup(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController();
    final passphrase = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Encrypt private backup'),
        content: TextField(
          controller: controller,
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Backup passphrase', helperText: 'Use at least 12 characters.'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Export')),
        ],
      ),
    );
    controller.dispose();
    if (passphrase == null) return;
    try {
      final backup = await ref.read(appControllerProvider).exportPrivateBackup(passphrase);
      await Clipboard.setData(ClipboardData(text: backup));
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Encrypted backup copied')));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }
}
