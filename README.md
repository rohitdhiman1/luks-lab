# LUKS Lab: a hands-on guide using Docker

A self-paced course for learning LUKS disk encryption inside a Docker container, using plain files as fake disks. Nothing here touches a real disk.

This page is the map. **Lessons** explain one idea each; **labs** are step-by-step exercises you type yourself.

## Quick start

```bash
docker build -t luks-lab .
docker run -it --rm --privileged --name luks-lab luks-lab
```

Full details, safety notes and cleanup are in [Lab 0: Setup](labs/00-setup.md).

> **Safety:** only ever point `cryptsetup` at the lab image files (`disk.img` and friends). A `--privileged` container can see real block devices.

## Suggested path

Work down the table. Read the lesson, then do the lab.

| # | Read | Then do |
|---|---|---|
| 0 | | [Lab 0: Setup](labs/00-setup.md) |
| 1 | [Lesson 1: What LUKS is](notes/01-what-is-luks.md)<br>[Lesson 2: The master key](notes/02-master-key.md) | [Lab 1: Create a LUKS volume and read its header](labs/01-create-and-inspect.md) |
| 2 | [Lesson 6: The layers](notes/06-the-layers.md) | [Lab 2: Open, use, close, and prove it's encrypted](labs/02-open-use-close.md) |
| 3 | [Lesson 3: Keyslots](notes/03-keyslots.md) | [Lab 3: Keyslots](labs/03-keyslots.md) |
| 4 | [Lesson 5: The header is critical](notes/05-the-header.md) | [Lab 4: Header backup, destruction and restore](labs/04-header-backup-restore.md) |
| 5 | | [Lab 5: See the master key in the kernel](labs/05-master-key-in-kernel.md) |
| 6 | | [Lab 6: Grow the volume](labs/06-grow-the-volume.md) |
| 7 | | [Lab 7: Detached header](labs/07-detached-header.md) |
| 8 | | [Lab 8: Re-encrypt (rotate the master key)](labs/08-reencrypt.md) |
| 9 | [Lesson 4: Key derivation](notes/04-key-derivation.md) | [Lab 9: Performance and cipher choices](labs/09-performance-and-ciphers.md) |
| 10 | [Lesson 7: LUKS1 vs LUKS2](notes/07-luks1-vs-luks2.md) | [Lab 10: Unlocking at boot (reading only)](labs/10-unlock-at-boot.md) |

Labs 1 to 6 and Lab 8 build on the same `disk.img`, so do them in order and in one container session. Labs 7 and 9 stand alone.

## Lessons

Short concept notes, in [`notes/`](notes/).

1. [What LUKS is](notes/01-what-is-luks.md): dm-crypt, LUKS and cryptsetup
2. [The master key](notes/02-master-key.md): what actually encrypts your data
3. [Keyslots](notes/03-keyslots.md): many passphrases, one key
4. [Key derivation (KDF)](notes/04-key-derivation.md): why unlocking is deliberately slow
5. [The header is critical](notes/05-the-header.md): backups, erasing, detached headers
6. [The layers](notes/06-the-layers.md): from image file to mount point
7. [LUKS1 vs LUKS2](notes/07-luks1-vs-luks2.md)

### Case studies

- [An encrypted data disk on a Kafka broker](notes/case-study-kafka-broker.md): the same layers on a real server, and why an always-open volume is not a security hole
- [How the keys work on the Kafka broker](notes/case-study-kafka-keys.md): what format and open do, what the header holds, with flowcharts

## Labs

Step-by-step exercises, in [`labs/`](labs/).

0. [Setup](labs/00-setup.md)
1. [Create a LUKS volume and read its header](labs/01-create-and-inspect.md)
2. [Open, use, close, and prove it's encrypted](labs/02-open-use-close.md)
3. [Keyslots](labs/03-keyslots.md)
4. [Header backup, destruction and restore](labs/04-header-backup-restore.md)
5. [See the master key in the kernel](labs/05-master-key-in-kernel.md)
6. [Grow the volume](labs/06-grow-the-volume.md)
7. [Detached header](labs/07-detached-header.md)
8. [Re-encrypt (rotate the master key)](labs/08-reencrypt.md)
9. [Performance and cipher choices](labs/09-performance-and-ciphers.md)
10. [Unlocking at boot (reading only)](labs/10-unlock-at-boot.md)

## Reference

- [Cheat sheet](notes/cheat-sheet.md): every command in one table
- [Troubleshooting](labs/troubleshooting.md): common errors and fixes
- [Self-test](notes/self-test.md): seven questions with answers

## Repo layout

```
luks-lab/
├── Dockerfile     the lab image
├── README.md      this page
├── notes/         lessons and reference
└── labs/          step-by-step exercises
```

## Where to go next

- LVM on LUKS vs LUKS on LVM
- TPM2 and FIDO2 unlocking with `systemd-cryptenroll`
- Integrity protection with `--integrity` (dm-integrity)
- `man cryptsetup` and the cryptsetup FAQ

---

> **Note for Claude Code:** the learner is a beginner to LUKS and wants bite-sized explanations followed by exercises. Walk through one lab at a time, explain the output of each command, and wait for them before moving on. If a command fails, diagnose it rather than assuming the learner made a mistake. Passphrase prompts are interactive; see "Running without prompts" in [Lab 0](labs/00-setup.md) if you need to script a step.
