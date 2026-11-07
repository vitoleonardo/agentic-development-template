# What the hooks do around every tool call

The skills describe the workflow; the hooks enforce it, in every session, also in a headless one. They are POSIX shell, wired in `.claude/settings.json` (or shipped by the plugin), and they run on Claude Code's hook events:

```mermaid
%%{init: {'theme': 'base', 'themeVariables': {'fontSize': '13px', 'primaryColor': '#F8F2E5', 'primaryTextColor': '#15110C', 'primaryBorderColor': '#15110C', 'lineColor': '#15110C', 'clusterBkg': '#EFE7D6', 'clusterBorder': '#15110C', 'edgeLabelBackground': '#F8F2E5'}}}%%
flowchart TB
  classDef hook fill:#2E5FA6,stroke:#15110C,stroke-width:2px,color:#F8F2E5
  classDef stop fill:#C8302C,stroke:#15110C,stroke-width:2px,color:#F8F2E5
  classDef ask fill:#E2AE34,stroke:#15110C,stroke-width:2px,color:#15110C
  classDef ok fill:#1F7A4D,stroke:#15110C,stroke-width:2px,color:#F8F2E5
  classDef plain fill:#F8F2E5,stroke:#15110C,stroke-width:2px,color:#15110C

  subgraph pre ["PreToolUse · before the tool runs"]
    direction TB
    CALL["Claude calls Bash, Read, Edit,<br/>Write, Grep or Glob"]:::plain --> GUARD{{"guard"}}:::hook
    GUARD -- "secret file (.env, *.pem, ~/.ssh), rm -rf,<br/>force push, reset --hard, protected path,<br/>destructive SQL, network tool, sh -c wrapper,<br/>test-writer outside a test file, an agent<br/>editing .claude/, new source file outside the Map" --> BLOCK["blocked: the reason goes to Claude,<br/>'ask the user to run it'"]:::stop
    GUARD -- "git commit, git push, gh pr create,<br/>install, lockfile, CI or infra file" --> GATE{{"gate <name>"}}:::ask
    GATE -- "ask" --> PERM["permission prompt for you"]:::ask
    GATE -- "auto" --> ALLOW["allowed; Claude logs it<br/>under Decisions to review"]:::ok
    GUARD -- "anything else" --> RUN["the tool runs"]:::ok
    DISPATCH["Claude dispatches a subagent"]:::plain --> USAGE1{{"usage"}}:::hook
    USAGE1 -- "KIT_BUDGET_TOKENS used up" --> BLOCK2["dispatch blocked;<br/>/ship-feature stops and asks"]:::stop
    USAGE1 -- "80 % used" --> WARN["Claude is told to report it"]:::ask
  end

  subgraph post ["PostToolUse · after it ran"]
    direction TB
    REC{{"record-edit<br/>on Edit and Write"}}:::hook --> PEND["notes the edited file<br/>for this batch and this turn"]:::plain
    STEER{{"steer<br/>on every tool"}}:::hook -- "a message queued by<br/>autopilot steer" --> MSG["handed to the session<br/>after this tool call"]:::plain
    USAGE2{{"usage<br/>on Agent, also on SubagentStop"}}:::hook --> TSV["tokens per agent and model<br/>→ .work/branch/usage.tsv"]:::plain
  end

  subgraph batch ["PostToolBatch · once per batch of tool calls"]
    direction TB
    CHK{{"check-edits"}}:::hook
    CHK -- "specs/*.md edited" --> SL["spec-lint"]:::plain
    CHK -- "source edited" --> SEQ["format → typecheck →<br/>related tests → duplicates-related"]:::plain
    SL & SEQ -- "fail" --> CTX["failure text goes back into the turn:<br/>fix it now, or record the expected red"]:::stop
    SL & SEQ -- "pass" --> LOG["result logged for the turn"]:::ok
  end

  subgraph stop ["Stop · the turn ends"]
    direction TB
    SUM{{"summary"}}:::hook
    SUM -- "a check was red" --> RERUN["re-runs it once on this turn's files"]:::plain
    RERUN -- "still red" --> HOLD["the turn does not end:<br/>fix it, or say plainly why it stays red"]:::stop
    RERUN -- "green now" --> DONE["to you: changed files,<br/>checks and their results"]:::ok
    SUM -- "all green" --> DONE
    USAGE3{{"usage"}}:::hook --> TSV2["the main session's tokens"]:::plain
  end

  pre --> post --> batch --> stop
```

Three details matter in practice. The guard decides approval gates itself: it answers the permission check with `ask` or `allow` by `KIT_APPROVAL`, so a chained or substituted command (`a && b`, `$(…)`) always goes through the normal prompt. The check hooks run only the commands `.claude/kit.conf` defines, through `.claude/bin/check`, so they are as fast as your typecheck. And a red check does not fail the turn silently: the Stop hook holds the session once, which is why a test written to fail first has to be recorded as such in the state file.

### Hooks and permissions

| Event | Hook | What it does |
|---|---|---|
| `PreToolUse` on Bash, Read, Edit, Write, Grep, Glob | `guard` | Blocks secret files, `rm -rf`, force push, `git reset --hard`, `git clean`, branch deletion, destructive SQL, network tools and the `sh -c`, `/usr/bin/env` and `git -C` wrappers the deny list cannot see. Blocks commands and reads on `KIT_PROTECTED_PATHS`, the test-writer outside test files, agents editing `.claude/`, and a new source file outside the Map. Decides the `commit`, `push`, `deps` and `config` gates by `KIT_APPROVAL` |
| `PreToolUse` on Agent | `usage` | Warns at 80 % of `KIT_BUDGET_TOKENS`, blocks the dispatch at 100 % |
| `PostToolUse` on Edit, Write | `record-edit` | Notes the file for the batch and the turn |
| `PostToolUse` on Agent, `SubagentStop`, `Stop` | `usage` | Reads the transcripts and writes tokens per agent and model to `.work/<branch>/usage.tsv` |
| `PostToolUse` on everything | `steer` | Hands an autopilot session the messages queued with `autopilot steer` |
| `PostToolBatch` | `check-edits` | `spec-lint` for edited specs; format, typecheck, related tests and `duplicates-related` for edited sources; failures go back into the turn |
| `Stop` | `summary` | Re-runs a red check once and holds the turn while it stays red; otherwise reports changed files and check results |

`.claude/settings.json` sets the permissions underneath: read-only git and the kit's own scripts run without asking; `gh pr merge` and edits to `settings.json`, `kit.conf`, the baseline, the hooks, the scripts and the rules always ask, so the agent cannot raise its own level; reading `.env*`, keys and `~/.ssh`, `sudo`, `rm -rf`, force pushes, `curl`, `wget`, `ssh` and `printenv` are denied. For OS-level isolation `/onboard` can turn on Claude Code's sandbox with `denyRead` on protected paths; without it these layers are best effort.
