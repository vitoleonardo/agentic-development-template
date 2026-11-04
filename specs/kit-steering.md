# Kit steering

ID prefix: STEER

## Goal
A developer who lets the kit's autopilot build features unattended can steer each headless session when needed: send it a message, stop the run, or start one. The kit owns these controls as commands, so they work from any terminal, and its status command reports each session, so a pane beside the chat can show them live and call the same commands.

## User flow
1. The developer starts a run with `.claude/bin/autopilot start`. The command returns once the run is underway; the run goes on without the terminal or the session that started it.
2. `.claude/bin/status --json` lists the run's sessions with their transcripts, the queued and delivered messages, and whether a stop is requested.
3. The developer sees the session drift and sends a message: `.claude/bin/autopilot steer "<text>"`. The session reads it after its next tool call and logs what it did under Decisions to review.
4. The developer stops the run with `.claude/bin/autopilot stop`. Autopilot ends the session within 5 seconds, writes the run log as for any stop, and prints `claude --resume <session>`.

## Terms
- **Run lock**: the file `.work/autopilot/lock`, holding the run's process ID and run ID.
- **Running**: the run lock exists and its process is alive and is an autopilot.
- **Message**: a file `.work/autopilot/steer/<run>-<time>-<n>-<pid>.md` with the developer's text. **Delivered**: moved to `.work/autopilot/steer/delivered/`.
- **Main agent**: a tool call whose hook input has no `agent_id`.
- **Run's sessions**: the transcripts `.work/autopilot/<run>-*.jsonl`, oldest first by modification time. Kind: `answer` for an answerer's, `restart`, `wait` or `resumed` for the endings `-restart-<n>`, `-wait-<n>` and `-<n>`, else `session`.

## Acceptance criteria

Run lock and start:

- **STEER-AC1**: Given no run is running, when `autopilot` starts with an approved spec queued, then it writes the run lock with its process ID and run ID before its first session, and removes the lock when it ends, whether it finishes, stops or is terminated.
- **STEER-AC2**: Given a run is running, when `autopilot` or `autopilot start` is called, then it exits 2 with `autopilot: run <run> is already running (pid <pid>). Stop it with .claude/bin/autopilot stop.` and starts no session.
- **STEER-AC3**: Given a run lock whose process is not alive, when `autopilot` starts, then it replaces the lock and runs.
- **STEER-AC4**: Given an approved spec queued, when `autopilot start` is called, then it returns exit 0 with `autopilot: started run <run>. Run log: <path>` once the run lock exists, and the run goes on after the command and its caller have ended.
- **STEER-AC5**: Given a check before the first session fails (budget unset, uncommitted changes, an untrusted folder), when `autopilot start` is called, then it exits with that check's code and prints that check's message.

Stop:

- **STEER-AC6**: Given a run is running a session, the answerer or a usage-limit wait, when `autopilot stop` is called, then within 5 seconds the session's process ends, the run log gets the row `| <feature> | <branch> | stopped: user | stopped by the user | <sessions> |` and the line `Stopped at <feature>: stopped by the user`, and `autopilot stop` returns with `claude --resume <session>` once the run has ended.
- **STEER-AC7**: Given a session is stopped before it wrote a result line, when autopilot stops, then the session ID it prints is the one from the session's first line.
- **STEER-AC8**: Given a stop is requested between two sessions, when autopilot would start the next session, then it starts none and stops as in AC6.
- **STEER-AC9**: Given a run stopped by the user, when the state file of the feature's branch is read, then Decisions to review has `- stopped-by-user | <phase> session | <DD.MM.YYYY HH:MM>`.
- **STEER-AC10**: Given no run is running, when `autopilot stop` or `autopilot steer <text>` is called, then it exits 1 with `autopilot: no run is running.`
- **STEER-AC11**: Given a stop request left from an earlier run, when a new run starts, then the run does not stop.

Messages:

- **STEER-AC12**: Given a run is running, when `autopilot steer "keep the CSV columns as in the spec"` is called, then a message with that text exists for the run, and it exits 0 with `autopilot: message queued; the session reads it after its next tool call.`
- **STEER-AC13**: Given `autopilot steer` with no text or only spaces, then it exits 2 and queues nothing.
- **STEER-AC14**: Given a session of the run and two undelivered messages of the run, when the main agent finishes a tool call, then the kit's steer hook delivers both, oldest first, as additional context that starts with `The person watching this autopilot run says:` and asks to log each under Decisions to review as `steered-by-user | <text> | <what you did>`.
- **STEER-AC15**: Given a delivered message, when the main agent finishes another tool call, then the hook delivers nothing.
- **STEER-AC16**: Given a subagent finishes a tool call, when undelivered messages exist, then the hook delivers nothing and leaves them undelivered.
- **STEER-AC17**: Given a session that autopilot did not start (an interactive session, the answerer, the trust probe), when it finishes a tool call while messages exist, then the hook delivers nothing.
- **STEER-AC18**: Given an undelivered message of an earlier run, when a session of the current run finishes a tool call, then the hook does not deliver it.
- **STEER-AC19**: Given a run's feature branch whose state file has 2 `steered-by-user` and 1 `stopped-by-user` lines under Decisions to review, when the run records are written and reported, then that run counts 3 interventions.

Status command (`--json`, the `autopilot` object):

- **STEER-AC20**: Given a run is running, when the status command runs, then `autopilot.running` is `true` and `autopilot.active` is `true`; with no run lock or a dead one, `running` is `false`.
- **STEER-AC21**: Given a run is running with a stop requested, when the status command runs, then `autopilot.stop_requested` is `true`.
- **STEER-AC22**: Given the newest run has one delivered and one undelivered message, when the status command runs, then `autopilot.messages` lists both, oldest first, as `{ text, delivered }`.
- **STEER-AC23**: Given the newest run has a plan session, a build session, a watchdog restart and an answerer session, when the status command runs, then `autopilot.sessions` lists the four transcripts oldest first as `{ file, feature, phase, kind }` with kinds `session`, `session`, `restart` and `answer`, `file` relative to the project.
- **STEER-AC24**: Given the newest run log ends with `Stopped at <feature>` and the stopped row's Sessions cell names `s1 s3`, when the status command runs, then `autopilot.resume` is `s3`; for a run without a stop it is `null`.


## Out of scope
- A view of the sessions: the status command reports them, and a pane draws them.
- Typing into a session while it runs, or taking it over in a terminal before it stops. After a stop, `claude --resume <session>` does that.
- Delivering a message into a running subagent. It waits for the subagent's end; a stop is the way for urgent cases.
- Runs on other machines or in the cloud.

## Open questions

## Decisions
- 02.11.2026: Sessions stay headless `claude -p`, and messages go through a kit hook on PostToolUse. A probe showed that additional context from that hook reaches a `-p` session's model at its next tool call. A probe of `claude --bg` showed a background session waits after its turn instead of ending, and holds a message from a session in another permission mode for a person's approval; `-p` sessions are not reachable by session messages at all.
- 02.11.2026: The kit owns start, stop and messages as autopilot commands, and a pane only calls them, so the controls work without one and the file formats stay the kit's.
- 02.11.2026: The status command names the transcripts but does not parse them, because the stream format belongs to Claude Code, not the kit.
- 02.11.2026: A message is delivered only to the main agent, so the agent that plans and dispatches the work reads it.
- 02.11.2026: Steering messages and user stops count as interventions in the run records, next to stops resolved by the user.
- 02.11.2026: A message delivered to a session that is then stopped counts as delivered, though the model may not have read it.
