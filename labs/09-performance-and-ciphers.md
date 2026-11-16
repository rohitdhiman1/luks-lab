# Lab 9: Performance and cipher choices

[← Lab 8](08-reencrypt.md) · [Home](../README.md) · Next: [Lab 10 →](10-unlock-at-boot.md)

**Goal:** measure what encryption costs on your machine, and feel the effect of a slower key derivation.

**Read first:** [Lesson 4: Key derivation](../notes/04-key-derivation.md)

**Before you start:** a shell inside the lab container. This lab uses its own file and does not depend on earlier labs.

## Step 1: Benchmark

```bash
cryptsetup benchmark
```

It takes a little while and prints two blocks.

The first block is key derivation:

```
PBKDF2-sha256    4634590 iterations per second for 256-bit key
argon2id      6 iterations, 1048576 memory, 4 parallel threads (CPUs) for 256-bit key (requested 2000 ms time)
```

PBKDF2 manages millions of iterations a second, which is exactly what makes it cheap to attack. argon2id gets through only a handful of passes in two seconds because each pass works through 1 GB of memory.

The second block is cipher throughput:

```
#     Algorithm |       Key |      Encryption |      Decryption
        aes-xts        512b      3092.7 MiB/s      3150.3 MiB/s
    serpent-xts        512b        82.6 MiB/s        91.8 MiB/s
```

AES is far faster than the alternatives because modern CPUs have dedicated AES instructions. At several GiB/s it is quicker than most disks, so encryption is rarely the bottleneck. Your numbers will differ.

## Step 2: Format with explicit choices

```bash
fallocate -l 64M disk3.img
cryptsetup luksFormat disk3.img \
  --cipher aes-xts-plain64 --key-size 512 \
  --pbkdf argon2id --iter-time 4000
```

Type `YES`, then `labpass` twice. The cipher, key size and KDF here are the defaults, written out. The one real change is `--iter-time 4000`: aim for a 4000 ms unlock instead of the default 2000 ms. Formatting takes noticeably longer.

## Step 3: Compare the dump

```bash
cryptsetup luksDump disk3.img
```

Under **Keyslots**, `Time cost` is roughly double what you saw in [Lab 1](01-create-and-inspect.md) (13 against 7 when this lab was tested). `Memory` is unchanged.

## Step 4: Time an unlock

```bash
time cryptsetup open --test-passphrase disk3.img
```

Enter `labpass`. The `real` time is around 4 to 5 seconds plus however long you took to type. A default volume takes about 2.

## Takeaway

`--iter-time` trades your convenience for the attacker's cost. Every extra second you wait at unlock is an extra second for each of an attacker's guesses.
