# Lab 10: Unlocking at boot (reading only)

[← Lab 9](09-performance-and-ciphers.md) · [Home](../README.md) · Next: [Lab 11 →](11-rotate-a-keyfile.md)

**Goal:** understand how a real system opens LUKS volumes when it starts.

**Read first:** [Lesson 7: LUKS1 vs LUKS2](../notes/07-luks1-vs-luks2.md)

Containers don't boot, so most of this lab is conceptual. There is one command to run at the end.

## The two files

On a real system, two files work together:

1. **`/etc/crypttab`** lists the volumes to unlock at boot. It does the job of `cryptsetup open`.
2. **`/etc/fstab`** then mounts the resulting `/dev/mapper/<name>`. It does the job of `mount`.

A `crypttab` line has four fields:

```
name   device               keyfile-or-none   options
vault  UUID=1234abcd-...    none              luks,discard
```

| Field | Meaning |
|---|---|
| `name` | The mapping name, giving `/dev/mapper/vault` |
| `device` | Which encrypted device to open |
| `keyfile-or-none` | A keyfile path, or `none` to prompt for a passphrase at boot |
| `options` | `luks` for a LUKS volume; `discard` passes TRIM through to an SSD |

## Why UUIDs

Devices are referenced by UUID because names like `/dev/sdb` can change between boots, depending on the order in which disks are detected. The UUID is stored in the LUKS header and never changes.

## Unlocking without typing

LUKS2 **tokens** are entries in the header that describe another way to obtain a key. `systemd-cryptenroll` uses them to unlock with:

- a **TPM2** chip, so the disk opens automatically on the machine it belongs to
- a **FIDO2** security key, so the disk opens when the key is plugged in and touched

This is why `cryptsetup` printed `No usable token is available` in [Lab 3](03-keyslots.md): it looked for a token first, found none, and fell back to asking for a passphrase.

## Try it

If you still have `disk.img` from the earlier labs:

```bash
cryptsetup luksUUID disk.img
```

This prints the UUID you would put in `crypttab`. It matches the `UUID:` line in `cryptsetup luksDump disk.img`.

## Next

[Lab 11: Rotate a keyfile safely](11-rotate-a-keyfile.md) puts keyslots to work in a realistic procedure.

When you have finished the labs, test yourself with the [self-test](../notes/self-test.md), then run the [full cleanup](00-setup.md#full-cleanup) before leaving the container.
