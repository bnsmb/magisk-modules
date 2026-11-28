<div align="center">

# bnsmb Magisk Modules — AROMA-Next (`ANI`) AIO Installer

**Interactive All-In-One Multi-Module Installer Builder for `bnsmb/magisk-modules` — Powered by [AROMA-Next-Installer (`ANI`)](https://github.com/Miustone/AROMA-Next-Installer), [AROMA-Next-Filemanager (`ANF`)](https://github.com/Miustone/AROMA-Next-Installer), and [`Miustone/aroma-next-action@v1`](https://github.com/Miustone/aroma-next-action)**

[![ANI Engine](https://img.shields.io/badge/Engine-ANI%20V26.11--RC5%20%2B%20ANF-0099CC)](https://github.com/Miustone/AROMA-Next-Installer)
[![CI Action](https://img.shields.io/badge/CI-aroma--next--action%40v1-6f42c1)](https://github.com/Miustone/aroma-next-action)
[![Architecture](https://img.shields.io/badge/Arch-arm64--v8a-222222)](#presets)
[![Zero Bloat](https://img.shields.io/badge/Vendored%20ANI%20Binaries-0%20Bytes-00AA55)](#how-the-zero-bloat-ci-magic-works)

[Features](#highlights) • [How the Magic Works](#how-the-zero-bloat-ci-magic-works) • [Presets](#presets) • [1-Click GitHub Actions](#option-1-1-click-github-actions-recommended) • [Local CLI Usage](#option-2-build-locally-python-3-stdlib-only) • [Changelog](CHANGELOG.md)

</div>

---

## Highlights

Instead of manually downloading and flashing 10+ separate `.zip` files one by one, **`aroma-aio`** generates a **single flashable All-In-One (AIO) ZIP** directly from [`Magisk_Modules/*.zip`](../Magisk_Modules) where users simply check whichever modules they want:

| Environment | Installer Experience | Highlights |
| :--- | :--- | :--- |
| **Custom Recovery** (`TWRP`, `OrangeFox`, `AERA`, `PitchBlack` — `BOOTMODE=0`) | **60–120Hz `ANI` Material 3 Touch GUI** | **AMOLED Modern** theme (Monochrome White default + 8 Live Accents), **Google Sans** typography, categorized & paginated checkboxes, live detection of already-installed modules, and built-in **`ANF` Bootloop-Saver**! |
| **Root Manager App** (`Magisk`, `KernelSU`, `APatch` — `BOOTMODE=1`) | **Built-In `ANI` Native C Volume Key Selector** | Renders the **exact same generated `aroma-config`** via hardware Volume Keys with **Back navigation** — zero duplicate code! |
| **Authentic Module Installation** | **Runs Each Module's Real Installer** | Installs every checked child `.zip` via `magisk --install-module`, `ksud module install`, `apd module install`, or its own `customize.sh`, then **removes the temporary AIO wrapper automatically** so only the real individual modules remain in `/data/adb/modules/`. |

---

## How the Zero-Bloat CI Magic Works

**Zero ~6 MB `ANI` binaries, zero fonts, and zero theme PNGs are committed to this repository!**

```text
  Magisk_Modules/*.zip + aroma-aio/             Miustone/AROMA-Next-Installer (Release)
  ├─ Auto-reads module.prop from every ZIP      ├─ arm64-v8a ANI + ANF static binary
  ├─ Deduplicates older versions automatically  ├─ AMOLED Modern + 7 Classic Themes
  ├─ Generates paginated Material 3 aroma-config├─ 17 Material 3 Icons + 7 SIL OFL Fonts
  └─ Adds multi-module customize.sh wrapper     └─ update-binary & aroma-mod-lib.sh
                         │                                       │
                         └──────────────────┬────────────────────┘
                                            ▼
                  [ Miustone/aroma-next-action@v1 (template: magisk) ]
                   + Automated ZIP, 0755 Perm, LF, Edify & sh -n Checks
                                            │
                                            ▼
             dist/bnsmb-Magisk-Modules-AIO-<preset>-ANI.zip  (Ready to flash!)
```

- **Zero Maintenance:** Every time `AROMA-Next-Installer` ships a new display fix, Material 3 UI upgrade, or `ANF` recovery tool, your next AIO build automatically inherits it!
- **Zero Impact on Existing Repo Files:** Every existing `.zip` in `Magisk_Modules/` and every script in `scripts/` remains 100% untouched.

---

## Presets

`build_aio.py` automatically scans `Magisk_Modules/*.zip`, deduplicates older versions (keeping the newest release per unique `module.prop` `id`), and groups modules into clean categories (**Shell & CLI Essentials**, **Networking & Remote**, **Dev & Compilers**, **System & MicroG**):

| Preset | Included Modules (Latest Version Auto-Selected) |
| :--- | :--- |
| **`essentials`** *(Default)* | `bash`, `btop`, `coreutils`, `curl`, `findutils`, `procps`, `rsync`, `util-linux`, `vim`, `wget2`, `compression_tools`, `initshell`, `myscripts`, `enable_wireless_adb`, `bootctl`, `selinux_tools`, `e2fsprogs` |
| **`networking`** | `openssh`, `openssl`, `openvpn`, `curl`, `wget2`, `rsync`, `dnsmasq`, `httpd`, `unfsd3`, `syslogd`, `network_tools`, `enable_wireless_adb` |
| **`dev`** | `git`, `vim`, `python3`, `cmake`, `gdb`, `binutils`, `autoconf_tools`, `bison_flex`, `sqlite3`, `lua`, `perl`, `protoc`, `bash`, `DebugTools` |
| **`all-latest`** | Automatically bundles the latest version of every unique module ID in `Magisk_Modules/` |
| **`custom`** | Pick any comma-separated list of module IDs or filename substrings (e.g. `bash,git,vim,btop,openssh`) |

---

## Usage

### Option 1: 1-Click GitHub Actions *(Recommended)*
1. Open the **Actions** tab → **[Build AROMA-Next (ANI) AIO Installer](../.github/workflows/aroma-aio-builder.yml)**.
2. Click **Run workflow**, choose your `preset` (or `custom` + `custom_modules`), and click **Run**.
3. Download the verified `bnsmb-Magisk-Modules-AIO-<preset>-ANI.zip` + `SHA256SUMS.txt` from the workflow artifacts and flash it in Custom Recovery or Magisk / KernelSU / APatch!

### Option 2: Build Locally *(Python 3 stdlib only)*
```bash
# Build the lightweight CLI essentials AIO bundle:
python3 aroma-aio/build_aio.py --preset essentials

# Build a custom selection of your favorite modules:
python3 aroma-aio/build_aio.py --preset custom --include bash,git,vim,btop,openssh

# Offline build using a local AROMA-Next-Magisk-Template.zip:
python3 aroma-aio/build_aio.py --preset essentials --aroma-zip /path/to/AROMA-Next-Magisk-Template.zip
```
Local builds auto-fetch and cache the `ANI` Magisk template into `aroma-aio/.aroma-cache/` (gitignored).

---

## Credits & License

- **All arm64 Magisk Modules & Scripts:** **[bnsmb](https://github.com/bnsmb/magisk-modules)** (`Bernd.Schemmer@gmx.de`)
- **AROMA-Next-Installer (`ANI`), Filemanager (`ANF`), `aroma-next-action` & AIO Builder:** **[Miustone](https://github.com/Miustone/AROMA-Next-Installer)** (Apache License 2.0, based on 2013 Ahmad Amarullah `amarullz`)
- See [CHANGELOG.md](CHANGELOG.md) for the AIO builder release history.
