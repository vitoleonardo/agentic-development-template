# shellcheck shell=sh

json_str() {
  printf '"%s"' "$(printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' | tr '\001-\037' ' ')"
}

pack_head() {
  sed -n 's/^ *"head": *"\([0-9a-f]*\)".*/\1/p' | head -n 1
}

# Hook input: the hooks of the core and of the extensions read it into HOOK_INPUT.
# Print the string value of a JSON key from the hook input (last occurrence),
# with the common escapes undone. Good enough for paths and commands; not a
# general JSON parser.
json_string() {
  printf '%s' "$HOOK_INPUT" | tr '\n' ' ' |
    sed -nE 's/.*"'"$1"'"[[:space:]]*:[[:space:]]*"(([^"\\]|\\.)*)".*/\1/p' |
    sed -e 's/\\"/"/g' -e 's/\\\//\//g' -e 's/\\[nt]/ /g' -e 's/\\\\/\\/g'
}

json_bool() {
  printf '%s' "$HOOK_INPUT" | grep -Eq '"'"$1"'"[[:space:]]*:[[:space:]]*true'
}

# Encode stdin as the body of a JSON string (without the surrounding quotes).
json_escape() {
  esc=$(printf '\033')
  sed "s/${esc}\[[0-9;]*[A-Za-z]//g" | tr -d '\000-\010\013\014\016-\037' |
    awk 'BEGIN { ORS = "" } {
      gsub(/\\/, "\\\\"); gsub(/"/, "\\\""); gsub(/\t/, "\\t"); gsub(/\r/, "")
      if (NR > 1) print "\\n"
      print
    }'
}
