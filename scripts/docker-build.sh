#!/usr/bin/env bash
# Copyright (c) 2026 NOAMi (https://noami.us)
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root_dir"

mkdir -p site
mkdir -p site/images
cp docs/index.html site/
cp .nojekyll site/

image_size="${OPENSCAD_IMAGE_SIZE:-1200,900}"

convert_image() {
  local in_path="$1"
  local out_path="$2"
  if command -v magick >/dev/null 2>&1; then
    magick "$in_path" "$out_path"
    return $?
  fi
  if command -v convert >/dev/null 2>&1; then
    convert "$in_path" "$out_path"
    return $?
  fi
  if [ "${in_path##*.}" = "png" ] || [ "${in_path##*.}" = "PNG" ]; then
    cp "$in_path" "$out_path"
    return $?
  fi
  echo "WARN: No image converter found for $in_path (install ImageMagick)" >&2
  return 1
}

render_preview() {
  local stl_path="$1"
  local png_path="$2"
  local stl_dir stl_abs tmp_scad tmp_err
  stl_dir="$(cd "$(dirname "$stl_path")" && pwd)"
  stl_abs="${stl_dir}/$(basename "$stl_path")"
  tmp_scad="$(mktemp "${TMPDIR:-/tmp}/scadpreview.XXXXXX.scad")"
  tmp_err="$(mktemp "${TMPDIR:-/tmp}/scadpreview.XXXXXX.err")"
  printf 'import("%s");\n' "$stl_abs" > "$tmp_scad"
  if ! openscad -o "$png_path" --imgsize="$image_size" --viewall "$tmp_scad" 2>"$tmp_err"; then
    echo "WARN: Failed to render preview for $stl_path" >&2
    if [ -s "$tmp_err" ]; then
      sed -n '1,8p' "$tmp_err" >&2
    fi
  fi
  rm -f "$tmp_scad" "$tmp_err"
}

shopt -s nullglob
scad_files=( src/models/*.scad )
asset_stls=( src/assets/*.stl )
user_images=( src/images/* )
if [ ${#scad_files[@]} -eq 0 ] && [ ${#asset_stls[@]} -eq 0 ]; then
  echo "No .scad files in src/models or .stl files in src/assets." >&2
  exit 1
fi

if [ -d src/assets ]; then
  mkdir -p site/assets
  cp -R src/assets/. site/assets/
fi

printf "[" > site/images.json
images_first=1

if [ -d src/images ] && [ ${#user_images[@]} -gt 0 ]; then
  while IFS= read -r path; do
    [ -f "$path" ] || continue
    base="$(basename "$path")"
    base_no_ext="${base%.*}"
    out="site/images/${base_no_ext}.png"
    if convert_image "$path" "$out"; then
      if [ $images_first -eq 0 ]; then printf "," >> site/images.json; fi
      printf "{\"src\":\"images/%s.png\"}" "$base_no_ext" >> site/images.json
      images_first=0
    fi
  done < <(printf '%s\n' "${user_images[@]}" | sort -f)
fi

printf "[" > site/models.json
first=1
for file in "${scad_files[@]}"; do
  base="$(basename "${file%.scad}")"
  out="site/${base}.stl"
  openscad -o "$out" "$file"
  preview_out="site/images/${base}_stl.png"
  render_preview "$out" "$preview_out"
  if [ -f "$preview_out" ]; then
    if [ $images_first -eq 0 ]; then printf "," >> site/images.json; fi
    printf "{\"src\":\"images/%s_stl.png\",\"stl\":\"%s.stl\"}" "$base" "$base" >> site/images.json
    images_first=0
  fi
  if [ $first -eq 0 ]; then printf "," >> site/models.json; fi
  printf "\"%s.stl\"" "$base" >> site/models.json
  first=0
done
for file in "${asset_stls[@]}"; do
  base="$(basename "$file")"
  base_no_ext="${base%.stl}"
  if [ $first -eq 0 ]; then printf "," >> site/models.json; fi
  printf "\"assets/%s\"" "$base" >> site/models.json
  first=0
  preview_out="site/images/${base_no_ext}_stl.png"
  render_preview "site/assets/$base" "$preview_out"
  if [ -f "$preview_out" ]; then
    if [ $images_first -eq 0 ]; then printf "," >> site/images.json; fi
    printf "{\"src\":\"images/%s_stl.png\",\"stl\":\"assets/%s\"}" "$base_no_ext" "$base" >> site/images.json
    images_first=0
  fi
done
printf "]" >> site/images.json
printf "]" >> site/models.json

echo "Build complete. Output in ./site"
