# Troubleshooting

[← Home](../README.md)

| Symptom | Likely cause and fix |
|---|---|
| `Cannot initialize device-mapper` | Container isn't privileged. Rerun with `--privileged`. |
| `/dev/mapper/<name>` missing after open | No udev in the container. Run `dmsetup mknodes`, or restart with `-v /dev:/dev` added. |
| `Device <name> already exists` | A mapping survived from an earlier container (device mapper is kernel-wide). `dmsetup ls`, then `cryptsetup close <name>`. |
| `Device or resource busy` on close | Still mounted. `umount` first. |
| Out of loop devices / stale loops | `losetup -a` to list, `losetup -d /dev/loopN` to detach. |
| `Not enough available memory to open a keyslot` | argon2id needs more RAM than the container has. Raise Docker's memory limit or format with `--pbkdf-memory 65536`. |
| `fallocate` fails | Filesystem doesn't support it. Use `dd if=/dev/zero of=disk.img bs=1M count=64`. |
| `Device disk.img is not a block device. Can not auto-detect if it is active or not.` | `cryptsetup reencrypt` on an image file. Close the volume, then add `--force-offline-reencrypt`. See [Lab 8](08-reencrypt.md). |
| `Key file can be used only with --key-slot or with exactly one key slot active.` | `cryptsetup reencrypt` with `--key-file` on a volume that has several keyslots. Add `--key-slot <n>` (the other slots are removed), or run it interactively. |
| `No key available with this passphrase.` | Wrong passphrase, or that slot was removed. Check which slots exist with `cryptsetup luksDump`. |
| Disk images vanished | The container was started with `--rm` and has exited. Start again from [Lab 1](01-create-and-inspect.md). |

To reset everything, run the [full cleanup](00-setup.md#full-cleanup).
