# LUKS Lab: a hands-on guide using Docker

A self-paced set of exercises for learning LUKS disk encryption inside a Docker container, using plain files as fake disks.

Suggested repo name: `luks-lab`

> **Note for Claude Code:** the learner is a beginner to LUKS and wants bite-sized explanations followed by exercises. Walk through one exercise at a time, explain the output of each command, and wait for them before moving on. The commands here were written from knowledge of cryptsetup and have not been run on the learner's machine, so if one fails, diagnose it rather than assuming the learner made a mistake. Passphrase prompts are interactive; see "Running without prompts" if you need to script a step.

---

## Safety first

- Only ever point `cryptsetup` at the lab image files (`disk.img` and friends).
- A `--privileged` container can see real block devices. On a Linux host, `/dev/sda`, `/dev/nvme0n1` and similar are your actual disks. `luksFormat` on one of those destroys its contents.
- On Docker Desktop (macOS/Windows) the container runs inside a Linux VM, so the blast radius is that VM, but the same habit applies.

---

## Part 1: Concepts

### 1. What LUKS is
LUKS (Linux Unified Key Setup) is the standard on-disk format for encrypted volumes on Linux. The encryption work is done by **dm-crypt**, a kernel feature. LUKS is the **header** at the start of the disk that records how the volume is encrypted and how to unlock it. `cryptsetup` is the command-line tool that manages both.

### 2. The master key
Your data is encrypted with a random **master key** (also called the volume key). Your passphrase never encrypts data directly.

### 3. Keyslots
The header contains **keyslots**. Each one stores a copy of the master key, encrypted with a key derived from one passphrase or keyfile. Consequences:

- Several passphrases can unlock the same volume.
- Changing or removing a passphrase is instant; no data is re-encrypted.
- Removing every keyslot makes the data unrecoverable, even though it is still on disk.

### 4. Key derivation (KDF)
A passphrase is turned into a key by a deliberately slow function (argon2id in LUKS2). Slowness and memory cost make brute-force guessing expensive.

### 5. The header is critical
Header gone or corrupted means data gone, even if you know the passphrase. A header backup is also as sensitive as the disk: anyone with an old header and an old passphrase can unlock the volume.

### 6. The layers

```
 file or disk (ciphertext)      disk.img
        |
 loop device (file as a disk)   /dev/loopN
        |
 dm-crypt mapping (plaintext)   /dev/mapper/vault
        |
 filesystem                     ext4
        |
 mount point                    /mnt/vault
```

### 7. LUKS1 vs LUKS2

| | LUKS1 | LUKS2 |
|---|---|---|
| Status | Legacy | Current default |
| Keyslots | 8 | Up to 32 |
| KDF | PBKDF2 | argon2id (or PBKDF2) |
| Header | Single copy, binary | Two copies, JSON metadata |
| Online re-encryption | No | Yes |

---

## Part 2: Setup

### Repo layout

```
luks-lab/
├── Dockerfile
├── README.md          (this guide)
└── notes/             (your notes, one file per exercise)
```

### Dockerfile

```dockerfile
FROM ubuntu:24.04
RUN apt-get update \
 && apt-get install -y cryptsetup e2fsprogs bsdextrautils \
 && rm -rf /var/lib/apt/lists/*
WORKDIR /lab
```

### Build and run

```bash
docker build -t luks-lab .
docker run -it --rm --privileged --name luks-lab luks-lab
```

- `--privileged` is required: LUKS needs loop devices and the kernel device mapper.
- Keep the disk images inside the container (in `/lab`) rather than on a bind mount. Loop devices on shared host folders can misbehave on Docker Desktop.
- `--rm` means everything is discarded on exit, which is what you want for a lab.

### Sanity check

```bash
cryptsetup --version
ls /dev/mapper/control      # should exist
```

---

## Part 3: Exercises

### Exercise 1: Create a LUKS volume and read its header

```bash
fallocate -l 64M disk.img
cryptsetup luksFormat disk.img        # type YES (uppercase), then a passphrase
cryptsetup luksDump disk.img
```

