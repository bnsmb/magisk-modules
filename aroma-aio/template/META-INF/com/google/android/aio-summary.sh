#!/sbin/sh
# bnsmb Magisk Modules AIO — Collect checked modules from sel_p*.prop into selected_modules.tsv & summary.txt
AROMA_TMP="${AROMA_TMP:-/tmp/aroma}"
mkdir -p "$AROMA_TMP"

MODE="1"
if [ -f "$AROMA_TMP/mode.prop" ]; then
  MVAL="$(sed -n 's/^selected=//p' "$AROMA_TMP/mode.prop" | head -n1 | tr -d '\r')"
  [ -n "$MVAL" ] && MODE="$MVAL"
fi

is_checked() {
  local key="$1" f v
  [ "$MODE" = "2" ] && return 0
  for f in "$AROMA_TMP"/sel_p*.prop; do
    [ -f "$f" ] || continue
    v="$(sed -n "s/^${key}=//p" "$f" 2>/dev/null | tail -n1 | tr -d '\r')"
    [ "$v" = "1" ] && return 0
  done
  return 1
}

SEL_FILE="$AROMA_TMP/selected_modules.tsv"
SUM_FILE="$AROMA_TMP/summary.txt"
: > "$SEL_FILE"

COUNT=0
TOTAL_KB=0
LIST=""

if [ -f "$AROMA_TMP/catalog.tsv" ]; then
  while IFS='|' read -r idx skey mid mname mver szkb rzip mcat; do
    [ -n "$skey" ] || continue
    if is_checked "$skey"; then
      printf '%s|%s|%s|%s|%s|%s|%s\n' "$skey" "$mid" "$mname" "$mver" "$szkb" "$rzip" "$mcat" >> "$SEL_FILE"
      COUNT=$((COUNT + 1))
      TOTAL_KB=$((TOTAL_KB + szkb))
      SZ_TENTHS="$(( (szkb * 10 + 512) / 1024 ))"
      SZ_STR="$(( SZ_TENTHS / 10 )).$(( SZ_TENTHS % 10 )) MB"
      LIST="${LIST}  • ${mname} (${mver}) — ${SZ_STR}\n"
    fi
  done < "$AROMA_TMP/catalog.tsv"
fi

TOT_TENTHS="$(( (TOTAL_KB * 10 + 512) / 1024 ))"
TOT_MB="$(( TOT_TENTHS / 10 )).$(( TOT_TENTHS % 10 ))"

DEV="$(sed -n 's/^device_info=//p' "$AROMA_TMP/probe.prop" 2>/dev/null | head -n1 | tr -d '\r')"
ROOT="$(sed -n 's/^root_name=//p' "$AROMA_TMP/probe.prop" 2>/dev/null | head -n1 | tr -d '\r')"

if [ "$COUNT" = "0" ]; then
  LIST="  (None selected — go Back and check at least one module!)\n"
fi

printf '%b' "Device: ${DEV:-Android}\nTarget: ${ROOT:-Root Manager}\nSelected Modules: ${COUNT} (${TOT_MB} MB)\n\n${LIST}\nEach module will be installed cleanly using its own customize.sh under /data/adb/modules/<id>/.\nThe temporary AIO wrapper removes itself automatically.\n" > "$SUM_FILE"

cat > "$AROMA_TMP/summary.prop" <<EOF
selected_count=$COUNT
total_mb=$TOT_MB
EOF
exit 0
