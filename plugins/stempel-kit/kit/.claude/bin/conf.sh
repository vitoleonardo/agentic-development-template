# Package config lookup, sourced by .claude/bin/check, the hooks and the extensions' scripts (POSIX sh).
# A package is a folder with its own .claude/kit.conf; the project root's .claude/kit.conf is the fallback.
# Paths are relative to the project root. KIT_CONF_ROOT (default: the root) and KIT_CONF_DIR (default: .claude)
# say where configs are looked up, so /onboard can measure a baseline with configs it only staged
# (KIT_CONF_ROOT=.work/onboard/files KIT_CONF_DIR=dot-claude).
# shellcheck shell=sh

KIT_CONF_ROOT=${KIT_CONF_ROOT:-.}
KIT_CONF_DIR=${KIT_CONF_DIR:-.claude}
# The root config's bin folder, for adapter helpers that kit.conf commands call ("$KIT_BIN/coverage-files.mjs").
KIT_BIN=$(CDPATH='' cd -- "$KIT_CONF_ROOT/$KIT_CONF_DIR/bin" 2>/dev/null && pwd) || KIT_BIN=$PWD/.claude/bin
export KIT_BIN

# conf_file <package>: the config file of a package.
conf_file() { printf '%s/%s/%s/kit.conf' "$KIT_CONF_ROOT" "$1" "$KIT_CONF_DIR"; }

# package_of <path>: the package folder ("." for the root) whose config owns the path.
package_of() {
  _dir=$(dirname -- "$1")
  while [ "$_dir" != . ] && [ "$_dir" != / ]; do
    [ ! -f "$(conf_file "$_dir")" ] || { printf '%s\n' "$_dir"; return 0; }
    _dir=$(dirname -- "$_dir")
  done
  printf '.\n'
}

# packages: every package folder, the root first.
packages() {
  printf '.\n'
  (cd "$KIT_CONF_ROOT" && find . \( -name node_modules -o -name .git -o -name .work -o -name .venv \) -prune -o \
    -path "./*/$KIT_CONF_DIR/kit.conf" -type f -print) | sed -e 's|^\./||' -e "s|/$KIT_CONF_DIR/kit\.conf\$||" | sort
}

# conf_value <package> <variable>: the value a package's config gives a variable, sourced in its folder.
conf_value() {
  (
    conf=$(CDPATH='' cd -- "$(dirname -- "$(conf_file "$1")")" 2>/dev/null && pwd)/kit.conf
    cd "$1" 2>/dev/null && [ -f "$conf" ] || exit 0
    # shellcheck source=/dev/null
    . "$conf"
    eval "printf '%s' \"\${$2:-}\""
  )
}

# file_value <path relative to the root> <variable>: the variable from the config of the file's package.
# In a monorepo a package's .claude/kit.conf decides its own source and test patterns.
file_value() { conf_value "$(package_of "$1")" "$2"; }

# test_patterns <package>: the package's KIT_TEST_PATTERNS, or the kit's default test file patterns.
test_patterns() {
  _patterns=$(conf_value "$1" KIT_TEST_PATTERNS)
  printf '%s' "${_patterns:-*.test.* *.spec.* *_test.* test_*.* __tests__/* test/* tests/* e2e/* spec/*}"
}

# base_ref: the base branch. KIT_BASE, else the "Base:" line /ship-feature writes into .work/<branch>.md
# (stacked branches build on the previous one), else origin's default branch, else main.
base_ref() {
  [ -z "${KIT_BASE:-}" ] || { printf '%s' "$KIT_BASE"; return; }
  _branch=$(git branch --show-current 2>/dev/null)
  _base=$(sed -n 's/^Base:[[:space:]]*`\{0,1\}\([^`[:space:]]*\).*/\1/p' "${KIT_ROOT:-.}/.work/$_branch.md" 2>/dev/null | head -n 1)
  if [ -n "$_branch" ] && [ -n "$_base" ]; then
    if git rev-parse -q --verify "$_base^{commit}" >/dev/null 2>&1; then printf '%s' "$_base"; return; fi
    if git rev-parse -q --verify "origin/$_base^{commit}" >/dev/null 2>&1; then printf 'origin/%s' "$_base"; return; fi
  fi
  git symbolic-ref -q --short refs/remotes/origin/HEAD 2>/dev/null || printf 'main'
}

# merge_base: the point the branch left the base; the working tree is compared with it.
merge_base() {
  git merge-base "$(base_ref)" HEAD 2>/dev/null || git rev-parse "$(base_ref)" 2>/dev/null || git rev-parse HEAD
}

# numstat_total: the changed lines of a --numstat diff on stdin, without lockfiles, test snapshots and drizzle's
# generated migration snapshots.
numstat_total() {
  awk '$3 !~ /(^|\/)(package-lock\.json|pnpm-lock\.yaml|yarn\.lock|uv\.lock)$|\.snap$|^drizzle\/meta\/[0-9]+_snapshot\.json$/ {
    total += ($1 == "-" ? 0 : $1) + ($2 == "-" ? 0 : $2) } END { print total + 0 }'
}

# matches_any <file> <space-separated shell patterns>: true if the file matches one of them.
matches_any() {
  set -f
  for _pattern in $2; do
    # shellcheck disable=SC2254
    case $1 in $_pattern | */$_pattern) set +f; return 0 ;; esac
  done
  set +f
  return 1
}

# changed_file_matching <since> <patterns> [paths]: the first file changed since the commit that matches a pattern.
changed_file_matching() {
  _since=$1 _patterns=$2
  shift 2
  [ -n "$_patterns" ] || return 1
  _file=$(git diff --name-only "$_since" -- "$@" 2>/dev/null | while IFS= read -r _f; do
    matches_any "$_f" "$_patterns" && { printf '%s\n' "$_f"; break; }
  done)
  [ -n "$_file" ] && printf '%s\n' "$_file"
}

# kit_check <check> [files]: a check as the hooks run it; typecheck compares with the baseline when there is one.
kit_check() {
  if [ "$1" = typecheck ] && [ -f .claude/baseline.tsv ]; then .claude/bin/check --against-baseline typecheck; else .claude/bin/check "$@"; fi
}
