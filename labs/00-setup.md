# Lab 0: Setup

[← Home](../README.md) · Next: [Lab 1 →](01-create-and-inspect.md)

**Goal:** build the lab image and get a shell inside a container where LUKS works.

## Safety first

- Only ever point `cryptsetup` at the lab image files (`disk.img` and friends).
- A `--privileged` container can see real block devices. On a Linux host, `/dev/sda`, `/dev/nvme0n1` and similar are your actual disks. `luksFormat` on one of those destroys its contents.
- On Docker Desktop (macOS/Windows) the container runs inside a Linux VM, so the blast radius is that VM, but the same habit applies.

## Step 1: Build the image

From the repo root on your host:

```bash
docker build -t luks-lab .
```

This builds an Ubuntu 24.04 image with `cryptsetup` and the handful of tools the labs use.

## Step 2: Start the container

```bash
docker run -it --rm --privileged --name luks-lab luks-lab
```

- `--privileged` is required: LUKS needs loop devices and the kernel device mapper.
- `--rm` discards everything on exit, which is what you want for a lab. **Exiting the container deletes your disk images**, so stay in the same container while you work through labs that build on each other.
- You land in `/lab`. Keep the disk images there rather than on a bind mount; loop devices on shared host folders can misbehave on Docker Desktop.

## Step 3: Sanity check

Inside the container:

```bash
cryptsetup --version
ls /dev/mapper/control
```

You should see a version line such as `cryptsetup 2.7.0 ...`, and `/dev/mapper/control` should exist. If it doesn't, the container is not privileged.

## Passphrases in this lab

Use throwaway passphrases. The labs suggest `labpass`, `labpass2` and `labpass3` so the steps can refer to them. Nothing appears on screen while you type a passphrase.

## Running without prompts

For scripts, or when an assistant is running commands for you:

```bash
printf 'labpass' | cryptsetup luksFormat --batch-mode disk.img --key-file -
printf 'labpass' | cryptsetup open disk.img vault --key-file -
```

Use `printf`, not `echo`: with `--key-file -` a trailing newline becomes part of the key. Only do this with throwaway lab passphrases, since they end up in shell history.

## Full cleanup

Run this before leaving the container. Device-mapper names and loop devices belong to the kernel, not the container, so they can outlive it.

```bash
umount /mnt/vault /mnt/plain /data/kafka /mnt/safe 2>/dev/null
for m in vault vault2 oldvault kafka safe rescue; do cryptsetup close $m 2>/dev/null; done
losetup -D
exit
```

Stuck? See [Troubleshooting](troubleshooting.md).
