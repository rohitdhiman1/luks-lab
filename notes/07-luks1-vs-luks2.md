# Lesson 7: LUKS1 vs LUKS2

[← Lesson 6](06-the-layers.md) · [Home](../README.md)

There are two versions of the LUKS format. Everything in this lab uses LUKS2, which is what `cryptsetup luksFormat` creates by default.

| | LUKS1 | LUKS2 |
|---|---|---|
| Status | Legacy | Current default |
| Keyslots | 8 | Up to 32 |
| KDF | PBKDF2 | argon2id (or PBKDF2) |
| Header | Single copy, binary | Two copies, JSON metadata |
| Online re-encryption | No | Yes |

## What the differences mean in practice

- **Stronger passphrase protection.** argon2id is memory-hard; see [Lesson 4](04-key-derivation.md).
- **A more resilient header.** LUKS2 keeps two copies of its metadata, so a small corruption can be repaired.
- **Tokens.** LUKS2 metadata can describe other ways to unlock, such as a TPM2 chip or a FIDO2 security key. See [Lab 10](../labs/10-unlock-at-boot.md).
- **Re-encryption in place.** LUKS2 can replace the master key without copying the data elsewhere. See [Lab 8](../labs/08-reencrypt.md).

You will still meet LUKS1 on older systems and where a bootloader cannot read LUKS2. Check a volume's version with `cryptsetup luksDump <device>` and look at the `Version:` line.
