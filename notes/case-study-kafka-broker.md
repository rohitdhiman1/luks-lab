# Case study: an encrypted data disk on a Kafka broker

[← Home](../README.md) · Related: [Lesson 1](01-what-is-luks.md), [Lesson 6: The layers](06-the-layers.md)

The lab uses a file as a fake disk. This case study shows the same layers on a real server, using a common setup: a Kafka broker that stores its data on a dedicated disk encrypted with LUKS.

The server has two disks. `sda` is the small one holding the operating system. `sdb` is the large one for Kafka's data. Kafka is configured to write under `/data/kafka`.

## The four layers

```
/data/kafka          mount point: where Kafka sees its files
     |
XFS                  filesystem: turns files into numbered blocks
     |
/dev/mapper/kafka    dm-crypt mapping: decrypted view, exists only while open
     |
/dev/sdb             physical disk: LUKS header + ciphertext
```

| Layer | What it is | Why it is there |
|---|---|---|
| **Physical disk** `/dev/sdb` | A block device: a long row of numbered blocks on real hardware. It starts with the LUKS header; everything after is ciphertext. | It is the only place anything is actually stored. |
| **dm-crypt mapping** `/dev/mapper/kafka` | A virtual block device created when the volume is opened. It stores nothing itself: it decrypts blocks read from `sdb` and encrypts blocks written to it. | Without it there is no way to read or write the disk in plaintext. |
| **Filesystem** XFS | The structure written onto the mapping that organises blocks into files and directories. | A block device has no idea what a file is. Kafka needs files. |
| **Mount point** `/data/kafka` | An ordinary directory where the filesystem is attached to the directory tree. | It gives programs a path to reach the filesystem. |

`/dev/sdb` and `/dev/mapper/kafka` are both block devices, and they are two views of the same storage. Read `sdb` directly and you get scrambled bytes. Read the mapping and you get the decrypted blocks, which is where XFS lives.

## How it is built

> These commands explain the layers. Do not run them on a disk that holds data: steps 1 and 3 destroy whatever is there.

| Step | Command | In words | How often |
|---|---|---|---|
| 1 | `cryptsetup luksFormat /dev/sdb` | Format the disk as LUKS. Generates the master key and writes the header. | Once |
| 2 | `cryptsetup open /dev/sdb kafka` | Open the LUKS volume. Unlocks the master key and creates `/dev/mapper/kafka`. | Every boot |
| 3 | `mkfs.xfs /dev/mapper/kafka` | Create a filesystem on the mapping. | Once |
| 4 | `mount /dev/mapper/kafka /data/kafka` | Mount the filesystem at the directory. | Every boot |

Note where the filesystem goes: on `/dev/mapper/kafka`, never on `/dev/sdb`. XFS has no idea it is encrypted.

On a real server, steps 2 and 4 are not typed by hand. `/etc/crypttab` performs the open and `/etc/fstab` performs the mount; see [Lab 10](../labs/10-unlock-at-boot.md).

## What a write looks like

```
Kafka appends to a log file under /data/kafka
        |
XFS decides which blocks hold that data
        |
/dev/mapper/kafka encrypts those blocks
        |
/dev/sdb stores the ciphertext
```

Reads travel the same path in reverse, with decryption in place of encryption.

## What `lsblk` shows

`lsblk` draws this stack as a tree, starting from the disk:

```
NAME      SIZE  TYPE   MOUNTPOINTS
sda       100G  disk
└─sda1    100G  part   /
sdb       2T    disk
└─kafka   2T    crypt  /data/kafka
```

`kafka` is nested under `sdb` with type `crypt`, and the mount point belongs to `kafka`, not to `sdb`. Real servers often have an extra layer, such as a partition (`sdb1`) or LVM, between the disk and the mapping. `lsblk` shows whatever is there.

## Why `/dev/mapper/kafka` is always present on a live broker

Because the filesystem mounted at `/data/kafka` lives on it. Every read and write Kafka makes passes through the mapping, so it has to exist for as long as the filesystem is mounted. The kernel enforces this: closing a mapping that is still mounted fails with `Device or resource busy`.

This has nothing to do with how busy the broker is. A broker handling one message an hour needs the volume open just as much as one handling a million a second.

## Is an always-open volume a security hole?

No. It is how disk encryption is meant to work.

| Situation | Does LUKS protect the data? |
|---|---|
| A drive is pulled and returned to the vendor | Yes |
| A drive or server is stolen | Yes |
| Hardware is decommissioned without being wiped | Yes |
| Someone copies the raw disk or a storage-level snapshot | Yes |
| The server is powered off | Yes |
| An attacker gains access to the running server | **No** |

While the volume is open, the master key is in kernel memory and the files are plaintext to anyone the file permissions allow. Protecting a running system is the job of other controls: file permissions, network rules, and Kafka's own authentication and authorisation.

## What it costs

Encryption adds CPU work to every read and write. Modern CPUs have dedicated AES instructions, so the cost is usually modest, but it is not zero and is most noticeable on very fast drives. `cryptsetup benchmark` shows what one CPU core can do; see [Lab 9](../labs/09-performance-and-ciphers.md). Measure on your own hardware before relying on any figure.

## Common misunderstandings

- **"The header contains nothing secret."** It contains the master key, in locked form, inside a keyslot. It never holds the passphrase or the master key in the clear. Losing the header loses the data. ([Lesson 2](02-master-key.md), [Lesson 5](05-the-header.md))
- **"The key has been in memory since the disk was first encrypted."** Kernel memory is wiped at every reboot. The volume is unlocked again at each boot, and the key stays in memory until the volume is closed or the machine powers off.
- **"`luksFormat` encrypts the data already on the disk."** It writes a new header and discards what was there. Encryption happens block by block as data is written through the mapping.
- **"`/data/kafka` is a symlink to `/dev/mapper/kafka`."** A symlink is a pointer from one path to another. A mount attaches a filesystem to a directory. The directory, the filesystem and the device are separate layers.
- **"Everything under `/dev/mapper/` is encrypted."** The device mapper also provides LVM volumes and multipath devices, which are not encrypted. Check the type before assuming.

## Checking a real server

These commands only read information:

```bash
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINTS   # the whole stack as a tree
cryptsetup status kafka                      # is the mapping LUKS, and what is it built on?
df -T /data/kafka                            # which filesystem is mounted there?
```

In `lsblk`, a `TYPE` of `crypt` means an open encrypted volume; `lvm` means an ordinary LVM volume.

## How this maps to the lab

| Kafka broker | Lab |
|---|---|
| `/dev/sdb` | `disk.img` attached to `/dev/loop0` |
| `/dev/mapper/kafka` | `/dev/mapper/vault` |
| XFS | ext4 |
| `/data/kafka` | `/mnt/vault` |

[Lab 2](../labs/02-open-use-close.md) builds this exact stack by hand. While the volume is mounted there, try `cryptsetup close vault` to see the "busy" refusal for yourself.
