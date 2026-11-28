#!/sbin/sh
# bnsmb Magisk Modules AIO — Live Device, Root Manager & Installed Modules Probe
AROMA_TMP="${AROMA_TMP:-/tmp/aroma}"
ROOT_PFX="${AIO_ROOT_PREFIX:-}"
mkdir -p "$AROMA_TMP"

IN_ANDROID=0
case "$BOOTMODE" in
  true|1) IN_ANDROID=1 ;;
  false|0) IN_ANDROID=0 ;;
  *)
    if [ -z "$ROOT_PFX" ] && (ps -A 2>/dev/null || ps 2>/dev/null) | grep -qE "zygote|surfaceflinger"; then
      IN_ANDROID=1
    fi
    ;;
esac

if [ -z "$ROOT_PFX" ] && [ "$IN_ANDROID" = "0" ]; then
  for mp in /data /system_root /vendor; do
    if [ -d "$mp" ] && ! grep -q " $mp " /proc/mounts 2>/dev/null; then
      if [ "$mp" = "/data" ]; then
        mount "$mp" >/dev/null 2>&1 || true
      else
        mount -o ro "$mp" >/dev/null 2>&1 || true
      fi
    fi
  done
fi

CAN_MOD=0
ROOT_NAME="No Root / Encrypted /data"
if [ -d "${ROOT_PFX}/data/adb/ksu" ] || [ -f "${ROOT_PFX}/data/adb/ksu/modules.img" ]; then
  CAN_MOD=1; ROOT_NAME="KernelSU (Systemless Overlay)"
elif [ -d "${ROOT_PFX}/data/adb/ap" ]; then
  CAN_MOD=1; ROOT_NAME="APatch (Systemless Overlay)"
elif [ -d "${ROOT_PFX}/data/adb/magisk" ] || [ -d "${ROOT_PFX}/data/adb/modules" ]; then
  CAN_MOD=1; ROOT_NAME="Magisk (Systemless Magic Mount)"
elif [ -d "${ROOT_PFX}/data/adb" ]; then
  CAN_MOD=1; ROOT_NAME="Root Manager (/data/adb)"
fi

MODEL=""
REL=""
if [ -z "$ROOT_PFX" ]; then
  MODEL="$(getprop ro.product.model 2>/dev/null)"
  [ -z "$MODEL" ] && MODEL="$(getprop ro.product.vendor.model 2>/dev/null)"
  REL="$(getprop ro.build.version.release 2>/dev/null)"
fi
for bp in "${ROOT_PFX}/vendor/build.prop" "${ROOT_PFX}/system_root/system/build.prop" "${ROOT_PFX}/system/build.prop"; do
  if [ -f "$bp" ]; then
    [ -z "$MODEL" ] && MODEL="$(sed -n 's/^ro\.product\.vendor\.model=//p' "$bp" | head -n1 | tr -d '\r')"
    [ -z "$MODEL" ] && MODEL="$(sed -n 's/^ro\.product\.model=//p' "$bp" | head -n1 | tr -d '\r')"
    [ -z "$REL" ]   && REL="$(sed -n 's/^ro\.build\.version\.release=//p' "$bp" | head -n1 | tr -d '\r')"
  fi
done
[ -z "$MODEL" ] && MODEL="Android arm64 Device"
[ -z "$REL" ] && REL="Android"

INSTALLED=0
if [ -f "$AROMA_TMP/catalog.tsv" ]; then
  while IFS='|' read -r idx skey mid mname mver szkb rzip mcat; do
    [ -n "$mid" ] || continue
    if [ -d "${ROOT_PFX}/data/adb/modules/$mid" ]; then
      INSTALLED=$((INSTALLED + 1))
    fi
  done < "$AROMA_TMP/catalog.tsv"
fi

cat > "$AROMA_TMP/probe.prop" <<EOF
device_info=$MODEL (Android $REL)
can_modify=$CAN_MOD
root_name=$ROOT_NAME
installed_count=$INSTALLED
in_android=$IN_ANDROID
EOF
exit 0
