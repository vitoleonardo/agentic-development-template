---
paths:
  - "src/**/*.ts"
  - "src/**/*.mts"
  - "bin/**"
  - "scripts/**/*.ts"
---

# Node.js (services, workers, CLIs)

- Follow the module system in `package.json` (`"type": "module"` or CommonJS). Do not mix them.
- Import built-ins with the `node:` prefix (`node:fs/promises`, `node:path`).
- Prefer the platform before adding a dependency: `fetch`, `AbortSignal.timeout`, `crypto.randomUUID`, `structuredClone`, `node:util` `parseArgs`, `node:test` only if the project already uses it.
- The Node version is pinned in `engines` (and `.nvmrc` if present). Do not use APIs newer than that version.
- Every outbound network call has a timeout and handles non-2xx responses explicitly.
- No synchronous file system calls (`readFileSync`, ...) in request handlers or hot paths. Startup code may use them.
- Stream large files instead of reading them into memory.
- Long-running processes handle `SIGTERM` and `SIGINT`: stop accepting work, finish or abort in-flight work, close connections, then exit.
- Never leave a promise rejection unhandled. An unexpected error is logged with context and the process exits non-zero; it is not silently ignored.
- CLIs write results to stdout and errors to stderr, and exit with a non-zero code on failure.
- Validate environment variables once at startup and fail fast with a message naming the missing variable (never its value).

## Map

Homes Node.js services and CLIs add to the Map in `structure.md`.

| Kind | Home | Naming |
|------|------|--------|
| Process entry | `src/index.ts`, `src/main.ts`, `src/server.ts` | – |
| HTTP routes and jobs | `src/routes/`, `src/jobs/` | the route or the job |
