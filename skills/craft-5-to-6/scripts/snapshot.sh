#!/usr/bin/env bash
# Fetches every path in a list and stores the HTML plus status codes.
#
#   snapshot.sh <base-url> <paths-file> <out-dir> [host-header]
#
# paths-file: one path per line without leading slash, __home__ for "/".
# host-header: optional. Use it to reach a container port directly
# (http://127.0.0.1:8080) while the app believes it serves the real host.
# X-Forwarded-Proto is then set to https.
set -euo pipefail

BASE=${1:?base url}
PATHS=${2:?paths file}
OUT=${3:?output dir}
HOST=${4:-}

mkdir -p "$OUT"
: > "$OUT/status.txt"

headers=()
if [[ -n $HOST ]]; then
  headers=(-H "Host: $HOST" -H "X-Forwarded-Proto: https")
fi

while IFS= read -r path; do
  [[ $path == "__home__" ]] && path=""
  name=$(printf '%s' "${path:-home}" | tr '/' '_')
  code=$(curl -sk "${headers[@]}" -o "$OUT/$name.html" \
    -w '%{http_code} %{redirect_url}' "$BASE/$path")
  echo "/$path $code" >> "$OUT/status.txt"
done < "$PATHS"

awk '{print $2}' "$OUT/status.txt" | sort | uniq -c
