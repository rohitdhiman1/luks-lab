# Lab 11: Rotate a keyfile safely

[← Lab 10](10-unlock-at-boot.md) · [Home](../README.md) · Next: [Lab 12 →](12-recover-a-locked-out-disk.md)

**Goal:** replace the keyfile on a live, mounted volume without ever risking the data: add the new key, prove it works, and only then remove the old one.

**Read first:** [Case study, part 3: rotating the keyfile](../notes/case-study-kafka-key-rotation.md), [Lesson 3: Keyslots](../notes/03-keyslots.md)

**Before you start:** a shell inside the lab container. This lab builds its own disk and does not depend on earlier labs.

The lab imitates the Kafka broker from the case studies. `broker.img` stands in for `/dev/sdb`, the mapping is called `kafka`, and it is mounted at `/data/kafka`.

## Part A: Build the broker's disk

### Step 1: Create the disk and the original keyfile

```bash
fallocate -l 64M broker.img
dd if=/dev/urandom of=old.key bs=64 count=1
chmod 600 old.key
```

`old.key` is 64 random bytes. It is the key the "server" was built with.

### Step 2: Format and open with the keyfile

```bash
cryptsetup luksFormat broker.img --key-file old.key
cryptsetup open broker.img kafka --key-file old.key
```

Type `YES` to confirm the format. No passphrase is asked for: the keyfile is the key.

### Step 3: Create a filesystem, mount it, and write some data

```bash
mkfs.ext4 -q /dev/mapper/kafka
mkdir -p /data/kafka
mount /dev/mapper/kafka /data/kafka
echo "message 1" > /data/kafka/topic.log
```

The broker is now "live": the volume is open and mounted, and it stays that way for the whole rotation.

### Step 4: Record the starting state

```bash
cryptsetup luksDump broker.img | grep luks2
cryptsetup luksDump broker.img | grep Digest:
```

One keyslot, slot `0`. Note the first few bytes of the `Digest:` line: it is the fingerprint of the master key, and it should be exactly the same when you finish.

## Part B: Rotate the key

### Step 5: Back up the header first

```bash
cryptsetup luksHeaderBackup broker.img --header-backup-file pre-rotation.bak
```

This is the safety net. If anything goes wrong with the keyslots in the next few steps, restoring this file puts them back.

### Step 6: Generate the new keyfile

```bash
dd if=/dev/urandom of=new.key bs=64 count=1
chmod 600 new.key
```

### Step 7: Add the new key

```bash
cryptsetup luksAddKey broker.img new.key --key-file old.key
```

Read the command as: on `broker.img`, add `new.key`, and use `old.key` to prove you are allowed.

Internally, `cryptsetup` opens keyslot 0 with `old.key`, takes out the master key, generates a fresh salt, and locks the same master key into a new keyslot using `new.key`. Keyslot 0 is not touched. Neither is the data, and the volume stays mounted throughout.

### Step 8: Confirm there are now two keyslots

```bash
cryptsetup luksDump broker.img | grep luks2
```

Slots `0` and `1`. For this moment, both keyfiles open the disk. That overlap is the whole point of doing it in two steps.

### Step 9: Prove the new key works

```bash
cryptsetup open --test-passphrase --verbose broker.img --key-file new.key
```

`--test-passphrase` opens nothing; it only checks the key. You should see:

```
Key slot 1 unlocked.
Command successful.
```

**Do not go further until this succeeds.** This check is what makes the next step safe.

To see what a failure looks like, test a key that was never added:

```bash
dd if=/dev/urandom of=wrong.key bs=64 count=1
cryptsetup open --test-passphrase broker.img --key-file wrong.key
```

It prints `No key available with this passphrase.` If you saw that for `new.key`, you would stop here with the old key still working and nothing lost.

### Step 10: Remove the old key

```bash
cryptsetup luksRemoveKey broker.img old.key
```

This removes whichever keyslot `old.key` opens.

### Step 11: Confirm the old key is dead

```bash
cryptsetup luksDump broker.img | grep luks2
cryptsetup open --test-passphrase broker.img --key-file old.key
```

Only slot `1` remains, and `old.key` is refused with `No key available with this passphrase.`

### Step 12: Confirm nothing else changed

```bash
cryptsetup luksDump broker.img | grep Digest:
echo "message 2" >> /data/kafka/topic.log
cat /data/kafka/topic.log
```

The digest is identical to Step 4: same master key. The volume was mounted the whole time, and both messages are there. The rotation changed one lockbox in the header and nothing else.

## Part C: Survive a reboot

A rotation is not finished until the disk has been opened from cold with the new key.

### Step 13: Simulate a reboot

```bash
umount /data/kafka
cryptsetup close kafka
ls /dev/mapper/
```

Only `control` is listed. The mapping is gone and the master key has been wiped from kernel memory, just as after a real reboot.

### Step 14: Open with the new key

```bash
cryptsetup open broker.img kafka --key-file new.key
mount /dev/mapper/kafka /data/kafka
cat /data/kafka/topic.log
```

Both messages are back.

```bash
umount /data/kafka
cryptsetup close kafka
```

## Part D: The loose end

### Step 15: See that the old backup still accepts the old key

Work on a copy so the real disk stays as it is:

```bash
cp broker.img copy.img
cryptsetup luksHeaderRestore copy.img --header-backup-file pre-rotation.bak
cryptsetup open --test-passphrase copy.img --key-file old.key && echo "old key works again"
```

Type `YES` for the restore. The old key works again, and because the master key never changed, it would decrypt all the data.

`pre-rotation.bak` contains the old keyslot. As long as that file exists, the old key has not really been retired.

### Step 16: Replace the backup

```bash
cryptsetup luksHeaderBackup broker.img --header-backup-file post-rotation.bak
rm pre-rotation.bak copy.img
```

Take a fresh backup of the rotated header and destroy the old one.

## Part E (optional): What happens if you remove the last keyslot

```bash
cryptsetup luksRemoveKey broker.img new.key
```

`cryptsetup` stops and warns:

```
This is the last keyslot. Device will become unusable after purging this key.
Are you sure? (Type 'yes' in capital letters):
```

Type `no`. It reports `Operation aborted, the keyslot was NOT wiped.`

Do not rely on this warning. When this lab was tested, `luksKillSlot` given a keyfile removed the last keyslot with no prompt at all, and scripts that use `--batch-mode` skip the prompt too. The procedure is what protects you, not the tool.

## Check yourself

- Why was it safe to do this while the volume was mounted?
- At which step could a mistake first have cost you the data?
- Why did the digest not change?
- What would you do differently if you believed the *master key*, not just the keyfile, had leaked?

<details>
<summary>Answers</summary>

- Rotation only rewrites keyslots in the header. The open volume uses the master key already in kernel memory and never looks at the keyslots.
- Step 10, removing the old key. Before that, the old key still worked. That is why Steps 5 and 9 come first.
- The digest is the fingerprint of the master key, and rotation reuses the master key.
- Rotating the keyfile would not help, because the master key itself still decrypts the data. You would re-encrypt with a new master key: see [Lab 8](08-reencrypt.md).

</details>

## Clean up

```bash
umount /data/kafka 2>/dev/null
cryptsetup close kafka 2>/dev/null
```

## Takeaway

Add, test, then remove. There is never a moment with fewer than one proven-working keyslot, and a header backup stands behind even that. Afterwards, the old key is only truly gone once old header backups are gone too.
