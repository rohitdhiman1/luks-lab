# Lab 12: Recover a locked-out disk

[← Lab 11](11-rotate-a-keyfile.md) · [Home](../README.md)

**Goal:** lose access to a disk in two different ways, and get the data back by two different routes: a header backup, and the master key on its own.

**Read first:** [Case study, part 4: escrow and recovery](../notes/case-study-kafka-recovery.md)

**Before you start:** a shell inside the lab container. This lab builds its own disk and does not depend on earlier labs.

There are two independent ways back to the data:

| Path | What you need |
|---|---|
| **A: through the header** | A header backup, and a key that opens one of its keyslots |
| **B: around the header** | The master key, and the settings the header used to hold |

## Part A: Build a disk worth saving

### Step 1: Create, format and fill it

```bash
fallocate -l 64M safe.img
dd if=/dev/urandom of=disk.key bs=64 count=1
chmod 600 disk.key
cryptsetup luksFormat safe.img --key-file disk.key
```

Type `YES`. Then:

```bash
cryptsetup open safe.img safe --key-file disk.key
mkfs.ext4 -q /dev/mapper/safe
mkdir -p /mnt/safe
mount /dev/mapper/safe /mnt/safe
echo "irreplaceable" > /mnt/safe/data.txt
umount /mnt/safe
cryptsetup close safe
```

## Part B: Prepare the two safety nets

Everything in this part is done while the disk is healthy. None of it can be done afterwards.

### Step 2: Back up the header (for path A)

```bash
cryptsetup luksHeaderBackup safe.img --header-backup-file header.bak
```

### Step 3: Export the master key (for path B)

```bash
cryptsetup luksDump safe.img --dump-volume-key --key-file disk.key --volume-key-file master.key
ls -l master.key
```

Type `YES`. Instead of printing the master key, `--volume-key-file` writes it to a file: 64 bytes, the key that encrypts every block of this disk. In real life this file would go straight into a vault.

### Step 4: Record the settings (for path B)

```bash
cryptsetup luksDump safe.img | grep -E 'offset:|cipher:|sector:|Key:' | tee settings.txt
```

```
	offset: 16777216 [bytes]
	cipher: aes-xts-plain64
	sector: 4096 [bytes]
	Key:        512 bits
```

These four facts describe how the data is laid out and encrypted. Without the header, nothing else records them. (Ignore the extra `Area offset` line; it describes the keyslot, not the data.)

## Part C: Disaster 1, every keyslot is lost

### Step 5: Wipe the keyslots

```bash
cryptsetup luksErase safe.img
cryptsetup open safe.img safe --key-file disk.key
```

Type `YES` for the erase. The open fails with `No usable keyslot is available.` The header is still there, the data is still there, and the correct keyfile is useless.

### Step 6: Recover by path A, the header backup

```bash
cryptsetup luksHeaderRestore safe.img --header-backup-file header.bak
cryptsetup open --test-passphrase safe.img --key-file disk.key && echo "restored"
```

Type `YES`. The keyslot is back and `disk.key` works again.

### Step 7: Break it again

```bash
cryptsetup luksErase safe.img
```

### Step 8: Recover by path B, the master key

This time, pretend there is no header backup. Make a brand-new keyfile and build a keyslot for it straight from the master key:

```bash
dd if=/dev/urandom of=fresh.key bs=64 count=1
chmod 600 fresh.key
cryptsetup luksAddKey safe.img fresh.key --volume-key-file master.key --key-size 512
```

No existing key was needed. `cryptsetup` checked the master key against the fingerprint (digest) still in the header, then locked it into a new keyslot. `--key-size 512` is required here only because, with no keyslots left, the header no longer says how long the key is.

```bash
cryptsetup open safe.img safe --key-file fresh.key
mount /dev/mapper/safe /mnt/safe && cat /mnt/safe/data.txt
umount /mnt/safe && cryptsetup close safe
```

