# Lesson 6: The layers

[← Lesson 5](05-the-header.md) · [Home](../README.md) · Next: [Lesson 7: LUKS1 vs LUKS2 →](07-luks1-vs-luks2.md)

An encrypted filesystem is a stack. Each layer sits on the one above it in this diagram:

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

| Layer | What it does |
|---|---|
| **File or disk** | Holds the LUKS header followed by ciphertext. In this lab it is an ordinary file; on a real machine it is a disk or partition. |
| **Loop device** | Makes a file behave like a block device. `cryptsetup` creates one automatically when you open an image file. Real disks skip this layer. |
| **dm-crypt mapping** | A virtual device that appears when you open the volume. Reads from it are decrypted on the fly; writes are encrypted on the way down. |
| **Filesystem** | An ordinary filesystem such as ext4, created on the mapping. It has no idea it is encrypted. |
| **Mount point** | Where the files appear. |

## Two things worth noticing

- **The mapping is smaller than the file.** A 64 MB image gives a 48 MB mapping, because the 16 MB header is not usable space.
- **Opening and mounting are separate steps**, and so are unmounting and closing. Close in reverse order: `umount` first, then `cryptsetup close`.

## Growing a volume

To grow an encrypted filesystem you resize from the outside in: the underlying device, then the dm-crypt mapping, then the filesystem.

## On a real server

[Case study: an encrypted data disk on a Kafka broker](08-case-study-kafka-broker.md) shows this same stack with a physical disk in place of the image file.

## Try it

- [Lab 2: Open, use, close](../labs/02-open-use-close.md)
- [Lab 6: Grow the volume](../labs/06-grow-the-volume.md)
