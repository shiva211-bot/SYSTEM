import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_sqlcipher/sqflite.dart';

import '../storage/key_vault.dart';

class LocalDatabase {
  final KeyVault vault;
  Database? _db;
  final _aes = AesGcm.with256bits();

  LocalDatabase(this.vault);

  Future<Database> get database async {
    if (_db != null) return _db!;
    final key = await vault.getOrCreateDbKey();
    final root = await getDatabasesPath();
    final path = p.join(root, 'making_system.db');
    _db = await openDatabase(
      path,
      password: key,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE messages (
            id TEXT PRIMARY KEY,
            channel TEXT NOT NULL,
            sender_id TEXT NOT NULL,
            body TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            encrypted INTEGER NOT NULL DEFAULT 1
          )
        ''');
        await db.execute('CREATE INDEX idx_messages_created_at ON messages(created_at DESC)');
        await db.execute('''
          CREATE TABLE pending_messages (
            id TEXT PRIMARY KEY,
            event TEXT NOT NULL,
            payload TEXT NOT NULL,
            created_at INTEGER NOT NULL
          )
        ''');
      },
    );
    return _db!;
  }

  Future<void> saveMessage({
    required String id,
    required String channel,
    required String senderId,
    required String body,
  }) async {
    final db = await database;
    final secretKey = SecretKey(base64Url.decode(await vault.getOrCreateDbKey()));
    final box = await _aes.encrypt(
      utf8.encode(body),
      secretKey: secretKey,
    );
    await db.insert(
      'messages',
      {
        'id': id,
        'channel': channel,
        'sender_id': senderId,
        'body': base64UrlEncode(box.concatenation()),
        'created_at': DateTime.now().millisecondsSinceEpoch,
        'encrypted': 1,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> recentMessages({int limit = 50, int offset = 0}) async {
    final db = await database;
    final rows = await db.query('messages', orderBy: 'created_at DESC', limit: limit, offset: offset);
    final key = SecretKey(base64Url.decode(await vault.getOrCreateDbKey()));
    final result = <Map<String, dynamic>>[];
    for (final row in rows) {
      final box = SecretBox.fromConcatenation(
        base64Url.decode(row['body'] as String),
        nonceLength: _aes.nonceLength,
        macLength: _aes.macAlgorithm.macLength,
      );
      final body = utf8.decode(await _aes.decrypt(box, secretKey: key));
      result.add({...row, 'body': body});
    }
    return result;
  }

  Future<void> queueMessage(String event, Map<String, dynamic> payload) async {
    final db = await database;
    await db.insert('pending_messages', {
      'id': DateTime.now().microsecondsSinceEpoch.toString(),
      'event': event,
      'payload': jsonEncode(payload),
      'created_at': DateTime.now().millisecondsSinceEpoch,
    });
  }

  Future<List<Map<String, dynamic>>> pendingMessages() async {
    final db = await database;
    return db.query('pending_messages', orderBy: 'created_at ASC');
  }

  Future<void> deletePending(String id) async {
    final db = await database;
    await db.delete('pending_messages', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> close() async {
    await _db?.close();
    _db = null;
  }
}
