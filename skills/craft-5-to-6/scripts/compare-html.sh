#!/usr/bin/env bash
# Compares two snapshot.sh output folders page by page and prints the number
# of differing lines per page, largest first.
#
#   compare-html.sh <before-dir> <after-dir> [old-host new-host]
#
# Masks values that change on every request or between versions:
# CSRF tokens (Craft 5 CRAFT_CSRF_TOKEN, Craft 6 _token), timestamps of the
# dev-mode error page, cache-busting ?v= parameters.
# Pass old-host/new-host when the two snapshots ran under different hostnames.
set -euo pipefail

A=${1:?before dir}
B=${2:?after dir}
OLD_HOST=${3:-}
NEW_HOST=${4:-}

norm() {
  sed -E \
    -e 's/(CRAFT_CSRF_TOKEN|_token|csrf-token)[^>]*/CSRF/g' \
    -e 's/[0-9]{4}-[0-9]{2}-[0-9]{2}, [0-9:]{8}/TS/g' \
    -e 's/\?v=[0-9a-f]+/?v=X/g' "$1" |
  if [[ -n $OLD_HOST ]]; then sed "s#$NEW_HOST#$OLD_HOST#g"; else cat; fi
}

for f in "$A"/*.html; do
  page=$(basename "$f")
  [[ -f "$B/$page" ]] || { echo "missing $page"; continue; }
  n=$(diff <(norm "$f") <(norm "$B/$page") | grep -c '^[<>]' || true)
  [[ $n -gt 0 ]] && echo "$n $page"
done | sort -rn

echo "Status codes that changed:"
paste -d' ' <(awk '{print $1, $2}' "$A/status.txt") <(awk '{print $2}' "$B/status.txt") |
  awk '$2 != $3'
