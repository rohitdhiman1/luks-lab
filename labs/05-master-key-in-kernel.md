# Lab 5: See the master key in the kernel

[← Lab 4](04-header-backup-restore.md) · [Home](../README.md) · Next: [Lab 6 →](06-grow-the-volume.md)

**Goal:** see where the master key lives while a volume is open, and print the key itself.

**Read first:** [Lesson 2: The master key](../notes/02-master-key.md)

**Before you start:** `disk.img` from [Lab 4](04-header-backup-restore.md), closed, opening with `labpass3`.

## Step 1: Open the volume

```bash
cryptsetup open disk.img vault
```

## Step 2: Ask the device mapper what it knows

```bash
dmsetup table vault
dmsetup table --showkeys vault
```

`dmsetup` talks to the kernel's device mapper directly, one level below `cryptsetup`. Both commands print something like:

```
0 98304 crypt aes-xts-plain64 :64:logon:cryptsetup:e4264aad-...-d0 0 7:0 32768 1 sector_size:4096
```

Reading left to right: the mapping covers 98304 sectors, uses `aes-xts-plain64`, and sits on device `7:0` (the loop device) starting at sector 32768 (the 16 MB header offset).

The field `:64:logon:cryptsetup:...` is where a key would be. It is a **reference to the kernel keyring**: a 64-byte key stored inside the kernel. On older kernels or cryptsetup versions, `--showkeys` prints the raw key in hex here instead.

## Step 3: Close the volume

```bash
cryptsetup close vault
```

## Step 4: Print the master key from the header

```bash
cryptsetup luksDump --dump-volume-key disk.img
```

Type `YES`, then `labpass3`. Among the output:

```
MK dump:	d6 e6 58 f7 39 70 fa 8f ...
```

Those 64 bytes (512 bits) are the master key. Anyone holding them can decrypt the volume without any passphrase, and no change of passphrase would stop them. (Older cryptsetup versions call the option `--dump-master-key`.)

## Takeaway

While a volume is open, the key is in kernel memory and root can reach it. LUKS protects data **at rest** (powered off, or closed), not from a compromised running system.

**Leave `disk.img` in place** for Lab 6.
