# Lab 2: Open, use, close, and prove it's encrypted

[← Lab 1](01-create-and-inspect.md) · [Home](../README.md) · Next: [Lab 3 →](03-keyslots.md)

**Goal:** unlock the volume, put a filesystem and a file on it, lock it again, and confirm the file on disk holds only ciphertext.

**Read first:** [Lesson 6: The layers](../notes/06-the-layers.md)

**Before you start:** `disk.img` from [Lab 1](01-create-and-inspect.md).

## Step 1: Open the volume

```bash
cryptsetup open disk.img vault
```

Enter `labpass`. `vault` is a name you choose; the decrypted view of the disk now exists as `/dev/mapper/vault`.

## Step 2: Look at what was created

```bash
ls -l /dev/mapper/vault
cryptsetup status vault
lsblk
```

`status` shows the stack:

```
/dev/mapper/vault is active.
  type:    LUKS2
  cipher:  aes-xts-plain64
  key location: keyring
  device:  /dev/loop0
  loop:    /lab/disk.img
```

`cryptsetup` attached `disk.img` to a loop device (`/dev/loop0`) so the file behaves like a disk, then built the dm-crypt mapping on top. In `lsblk`, find the loop device with `vault` nested beneath it:

```
loop0     7:0    0  64M  0 loop
`-vault 253:0    0  48M  0 crypt
```

The mapping is 48 MB, not 64 MB. The missing 16 MB is the header. (`lsblk` also lists other devices belonging to the Docker VM; ignore them.)

## Step 3: Create a filesystem and write a file

```bash
mkfs.ext4 /dev/mapper/vault
mkdir -p /mnt/vault
mount /dev/mapper/vault /mnt/vault
echo "top secret" > /mnt/vault/note.txt
cat /mnt/vault/note.txt
```

The filesystem goes on `/dev/mapper/vault`, never on `disk.img` directly. ext4 has no idea it is encrypted: dm-crypt encrypts every block on its way down to the file.

## Step 4: Close it

```bash
umount /mnt/vault
cryptsetup close vault
```

Unmount first, then close, the reverse of the order you opened in. `/dev/mapper/vault` is now gone and the key has been dropped from kernel memory.

## Step 5: Look for the secret in the raw file

```bash
strings disk.img | grep "top secret"
```

It prints nothing. `strings` pulls readable text out of a file, and there is none to find.

## Step 6: Contrast with an unencrypted disk

```bash
fallocate -l 16M plain.img
mkfs.ext4 -q plain.img
mkdir -p /mnt/plain && mount plain.img /mnt/plain
echo "top secret" > /mnt/plain/note.txt
umount /mnt/plain
strings plain.img | grep "top secret"
```

This time it prints `top secret`. Anyone who gets hold of an unencrypted disk can read it without mounting it.

## Takeaway

`/dev/mapper/vault` is a live decrypted view that exists only while the volume is open. `disk.img` holds only ciphertext.

**Leave `disk.img` in place** for Lab 3.
