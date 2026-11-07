#!/bin/sh
# The core skills work without extensions (CORE-AC9, CORE-AC12, CORE-AC22).
# Every mention of a script or skill an extension owns sits in a block that starts with
# "If stempel-kit-<extension> is installed": a paragraph or list item that starts so, or a heading that says so
# (the block then runs to the next heading of the same or a higher level).
# Run: sh plugins/stempel-kit/tests/skills.test.sh
set -u

here=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
skills=$here/kit/.claude/skills
failed=0
passed=0
ok() { passed=$((passed + 1)); }
fail() { failed=$((failed + 1)); echo "FAIL: $1"; }

# unblocked <file>: "line: text" of every mention outside a block of the extension that owns it.
unblocked() {
  awk '
    function owner(s) {
      if (s ~ /\.claude\/bin\/(evidence|verify)([^a-z-]|$)|\/verify-feature|verify-feature\/|kit-evidence/) return "evidence"
      if (s ~ /\.claude\/bin\/(autopilot|stack|status)([^a-z-]|$)|\/steer|hooks\/(steer|summary)/) return "autopilot"
      if (s ~ /\.claude\/bin\/(route|usage)([^a-z-]|$)|hooks\/usage/) return "routing"
      if (s ~ /\.claude\/bin\/(runs|leadtime)([^a-z-]|$)|\/improve-kit|improve-kit\//) return "improve"
      if (s ~ /\.claude\/bin\/risk([^a-z-]|$)/) return "risk"
      if (s ~ /\.claude\/bin\/(baseline|onboard-apply)([^a-z-]|$)|\/onboard([^a-z-]|$)/) return "onboard"
      return ""
    }
    # names <text>: the extensions an opener names, as " a b ", or "" when it is no opener.
    function names(t,   out) {
      sub(/^[#>*[:space:]-]*([0-9]+\.[[:space:]]*)?(\*\*)?/, "", t)
      if (t !~ /^If (`?stempel-kit-[a-z]+`?(, | or | and )?)+ (is|are) installed/) return ""
      out = " "
      while (match(t, /stempel-kit-[a-z]+/)) { out = out substr(t, RSTART + 12, RLENGTH - 12) " "; t = substr(t, RSTART + RLENGTH); if (t ~ /^`? (is|are) installed/) break }
      return out
    }
    /^```/ { fence = !fence }
    !fence && /^#+ / {
      match($0, /^#+/); level = RLENGTH
      for (l = level; l <= 6; l++) head[l] = ""
      head[level] = names($0)
      unit = ""
      next
    }
    /^[[:space:]]*$/ { unit = ""; started = 0; next }
    !fence && (!started || /^[[:space:]]*(- |[0-9]+\. )/) { unit = names($0); started = 1 }
    {
      rest = $0
      while ((o = owner(rest)) != "") {
        allowed = (index(unit, " " o " ") > 0)
        for (l = 1; l <= 6; l++) if (index(head[l], " " o " ") > 0) allowed = 1
        if (!allowed) { printf "%d: %s needs an \"If stempel-kit-%s is installed\" block: %s\n", FNR, o, o, substr($0, 1, 120); break }
        # look past this mention for another extension on the same line
        match(rest, /\.claude\/bin\/[a-z-]+|\/verify-feature|verify-feature\/|kit-evidence|\/steer|hooks\/[a-z]+|\/improve-kit|improve-kit\/|\/onboard/)
        rest = substr(rest, RSTART + RLENGTH)
      }
    }
  ' "$1"
}

for s in spec-feature plan-feature ship-feature fix-bug pr-description review-diff write-tests; do
  out=$(unblocked "$skills/$s/SKILL.md")
  [ -z "$out" ] && ok || fail "CORE-AC12: $s names extension scripts outside their blocks:
$out"
done

# The lint itself: a mention outside a block is found, one inside its own block is not, one in another's is found.
probe=$(mktemp)
trap 'rm -f "$probe"' EXIT
cat >"$probe" <<'EOF'
# Probe

Run `.claude/bin/evidence gates`.

If stempel-kit-evidence is installed, run `.claude/bin/evidence gates`.
It continues here with `/verify-feature`.

- If stempel-kit-routing is installed, pass `model` from `.claude/bin/route tests`.
- Then `.claude/bin/route review`.

## If stempel-kit-autopilot is installed

Run `.claude/bin/autopilot --ship`.

**If stempel-kit-routing is installed:** `.claude/bin/usage line` inside the autopilot section.

Run `.claude/bin/route up deep` here.

## Next

Run `.claude/bin/stack submit`.
EOF
out=$(unblocked "$probe")
want='3: evidence
9: routing
17: routing
21: autopilot'
got=$(printf '%s\n' "$out" | sed 's/^\([0-9]*\): \([a-z]*\) .*/\1: \2/')
[ "$got" = "$want" ] && ok || fail "the lint finds exactly the unblocked mentions; got:
$out"

# CORE-AC9, CORE-AC22: the core writes the PR body with a red and a green run per criterion; /verify-feature runs
# only in the evidence block.
ship=$skills/ship-feature/SKILL.md
desc=$skills/pr-description/SKILL.md
grep -qF '| Criterion | Test | Red run | Green run |' "$desc" && ok || fail "CORE-AC9: the PR description has a table with the red and the green run per criterion"
grep -qF 'one line per criterion with the test name, its red run and its green run' "$ship" && ok || fail "CORE-AC9: /ship-feature puts one line per criterion with its red and green run into the PR body"
grep -q '^If stempel-kit-evidence is installed, follow `${CLAUDE_SKILL_DIR}/../verify-feature/SKILL.md`' "$ship" && ok || fail "CORE-AC22: /ship-feature dispatches /verify-feature in the evidence block"
grep -qF 'Without it, write the pull request body directly' "$ship" && ok || fail "CORE-AC22: without the extension /ship-feature writes the PR body directly"

echo "$passed passed, $failed failed"
[ "$failed" -eq 0 ]
