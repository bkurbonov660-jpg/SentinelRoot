#!/bin/bash
set -e
mkdir -p assets/icon
IM=$(command -v magick || command -v convert || true)
if [ -z "$IM" ]; then exit 0; fi

$IM -size 1024x1024 xc:"#080A0F" \
  -stroke "#38BDF8" -strokewidth 52 -fill none \
  -draw "circle 512,512 512,150" \
  -stroke "#10B981" -strokewidth 46 -fill none \
  -draw "stroke-linecap round stroke-linejoin round polyline 280,520 430,520 490,330 560,700 630,470 750,470" \
  /tmp/sentinel_icon.png

cp /tmp/sentinel_icon.png assets/icon/logo.png
RES=android/app/src/main/res
for p in mdpi:48 hdpi:72 xhdpi:96 xxhdpi:144 xxxhdpi:192; do
  d="$RES/mipmap-${p%%:*}"
  s="${p##*:}"
  mkdir -p "$d"
  $IM /tmp/sentinel_icon.png -resize "${s}x${s}" "$d/ic_launcher.png"
done
