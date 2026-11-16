# Cheat sheet

[← Home](../README.md)

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
| Rotate master key | `cryptsetup reencrypt <dev>` (add `--force-offline-reencrypt` for an image file) |
| Benchmark | `cryptsetup benchmark` |

`<dev>` is the encrypted device or image file (`disk.img`). `<name>` is the mapping name you chose when opening (`vault`), which appears as `/dev/mapper/<name>`.
