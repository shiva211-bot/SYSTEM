import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app.dart';

class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(appControllerProvider).refreshLeaderboard());
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appControllerProvider);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Leaderboard', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            const Text('Rank points first, currency as the secondary score.'),
            const SizedBox(height: 16),
            Expanded(
              child: RefreshIndicator(
                onRefresh: state.refreshLeaderboard,
                child: ListView.builder(
                  itemCount: state.leaderboard.length,
                  itemBuilder: (context, index) {
                    final row = state.leaderboard[index];
                    final isCurrent = '${row['id']}' == state.userId;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      color: isCurrent ? Theme.of(context).colorScheme.primaryContainer : null,
                      child: ListTile(
                        leading: CircleAvatar(child: Text('${row['rank'] ?? index + 1}')),
                        title: Text('${row['username'] ?? row['id'] ?? 'User'}'),
                        subtitle: Text('${row['messageCount'] ?? 0} messages'),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('${row['rankPoints'] ?? 0} RP', style: const TextStyle(fontWeight: FontWeight.w800)),
                            Text('¤${row['currency'] ?? 0}'),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
