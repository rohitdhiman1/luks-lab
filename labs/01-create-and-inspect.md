# Lab 1: Create a LUKS volume and read its header

[← Lab 0](00-setup.md) · [Home](../README.md) · Next: [Lab 2 →](02-open-use-close.md)

**Goal:** turn a blank file into a LUKS volume and learn to read its header.

**Read first:** [Lesson 1: What LUKS is](../notes/01-what-is-luks.md), [Lesson 2: The master key](../notes/02-master-key.md)

**Before you start:** a shell inside the lab container ([Lab 0](00-setup.md)).

## Step 1: Create a fake disk

```bash
fallocate -l 64M disk.img
```

This creates a blank 64 MB file. It will stand in for a disk.

## Step 2: Format it as LUKS

```bash
cryptsetup luksFormat disk.img
```

Type `YES` in uppercase to confirm, then enter the passphrase `labpass` twice. It pauses for a couple of seconds: that is the slow key derivation at work.

`luksFormat` generated a random master key, locked a copy of it in keyslot 0 with your passphrase, and wrote the header to the start of the file. No data has been encrypted yet because there is no data.

## Step 3: Read the header

```bash
cryptsetup luksDump disk.img
```

The output is long. These are the parts that matter (your salts, digest and UUID will differ):

```
Version:       	2
UUID:          	e4264aad-c7f1-48e2-8e01-f98569ee70c9

Data segments:
  0: crypt
	offset: 16777216 [bytes]
	cipher: aes-xts-plain64

Keyslots:
  0: luks2
	Key:        512 bits
	PBKDF:      argon2id
	Time cost:  7
	Memory:     1048576

Digests:
  0: pbkdf2
	Digest:     03 26 56 ca ...
```

| Section | What it tells you |
|---|---|
| `Version: 2` | This is a LUKS2 volume. |
| **Data segments** | The cipher (`aes-xts-plain64`) and the `offset` where encrypted data begins. 16777216 bytes is 16 MB: the space reserved for the header. |
| **Keyslots** | One slot in use, slot `0`, protected with `argon2id`. `Memory` is in kilobytes, so about 1 GB per unlock attempt. |
| **Digests** | A fingerprint of the master key, used to check that a passphrase unlocked the right key. |

## Step 4: Confirm it is LUKS

```bash
cryptsetup isLuks disk.img && echo "is LUKS"
hexdump -C disk.img | head -5
```

`isLuks` prints nothing itself; it succeeds or fails, so the `echo` runs only on success. The hexdump shows the first bytes of the file:

```
00000000  4c 55 4b 53 ba be 00 02  ...  |LUKS..........@.|
```

`LUKS` followed by `ba be` is the magic signature, and the `00 02` after it is the version. Anyone who looks at this disk can tell it is LUKS-encrypted. [Lab 7](07-detached-header.md) shows how to hide even that.

## Check yourself

- How many keyslots are in use?
- Where does the data start?

<details>
<summary>Answers</summary>

One keyslot (slot 0). Data starts at offset 16777216 bytes, 16 MB into the file, straight after the header.

</details>

**Leave `disk.img` in place** for Lab 2.
