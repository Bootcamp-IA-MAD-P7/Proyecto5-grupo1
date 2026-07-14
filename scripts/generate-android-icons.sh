#!/usr/bin/env bash
# Regenera ic_launcher* desde frontend/assets/icon/app_icon.png (1024×1024).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ICON="$ROOT/frontend/assets/icon/app_icon.png"
RES="$ROOT/frontend/android/app/src/main/res"

if [[ ! -f "$ICON" ]]; then
  echo "Missing source icon: $ICON" >&2
  exit 1
fi

command -v convert >/dev/null || { echo "ImageMagick (convert) required" >&2; exit 1; }

convert "$ICON" -resize 48x48   "$RES/mipmap-mdpi/ic_launcher.png"
convert "$ICON" -resize 72x72   "$RES/mipmap-hdpi/ic_launcher.png"
convert "$ICON" -resize 96x96   "$RES/mipmap-xhdpi/ic_launcher.png"
convert "$ICON" -resize 144x144 "$RES/mipmap-xxhdpi/ic_launcher.png"
convert "$ICON" -resize 192x192 "$RES/mipmap-xxxhdpi/ic_launcher.png"

convert "$ICON" -resize 108x108 "$RES/mipmap-mdpi/ic_launcher_foreground.png"
convert "$ICON" -resize 162x162 "$RES/mipmap-hdpi/ic_launcher_foreground.png"
convert "$ICON" -resize 216x216 "$RES/mipmap-xhdpi/ic_launcher_foreground.png"
convert "$ICON" -resize 324x324 "$RES/mipmap-xxhdpi/ic_launcher_foreground.png"
convert "$ICON" -resize 432x432 "$RES/mipmap-xxxhdpi/ic_launcher_foreground.png"

for spec in "108:mdpi" "162:hdpi" "216:xhdpi" "324:xxhdpi" "432:xxxhdpi"; do
  size="${spec%%:*}"
  density="${spec##*:}"
  convert -size "${size}x${size}" xc:'#5EC4B8' "$RES/mipmap-$density/ic_launcher_background.png"
done

echo "Android launcher icons updated from $ICON"
