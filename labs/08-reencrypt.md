# Lab 8: Re-encrypt (rotate the master key)

[← Lab 7](07-detached-header.md) · [Home](../README.md) · Next: [Lab 9 →](09-performance-and-ciphers.md)

**Goal:** replace the master key, and prove that an old header backup stops working.

**Read first:** [Lesson 2: The master key](../notes/02-master-key.md)

**Before you start:** `disk.img` (closed, one keyslot, opening with `labpass3`) and `header.bak` from [Lab 4](04-header-backup-restore.md).

Removing a passphrase doesn't help if someone already copied the master key or an old header. Re-encryption generates a new master key and rewrites all the data with it.

## Step 1: Note the current digest

```bash
cryptsetup luksDump disk.img | grep -A6 Digests
```

The `Digest:` line is the master key's fingerprint. Remember its first few bytes.

## Step 2: Re-encrypt

```bash
cryptsetup reencrypt --force-offline-reencrypt disk.img
```

Enter `labpass3`. A progress line runs and ends with `Finished`.

`--force-offline-reencrypt` is needed only because `disk.img` is a file. `cryptsetup` cannot tell whether a plain file is currently open, so it asks you to confirm that it isn't. Make sure the volume is closed first. On a real disk you would leave the flag off, and LUKS2 can even re-encrypt while the volume is in use.

If the volume has several keyslots, `reencrypt` asks for the passphrase of each one, because every slot has to be rewritten to hold the new master key.

## Step 3: See what changed

```bash
cryptsetup luksDump disk.img | grep -A6 Digests
cryptsetup luksDump disk.img | grep luks2
```

The digest is different: there is a new master key. The keyslot number may have changed too, since the slot was rebuilt.

## Step 4: Confirm your data survived

```bash
cryptsetup open disk.img vault
mount /dev/mapper/vault /mnt/vault && cat /mnt/vault/note.txt
umount /mnt/vault && cryptsetup close vault
```

`labpass3` still works and the note is intact. The passphrase is the same; the key it unlocks is new.

## Step 5: Try the old header backup

Work on a copy so the real volume stays safe:

```bash
cp disk.img copy.img
cryptsetup luksHeaderRestore copy.img --header-backup-file header.bak
cryptsetup open copy.img oldvault
```

Type `YES` for the restore, then `labpass3` to open. **It opens.** The old header is self-consistent: its keyslot yields the old master key and its digest agrees.

```bash
mount /dev/mapper/oldvault /mnt/vault
```

The mount fails with `wrong fs type, bad option, bad superblock`. The old master key is decrypting data that was written with the new one, so the result is garbage and no filesystem can be found.

```bash
cryptsetup close oldvault
```

## Takeaway

After a suspected leak of the master key or a header, `luksRemoveKey` is not enough. `cryptsetup reencrypt` makes every old header backup and every old copy of the master key worthless. Take a fresh header backup afterwards, and destroy the old ones.
