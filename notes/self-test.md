# Self-test

[← Home](../README.md)

Try these after finishing the labs.

1. Why can you change a LUKS passphrase without re-encrypting the disk?
2. What two things make a header backup dangerous to leave lying around?
3. An attacker has root on a running machine with the volume open. Does LUKS protect the data?
4. A passphrase was leaked. Is `luksRemoveKey` enough? When isn't it?
5. What are the three layers you resize when growing an encrypted filesystem, and in what order?
6. What does a detached header buy you?
7. Why is argon2id preferred over PBKDF2?

<details>
<summary>Answers</summary>

1. The passphrase only encrypts the master key inside a keyslot. The data is encrypted with the master key, which doesn't change. ([Lesson 2](02-master-key.md), [Lesson 3](03-keyslots.md))
2. It contains keyslots that old passphrases can still unlock, and it restores access after an erase. ([Lesson 5](05-the-header.md))
3. No. The master key is in kernel memory and the plaintext device is readable. LUKS protects data at rest. ([Lesson 1](01-what-is-luks.md))
4. Enough if the attacker never had the disk or header. If they could have copied the header (or the master key), you need `cryptsetup reencrypt`. ([Lesson 2](02-master-key.md))
5. Underlying device, then dm-crypt mapping, then filesystem. ([Lesson 6](06-the-layers.md))
6. The data disk has no identifiable LUKS signature and can't be unlocked without the separately stored header. ([Lesson 5](05-the-header.md))
7. It is memory-hard, so GPU and ASIC cracking rigs gain much less advantage than against PBKDF2. ([Lesson 4](04-key-derivation.md))

</details>
