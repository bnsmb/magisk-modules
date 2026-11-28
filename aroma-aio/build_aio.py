#!/usr/bin/env python3
"""
Dynamic AROMA-Next-Installer (ANI) All-In-One (AIO) Multi-Module Builder
for bnsmb/magisk-modules.

Zero external dependencies (Python 3 stdlib only).

Scans Magisk_Modules/*.zip, reads each module's module.prop metadata, automatically
deduplicates older versions (keeping the newest release per module ID), categorizes
modules cleanly, generates a paginated AMOLED Modern Material 3 aroma-config, and
stages a clean directory ready for:
  - GitHub Actions: Miustone/aroma-next-action@v1 (zero vendored ANI binaries!)
  - Local builds:   --build-zip (auto-fetches & caches ANI Magisk Template)
"""

import argparse
import json
import os
import re
import shutil
import urllib.request
import zipfile
from dataclasses import dataclass
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parent
TEMPLATE_DIR = SCRIPT_DIR / "template"
CACHE_DIR = SCRIPT_DIR / ".aroma-cache"

UPSTREAM_ANI_REPO = "Miustone/AROMA-Next-Installer"
ANI_ASSET_NAME = "AROMA-Next-Magisk-Template.zip"

PRESETS: dict[str, list[str]] = {
    "essentials": [
        "bash",
        "btop",
        "coreutils",
        "curl",
        "findutils",
        "procps",
        "rsync",
        "util-linux",
        "vim",
        "wget2",
        "compression_tools",
        "initshell",
        "myscripts",
        "enable_wireless_adb",
        "bootctl",
        "selinux_tools",
        "e2fsprogs",
    ],
    "networking": [
        "openssh",
        "openssl",
        "openvpn",
        "curl",
        "wget2",
        "rsync",
        "dnsmasq",
        "httpd",
        "unfsd3",
        "syslogd",
        "network_tools",
        "enable_wireless_adb",
    ],
    "dev": [
        "git",
        "vim",
        "python3",
        "cmake",
        "gdb",
        "binutils",
        "autoconf_tools",
        "bison",
        "sqlite3",
        "lua",
        "perl",
        "protoc",
        "bash",
        "DebugTools",
    ],
}

CATEGORIES: list[tuple[str, list[str]]] = [
    ("Shell & CLI Essentials", ["bash", "btop", "coreutils", "findutils", "procps", "util-linux", "compression", "initshell", "myscripts", "man", "bvi", "the"]),
    ("Networking & Remote",    ["openssh", "openssl", "openvpn", "curl", "wget", "rsync", "dnsmasq", "httpd", "unfsd", "syslogd", "network_tools", "wireless_adb", "nrpe", "ckermit", "clang19_sshd"]),
    ("Dev & Compilers",        ["git", "vim", "python", "cmake", "gdb", "binutils", "autoconf", "bison", "sqlite", "lua", "perl", "protoc", "gettext", "gpg", "tcl", "texinfo", "regina", "androidsdk", "android-sdk"]),
    ("System & MicroG",        ["playstore", "fake_store", "debugtools", "bootctl", "selinux", "e2fsprogs", "ro2rw", "dynamic_partition", "asus_hw"]),
]

MAX_ITEMS_PER_PAGE = 20


@dataclass
class ModEntry:
    zip_path: Path
    mod_id: str
    safe_key: str
    name: str
    version: str
    version_code: int
    description: str
    size_bytes: int
    category: str


def nat_key(s: str) -> list[tuple[int, object]]:
    parts = re.split(r"(\d+)", s.lower())
    out: list[tuple[int, object]] = []
    for p in parts:
        if p.isdigit():
            out.append((0, int(p)))
        elif p:
            out.append((1, p))
    return out


def sanitize_edify(s: str, max_bytes: int) -> str:
    s = s.replace("\\", "/").replace('"', "'").replace("\r", " ").replace("\n", " ").replace("|", "-")
    s = re.sub(r"\s+", " ", s).strip()
    raw = s.encode("utf-8")
    if len(raw) <= max_bytes:
        return s
    # Truncate cleanly on UTF-8 boundary
    cut = raw[: max(1, max_bytes - 3)]
    while True:
        try:
            return cut.decode("utf-8").rstrip() + "..."
        except UnicodeDecodeError:
            cut = cut[:-1]


