#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$root_dir"

if [ -n "${OPENSCAD_BIN:-}" ] && [ -x "$OPENSCAD_BIN" ]; then
  OPENSCAD="$OPENSCAD_BIN"
elif command -v openscad >/dev/null 2>&1; then
  OPENSCAD="$(command -v openscad)"
elif [ -x "/Applications/OpenSCAD.app/Contents/MacOS/OpenSCAD" ]; then
  OPENSCAD="/Applications/OpenSCAD.app/Contents/MacOS/OpenSCAD"
else
  echo "ERROR: OpenSCAD not found." >&2
  echo "Install OpenSCAD or set OPENSCAD_BIN." >&2
  exit 1
fi

mkdir -p site
cp docs/index.html site/
cp .nojekyll site/

shopt -s nullglob
scad_files=( src/models/*.scad )
if [ ${#scad_files[@]} -eq 0 ]; then
  echo "No .scad files found in src/models." >&2
  exit 1
fi

printf "[" > site/models.json
first=1
for file in "${scad_files[@]}"; do
  base="$(basename "${file%.scad}")"
  out="site/${base}.stl"
  "$OPENSCAD" -o "$out" "$file"
  if [ $first -eq 0 ]; then printf "," >> site/models.json; fi
  printf "\"%s.stl\"" "$base" >> site/models.json
  first=0
done
printf "]" >> site/models.json

echo "Build complete. Output in ./site"
