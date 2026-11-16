# Lesson 2: The master key

[← Lesson 1](01-what-is-luks.md) · [Home](../README.md) · Next: [Lesson 3: Keyslots →](03-keyslots.md)

Your data is encrypted with a random **master key**, also called the **volume key**. `cryptsetup` generates it when you format the volume.

**Your passphrase never encrypts data directly.** It only unlocks a protected copy of the master key.

```
 passphrase ──(slow key derivation)──► unlocks ──► master key ──► encrypts/decrypts data
```

## Why the indirection matters

- **Changing a passphrase is instant.** Only the small protected copy of the master key is rewritten. The data, still encrypted with the same master key, is untouched.
- **A leaked master key is worse than a leaked passphrase.** Anyone holding the master key can decrypt the data no matter which passphrases you later add or remove. The only cure is to replace the master key and rewrite all the data, which is called re-encryption.

## How LUKS knows a passphrase is right

The header stores a **digest**: a fingerprint of the master key. When a passphrase unlocks a candidate key, LUKS fingerprints it and compares. A match means the passphrase was correct. The digest also changes whenever the master key changes, which makes it a handy way to confirm a re-encryption happened.

## Try it

- [Lab 1](../labs/01-create-and-inspect.md): find the digest in the header
- [Lab 5](../labs/05-master-key-in-kernel.md): print the master key itself
- [Lab 8](../labs/08-reencrypt.md): replace the master key
