#!/bin/sh
# Tests for .claude/bin/leadtime against recorded GitHub data (tests/leadtime/prs.json), no network.
# Run: sh templates/agentic-workflow-kit/tests/leadtime.test.sh   (needs jq, which stands in for gh's --jq)
#
# Expected values, calculated by hand from prs.json (September 2026, times in hours):
#   PR   first commit  ready        first review       merged       lead cycle review rounds size  kit fix
#   101  09-01 00:00   09-01 02:00  09-01 06:00 (ben)  09-01 12:00   12    10     4      0     40   yes
#   102  09-01 20:00   09-02 10:00* 09-02 12:00 (ben)  09-02 20:00   24    10     2      2    120
#   103  dependabot: left out
#   104  09-04 00:00   09-04 00:00  09-04 03:00 (cara) 09-04 06:00    6     6     3      0      8        fix
#   105  09-10 00:00   09-10 01:00  none               09-11 01:00   25    24     –      0    200   yes
#   106  09-20 00:00   09-20 00:00  none               09-20 02:00    2     2     –      0      2        revert
#   * draft until the ReadyForReviewEvent; ana's own comment at 11:00 and the bot's kit comment do not count.
#   102 rounds: one "changes requested" plus one commit after the first review.
#   lead: 2 6 12 24 25 -> median 12, p75 (nearest rank, 4th of 5) 24. cycle: 2 6 10 10 24 -> 10, 10.
#   first review: 2 3 4 -> 3, 4. rounds: 0 0 0 0 2 -> 0, 0. size: 2 8 40 120 200 -> 40, 120.
#   rework: 104 fixes src/a.ts within 14 days of 101 and 102 -> 2 of 5 = 40 %.
#   spec to merge: the Export spec was approved 09-05 00:00, its branch 12-export (PR 105) merged 09-11 01:00 -> 145.
#   with kit (101, 105): lead 12 25 -> median 18.5, p75 25.
#   Baseline (06-02..08-31): PR 90 lead 24, PR 91 lead 12 -> median 18; 12 vs 18 is -33 %.
set -u

here=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
project=$(mktemp -d)
trap 'rm -rf "$project"' EXIT
cp -R "$here/kit/." "$project/"
cd "$project" || exit 1
export GH="$here/tests/leadtime/fake-gh" LEADTIME_TODAY=2026-09-30 FAKE_GH_LOG="$project/gh.log"

failed=0
passed=0
ok() { passed=$((passed + 1)); }
fail() { failed=$((failed + 1)); echo "FAIL: $1"; }
has() { if grep -qF -- "$2" "$1"; then ok; else fail "$3: no '$2' in $1:
$(cat "$1")"; fi; }
hasnt() { if grep -qF -- "$2" "$1"; then fail "$3: '$2' found in $1"; else ok; fi; }

# specs/README.md history: Export approved on 09-05, planned with its branch on 09-06.
git init -q -b main
commit_at() { GIT_AUTHOR_DATE=$1 GIT_COMMITTER_DATE=$1 git -c user.name=t -c user.email=t@example.invalid commit -qam "$2"; }
cat >specs/README.md <<'EOF'
| Feature | Spec | Status | Branch | Open questions |
| ------- | ---- | ------ | ------ | -------------- |
| Export | [export.md](./export.md) | draft | – | 1 |
EOF
git add -A
commit_at 2026-09-01T00:00:00Z draft
sed -i 's/| draft | – | 1 |/| approved | – | 0 |/' specs/README.md
commit_at 2026-09-05T00:00:00Z approved
sed -i 's/| approved | – | 0 |/| planned | 12-export | 0 |/' specs/README.md
commit_at 2026-09-06T00:00:00Z planned

# --- baseline -------------------------------------------------------------------

.claude/bin/leadtime --baseline --until 2026-08-31 >/dev/null || fail "--baseline failed"
has reports/lead-time-baseline.csv "2026-06-02..2026-08-31,all,lead_time_h,2,18.0,24.0" "the baseline covers the 90 days before its end"
has reports/lead-time-baseline.csv "2026-06-02..2026-08-31,all,first_review_h,1,6.0,6.0" "baseline first review"
[ -f reports/lead-time-baseline.md ] && ok || fail "the baseline report is written"

# --- metrics (LEAD-AC1) ---------------------------------------------------------

.claude/bin/leadtime --since 2026-09-01 --until 2026-09-30 --format csv >/dev/null || fail "the csv run failed"
csv=reports/lead-time.csv
p=2026-09-01..2026-09-30
has "$csv" "$p,all,lead_time_h,5,12.0,24.0" "lead time for changes (LEAD-AC1)"
has "$csv" "$p,all,cycle_time_h,5,10.0,10.0" "PR cycle time, drafts from ready for review (LEAD-AC1, AC4)"
has "$csv" "$p,all,first_review_h,3,3.0,4.0" "time to first review without self and bot comments (LEAD-AC1, AC4)"
has "$csv" "$p,all,review_rounds,5,0.0,0.0" "review rounds (LEAD-AC1)"
has "$csv" "$p,all,spec_to_merge_h,1,145.0,145.0" "spec to merge (LEAD-AC1)"
has "$csv" "$p,all,rework_pct,5,40.0," "rework rate (LEAD-AC1)"
has "$csv" "$p,all,pr_size_lines,5,40.0,120.0" "PR size (LEAD-AC1)"
has "$csv" "$p,all,excluded_bots,1,," "the dependabot PR is left out (LEAD-AC4)"
has "$csv" "$p,all,prs,5,5,5" "five PRs count"

# --- report with the baseline (LEAD-AC2, AC3, AC5) ------------------------------

.claude/bin/leadtime >/dev/null || fail "the default run failed"
md=reports/lead-time.md
has gh.log "merged:2026-08-31..2026-09-30" "the default period starts where the baseline ended"
has "$md" "| Lead time for changes (h) | 12.0 | 24.0 | 5 | 18.0 | -33% |" "the baseline and the change sit next to the numbers (LEAD-AC2)"
has "$md" "**Too few PRs for a reliable comparison** (5)." "the warning below ten PRs (LEAD-AC3)"
has "$md" "not why." "no claim of causation"
for word in ana ben cara "Show history" "Export as CSV"; do
  hasnt "$md" "$word" "no names or titles by default (LEAD-AC5)"
done
.claude/bin/leadtime --with-titles >/dev/null
has "$md" "| #102 | Show history | ana |" "--with-titles adds them"

# --- split by kit ---------------------------------------------------------------

.claude/bin/leadtime --since 2026-09-01 --until 2026-09-30 --split-by kit --format csv >/dev/null
has "$csv" "$p,with-kit,lead_time_h,2,18.5,25.0" "PRs with an evidence pack"
has "$csv" "$p,without-kit,prs,3,3,3" "PRs without one"

echo "$passed passed, $failed failed"
[ "$failed" -eq 0 ]
