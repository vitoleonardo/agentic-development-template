#!/usr/bin/env node
// Reads a mutation report in the mutation-testing-report schema (Stryker's reporters json) and prints one row per
// mutant: "<file> TAB <line> TAB <mutator> TAB <status>", the file relative to the current folder.
// Usage: node mutation-files.mjs [report]   (default: reports/mutation/mutation.json, or $KIT_MUTATION_REPORT)
import { readFileSync } from 'node:fs';
import { isAbsolute, relative } from 'node:path';

const path = process.argv[2] || process.env.KIT_MUTATION_REPORT || 'reports/mutation/mutation.json';
let report;
try {
  report = JSON.parse(readFileSync(path, 'utf8'));
} catch (error) {
  console.error(`mutation-files: cannot read ${path}: ${error.message}`);
  process.exit(2);
}
const root = report.projectRoot || process.cwd();
for (const [name, file] of Object.entries(report.files || {})) {
  const shown = isAbsolute(name) ? relative(root, name) : name;
  for (const mutant of file.mutants || []) {
    const line = mutant.location?.start?.line ?? 0;
    process.stdout.write(`${shown}\t${line}\t${mutant.mutatorName ?? '?'}\t${mutant.status ?? '?'}\n`);
  }
}
