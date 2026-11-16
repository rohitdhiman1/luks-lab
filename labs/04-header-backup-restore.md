# Lab 4: Header backup, destruction and restore

[← Lab 3](03-keyslots.md) · [Home](../README.md) · Next: [Lab 5 →](05-master-key-in-kernel.md)

**Goal:** destroy access to the volume by wiping its keys, then bring it back from a header backup.

**Read first:** [Lesson 5: The header is critical](../notes/05-the-header.md)

**Before you start:** `disk.img` from [Lab 3](03-keyslots.md), closed, opening with `labpass3`.

## Step 1: Back up the header

```bash
cryptsetup luksHeaderBackup disk.img --header-backup-file header.bak
ls -l header.bak
```

`header.bak` is 16 MB: a copy of the whole header, keyslots included. It contains none of your data.

## Step 2: Wipe every keyslot

```bash
cryptsetup luksErase disk.img
```

Type `YES` to confirm. No passphrase is asked for: destroying keys needs no secret.

## Step 3: See the damage

```bash
cryptsetup luksDump disk.img
```

The **Keyslots** section is empty. (The digest, the master key's fingerprint, is still listed, but a fingerprint cannot be turned back into a key.) Try to open it:

```bash
cryptsetup open disk.img vault
```

It fails with `No usable keyslot is available.` The ciphertext is all still there, but no copy of the master key exists on this disk, so nothing can decrypt it. A correct passphrase is useless.

## Step 4: Restore the header

```bash
cryptsetup luksHeaderRestore disk.img --header-backup-file header.bak
```

Type `YES` to confirm.

## Step 5: Open it again

```bash
cryptsetup open disk.img vault
mount /dev/mapper/vault /mnt/vault && cat /mnt/vault/note.txt
umount /mnt/vault && cryptsetup close vault
```

Enter `labpass3`. The note is back.

## Takeaways

- `luksErase` is how you securely "delete" a disk quickly: destroy the keys, not the data.
- A header backup resurrects old keyslots. If a passphrase was compromised and you removed it, an old backup still accepts it. Guard backups as carefully as passphrases.

**Keep both `disk.img` and `header.bak`**: [Lab 8](08-reencrypt.md) uses the backup again.
