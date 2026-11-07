#!/bin/sh
# Each extension holds its own files and the core holds none of them (CORE-AC13 to CORE-AC18); every extension
# declares its runtime and what it extends (CORE-AC21); the core's plugin description names every extension.
# Run: sh plugins/stempel-kit/tests/extensions.test.sh
set -u

plugins=$(CDPATH='' cd -- "$(dirname -- "$0")/../.." && pwd)
core=$plugins/stempel-kit/kit/.claude
failed=0
passed=0
ok() { passed=$((passed + 1)); }
fail() { failed=$((failed + 1)); echo "FAIL: $1"; }

# owns <extension> <path under plugin/ or tests/>...: the extension holds each path, the core holds none.
owns() {
  ext=$plugins/stempel-kit-$1
  shift
  for f in "$@"; do
    [ -e "$ext/$f" ] && ok || fail "stempel-kit-${ext##*-} has no $f"
    case $f in plugin/hooks/hooks.json) ;; plugin/*) [ ! -e "$core/${f#plugin/}" ] && ok || fail "the core still holds ${f#plugin/}" ;; esac
  done
}

owns evidence plugin/bin/evidence plugin/skills/verify-feature/SKILL.md tests/evidence.test.sh
owns autopilot plugin/bin/autopilot plugin/bin/stack plugin/bin/status plugin/hooks/steer plugin/hooks/summary plugin/hooks/hooks.json tests/autopilot.test.sh tests/stack.test.sh tests/status.test.sh tests/steer.test.sh
owns routing plugin/bin/route plugin/bin/usage plugin/hooks/usage plugin/hooks/hooks.json tests/usage.test.sh
owns improve plugin/bin/runs plugin/bin/leadtime plugin/skills/improve-kit/SKILL.md tests/runs.test.sh tests/leadtime.test.sh
owns risk plugin/bin/risk plugin/workflows/risk.yml tests/risk.test.sh
owns onboard plugin/bin/baseline plugin/bin/onboard-apply plugin/skills/onboard/SKILL.md tests/baseline.test.sh

# json_list <file> <key>: the strings of a JSON array under the key, one per line.
json_list() { tr -d '\n' <"$1" | sed -n "s/.*\"$2\"[[:space:]]*:[[:space:]]*\[\([^]]*\)\].*/\1/p" | tr -d '" ' | tr ',' '\n' | grep .; }

# problems <extension folder>: what an extension lacks, one line each (CORE-AC21): a plugin.json whose requires
# names every runtime its scripts need (sh, node or python3, by the script's suffix) and whose extends names the
# core or an existing extension; a kit.conf.part; a script in plugin/bin; a test; no file that the core also holds.
problems() {
  _name=${1##*/}
  _manifest=$1/plugin/.claude-plugin/plugin.json
  [ -f "$_manifest" ] || { echo "$_name: no plugin/.claude-plugin/plugin.json"; return; }
  _requires=$(json_list "$_manifest" requires)
  [ -n "$_requires" ] || echo "$_name: plugin.json names no runtime under requires (sh, node or python3)"
  for _r in $_requires; do
    case $_r in sh | node | python3) ;; *) echo "$_name: requires names $_r, which is not sh, node or python3" ;; esac
  done
  for _script in "$1"/plugin/bin/*; do
    [ -f "$_script" ] || continue
    case $_script in
      *.ts | *.mts | *.js | *.mjs | *.cjs) _runtime=node ;;
      *.py) _runtime=python3 ;;
      *) _runtime="sh" ;;
    esac
    printf '%s\n' "$_requires" | grep -qx "$_runtime" || echo "$_name: plugin/bin/${_script##*/} needs $_runtime, which requires does not name"
  done
  for _e in $(json_list "$_manifest" extends); do
    [ "$_e" = stempel-kit ] || [ -d "$plugins/$_e/plugin" ] || echo "$_name: extends names $_e, which is not the core or an extension"
  done
  [ -f "$1/plugin/kit.conf.part" ] || echo "$_name: no plugin/kit.conf.part"
  [ -n "$(ls "$1/plugin/bin" 2>/dev/null)" ] || echo "$_name: no script in plugin/bin"
  [ -n "$(ls "$1"/tests/*.test.sh 2>/dev/null)" ] || echo "$_name: no tests/*.test.sh"
  for _f in "$1"/plugin/bin/* "$1"/plugin/hooks/* "$1"/plugin/skills/*; do
    [ -e "$_f" ] || continue
    _rel=${_f#"$1"/plugin/}
    case $_rel in hooks/hooks.json) continue ;; esac
    [ ! -e "$core/$_rel" ] || echo "$_name: $_rel is in the extension and in the core ($core/$_rel)"
  done
}

for ext in "$plugins"/stempel-kit-*; do
  out=$(problems "$ext")
  [ -z "$out" ] && ok || fail "$out"
  grep -qF "${ext##*/}" "$core/.claude-plugin/plugin.json" && ok || fail "the core's plugin.json description does not name ${ext##*/}"
done

# CORE-AC21: an extension in TypeScript passes when requires names node, and fails naming the runtime when it does not.
fixture=$plugins/stempel-kit/tests/fixtures/ext-node
out=$(problems "$fixture")
[ -z "$out" ] && ok || fail "CORE-AC21: the TypeScript fixture with requires node: $out"
tmp=$(mktemp -d)
cp -R "$fixture" "$tmp/ext-node"
sed -i.bak '/"requires":/d' "$tmp/ext-node/plugin/.claude-plugin/plugin.json"
out=$(problems "$tmp/ext-node")
case $out in *"scan.mts needs node"*) ok ;; *) fail "CORE-AC21: the TypeScript fixture without node under requires should name the runtime: $out" ;; esac
mkdir -p "$tmp/ext-node/plugin/bin" && cp "$core/bin/check" "$tmp/ext-node/plugin/bin/check"
out=$(problems "$tmp/ext-node")
case $out in *"bin/check is in the extension and in the core"*) ok ;; *) fail "a file present in core and extension should fail naming both paths: $out" ;; esac
rm -rf "$tmp"

echo "$passed passed, $failed failed"
[ "$failed" -eq 0 ]
