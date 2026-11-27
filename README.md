<div align="center">

# Magisk Modules for Android (`arm64`)

**Comprehensive collection of prebuilt Linux CLI tools, compilers, networking daemons, debugging utilities, MicroG PlayStore, and ADB maintenance scripts for rooted Android (`arm64-v8a`) devices.**

[![Architecture](https://img.shields.io/badge/Arch-arm64--v8a-222222)](#module-collection-overview)
[![Root Solutions](https://img.shields.io/badge/Root-Magisk%20%7C%20KernelSU%20%7C%20APatch-00AA55)](#interactive-all-in-one-aio-installer-aroma-next-installer)
[![AIO Installer](https://img.shields.io/badge/AIO%20Installer-ANI%20Touch%20GUI%20%2B%20VolKey-0099CC)](aroma-aio/README.md)
[![CI Action](https://img.shields.io/badge/CI-aroma--next--action%40v1-6f42c1)](https://github.com/Miustone/aroma-next-action)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue)](LICENSE)

[Interactive AIO Installer](#interactive-all-in-one-aio-installer-aroma-next-installer) • [Module Overview](#module-collection-overview) • [ADB Scripts](#adb-shell-maintenance-scripts) • [Compiler Toolchains](#dedicated-compiler--toolchain-repositories) • [MicroG PlayStore](#playstore-for-custom-roms-with-microg) • [Full Documentation](#documentation--archive)

</div>

---

> **CPU Architecture Note:** The binaries in the Magisk modules in this repository (and in the dedicated toolchain repositories linked below) are compiled for Android running on **`arm64`** (`arm64-v8a`) CPUs *(except `PlayStore_for_MicroG`, which includes multi-arch libraries for `arm64`, `arm`, `x86`, and `x86-64`)*.

---

## Interactive All-In-One (AIO) Installer (`AROMA-Next-Installer`)

Want to install multiple modules in a **single flash** instead of downloading and flashing individual `.zip` files one by one?

Download the ready-to-flash AIO ZIP from **[GitHub Releases](../../releases)** — or build your own custom bundle in 1 click using the **[Build & Release AROMA-Next (ANI) AIO Installer](.github/workflows/aroma-aio-builder.yml)** workflow (full guide in [`aroma-aio/README.md`](aroma-aio/README.md) • [Changelog](aroma-aio/CHANGELOG.md)):

- **Custom Recovery (`TWRP` / `OrangeFox` / `AERA` / `PitchBlack` — `BOOTMODE=0`):** Full 60–120Hz **AMOLED Modern Material 3 Touch GUI** with categorized checkboxes, live detection of already-installed modules, and built-in **AROMA-Next-Filemanager (`ANF`) Bootloop-Saver**.
- **Magisk / KernelSU / APatch App (`BOOTMODE=1`):** The exact same generated `aroma-config` automatically runs via `ANI`'s native C **Volume Key Selector** (with Back navigation).
- **Zero Binary Bloat in Git:** Powered by **[`Miustone/aroma-next-action@v1`](https://github.com/Miustone/aroma-next-action)** — zero ~6 MB `ANI` binaries or UI assets are committed to this repository!
- **Authentic Installation:** Every checked module runs its own real `customize.sh` / root manager installer, and the temporary AIO wrapper deletes itself automatically afterwards.

| Preset | Included Latest Modules |
| :--- | :--- |
| **`essentials`** *(Default Release)* | `bash`, `btop`, `coreutils`, `curl`, `findutils`, `procps`, `rsync`, `util-linux`, `vim`, `wget2`, `compression_tools`, `initshell`, `myscripts`, `enable_wireless_adb`, `bootctl`, `selinux_tools`, `e2fsprogs` |
| **`networking`** | `openssh`, `openssl`, `openvpn`, `curl`, `wget2`, `rsync`, `dnsmasq`, `httpd`, `unfsd3`, `syslogd`, `network_tools`, `enable_wireless_adb` |
| **`dev`** | `git`, `vim`, `python3`, `cmake`, `gdb`, `binutils`, `autoconf_tools`, `bison_flex`, `sqlite3`, `lua`, `perl`, `protoc`, `bash`, `DebugTools` |
| **`all-latest`** / **`custom`** | Latest version of every unique module ID — or any custom comma-separated list (e.g. `bash,git,vim,btop,openssh`) |

---

## Module Collection Overview

All current flashable `.zip` modules live in **[`Magisk_Modules/`](Magisk_Modules)** *(older releases are kept in [`Magisk_Modules/archive/`](Magisk_Modules/archive))*:

| Category | Highlights in [`Magisk_Modules/`](Magisk_Modules) |
| :--- | :--- |
| **Shell & CLI Essentials** | `bash`, `coreutils` (GNU & Rust), `findutils`, `procps`, `util-linux`, `btop`, `vim`, `bvi`, `the`, `man`, `compression_tools`, `initshell`, `myscripts` |
| **Networking & Remote Access** | `openssh` (up to 10.3p1), `openssl` (up to 4.0), `openvpn`, `curl`, `wget2`, `rsync`, `dnsmasq`, `httpd`, `unfsd3`, `syslogd`, `network_tools`, `nrpe`, `ckermit`, `enable_wireless_adb` |
| **Development & Scripting** | `git`, `python3` (3.10 / 3.14 / 3.15), `perl` (5.38 / 5.40 / 5.44), `lua`, `tcl`, `regina`, `cmake` (4.x), `gdb` (15–18), `binutils`, `autoconf_tools`, `bison_flex`, `gettext`, `gpg1`, `protoc`, `sqlite3`, `texinfo`, `AndroidSDK` |
| **System, Debug & MicroG** | `DebugTools`, `PlayStore_for_MicroG`, `disable_fake_store`, `e2fsprogs`, `selinux_tools`, `bootctl`, `ro2rw`, `create_dynamic_partition`, `magisk_module_template` |

---

## ADB Shell Maintenance Scripts

Useful helper scripts for maintaining Magisk Modules directly in an `adb shell` are provided in **[`scripts/`](scripts)**:

| Script | Description |
| :--- | :--- |
| [`scripts/install_mm.sh`](scripts/install_mm.sh) | Install a Magisk Module via the `magisk` binary in an `adb shell` |
| [`scripts/lmm`](scripts/lmm) | List and maintain installed Magisk Modules |
| [`scripts/list_bind_mounts.sh`](scripts/list_bind_mounts.sh) | List bind mounts created by Magisk for installed Magisk Modules |
| [`scripts/recreate_bind_mount.sh`](scripts/recreate_bind_mount.sh) | Update a file installed via a Magisk Module without rebooting the phone |

---

## Dedicated Compiler & Toolchain Repositories

Larger standalone compiler toolchains are hosted in their own dedicated repositories:

| Toolchain | Repository | Documentation |
| :--- | :--- | :--- |
| **Clang 19** (`NDK r27b`) | [bnsmb/Magisk-Module-with-clang19](https://github.com/bnsmb/Magisk-Module-with-clang19) | [HowTo & Docs](http://bnsmb.de/My_HowTos_for_Android.html#Documentation_for_the_Magisk_Module_with_clang19_and_the_NDK_r27b) |
| **Clang 20** (`NDK r29 beta1`) | [bnsmb/clang20-for-Android](https://github.com/bnsmb/clang20-for-Android) | [HowTo & Docs](http://bnsmb.de/My_HowTos_for_Android.html#Documentation_for_the_Magisk_Module_with_clang20_and_the_NDK_r29_beta1) |
| **CMake 3.30.4 & Ninja 1.13** *(CMake 4.x is in this repo)* | [bnsmb/Magisk-Module-with-cmake](https://github.com/bnsmb/Magisk-Module-with-cmake) | — |
| **GCC 16.x Toolchain** | [bnsmb/Magisk-module-with-gcc-16.x](https://github.com/bnsmb/Magisk-module-with-gcc-16.x) | — |

---

## PlayStore for Custom ROMs with MicroG

The recommended Magisk Module for replacing FakeStore with the official Google Play Store on Custom ROMs with **MicroG** is **`PlayStore_for_MicroG_41.1.19-31-v1.2.0.zip`** *(see also `PlayStore_for_MicroG_41.1.19-31-v1.2.1.zip` / `PlayStore_for_MicroG_v2.0.0.zip` in [`Magisk_Modules/`](Magisk_Modules))*:

- Multi-arch libraries included for **`arm64`**, **`arm`**, **`x86`**, and **`x86-64`** CPUs.
- Successfully tested on **Android 12, 13, 14, 15, and 16**.
- The bundled PlayStore version automatically updates itself to the latest version after installation.
- **Documentation:** [How to replace the FakeStore in MicroG with the original Playstore](http://bnsmb.de/My_HowTos_for_Android.html#How_to_replace_the_FakeStore_in_MicroG_with_the_original_Playstore)

---

## Documentation & Archive

- **Online Module Documentation (always up to date):** [http://bnsmb.de/Magisk_Modules.html](http://bnsmb.de/Magisk_Modules.html)
- **Local Copy in This Repo:** [`Magisk_Modules.html`](./Magisk_Modules.html) *(note: local copy may be outdated)*
- **Previous Module Versions:** [`Magisk_Modules/archive/`](Magisk_Modules/archive)
