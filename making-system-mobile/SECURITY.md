# Mobile security baseline

- Never ship `JWT_SECRET`, database credentials, or backend signing secrets.
- Store JWTs and private identity keys only in secure storage.
- Do not log plaintext direct-message content.
- Direct messages must use authenticated encryption and recipient public keys.
- Use RSA-OAEP-SHA256 for key wrapping, not raw RSA.
- Use Ed25519 signatures for envelope authenticity.
- Use SQLCipher for local database encryption.
- Keep TLS enabled in production and use certificate pinning only after an operational rotation strategy exists.
- Treat Socket.IO events as untrusted input even when authenticated.
- Enforce server-side authorization for rooms, recipients, and public-key lookups.
- Add replay protection, key rotation, device revocation, and public-key fingerprint verification before production E2EE claims.
