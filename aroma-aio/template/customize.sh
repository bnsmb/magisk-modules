#!/system/bin/sh
# bnsmb Magisk Modules AIO — Multi-Module Installer (Dual-Mode: Recovery & Root App)
# Installs every selected child bnsmb Magisk module ZIP cleanly using the native root
# manager (Magisk / KernelSU / APatch) or authentic Recovery update-binary / customize.sh,
# then removes the temporary AIO wrapper so only the real individual modules remain.

SKIPUNZIP=1

unzip -qjo "$ZIPFILE" 'META-INF/com/google/android/aroma-mod-lib.sh' -d "$TMPDIR" >/dev/null 2>&1
[ -f "$TMPDIR/aroma-mod-lib.sh" ] && . "$TMPDIR/aroma-mod-lib.sh"

case "$BOOTMODE" in
  true|1)  BOOTMODE=true ;;
  false|0) BOOTMODE=false ;;
  *)
    if (ps -A 2>/dev/null || ps 2>/dev/null) | grep -qE "zygote|surfaceflinger"; then
      BOOTMODE=true
    else
      BOOTMODE=false
    fi
    ;;
esac

if command -v aroma_run_config_if_needed >/dev/null 2>&1; then
  aroma_run_config_if_needed
fi

AROMA_PROP_DIR="${AROMA_TMP:-/tmp/aroma}"
SEL_FILE="$AROMA_PROP_DIR/selected_modules.tsv"
LOG_FILE="$AROMA_PROP_DIR/aio-install.log"
mkdir -p "$AROMA_PROP_DIR"
: > "$LOG_FILE"

ui_print "********************************************"
ui_print "       bnsmb Magisk Modules AIO (ANI)       "
ui_print "********************************************"

if [ ! -s "$SEL_FILE" ]; then
  abort "! No modules selected (missing $SEL_FILE)."
fi

TOTAL="$(wc -l < "$SEL_FILE" | tr -d ' \r\n')"
[ -z "$TOTAL" ] && TOTAL=1
IDX=0
OK_CNT=0
FAIL_CNT=0

install_one_child_zip() {
  local czip="$1" cid="$2" cname="$3"
  local rc=1

  if [ "$BOOTMODE" = "true" ]; then
    # Booted Android: invoke native root manager CLI so module registers cleanly
    if command -v magisk >/dev/null 2>&1 && [ -d /data/adb/magisk ]; then
      magisk --install-module "$czip" >> "$LOG_FILE" 2>&1
      rc=$?
    elif command -v ksud >/dev/null 2>&1; then
      ksud module install "$czip" >> "$LOG_FILE" 2>&1
      rc=$?
    elif command -v apd >/dev/null 2>&1; then
      apd module install "$czip" >> "$LOG_FILE" 2>&1
      rc=$?
    fi
    if [ "$rc" -eq 0 ]; then
      return 0
    fi
  fi

  # Recovery (or fallback): use Magisk util_functions.sh if present, else standalone Recovery install
  if [ -f /data/adb/magisk/util_functions.sh ]; then
    (
      export OUTFD=""
      export ZIPFILE="$czip"
      export BOOTMODE=false
      . /data/adb/magisk/util_functions.sh
      install_module
    ) >> "$LOG_FILE" 2>&1
    rc=$?
    [ "$rc" -eq 0 ] && return 0
  fi

  # Standalone Recovery fallback (KernelSU / APatch / decrypted /data without Magisk)
  local cwork="$TMPDIR/child_${cid}"
  local cmod="/data/adb/modules/$cid"
  rm -rf "$cwork" "$cmod"
  mkdir -p "$cwork" "$cmod"
  unzip -o "$czip" -x 'META-INF/*' -d "$cmod" >> "$LOG_FILE" 2>&1 || return 1
  if [ -f "$cmod/customize.sh" ]; then
    (
      export MODPATH="$cmod"
      export TMPDIR="$cwork"
      export ZIPFILE="$czip"
      export BOOTMODE=false
      set_perm() { chown "$2:$3" "$1" 2>/dev/null || true; chmod "$4" "$1" 2>/dev/null || true; }
      set_perm_recursive() {
        find "$1" -type d 2>/dev/null | while IFS= read -r d; do chown "$2:$3" "$d" 2>/dev/null || true; chmod "$4" "$d" 2>/dev/null || true; done
        find "$1" -type f 2>/dev/null | while IFS= read -r f; do chown "$2:$3" "$f" 2>/dev/null || true; chmod "$5" "$f" 2>/dev/null || true; done
      }
      ui_print() { echo "$1"; }
      abort() { echo "ABORT: $1"; exit 1; }
      . "$cmod/customize.sh"
    ) >> "$LOG_FILE" 2>&1
    rc=$?
  else
    rc=0
  fi
  rm -rf "$cwork"
  return $rc
}

while IFS='|' read -r skey cid cname cver szkb rzip ccat; do
  [ -n "$rzip" ] || continue
  IDX=$((IDX + 1))
  ui_print ""
  ui_print "[$IDX/$TOTAL] Installing $cname ($cver)..."
  if command -v aroma_progress >/dev/null 2>&1; then
    PCT="$(awk -v i="$IDX" -v t="$TOTAL" 'BEGIN{printf "%.2f", (i - 0.5) / t}')"
    aroma_progress "$PCT" "Installing [$IDX/$TOTAL] $cname..."
  fi

  STAGE_ZIP="$TMPDIR/$(basename "$rzip")"
  rm -f "$STAGE_ZIP"
  unzip -qjo "$ZIPFILE" "$rzip" -d "$TMPDIR" >/dev/null 2>&1
  if [ ! -f "$STAGE_ZIP" ]; then
    ui_print "  ! Failed to extract $rzip"
    FAIL_CNT=$((FAIL_CNT + 1))
    continue
  fi

  if install_one_child_zip "$STAGE_ZIP" "$cid" "$cname"; then
    ui_print "  + Installed $cname ($cid)"
    OK_CNT=$((OK_CNT + 1))
  else
    ui_print "  ! Failed to install $cname ($cid) — see $LOG_FILE"
    FAIL_CNT=$((FAIL_CNT + 1))
  fi
  rm -f "$STAGE_ZIP"
done < "$SEL_FILE"

# Clean up temporary AIO wrapper module so only the real bnsmb modules stay installed
if [ -n "$MODPATH" ] && [ -d "$MODPATH" ]; then
  if [ "$BOOTMODE" = "true" ]; then
    touch "$MODPATH/remove" 2>/dev/null || true
    touch "$MODPATH/disable" 2>/dev/null || true
  else
    rm -rf "$MODPATH" 2>/dev/null || true
  fi
fi

command -v aroma_progress >/dev/null 2>&1 && aroma_progress 1.00 "Installed $OK_CNT/$TOTAL modules!"
ui_print ""
ui_print "********************************************"
ui_print "  Done! Installed: $OK_CNT | Failed: $FAIL_CNT"
ui_print "  Reboot to activate your selected modules."
ui_print "********************************************"
[ "$FAIL_CNT" -eq 0 ] || exit 1
