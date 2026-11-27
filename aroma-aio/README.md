# AROMA-Next-Installer (`ANI`) All-In-One Multi-Module Builder

This directory adds an optional, **zero-bloat** All-In-One (AIO) interactive installer builder for the `arm64` Magisk modules in [`Magisk_Modules/`](../Magisk_Modules), powered by **[AROMA-Next-Installer (`ANI`)](https://github.com/Miustone/AROMA-Next-Installer)** and **[`Miustone/aroma-next-action@v1`](https://github.com/Miustone/aroma-next-action)**.

## What It Does

Instead of downloading and flashing 10+ individual `.zip` files one by one, this builder generates a **single flashable AIO ZIP** where users simply check whichever modules they want:

- **In Custom Recovery (`TWRP` / `OrangeFox` / `AERA` / `PitchBlack` — `BOOTMODE=0`):** Full 60–120Hz **AMOLED Modern Material 3 Touch GUI** with categorized, paginated checkboxes, live detection of already-installed modules, and built-in **AROMA-Next-Filemanager (`ANF`) Bootloop-Saver**.
- **In Magisk / KernelSU / APatch App (`BOOTMODE=1`):** The exact same generated `aroma-config` automatically runs via `ANI`'s native C **Volume Key Selector** (with Back navigation).
- **Authentic Module Installation:** Every selected child `.zip` is installed via the native root manager (`magisk --install-module`, `ksud module install`, `apd module install`) or its own authentic `customize.sh` — and the temporary AIO wrapper removes itself automatically afterwards so **only the real individual modules** stay installed under `/data/adb/modules/`.
- **Zero Binary Bloat in Git:** No ~6 MB `ANI` binaries, themes, fonts, or icons are committed to this repository — [`Miustone/aroma-next-action@v1`](https://github.com/Miustone/aroma-next-action) fetches and merges the latest official `ANI` release automatically during CI!

## How to Build an AIO ZIP

### Option 1: GitHub Actions (1 Click)
Open the **Actions** tab → **Build AROMA-Next (ANI) AIO Installer** → **Run workflow** and choose a preset:
- `essentials` — Lightweight CLI essentials (`bash`, `btop`, `coreutils`, `curl`, `findutils`, `procps`, `rsync`, `util-linux`, `vim`, `wget2`, `compression_tools`, `initshell`, `myscripts`, `enable_wireless_adb`, `bootctl`, `selinux_tools`, `e2fsprogs`)
- `networking` — `openssh`, `openssl`, `openvpn`, `curl`, `wget2`, `rsync`, `dnsmasq`, `httpd`, `unfsd3`, `syslogd`, `network_tools`
- `dev` — `git`, `vim`, `python3`, `cmake`, `gdb`, `binutils`, `autoconf_tools`, `bison`, `sqlite3`, `lua`, `perl`, `protoc`, `DebugTools`
- `all-latest` — Automatically deduplicates and bundles the newest version of every unique module ID in `Magisk_Modules/`
- `custom` — Specify any comma-separated list (e.g. `bash,git,vim,btop,openssh`)

### Option 2: Locally (Python 3 stdlib only)
```bash
# Build the lightweight CLI essentials AIO bundle:
python3 aroma-aio/build_aio.py --preset essentials

# Or build a custom selection:
python3 aroma-aio/build_aio.py --preset custom --include bash,git,vim,btop,openssh
```
The local builder auto-fetches & caches the `ANI` Magisk template into `aroma-aio/.aroma-cache/` (or pass `--aroma-zip <path>` offline).
