# Lesson 3: Keyslots

[← Lesson 2](02-master-key.md) · [Home](../README.md) · Next: [Lesson 4: Key derivation →](04-key-derivation.md)

The LUKS header contains **keyslots**. Each keyslot stores one copy of the master key, encrypted with a key derived from one passphrase or one keyfile.

```
 header
 ├── keyslot 0:  master key, locked by passphrase A
 ├── keyslot 1:  master key, locked by passphrase B
 └── keyslot 2:  master key, locked by a keyfile
```

Every slot holds the *same* master key. They are different doors into the same room.

## Consequences

- **Several passphrases can unlock the same volume.** Useful for a personal passphrase plus a recovery key, or one per administrator.
- **Adding, changing or removing a passphrase is instant.** Only a keyslot changes; no data is re-encrypted.
- **Removing every keyslot makes the data unrecoverable**, even though the ciphertext is still on the disk. Nothing is left that can produce the master key.

## Passphrase or keyfile

A keyslot does not care what unlocks it. A **keyfile** is simply a file whose contents are used as the passphrase, typically random bytes. Keyfiles allow unlocking without a prompt, which suits scripts and boot-time unlocking.

## The full picture

[Case study: how the keys work on the Kafka broker](case-study-kafka-keys.md) explains what is inside a keyslot and how it is locked and opened.

## Try it

- [Lab 3: Keyslots](../labs/03-keyslots.md)
- [Lab 11: Rotate a keyfile safely](../labs/11-rotate-a-keyfile.md)
