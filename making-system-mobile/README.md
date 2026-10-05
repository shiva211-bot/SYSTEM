# Making System Mobile

Flutter/Android client for the Making System realtime chat platform.

## Architecture

```text
Flutter UI
  └─ Riverpod AppController
      ├─ REST ApiClient
      │    ├─ /health /ready
      │    ├─ /api/v1/users/:id
      │    ├─ /api/v1/leaderboard
      │    └─ /api/v1/system
      ├─ SocketService
      │    ├─ join_global
      │    ├─ send_global_message
      │    ├─ join_room
      │    ├─ send_group_message
      │    └─ send_direct_message
      ├─ CryptoEngine
      │    ├─ RSA-2048 / OAEP-SHA256 key wrapping
      │    ├─ AES-256-GCM message encryption
      │    └─ Ed25519 envelope signatures
      ├─ KeyVault
      │    └─ Android/iOS secure storage
      └─ LocalDatabase
           └─ SQLCipher encrypted SQLite
```

## Requirements

Use a current Flutter stable release compatible with Dart 3.12+. `go_router` is intentionally not required: the four primary tabs are a persistent navigation shell, while feature-specific dialogs/screens can be added without replacing the shell.

## Setup

```bash
flutter create . --platforms=android
flutter pub get
flutter analyze
flutter test
```

Run against the backend locally:

```bash
flutter run \
  --dart-define=API_BASE_URL=http://10.0.2.2:3000 \
  --dart-define=SOCKET_URL=http://10.0.2.2:3000 \
  --dart-define=JWT_TOKEN=YOUR_JWT
```

For a physical Android device, replace `10.0.2.2` with the reachable IP/hostname of the backend.

## Authentication

The Phase 2 backend expects an existing JWT. This client reads `auth.jwt` from secure storage. The CI workflow can also inject `JWT_TOKEN` as a GitHub Actions secret for test/release environments.

The client does not mint JWTs and does not embed `JWT_SECRET`.

## E2EE protocol

Direct messages use a hybrid envelope:

1. Generate a fresh random AES-256 key.
2. Encrypt the plaintext with AES-256-GCM.
3. Wrap the AES key using the recipient's RSA-2048 public key with RSA-OAEP-SHA256.
4. Sign the envelope with the sender's Ed25519 private key.
5. Send only the encrypted envelope through Socket.IO.

RSA is deliberately used to wrap the short symmetric key rather than encrypting the entire chat message. RSA-OAEP-2048 with SHA-256 has a small plaintext limit.

The server therefore transports opaque ciphertext for E2EE direct messages. Group E2EE should be implemented as a separate room-key protocol before claiming full group E2EE.

## Local persistence

`LocalDatabase` uses SQLCipher through `sqflite_sqlcipher`. The database password is generated once and stored in `flutter_secure_storage`. Message bodies are additionally encrypted before insertion. This provides both encrypted database storage and application-level ciphertext at rest.

## Key export

The profile screen can:

- copy the public identity bundle; or
- create an encrypted private-key backup protected by an Argon2id-derived AES-256-GCM key.

Never export or log raw private keys without explicit user intent.

## Backend compatibility note

The Phase 2 server currently emits `network_stats` for telemetry. The client listens to both `network_stats` and `presence_update`. If the backend is changed to emit `presence_update`, no client change is required.

The Phase 2 backend does not yet provide a public-key directory endpoint or persistent room-membership authorization. Before enabling production direct/group E2EE, add authenticated public-key registration/lookup and server-side room membership checks.

## GitHub Actions

`.github/workflows/build_apk.yml`:

- triggers on every push to `main`;
- creates the Android platform wrapper if the generated Flutter native files are not committed;
- runs `flutter analyze`;
- runs `flutter test`;
- builds a release APK;
- uploads `app-release.apk` as a workflow artifact.

For production signing, add a keystore, encrypted GitHub secrets, and a dedicated signing step. Do not commit signing keys.
