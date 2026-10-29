// Usage: node duplicates-new.mjs <jscpd> <scan arguments...>   (KIT_BASE: the base branch)
// Fails on the clones the branch adds; a clone inside one the same file pair already has on the base is legacy.
import { execFileSync } from "node:child_process";
import { mkdtempSync, readFileSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";

const [jscpdArg, ...scanArgs] = process.argv.slice(2);
const base = process.env.KIT_BASE || "main";
const jscpd = jscpdArg.includes("/") ? resolve(jscpdArg) : jscpdArg;
const work = mkdtempSync(join(tmpdir(), "kit-duplicates-"));

function scan(cwd, output, extra) {
  execFileSync(jscpd, [...scanArgs, ...extra, "--reporters", "json", "--output", output, "--no-colors"], {
    cwd,
    stdio: ["ignore", "ignore", "inherit"],
  });
  return JSON.parse(readFileSync(join(output, "jscpd-report.json"), "utf8")).duplicates;
}

const git = (...args) => execFileSync("git", args, { encoding: "utf8" }).trim();
const normal = (fragment) => fragment.replace(/\s+/g, " ").trim();
const pair = (clone) => [clone.firstFile.name, clone.secondFile.name].sort().join("\n");
const where = (clone) =>
  `${clone.firstFile.name}:${clone.firstFile.start}-${clone.firstFile.end} ~ ` +
  `${clone.secondFile.name}:${clone.secondFile.start}-${clone.secondFile.end}`;

try {
  const flagged = scan(process.cwd(), join(work, "head"), ["--baseline-from-ref", base]).filter((c) => c.isNew);
  let baseClones = [];
  if (flagged.length > 0) {
    const tree = join(work, "base");
    git("worktree", "add", "-q", "--detach", tree, git("merge-base", base, "HEAD"));
    try {
      baseClones = scan(join(tree, git("rev-parse", "--show-prefix")), join(work, "base-report"), []);
    } finally {
      git("worktree", "remove", "--force", tree);
    }
  }
  const fresh = [];
  for (const clone of flagged) {
    const inside = baseClones.some((b) => pair(b) === pair(clone) && normal(b.fragment).includes(normal(clone.fragment)));
    if (inside) console.log(`legacy, inside a clone the base already has: ${where(clone)}`);
    else fresh.push(clone);
  }
  for (const clone of fresh) {
    console.log(`new clone (${clone.tokens} tokens): ${where(clone)}`);
    console.log(clone.fragment.split("\n").slice(0, 6).map((line) => `  ${line}`).join("\n"));
  }
  console.log(`${fresh.length} new clones (${flagged.length - fresh.length} more inside clones the base already has)`);
  process.exitCode = fresh.length > 0 ? 1 : 0;
} finally {
  rmSync(work, { recursive: true, force: true });
}