def classify_category(mod_id: str, filename: str) -> str:
    hay = f"{mod_id} {filename}".lower()
    for cat_name, keywords in CATEGORIES:
        if any(k in hay for k in keywords):
            return cat_name
    return "Other Modules"


def inspect_module_zip(zp: Path) -> ModEntry | None:
    try:
        with zipfile.ZipFile(zp, "r") as zf:
            prop_name = None
            for n in zf.namelist():
                if n == "module.prop" or n.endswith("/module.prop"):
                    if prop_name is None or len(n) < len(prop_name):
                        prop_name = n
            if not prop_name:
                return None
            props: dict[str, str] = {}
            for line in zf.read(prop_name).decode("utf-8", errors="replace").splitlines():
                if "=" in line and not line.lstrip().startswith("#"):
                    k, v = line.split("=", 1)
                    props[k.strip()] = v.strip()
    except (zipfile.BadZipFile, OSError):
        return None

    mod_id = props.get("id", "").strip() or zp.stem
    if "magisk_module_template" in mod_id.lower() or "magisk_module_template" in zp.name.lower():
        return None

    name = props.get("name", "").strip() or mod_id
    version = props.get("version", "").strip() or "1.0"
    try:
        vcode = int(re.sub(r"\D", "", props.get("versionCode", "0")) or "0")
    except ValueError:
        vcode = 0
    desc = props.get("description", "").strip() or f"{name} Magisk module"
    safe_key = re.sub(r"[^a-zA-Z0-9_]", "_", mod_id)[:24]
    return ModEntry(
        zip_path=zp,
        mod_id=mod_id,
        safe_key=safe_key,
        name=name,
        version=version,
        version_code=vcode,
        description=desc,
        size_bytes=zp.stat().st_size,
        category=classify_category(mod_id, zp.name),
    )


def discover_latest_modules(modules_dir: Path) -> list[ModEntry]:
    by_family: dict[str, ModEntry] = {}
    for zp in sorted(modules_dir.glob("*.zip")):
        if not zp.is_file():
            continue
        ent = inspect_module_zip(zp)
        if ent is None:
            continue
        # Deduplicate by normalized family ID (e.g. gdb16/gdb17/gdb18 -> keep newest per unique mod_id)
        key = ent.mod_id.lower()
        prev = by_family.get(key)
        if prev is None:
            by_family[key] = ent
        else:
            # Prefer higher versionCode, then natural sort of version & filename
            cur_rank = (ent.version_code, nat_key(ent.version), nat_key(ent.zip_path.name))
            prev_rank = (prev.version_code, nat_key(prev.version), nat_key(prev.zip_path.name))
            if cur_rank > prev_rank:
                by_family[key] = ent

    # Ensure unique safe_key across all discovered modules
    used_keys: set[str] = set()
    result: list[ModEntry] = []
    for idx, ent in enumerate(sorted(by_family.values(), key=lambda e: (e.category, e.name.lower())), start=1):
        sk = f"m{idx:02d}_{ent.safe_key}"[:28]
        while sk in used_keys:
            sk = f"m{idx:02d}_{len(used_keys)}"
        used_keys.add(sk)
        ent.safe_key = sk
        result.append(ent)
    return result


def filter_modules(all_mods: list[ModEntry], preset: str, include_csv: str) -> list[ModEntry]:
    if include_csv.strip():
        tokens = [t.strip().lower() for t in include_csv.split(",") if t.strip()]
        return [
            m for m in all_mods
            if any(t in m.mod_id.lower() or t in m.zip_path.name.lower() or t in m.name.lower() for t in tokens)
        ]
    if preset == "all-latest":
        return all_mods
    patterns = PRESETS.get(preset, [])
    if not patterns:
        return all_mods
    chosen: list[ModEntry] = []
    for m in all_mods:
        hay = f"{m.mod_id} {m.zip_path.name}".lower()
        if any(p.lower() in hay for p in patterns):
            chosen.append(m)
    return chosen


