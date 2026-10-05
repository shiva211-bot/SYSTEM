import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/crypto/crypto_engine.dart';
import 'core/database/local_database.dart';
import 'core/network/api_client.dart';
import 'core/network/socket_service.dart';
import 'core/storage/key_vault.dart';
import 'core/theme.dart';
import 'features/home/app_controller.dart';
import 'features/home/home_shell.dart';

final keyVaultProvider = Provider<KeyVault>((ref) => const KeyVault());
final cryptoProvider = Provider<CryptoEngine>((ref) => CryptoEngine(ref.read(keyVaultProvider)));
final databaseProvider = Provider<LocalDatabase>((ref) => LocalDatabase(ref.read(keyVaultProvider)));
final socketProvider = Provider<SocketService>((ref) => SocketService(
      database: ref.read(databaseProvider),
      crypto: ref.read(cryptoProvider),
    ));
final apiProvider = Provider<ApiClient>((ref) => ApiClient());
final appControllerProvider = ChangeNotifierProvider<AppController>((ref) => AppController(
      vault: ref.read(keyVaultProvider),
      crypto: ref.read(cryptoProvider),
      database: ref.read(databaseProvider),
      socket: ref.read(socketProvider),
      api: ref.read(apiProvider),
    ));

class MakingSystemApp extends ConsumerStatefulWidget {
  const MakingSystemApp({super.key});

  @override
  ConsumerState<MakingSystemApp> createState() => _MakingSystemAppState();
}

class _MakingSystemAppState extends ConsumerState<MakingSystemApp> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.read(appControllerProvider).initialize());
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Making System',
      theme: AppTheme.dark(),
      home: const HomeShell(),
    );
  }
}
