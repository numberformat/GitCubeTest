#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root_dir"

mkdir -p site
cp docs/index.html site/
cp .nojekyll site/

shopt -s nullglob
scad_files=( src/models/*.scad )
asset_stls=( src/assets/*.stl )
if [ ${#scad_files[@]} -eq 0 ] && [ ${#asset_stls[@]} -eq 0 ]; then
  echo "No .scad files in src/models or .stl files in src/assets." >&2
  exit 1
fi

if [ -d src/assets ]; then
  mkdir -p site/assets
  cp -R src/assets/. site/assets/
fi

printf "[" > site/models.json
first=1
for file in "${scad_files[@]}"; do
  base="$(basename "${file%.scad}")"
  out="site/${base}.stl"
  openscad -o "$out" "$file"
  if [ $first -eq 0 ]; then printf "," >> site/models.json; fi
  printf "\"%s.stl\"" "$base" >> site/models.json
  first=0
done
for file in "${asset_stls[@]}"; do
  base="$(basename "$file")"
  if [ $first -eq 0 ]; then printf "," >> site/models.json; fi
  printf "\"assets/%s\"" "$base" >> site/models.json
  first=0
done
printf "]" >> site/models.json

echo "Build complete. Output in ./site"
