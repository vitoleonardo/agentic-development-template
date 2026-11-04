"""Coverage for .claude/bin/baseline, read from coverage.json (coverage.py JSON report).

Prints "<file> TAB <covered lines> TAB <total lines>" per file, or with --total the overall percentage.
Usage: python .claude/bin/coverage-files.py [--total]
"""

import json
import os
import sys

with open(os.environ.get("COVERAGE_JSON", "coverage.json"), encoding="utf-8") as report:
    data = json.load(report)

if "--total" in sys.argv:
    print(round(data["totals"]["percent_covered"], 2))
else:
    for name, entry in data["files"].items():
        summary = entry["summary"]
        print(f"{name}\t{summary['covered_lines']}\t{summary['num_statements']}")
