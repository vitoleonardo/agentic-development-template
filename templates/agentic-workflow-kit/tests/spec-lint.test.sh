#!/bin/sh
# Tests for .claude/bin/spec-lint. Run: sh templates/agentic-workflow-kit/tests/spec-lint.test.sh
set -u

here=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
project=$(mktemp -d)
trap 'rm -rf "$project"' EXIT
cp -R "$here/kit/." "$project/"
lint="$project/.claude/bin/spec-lint"

passed=0
failed=0

good='# Invite users

ID prefix: INVITE

## Goal
Admins invite colleagues by email.

## User flow
1. The admin opens Team and presses Invite.
2. The admin enters an email address and sends the invite.

## Acceptance criteria
- **INVITE-AC1**: Given an admin, when they invite a new email address, then the invitee receives an email within 1 minute.
- **INVITE-AC2** (removed 01.10.2026: merged into AC1)

## Edge cases
- **INVITE-AC3**: Given an address that is already a member, when the admin invites it, then the page shows "Already a member" and no email is sent.

## Out of scope
- Bulk invites.

## Open questions
- None.
'

# write <status> <spec text>: install the spec and its status row.
write() {
  printf '%s' "$2" >"$project/specs/invite.md"
  printf '| Feature | Spec | Status | Branch | Open questions |\n|---|---|---|---|---|\n| Invite | [invite.md](./invite.md) | %s | – | 0 |\n' "$1" >"$project/specs/README.md"
}

# expect <pass|fail> <description> <status> <spec text> [expected message fragment]
expect() {
  write "$3" "$4"
  out=$("$lint" 2>&1)
  code=$?
  ok=1
  case $1:$code in pass:0 | fail:1) ;; *) ok=0 ;; esac
  if [ $# -ge 5 ] && ! printf '%s' "$out" | grep -qF -- "$5"; then ok=0; fi
  if [ $ok -eq 1 ]; then
    passed=$((passed + 1))
  else
    failed=$((failed + 1))
    echo "FAIL: $2 (exit $code)"
    printf '%s\n' "$out" | sed 's/^/    /'
  fi
}

replace() { printf '%s' "$good" | sed "$1"; }

expect pass "valid spec" approved "$good"
expect fail "missing ID prefix" draft "$(replace '/^ID prefix/d')" 'ID prefix'
expect fail "lowercase prefix" draft "$(replace 's/^ID prefix: INVITE/ID prefix: invite/')" 'uppercase'
expect fail "ID with the wrong prefix" draft "$(replace 's/INVITE-AC3/USER-AC3/')" 'IDs look like INVITE-AC'
expect fail "reused ID" draft "$(replace 's/INVITE-AC3/INVITE-AC1/')" 'already used'
expect fail "reused ID of a removed criterion" draft "$(replace 's/INVITE-AC3/INVITE-AC2/')" 'never reused'
expect fail "bullet without an ID" draft "$(replace 's/^- \*\*INVITE-AC3\*\*: /- /')" 'bold ID'
expect fail "no Given/When/Then" draft "$(replace 's/Given an admin, when they invite a new email address, then/Inviting means/')" 'Given <state>'
expect fail "wrong order" draft "$(replace 's/Given an admin, when they invite/When an admin, given they invite/')" 'Given <state>'
expect fail "two results in one criterion" draft "$(replace 's/within 1 minute\./within 1 minute, then it is logged./')" 'more than one'
expect fail "vague word" draft "$(replace 's/within 1 minute/quickly/')" '"quickly"'
expect fail "vague phrase" draft "$(replace 's/within 1 minute/as needed/')" '"as needed"'
expect pass "vague word inside a longer word is fine" draft "$(replace 's/within 1 minute/at fastmail.com/')"
expect fail "missing User flow" draft "$(replace '/^## User flow/,/^2\./d')" 'User flow'
expect fail "empty Out of scope" draft "$(replace '/^- Bulk invites/d')" 'Out of scope is empty'
expect fail "no edge case" draft "$(replace '/INVITE-AC3/d')" 'no edge cases'
expect fail "approved with open questions" approved "$(replace 's/^- None\./- Who may invite admins?/')" 'open question'
expect pass "draft with open questions" draft "$(replace 's/^- None\./- Who may invite admins?/')"

rm -f "$project/specs/invite.md"
out=$("$lint")
case $out in *"no specs"*) passed=$((passed + 1)) ;; *) failed=$((failed + 1)); echo "FAIL: empty specs folder: $out" ;; esac

echo "$passed passed, $failed failed"
[ "$failed" -eq 0 ]
