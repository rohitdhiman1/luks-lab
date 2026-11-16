# Lab 6: Grow the volume

[← Lab 5](05-master-key-in-kernel.md) · [Home](../README.md) · Next: [Lab 7 →](07-detached-header.md)

**Goal:** make the encrypted volume bigger without losing its contents.

**Read first:** [Lesson 6: The layers](../notes/06-the-layers.md)

**Before you start:** `disk.img` from [Lab 5](05-master-key-in-kernel.md), **closed**, opening with `labpass3`.

## Step 1: Grow the underlying file

```bash
truncate -s +64M disk.img
ls -lh disk.img
```

The file is now 128 MB. The new space is at the end; the header and existing data are untouched.

## Step 2: Open it and check the mapping

```bash
cryptsetup open disk.img vault
cryptsetup status vault
```

The `size` line now reads `229376 sectors`, which is 112 MB (128 MB minus the 16 MB header). The header says the data segment covers the "whole device", so the mapping picked up the new size when it was opened.

## Step 3: Grow the filesystem

```bash
e2fsck -f /dev/mapper/vault
resize2fs /dev/mapper/vault
```

The mapping grew but the ext4 filesystem inside it still thinks it is 48 MB. `e2fsck` checks the filesystem is healthy, which `resize2fs` insists on, and `resize2fs` then stretches it to fill the mapping.

## Step 4: Confirm

```bash
mount /dev/mapper/vault /mnt/vault && df -h /mnt/vault
cat /mnt/vault/note.txt
umount /mnt/vault && cryptsetup close vault
```

`df` reports about 105M, and the note is still there.

## Takeaway

Three things get resized in a real setup, outermost first: the underlying device, the dm-crypt mapping, then the filesystem. Here the mapping resized itself because the volume was closed when the file grew. If the underlying device grows while the volume is open, run `cryptsetup resize vault` before `resize2fs`.