Look for in the dump:

- `Version: 2`
- Under **Data segments**: the cipher (`aes-xts-plain64`) and the offset where encrypted data begins
- Under **Keyslots**: slot `0`, with `PBKDF: argon2id`
- Under **Digests**: a fingerprint used to check that an unlocked key is the right master key

Also try:

```bash
cryptsetup isLuks disk.img && echo "is LUKS"
hexdump -C disk.img | head -5         # the LUKS magic bytes are visible
```

**Check yourself:** how many keyslots are in use? Where does the data start?

---

### Exercise 2: Open, use, close, and prove it's encrypted

```bash
cryptsetup open disk.img vault
ls -l /dev/mapper/vault
cryptsetup status vault
lsblk

mkfs.ext4 /dev/mapper/vault
mkdir -p /mnt/vault
mount /dev/mapper/vault /mnt/vault
echo "top secret" > /mnt/vault/note.txt
cat /mnt/vault/note.txt
```

Now close it and look at the raw file:

```bash
umount /mnt/vault
cryptsetup close vault
strings disk.img | grep "top secret"  # finds nothing
```

**Takeaway:** `/dev/mapper/vault` is a live decrypted view. `disk.img` holds only ciphertext.

**Contrast experiment:** make an unencrypted image, write the same note, and run the same `strings` command.

```bash
fallocate -l 16M plain.img
mkfs.ext4 -q plain.img
mkdir -p /mnt/plain && mount plain.img /mnt/plain
echo "top secret" > /mnt/plain/note.txt
umount /mnt/plain
strings plain.img | grep "top secret" # found
```

---

### Exercise 3: Keyslots

```bash
cryptsetup luksAddKey disk.img                 # asks for an existing passphrase, then a new one
dd if=/dev/urandom of=key.bin bs=64 count=1
chmod 600 key.bin
cryptsetup luksAddKey disk.img key.bin         # keyfile becomes a third key
cryptsetup luksDump disk.img                   # slots 0, 1, 2
```

Unlock with the keyfile, no prompt:

```bash
cryptsetup open disk.img vault --key-file key.bin
cryptsetup close vault
```

Test a passphrase without opening anything:

```bash
cryptsetup open --test-passphrase --verbose disk.img   # reports which slot matched
```

Change and remove keys:

```bash
cryptsetup luksChangeKey disk.img              # replace one passphrase with another
cryptsetup luksKillSlot disk.img 0             # remove slot 0 (asks for a remaining passphrase)
cryptsetup luksRemoveKey disk.img              # remove whichever slot matches the passphrase you type
```

**Check yourself:** after killing slot 0, does the original passphrase still work? Is `note.txt` still there when you open with another key? Why was nothing re-encrypted?

---

### Exercise 4: Header backup, destruction, and restore

```bash
cryptsetup luksHeaderBackup disk.img --header-backup-file header.bak
cryptsetup luksErase disk.img                  # wipes every keyslot
cryptsetup luksDump disk.img                   # no keyslots left
cryptsetup open disk.img vault                 # fails
```

The ciphertext is intact but nothing can decrypt it. Now restore:

```bash
cryptsetup luksHeaderRestore disk.img --header-backup-file header.bak
cryptsetup open disk.img vault
mount /dev/mapper/vault /mnt/vault && cat /mnt/vault/note.txt
umount /mnt/vault && cryptsetup close vault
```

**Takeaways:**

- `luksErase` is how you securely "delete" a disk quickly: destroy the keys, not the data.
- A header backup resurrects old keyslots. If a passphrase was compromised and you removed it, an old backup still accepts it.

---

### Exercise 5: See the master key in the kernel

```bash
cryptsetup open disk.img vault
dmsetup table vault                # key shown as a reference or zeros
dmsetup table --showkeys vault     # may show the raw key or a keyring reference
cryptsetup close vault
```

Depending on kernel and cryptsetup versions, the key is either printed in hex or shown as a kernel keyring reference (`:64:logon:cryptsetup:...`).

To print the actual master key from the header:

