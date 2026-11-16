# Lab 7: Detached header

[← Lab 6](06-grow-the-volume.md) · [Home](../README.md) · Next: [Lab 8 →](08-reencrypt.md)

**Goal:** keep the LUKS header in a separate file, so the data disk shows no sign of being encrypted.

**Read first:** [Lesson 5: The header is critical](../notes/05-the-header.md)

**Before you start:** a shell inside the lab container. This lab uses its own files and does not depend on earlier labs.

## Step 1: Create a data disk and a header file

```bash
fallocate -l 64M disk2.img
fallocate -l 16M header2.img
```

## Step 2: Format with the header kept separately

```bash
cryptsetup luksFormat disk2.img --header header2.img
```

Type `YES`, then the passphrase `labpass` twice. The header goes into `header2.img`; nothing is written to `disk2.img`.

## Step 3: Check which file is LUKS

```bash
cryptsetup isLuks disk2.img || echo "disk2.img does not look like LUKS"
cryptsetup isLuks header2.img && echo "header2.img is the LUKS header"
```

Both messages print. Look at the header:

```bash
cryptsetup luksDump header2.img
```

Under **Data segments**, `offset` is `0`. With no header in the way, encrypted data starts at the very first byte of `disk2.img`.

## Step 4: Open it using both files

```bash
cryptsetup open disk2.img vault2 --header header2.img
mkfs.ext4 -q /dev/mapper/vault2
cryptsetup close vault2
```

Every command that touches this volume needs `--header header2.img`.

## Step 5: Look at the data disk

```bash
hexdump -C disk2.img | head
```

There is no `LUKS` signature, only bytes that look like random noise. Compare with the `hexdump` in [Lab 1](01-create-and-inspect.md).

## Takeaway

Keep the header somewhere else, such as a USB stick. Without it, the disk is unusable and unidentifiable. The cost is that losing the header file loses the data, so it needs its own backup.
