# Changelog — `aroma-aio` (AROMA-Next Multi-Module AIO Builder)

## v1.0.0 — 2026-11-28
- **Initial Release:** Added optional, 100% additive AROMA-Next-Installer (`ANI`) All-In-One (AIO) multi-module installer builder for [`bnsmb/magisk-modules`](https://github.com/bnsmb/magisk-modules).
- **Dynamic Catalog & Config Generator (`aroma-aio/build_aio.py`):**
  - Zero-dependency Python 3 script that scans `Magisk_Modules/*.zip`, parses every module's `module.prop`, automatically deduplicates older versions (selecting the newest release per unique module ID), categorizes modules into 4 groups, and emits a paginated **AMOLED Modern Material 3 `aroma-config`** strictly respecting all C engine buffer limits.
  - Added 5 ready-to-use presets: `essentials`, `networking`, `dev`, `all-latest`, and `custom` (`--include`).
- **Dual-Mode Multi-Module Installer (`aroma-aio/template/`):**
  - Single generated `aroma-config` drives **60–120Hz Touch GUI + `ANF` Bootloop-Saver** in Custom Recovery (`BOOTMODE=0`) and native C **Volume Key Selector** (with Back navigation) in Magisk / KernelSU / APatch (`BOOTMODE=1`).
  - Live pre-flight probe (`aio-probe.sh`) detects hardware model, Root Manager, and already-installed modules under `/data/adb/modules/`.
  - `customize.sh` installs every checked child `.zip` via the native root manager (`magisk --install-module`, `ksud module install`, `apd module install`) or its own authentic Recovery `customize.sh`, streams live `aroma_progress` updates, and removes the temporary AIO wrapper automatically.
- **Zero-Bloat GitHub Actions CI (`.github/workflows/aroma-aio-builder.yml`):**
  - Packages AIO bundles dynamically via [`Miustone/aroma-next-action@v1`](https://github.com/Miustone/aroma-next-action) with zero committed `ANI` binaries/assets.
  - Uses `sparse-checkout` to skip `Magisk_Modules/archive/`, supports 1-click `workflow_dispatch` preset selection, verifies ZIP integrity, `0755` permissions, LF endings, Edify limits & POSIX `sh -n`, and uploads the flashable ZIP + `SHA256SUMS.txt`.
