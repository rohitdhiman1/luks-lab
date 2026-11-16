# Lesson 4: Key derivation (KDF)

[← Lesson 3](03-keyslots.md) · [Home](../README.md) · Next: [Lesson 5: The header →](05-the-header.md)

A passphrase is not used as a key directly. It is fed through a **key derivation function** (KDF) that turns it into a key, and that function is deliberately slow.

## Why slow is good

You unlock a volume once, so waiting a second or two costs you nothing. An attacker guessing passphrases has to pay that same cost for *every guess*. A KDF that takes two seconds turns a billion guesses into decades of work.

## PBKDF2 and argon2id

| | PBKDF2 | argon2id |
|---|---|---|
| Used by | LUKS1, optional in LUKS2 | LUKS2 default |
| Cost is | CPU time only | CPU time **and memory** |
| Weakness | Cheap to run in parallel on GPUs and custom chips | Each guess needs a large block of RAM, which is expensive to parallelise |

argon2id is **memory-hard**. On this lab's container each unlock uses about 1 GB of RAM. A cracking rig cannot run thousands of guesses side by side without thousands of gigabytes.

## The settings you will see

In `cryptsetup luksDump`, each keyslot shows:

- `PBKDF`: the function (`argon2id`)
- `Time cost`: the number of passes
- `Memory`: memory used, in kilobytes
- `Threads`: parallel threads

`cryptsetup` picks these by benchmarking your machine at format time, aiming for about two seconds per unlock. You can change the target with `--iter-time`.

## Try it

[Lab 9: Performance and cipher choices](../labs/09-performance-and-ciphers.md)
