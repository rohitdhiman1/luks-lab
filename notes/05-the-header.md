# Lesson 5: The header is critical

[← Lesson 4](04-key-derivation.md) · [Home](../README.md) · Next: [Lesson 6: The layers →](06-the-layers.md)

The LUKS header sits at the start of the disk. In LUKS2 it takes up 16 MB by default and holds:

- the cipher and where the encrypted data begins
- the keyslots (the protected copies of the master key)
- the digest used to verify the master key
- the volume's UUID

## Lose the header, lose the data

The master key exists only inside the keyslots. If the header is overwritten or corrupted, **the data is gone even if you know the passphrase**, because there is nothing left for the passphrase to unlock.

That is why you back up the header:

```bash
cryptsetup luksHeaderBackup <device> --header-backup-file header.bak
```

## A header backup is as sensitive as the disk

A backup is a snapshot of the keyslots at the moment it was taken. Two consequences:

1. **It resurrects old passphrases.** If a passphrase leaked and you removed it, anyone with an older backup can restore it and use the leaked passphrase again.
2. **It undoes an erase.** Wiping every keyslot is a fast way to destroy a disk's contents. A surviving header backup brings the data back.

Store header backups as carefully as you would store the passphrase itself.

## Erasing by destroying keys

`cryptsetup luksErase` wipes all keyslots. The ciphertext stays on disk, but nobody can decrypt it unless they hold a header backup or a copy of the master key. This is far faster than overwriting a whole disk.

## Detached headers

The header does not have to live on the data disk. With `--header <file>` it is kept in a separate file, and the data disk then contains nothing but ciphertext, with no sign that it is LUKS at all.

## When the master key is kept elsewhere

"Lose the header, lose the data" holds when the header was the only place the master key existed, which is the usual case. If the master key was exported beforehand, the data can still be reached without the header. See [Case study, part 4: escrow and recovery](11-case-study-kafka-recovery.md).

## Try it

- [Lab 4: Header backup, destruction and restore](../labs/04-header-backup-restore.md)
- [Lab 7: Detached header](../labs/07-detached-header.md)
- [Lab 12: Recover a locked-out disk](../labs/12-recover-a-locked-out-disk.md)