`irreplaceable` is back. Note that `disk.key` no longer works: its keyslot was erased, and only the new one exists.

## Part D: Disaster 2, the whole header is destroyed

### Step 9: Overwrite the header

```bash
dd if=/dev/zero of=safe.img bs=1M count=16 conv=notrunc
cryptsetup isLuks safe.img || echo "not LUKS any more"
cryptsetup open safe.img safe --key-file fresh.key
```

The first 16 MB, the entire header, is now zeros. `conv=notrunc` leaves the rest of the file alone, so the encrypted data is untouched. The open fails with `not a valid LUKS device`. There is no header to add a keyslot to, so Step 8's method cannot work either.

### Step 10: Recover by path B, plain dm-crypt

LUKS is only the header. The encryption itself is done by dm-crypt, and you can hand dm-crypt the key and the settings yourself:

```bash
cryptsetup open --type plain --cipher aes-xts-plain64 --key-size 512 \
  --key-file master.key --offset 32768 --sector-size 4096 safe.img rescue
```

Each option comes from `settings.txt`:

| Option | From |
|---|---|
| `--cipher aes-xts-plain64` | `cipher:` |
| `--key-size 512` | `Key:` |
| `--sector-size 4096` | `sector:` |
| `--offset 32768` | `offset:` is 16777216 bytes; `--offset` is counted in 512-byte units, and 16777216 ÷ 512 = 32768 |

```bash
mount -o ro /dev/mapper/rescue /mnt/safe && cat /mnt/safe/data.txt
umount /mnt/safe && cryptsetup close rescue
```

`irreplaceable`, read from a disk with no LUKS header at all. `-o ro` mounts read-only, the right habit during a rescue.

### Step 11: See what a wrong setting looks like

```bash
cryptsetup open --type plain --cipher aes-xts-plain64 --key-size 512 \
  --key-file master.key --offset 32768 --sector-size 512 safe.img rescue
mount -o ro /dev/mapper/rescue /mnt/safe
cryptsetup close rescue
```

Only the sector size is wrong. The open **succeeds**, because plain dm-crypt has no way to check anything, and then the mount fails with `wrong fs type, bad option, bad superblock`. A wrong setting gives garbage, not an error message. This is why the settings must be written down.

### Step 12: Recover by path A, the header backup

```bash
cryptsetup luksHeaderRestore safe.img --header-backup-file header.bak
```

`cryptsetup` warns that the device `does not contain LUKS2 header`. Type `YES`.

```bash
cryptsetup open safe.img safe --key-file disk.key
mount /dev/mapper/safe /mnt/safe && cat /mnt/safe/data.txt
umount /mnt/safe && cryptsetup close safe
```

The disk is a normal LUKS volume again. The backup was taken in Step 2, so it brought back the keyslot for `disk.key`, and `fresh.key` from Step 8 is unknown to it. A header backup restores the keys as they were when it was taken.

## Check yourself

- In Step 8, why did `luksAddKey` not need an existing key?
- Why could Step 8's method not be used after Step 9?
- Which of the two paths is easier to use, and which works in more situations?
- What would have happened if you had skipped Part B?

<details>
<summary>Answers</summary>

- An existing key is normally needed only to get the master key out of a keyslot. Here you supplied the master key directly.
- `luksAddKey` adds a keyslot to a header. After Step 9 there was no header.
- Path A (header backup) is one command and needs no knowledge of the settings. Path B (master key) works even with no header and no backup, but needs the settings and is harder to get right.
- The data would have been unrecoverable from Step 5 onwards. Neither safety net can be created after access is lost.

</details>

## Clean up

```bash
umount /mnt/safe 2>/dev/null
cryptsetup close safe 2>/dev/null
cryptsetup close rescue 2>/dev/null
```

## Takeaway

Keep at least two independent ways in, prepared while the disk is healthy. And remember what you were holding in this lab: `header.bak` and `master.key` can each rescue the data, which means each can also expose it. They belong in a vault, not next to the disk.
