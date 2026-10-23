// Coverage gate for the files a pull request changes.
// Reads coverage/coverage-summary.json (Istanbul json-summary, written by `.claude/bin/check coverage`)
// and fails when the changed source files together fall below COVERAGE_THRESHOLD percent of lines.
// Usage: BASE_REF=origin/main COVERAGE_THRESHOLD=70 node .github/scripts/changed-coverage.mjs
import { execFileSync } from "node:child_process";
import { appendFileSync, existsSync, readFileSync } from "node:fs";
import { resolve } from "node:path";

const base = process.env.BASE_REF ?? "origin/main";
const threshold = Number(process.env.COVERAGE_THRESHOLD ?? "70");
const summaryPath =
  process.env.COVERAGE_SUMMARY ?? "coverage/coverage-summary.json";

const sourceFile = /\.(ts|tsx|mts|cts|js|jsx|mjs|cjs)$/;
const testFile = /(\.(test|spec)\.[^/]+$|(^|\/)(__tests__|test|tests|e2e)\/)/;
const notCode = /(\.d\.ts$|(^|\/)[^/]*\.config\.[^/]+$)/;

function report(markdown) {
  console.log(markdown);
  if (process.env.GITHUB_STEP_SUMMARY)
    appendFileSync(process.env.GITHUB_STEP_SUMMARY, `${markdown}\n`);
}

function fail(message) {
  console.log(`::error title=Coverage on changed files::${message}`);
  report(`**Coverage on changed files failed:** ${message}`);
  process.exit(1);
}

if (!existsSync(summaryPath)) {
  fail(
    `${summaryPath} was not found. Run \`.claude/bin/check coverage\` first and make sure it writes the json-summary report.`,
  );
}

const changed = execFileSync(
  "git",
  ["diff", "--name-only", "--diff-filter=AMR", `${base}...HEAD`],
  { encoding: "utf8" },
)
  .split("\n")
  .filter(
    (file) =>
      sourceFile.test(file) && !testFile.test(file) && !notCode.test(file),
  );

if (changed.length === 0) {
  report(
    "Coverage on changed files: no changed source files, nothing to check.",
  );
  process.exit(0);
}

const summary = JSON.parse(readFileSync(summaryPath, "utf8"));
const byPath = new Map(
  Object.entries(summary).map(([path, data]) => [resolve(path), data]),
);

let covered = 0;
let total = 0;
const rows = [];
const missing = [];
for (const file of changed) {
  const lines = byPath.get(resolve(file))?.lines;
  if (!lines) {
    missing.push(file);
    continue;
  }
  covered += lines.covered;
  total += lines.total;
  rows.push(
    `| ${file} | ${lines.covered}/${lines.total} | ${lines.total ? lines.pct : 100}% |`,
  );
}

for (const file of missing) {
  console.log(
    `::warning file=${file},title=No coverage data::${file} is not in the coverage report. If it holds runtime code, add tests, or include it through the coverage include setting so untested files count as 0%.`,
  );
}

const pct = total === 0 ? 100 : Math.round((covered / total) * 1000) / 10;
report(
  [
    `### Coverage on changed files: ${pct}% (threshold ${threshold}%)`,
    "",
    "| File | Lines covered | % |",
    "|------|---------------|---|",
    ...rows,
    ...missing.map((file) => `| ${file} | no data | – |`),
  ].join("\n"),
);

if (pct < threshold) {
  fail(
    `${pct}% of the changed lines are covered by tests; at least ${threshold}% is required. Add tests for the files listed in the job summary.`,
  );
}
