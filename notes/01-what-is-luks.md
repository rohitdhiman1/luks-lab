# Lesson 1: What LUKS is

[← Home](../README.md) · Next: [Lesson 2: The master key →](02-master-key.md)

LUKS (Linux Unified Key Setup) is the standard on-disk format for encrypted volumes on Linux. Three names come up constantly, and they are three different things:

| Name | What it is |
|---|---|
| **dm-crypt** | A Linux kernel feature. It does the actual encrypting and decrypting of disk blocks as they are written and read. |
| **LUKS** | The **header** at the start of the disk. It records how the volume is encrypted and how to unlock it. |
| **cryptsetup** | The command-line tool that manages both. |

The **dm** in dm-crypt stands for **device mapper**, the part of the Linux kernel that creates virtual block devices layered on top of real ones. dm-crypt is the device-mapper module ("target") that encrypts. This is why an opened volume appears under `/dev/mapper/`, and why the low-level tool for inspecting it is called `dmsetup`.

dm-crypt on its own has no memory: every time you open a volume you would have to tell it the cipher, the key size and the key. LUKS solves that by writing those details (and a protected copy of the key) onto the disk itself, so opening a volume only needs a passphrase.

## What LUKS protects

LUKS protects data **at rest**: a disk that is powered off, or a volume that is closed. It does not protect a volume that is currently open on a compromised machine, because the key is in kernel memory and the decrypted view is readable. [Lab 5](../labs/05-master-key-in-kernel.md) shows this directly.

## Try it

[Lab 1: Create a LUKS volume and read its header](../labs/01-create-and-inspect.md)