def generate_aroma_config(mods: list[ModEntry], preset: str) -> str:
    # Group modules by category in stable display order
    cat_order = [c for c, _ in CATEGORIES] + ["Other Modules"]
    grouped: list[tuple[str, list[ModEntry]]] = []
    for cat in cat_order:
        items = [m for m in mods if m.category == cat]
        if items:
            grouped.append((cat, items))

    # Split into pages of <= MAX_ITEMS_PER_PAGE modules
    pages: list[list[tuple[str, list[ModEntry]]]] = []
    cur_page: list[tuple[str, list[ModEntry]]] = []
    cur_cnt = 0
    for cat, items in grouped:
        idx = 0
        while idx < len(items):
            room = MAX_ITEMS_PER_PAGE - cur_cnt
            if room <= 0:
                pages.append(cur_page)
                cur_page = []
                cur_cnt = 0
                room = MAX_ITEMS_PER_PAGE
            chunk = items[idx : idx + room]
            cur_page.append((cat, chunk))
            cur_cnt += len(chunk)
            idx += len(chunk)
    if cur_page:
        pages.append(cur_page)

    total_mb = sum(m.size_bytes for m in mods) / (1024 * 1024)
    total_pages = len(pages)

    lines: list[str] = [
        "###",
        f"# bnsmb Magisk Modules AIO — Generated AROMA-Next-Installer (ANI) Config",
        f"# Preset: {preset} | Bundled Modules: {len(mods)} ({total_mb:.1f} MB) | Pages: {total_pages}",
        "###",
        "",
        'ini_set("rom_name",    "bnsmb Magisk Modules AIO");',
        f'ini_set("rom_version", "{sanitize_edify(preset, 32)} ({len(mods)} modules)");',
        'ini_set("rom_author",  "bnsmb (ANI UI: Miustone)");',
        'ini_set("rom_device",  "Android arm64");',
        'ini_set("rom_date",    "2026");',
        "",
        "anisplash(",
        "    2,",
        '    "splash/a1", 320,',
        '    "splash/a2", 28,',
        '    "splash/a3", 28,',
        '    "splash/a4", 28,',
        '    "splash/a5", 28,',
        '    "splash/a6", 28',
        ");",
        "",
        'fontresload("0", "ttf/GoogleSans-Regular.ttf;ttf/Roboto-Regular.ttf;ttf/DroidSansFallback.ttf;", "12");',
        'fontresload("1", "ttf/GoogleSans-Regular.ttf;ttf/Roboto-Regular.ttf;ttf/DroidSansFallback.ttf;", "14");',
        "",
        'theme("amoled");',
        "",
        "# Run live device & root-manager pre-flight probe",
        'ziptotmp("META-INF/com/google/android/aio-probe.sh", "aio-probe.sh");',
        'ziptotmp("modules/catalog.tsv", "catalog.tsv");',
        'exec("/sbin/sh", "/tmp/aroma/aio-probe.sh");',
        "",
        'if prop("probe.prop", "can_modify") != "1" then',
        "  alert(",
        '    "Root Target Notice",',
        '    "<b>No Root Manager (/data/adb) detected!</b>\\n\\n" +',
        '    "Make sure /data is decrypted in Recovery or flash this ZIP inside the Magisk, KernelSU, or APatch app.",',
        '    "@alert"',
        "  );",
        "endif;",
        "",
        "# ==============================================================================",
        "# SCREEN 1: Welcome Hero Card",
        "# ==============================================================================",
        "viewbox(",
        '  "bnsmb Magisk Modules AIO",',
        '  "<b>Multi-Module All-In-One Installer</b>\\n" +',
        f'  "Preset: <b>{sanitize_edify(preset, 32)}</b> • {len(mods)} Modules ({total_mb:.1f} MB)\\n\\n" +',
        '  "<b>Device:</b> " + prop("probe.prop", "device_info") + "\\n" +',
        '  "<b>Target:</b> <#selectbg_g>" + prop("probe.prop", "root_name") + "</#>\\n" +',
        '  "<b>Already Installed:</b> " + prop("probe.prop", "installed_count") + " module(s)\\n\\n" +',
        '  "<i>Select exactly which arm64 CLI, dev &amp; networking modules to install in a single flash. Each module runs its own authentic installer!</i>",',
        '  "@welcome"',
        ");",
        "",
        "# ==============================================================================",
        "# SCREEN 2: Install Mode Hub",
        "# ==============================================================================",
        "menubox(",
        '  "Choose Installation Mode",',
        '  "Pick modules individually, install all bundled modules, or open ANF:",',
        '  "@personalize",',
        '  "mode.prop",',
        '  "Select Modules Individually",   "Browse categories and check the modules you want", "@customize",',
        f'  "Install ALL Bundled ({len(mods)})", "Install every module included in this AIO bundle", "@install",',
        '  "AROMA-Next-Filemanager (ANF)",  "Manage installed modules, Bootloop-Saver & Storage", "@apps"',
        ");",
        "",
        'if prop("mode.prop", "selected") == "3" then',
        '  filemanager("/data/adb/modules");',
        '  back("1");',
        "endif;",
        "",
        "# ==============================================================================",
        "# SCREEN 3+: Paginated Module Selection",
        "# ==============================================================================",
        'if prop("mode.prop", "selected") == "1" then',
    ]

    for p_idx, page_groups in enumerate(pages, start=1):
        title = f"Select Modules ({p_idx}/{total_pages})" if total_pages > 1 else "Select Modules to Install"
        prop_file = f"sel_p{p_idx}.prop"
        lines.append("  form(")
        lines.append(f'    "{sanitize_edify(title, 58)}",')
        lines.append('    "Check the bnsmb Magisk modules you want to install:",')
        lines.append('    "@apps",')
        lines.append(f'    "{prop_file}",')

        entries_lines: list[str] = []
        for g_idx, (cat, items) in enumerate(page_groups, start=1):
            gid = f"grp_{p_idx}_{g_idx}"
            entries_lines.append(f'    "{gid}", "{sanitize_edify(cat, 58)}", "", "group"')
            for m in items:
                sz_mb = m.size_bytes / (1024 * 1024)
                sz_str = f"{sz_mb:.1f} MB" if sz_mb >= 0.1 else f"{max(1, m.size_bytes // 1024)} KB"
                m_title = sanitize_edify(f"{m.name} ({m.version})", 58)
                m_desc = sanitize_edify(f"{sz_str} | {m.description}", 118)
                entries_lines.append(f'    "{m.safe_key}", "{m_title}", "{m_desc}", "check"')

        lines.append(",\n".join(entries_lines))
        lines.append("  );")
        lines.append("")

    lines.extend([
        "endif;",
        "",
        "# ==============================================================================",
        "# REVIEW & INSTALL",
        "# ==============================================================================",
        'ziptotmp("META-INF/com/google/android/aio-summary.sh", "aio-summary.sh");',
        'exec("/sbin/sh", "/tmp/aroma/aio-summary.sh");',
        "",
        'if prop("summary.prop", "selected_count") == "0" then',
        "  alert(",
        '    "No Modules Selected",',
        '    "You did not select any modules to install.\\n\\nPlease go back and check at least one module.",',
        '    "@alert"',
        "  );",
        '  back("1");',
        "endif;",
        "",
        "textbox(",
        '  "Review & Ready to Install",',
        '  "The following Magisk modules will be installed cleanly:",',
        '  "@confirm",',
        '  readtmpfile("summary.txt")',
        ");",
        "",
        'setvar("retstatus",',
        "  install(",
        '    "Installing Selected Modules",',
        '    "Running authentic installer for each chosen bnsmb module...",',
        '    "@install",',
        '    "All selected modules processed!"',
        "  )",
        ");",
        "",
        'ini_set("text_next", "Finish");',
        "",
        "checkviewbox(",
        '  "Installation Complete",',
        '  "<b>bnsmb Magisk Modules AIO</b> finished with exit code <b>" + getvar("retstatus") + "</b>.\\n\\n" +',
        '  "<b>Selected:</b> " + prop("summary.prop", "selected_count") + " module(s) (" + prop("summary.prop", "total_mb") + " MB)\\n" +',
        '  "<b>Log:</b> /tmp/aroma/aio-install.log\\n\\n" +',
        '  "<i>Each chosen module was installed independently under /data/adb/modules/!</i>",',
        '  "@finish",',
        '  "Reboot device now",',
        '  "0",',
        '  "reboot_it"',
        ");",
        "",
        'if prop("reboot_it", "selected") == "1" then',
        '  reboot("now");',
        "endif;",
        "",
    ])
    return "\n".join(lines)


