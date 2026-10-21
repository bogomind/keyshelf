#!/usr/bin/env bash
# Round-trip test in a throwaway shelf: add, reveal, copy-source, unset, doctor.
set -euo pipefail
here=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
export KEYSHELF_DATA="$tmp/data"
export SOPS_AGE_KEY_FILE="$tmp/age.txt"
mkdir -p "$KEYSHELF_DATA"
cp "$here/keyshelf" "$tmp/keyshelf"
cp "$here/inventory.json" "$KEYSHELF_DATA/"
age-keygen -o "$SOPS_AGE_KEY_FILE" 2>/dev/null
pub=$(grep -o 'age1[a-z0-9]*' "$SOPS_AGE_KEY_FILE" | head -1)
printf 'creation_rules:\n  - path_regex: vault\\.sops\\.json$\n    age: %s\n' "$pub" \
  > "$KEYSHELF_DATA/.sops.yaml"
k="$tmp/keyshelf"

"$k" init >/dev/null
"$k" set github password --value 's3cret with spaces'
[ "$("$k" reveal github password)" = 's3cret with spaces' ] || exit 1
"$k" reveal github password | grep -qx 's3cret with spaces'
"$k" list | grep -q 'secrets 1/4'
"$k" add newthing --name 'New thing' --username me --fields token,note >/dev/null
"$k" set newthing token --value tok
"$k" show newthing | grep -q 'token (present)'
"$k" unset newthing token
"$k" show newthing | grep -q 'token (MISSING)'
"$k" doctor >/dev/null || [ $? -eq 0 ]
grep -q 'BEGIN AGE' "$KEYSHELF_DATA/vault.sops.json"
echo "smoke: ok"
