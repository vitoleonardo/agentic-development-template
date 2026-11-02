# shellcheck shell=sh

json_str() {
  printf '"%s"' "$(printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' | tr '\001-\037' ' ')"
}

pack_head() {
  sed -n 's/^ *"head": *"\([0-9a-f]*\)".*/\1/p' | head -n 1
}
