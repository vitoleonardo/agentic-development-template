// Usage: node duplicates-new.mjs <jscpd> <scan arguments...>   (KIT_BASE: the base branch)
// Fails on the clones the branch adds; a clone inside one the same file pair already has on the base is legacy,
// and a clone inside constructor parameter lists in both files is dependency injection, not shared logic.
// The base is scanned whole: without --changed and without the edited files the edit hook appends.
import { execFileSync } from "node:child_process";
import { existsSync, mkdtempSync, readFileSync, rmSync, statSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";

const [jscpdArg, ...scanArgs] = process.argv.slice(2);
const base = process.env.KIT_BASE || "main";
const jscpd = jscpdArg.includes("/") ? resolve(jscpdArg) : jscpdArg;
const isFile = (arg) => existsSync(arg) && statSync(arg).isFile();
const baseArgs = scanArgs.filter((arg) => arg !== "--changed" && !isFile(arg));
const work = mkdtempSync(join(tmpdir(), "kit-duplicates-"));

function scan(cwd, output, args, extra) {
  execFileSync(jscpd, [...args, ...extra, "--reporters", "json", "--output", output, "--no-colors"], {
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

const lineAt = (text, index) => text.slice(0, index).split("\n").length;
const constructorLines = new Map();
function constructorRanges(file) {
  if (!constructorLines.has(file)) {
    const text = isFile(file) ? readFileSync(file, "utf8") : "";
    const ranges = [];
    for (const match of text.matchAll(/constructor\s*\(/g)) {
      let depth = 0;
      let end = match.index + match[0].length - 1;
      for (; end < text.length; end++) {
        if (text[end] === "(") depth++;
        else if (text[end] === ")" && --depth === 0) break;
      }
      ranges.push([lineAt(text, match.index), lineAt(text, end)]);
    }
    constructorLines.set(file, ranges);
  }
  return constructorLines.get(file);
}
const inConstructor = (part) => constructorRanges(part.name).some(([from, to]) => part.start >= from && part.end <= to);

try {
  const added = scan(process.cwd(), join(work, "head"), scanArgs, ["--baseline-from-ref", base]).filter((c) => c.isNew);
  const injection = added.filter((c) => inConstructor(c.firstFile) && inConstructor(c.secondFile));
  for (const clone of injection) console.log(`dependency injection, inside constructor parameter lists: ${where(clone)}`);
  const flagged = added.filter((c) => !injection.includes(c));
  let baseClones = [];
  if (flagged.length > 0) {
    const tree = join(work, "base");
    git("worktree", "add", "-q", "--detach", tree, git("merge-base", base, "HEAD"));
    try {
      baseClones = scan(join(tree, git("rev-parse", "--show-prefix")), join(work, "base-report"), baseArgs, []);
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
  console.log(
    `${fresh.length} new clones (${flagged.length - fresh.length} more inside clones the base already has, ` +
      `${injection.length} inside constructor parameter lists)`,
  );
  process.exitCode = fresh.length > 0 ? 1 : 0;
} finally {
  rmSync(work, { recursive: true, force: true });
}