```bash
cryptsetup luksDump --dump-volume-key disk.img   # older versions: --dump-master-key
```

**Takeaway:** while a volume is open, the key is in kernel memory and root can reach it. LUKS protects data **at rest** (powered off, or closed), not from a compromised running system.

---

### Exercise 6: Grow the volume

```bash
truncate -s +64M disk.img                  # file is now 128M (volume must be closed)
cryptsetup open disk.img vault
cryptsetup status vault                    # size reflects the larger file
e2fsck -f /dev/mapper/vault
resize2fs /dev/mapper/vault
mount /dev/mapper/vault /mnt/vault && df -h /mnt/vault
umount /mnt/vault && cryptsetup close vault
```

Three things get resized in a real setup, outermost first: the underlying device, the dm-crypt mapping, then the filesystem. Here the mapping picked up the new size at open time. If the underlying device grows while the volume is open, run `cryptsetup resize vault` before `resize2fs`.

---

### Exercise 7: Detached header

The header can live in a separate file, leaving the data disk with no sign that it is LUKS at all.

```bash
fallocate -l 64M disk2.img
fallocate -l 16M header2.img
cryptsetup luksFormat disk2.img --header header2.img
cryptsetup isLuks disk2.img || echo "disk2.img does not look like LUKS"
cryptsetup isLuks header2.img && echo "header2.img is the LUKS header"

cryptsetup open disk2.img vault2 --header header2.img
mkfs.ext4 -q /dev/mapper/vault2
cryptsetup close vault2
hexdump -C disk2.img | head            # indistinguishable from random noise
```

**Use case:** keep the header on a USB stick. Without it, the disk is unusable and unidentifiable.

---

### Exercise 8: Re-encrypt (rotate the master key)

Removing a passphrase doesn't help if someone already copied the master key or an old header. Re-encryption replaces the master key and rewrites all data.

```bash
cryptsetup luksDump disk.img | grep -A6 Digests     # note the digest
cryptsetup reencrypt disk.img
cryptsetup luksDump disk.img | grep -A6 Digests     # digest has changed
```

Then confirm the header backup from Exercise 4 is now useless: restoring it onto a copy of the image gives a header whose master key no longer matches the data.

```bash
cp disk.img copy.img
cryptsetup luksHeaderRestore copy.img --header-backup-file header.bak
cryptsetup open copy.img oldvault        # may unlock, but...
mount /dev/mapper/oldvault /mnt/vault    # ...fails: decrypts to garbage
cryptsetup close oldvault
```

---

### Exercise 9: Performance and cipher choices

```bash
cryptsetup benchmark
```

This shows KDF speeds and cipher throughput on your CPU. Then format with explicit choices and compare dumps:

```bash
fallocate -l 64M disk3.img
cryptsetup luksFormat disk3.img \
  --cipher aes-xts-plain64 --key-size 512 \
  --pbkdf argon2id --iter-time 4000
cryptsetup luksDump disk3.img
```

`--iter-time` is the target unlock time in milliseconds. Higher means slower unlocks for you and far slower guessing for an attacker. Time an unlock to feel it:

```bash
time cryptsetup open --test-passphrase disk3.img
```

---

### Exercise 10 (reading only): Unlocking at boot

Containers don't boot, so this one is conceptual. On a real system:

- `/etc/crypttab` lists volumes to unlock at boot: `name  device  keyfile-or-none  options`
- `/etc/fstab` then mounts `/dev/mapper/name`
- Devices are referenced by UUID (`cryptsetup luksUUID disk.img`) because names like `/dev/sdb` can change
- LUKS2 **tokens** allow unlocking via TPM2 or FIDO2 keys through `systemd-cryptenroll`

Example `crypttab` line:

```
vault  UUID=1234abcd-...  none  luks,discard
```

---

## Part 4: Reference

### Cheat sheet

