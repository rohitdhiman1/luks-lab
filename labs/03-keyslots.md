# Lab 3: Keyslots

[← Lab 2](02-open-use-close.md) · [Home](../README.md) · Next: [Lab 4 →](04-header-backup-restore.md)

**Goal:** add, test, change and remove keys, and see that the data never needs re-encrypting.

**Read first:** [Lesson 3: Keyslots](../notes/03-keyslots.md)

**Before you start:** `disk.img` from [Lab 2](02-open-use-close.md), closed, with `labpass` in slot 0.

## Step 1: Add a second passphrase

```bash
cryptsetup luksAddKey disk.img
```

It first asks for **any existing passphrase** (`labpass`), then for the new one twice (`labpass2`). The existing passphrase is needed to unlock the master key so a second copy can be stored in slot 1.

## Step 2: Add a keyfile

```bash
dd if=/dev/urandom of=key.bin bs=64 count=1
chmod 600 key.bin
cryptsetup luksAddKey disk.img key.bin
```

`dd` writes 64 random bytes to `key.bin`; `chmod 600` makes it readable only by its owner. `luksAddKey` asks for an existing passphrase, then stores the keyfile's contents as a third key.

## Step 3: See the three slots

```bash
cryptsetup luksDump disk.img
```

Under **Keyslots** there are now slots `0`, `1` and `2`. Nothing in the dump says which is a passphrase and which is a keyfile: to LUKS they are the same thing.

## Step 4: Unlock with the keyfile

```bash
cryptsetup open disk.img vault --key-file key.bin
cryptsetup close vault
```

No prompt. This is how volumes are unlocked by scripts and at boot.

## Step 5: Test a passphrase without opening

```bash
cryptsetup open --test-passphrase --verbose disk.img
```

Enter `labpass2`. Nothing is opened; it only reports which slot matched:

```
Key slot 1 unlocked.
Command successful.
```

(A line saying `No usable token is available.` is normal. Tokens are covered in [Lab 10](10-unlock-at-boot.md).)

## Step 6: Change a passphrase

```bash
cryptsetup luksChangeKey disk.img
```

Enter the passphrase to replace (`labpass2`), then the new one twice (`labpass3`). The slot keeps its number: slot 1 now opens with `labpass3`.

## Step 7: Remove a slot by number

```bash
cryptsetup luksKillSlot disk.img 0
```

It asks for a passphrase from a **remaining** slot (`labpass3`), which stops you locking yourself out by accident. Now test the original passphrase:

```bash
cryptsetup open --test-passphrase disk.img
```

Enter `labpass`. It fails with `No key available with this passphrase.`

## Step 8: Remove a key by its value

```bash
cryptsetup luksRemoveKey disk.img key.bin
```

`luksRemoveKey` removes whichever slot matches the key you give it. Here that is the keyfile's slot. Without a filename it prompts for a passphrase instead.

## Step 9: Confirm where you ended up

```bash
cryptsetup luksDump disk.img
```

Only slot `1` remains, and it opens with `labpass3`. Later labs assume this state.

## Check yourself

- After killing slot 0, does the original passphrase still work?
- Is `note.txt` still there when you open with another key?
- Why was nothing re-encrypted?

<details>
<summary>Answers</summary>

No, `labpass` is gone. Yes, the note is intact: open with `labpass3`, mount, and `cat /mnt/vault/note.txt` (then unmount and close). Nothing was re-encrypted because every keyslot holds the same master key, and the master key never changed; only the small protected copies in the header were added and removed.

</details>

**Leave `disk.img` in place** for Lab 4.