def stage_aio(modules_dir: Path, stage_dir: Path, preset: str, include_csv: str) -> list[ModEntry]:
    all_mods = discover_latest_modules(modules_dir)
    if not all_mods:
        raise SystemExit(f"No valid Magisk module ZIPs found in {modules_dir}")
    chosen = filter_modules(all_mods, preset, include_csv)
    if not chosen:
        raise SystemExit(f"Preset '{preset}' / include '{include_csv}' matched 0 modules (available: {len(all_mods)})")

    if stage_dir.exists():
        shutil.rmtree(stage_dir)
    shutil.copytree(TEMPLATE_DIR, stage_dir)

    mods_out = stage_dir / "modules"
    mods_out.mkdir(parents=True, exist_ok=True)
    catalog_lines: list[str] = []
    for idx, m in enumerate(chosen, start=1):
        rel_zip = f"modules/{m.safe_key}.zip"
        shutil.copy2(m.zip_path, stage_dir / rel_zip)
        sz_kb = max(1, m.size_bytes // 1024)
        catalog_lines.append(
            f"{idx}|{m.safe_key}|{m.mod_id}|{sanitize_edify(m.name, 60)}|"
            f"{sanitize_edify(m.version, 32)}|{sz_kb}|{rel_zip}|{m.category}"
        )

    (mods_out / "catalog.tsv").write_text("\n".join(catalog_lines) + "\n", encoding="utf-8", newline="\n")
    cfg = generate_aroma_config(chosen, preset)
    cfg_path = stage_dir / "META-INF/com/google/android/aroma-config"
    cfg_path.parent.mkdir(parents=True, exist_ok=True)
    cfg_path.write_text(cfg, encoding="utf-8", newline="\n")

    total_mb = sum(m.size_bytes for m in chosen) / (1024 * 1024)
    print(f"[ok] Staged {len(chosen)} modules ({total_mb:.2f} MB) for preset '{preset}' -> {stage_dir}")
    return chosen


def gh_request(url: str) -> bytes:
    req = urllib.request.Request(url, headers={"User-Agent": "bnsmb-aio-builder/1.0"})
    token = os.environ.get("GITHUB_TOKEN", "").strip()
    if token:
        req.add_header("Authorization", f"Bearer {token}")
    with urllib.request.urlopen(req, timeout=60) as resp:
        return resp.read()


def package_local_zip(stage_dir: Path, out_zip: Path, aroma_version: str, local_ani_zip: str) -> None:
    if local_ani_zip:
        ani_zip = Path(local_ani_zip).resolve()
        tag = f"local:{ani_zip.name}"
    else:
        api = (
            f"https://api.github.com/repos/{UPSTREAM_ANI_REPO}/releases/latest"
            if aroma_version.lower() == "latest"
            else f"https://api.github.com/repos/{UPSTREAM_ANI_REPO}/releases/tags/{aroma_version}"
        )
        meta = json.loads(gh_request(api).decode("utf-8"))
        tag = meta.get("tag_name", aroma_version)
        CACHE_DIR.mkdir(parents=True, exist_ok=True)
        ani_zip = CACHE_DIR / f"{tag}-{ANI_ASSET_NAME}"
        if not ani_zip.is_file():
            dl_url = next((a["browser_download_url"] for a in meta.get("assets", []) if a["name"] == ANI_ASSET_NAME), None)
            if not dl_url:
                raise SystemExit(f"{ANI_ASSET_NAME} not found in {UPSTREAM_ANI_REPO} {tag}")
            print(f"[ani] Downloading {ANI_ASSET_NAME} ({tag})...")
            ani_zip.write_bytes(gh_request(dl_url))

    lf_names = {"aroma-config", "updater-script", "update-binary", "magisk-installer", "customize.sh", "module.prop"}
    lf_exts = {".sh", ".prop", ".lang", ".edify", ".txt", ".tsv"}
    exec_names = {"update-binary", "magisk-installer", "aroma_installer-arm64", "aroma_installer-arm32"}
    tmpl_scripts = {
        "META-INF/com/google/android/update-binary",
        "META-INF/com/google/android/magisk-installer",
        "META-INF/com/google/android/aroma-mod-lib.sh",
        "META-INF/com/google/android/updater-script",
    }

    entries: dict[str, tuple[bytes, int, int]] = {}  # rel -> (data, mode, compress_type)
    with zipfile.ZipFile(ani_zip, "r") as zf:
        for info in zf.infolist():
            if info.is_dir():
                continue
            arc = info.filename
            keep = (
                arc == "META-INF/com/google/android/bin/aroma_installer-arm64"
                or (arc.startswith("META-INF/com/google/android/aroma/") and not arc.endswith((".edify", "changelog.txt")))
                or arc in tmpl_scripts
            )
            if not keep:
                continue
            data = zf.read(info)
            p = Path(arc)
            if p.name in lf_names or p.suffix in lf_exts:
                data = data.replace(b"\r\n", b"\n").replace(b"\r", b"\n")
            mode = 0o755 if (p.name in exec_names or p.suffix == ".sh") else 0o644
            entries[arc] = (data, mode, zipfile.ZIP_DEFLATED)

    for p in sorted(stage_dir.rglob("*")):
        if not p.is_file():
            continue
        rel = p.relative_to(stage_dir).as_posix()
        data = p.read_bytes()
        if p.name in lf_names or p.suffix in lf_exts:
            data = data.replace(b"\r\n", b"\n").replace(b"\r", b"\n")
        mode = 0o755 if (p.name in exec_names or p.suffix == ".sh") else 0o644
        # Nested .zip files are already compressed -> store them for instant extraction!
        ctype = zipfile.ZIP_STORED if p.suffix == ".zip" else zipfile.ZIP_DEFLATED
        entries[rel] = (data, mode, ctype)

    out_zip.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(out_zip, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=6) as zf:
        for arc in sorted(entries.keys()):
            data, mode, ctype = entries[arc]
            zi = zipfile.ZipInfo(arc)
            zi.create_system = 3
            zi.external_attr = (0o100000 | mode) << 16
            zf.writestr(zi, data, compress_type=ctype)

    print(f"[ok] Built {out_zip} ({out_zip.stat().st_size:,} bytes, {len(entries)} entries, ANI {tag})")


def main() -> None:
    ap = argparse.ArgumentParser(description="Build bnsmb Magisk Modules AIO AROMA-Next ZIP")
    ap.add_argument("--modules-dir", type=Path, default=REPO_ROOT / "Magisk_Modules")
    ap.add_argument("--stage-dir", type=Path, default=REPO_ROOT / "build" / "aio-stage")
    ap.add_argument("--preset", default="essentials", choices=["essentials", "networking", "dev", "all-latest", "custom"])
    ap.add_argument("--include", default="", help="Comma-separated module IDs / filename substrings for custom bundles")
    ap.add_argument("--stage-only", action="store_true", help="Only stage directory (for Miustone/aroma-next-action@v1 in CI)")
    ap.add_argument("--output-zip", type=Path, default=None)
    ap.add_argument("--aroma-version", default="latest")
    ap.add_argument("--aroma-zip", default="")
    args = ap.parse_args()

    stage_aio(args.modules_dir, args.stage_dir, args.preset, args.include)
    if not args.stage_only:
        out_zip = args.output_zip or (REPO_ROOT / "dist" / f"bnsmb-Magisk-Modules-AIO-{args.preset}-ANI.zip")
        package_local_zip(args.stage_dir, out_zip, args.aroma_version, args.aroma_zip)


if __name__ == "__main__":
    main()