| Task | Command |
|---|---|
| Format | `cryptsetup luksFormat <dev>` |
| Open | `cryptsetup open <dev> <name>` |
| Close | `cryptsetup close <name>` |
| Status of open volume | `cryptsetup status <name>` |
| Show header | `cryptsetup luksDump <dev>` |
| Is it LUKS? | `cryptsetup isLuks <dev>` |
| UUID | `cryptsetup luksUUID <dev>` |
| Add key | `cryptsetup luksAddKey <dev> [keyfile]` |
| Change key | `cryptsetup luksChangeKey <dev>` |
| Remove key by passphrase | `cryptsetup luksRemoveKey <dev>` |
| Remove key by slot | `cryptsetup luksKillSlot <dev> <n>` |
| Test passphrase | `cryptsetup open --test-passphrase <dev>` |
| Wipe all keys | `cryptsetup luksErase <dev>` |
| Back up header | `cryptsetup luksHeaderBackup <dev> --header-backup-file <f>` |
| Restore header | `cryptsetup luksHeaderRestore <dev> --header-backup-file <f>` |
| Resize mapping | `cryptsetup resize <name>` |
| Rotate master key | `cryptsetup reencrypt <dev>` |
| Benchmark | `cryptsetup benchmark` |

### Running without prompts

For scripts, or when an assistant is running commands for you:

```bash
printf 'labpass' | cryptsetup luksFormat --batch-mode disk.img --key-file -
printf 'labpass' | cryptsetup open disk.img vault --key-file -
```

Use `printf`, not `echo`: with `--key-file -` a trailing newline becomes part of the key. Only do this with throwaway lab passphrases, since they end up in shell history.

### Troubleshooting

| Symptom | Likely cause and fix |
|---|---|
| `Cannot initialize device-mapper` | Container isn't privileged. Rerun with `--privileged`. |
| `/dev/mapper/<name>` missing after open | No udev in the container. Restart with `-v /dev:/dev` added, or run `dmsetup mknodes`. |
| `Device <name> already exists` | A mapping survived from an earlier container (device mapper is kernel-wide). `dmsetup ls`, then `cryptsetup close <name>`. |
| `Device or resource busy` on close | Still mounted. `umount` first. |
| Out of loop devices / stale loops | `losetup -a` to list, `losetup -d /dev/loopN` to detach. |
| `Not enough available memory to open a keyslot` | argon2id needs more RAM than the container has. Raise Docker's memory limit or format with `--pbkdf-memory 65536`. |
| `fallocate` fails | Filesystem doesn't support it. Use `dd if=/dev/zero of=disk.img bs=1M count=64`. |

### Full cleanup

```bash
umount /mnt/vault /mnt/plain 2>/dev/null
for m in vault vault2 oldvault; do cryptsetup close $m 2>/dev/null; done
losetup -D
exit
```

---

## Part 5: Self-test

1. Why can you change a LUKS passphrase without re-encrypting the disk?
2. What two things make a header backup dangerous to leave lying around?
3. An attacker has root on a running machine with the volume open. Does LUKS protect the data?
4. A passphrase was leaked. Is `luksRemoveKey` enough? When isn't it?
5. What are the three layers you resize when growing an encrypted filesystem, and in what order?
6. What does a detached header buy you?
7. Why is argon2id preferred over PBKDF2?

<details>
<summary>Answers</summary>

1. The passphrase only encrypts the master key inside a keyslot. The data is encrypted with the master key, which doesn't change.
2. It contains keyslots that old passphrases can still unlock, and it restores access after an erase.
3. No. The master key is in kernel memory and the plaintext device is readable. LUKS protects data at rest.
4. Enough if the attacker never had the disk or header. If they could have copied the header (or the master key), you need `cryptsetup reencrypt`.
5. Underlying device, then dm-crypt mapping, then filesystem.
6. The data disk has no identifiable LUKS signature and can't be unlocked without the separately stored header.
7. It is memory-hard, so GPU and ASIC cracking rigs gain much less advantage than against PBKDF2.

</details>

## Where to go next

- LVM on LUKS vs LUKS on LVM
- TPM2 and FIDO2 unlocking with `systemd-cryptenroll`
- Integrity protection with `--integrity` (dm-integrity)
- `man cryptsetup` and the cryptsetup FAQ
