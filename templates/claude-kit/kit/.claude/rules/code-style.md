# Code style

- TypeScript strict mode. No `any`, `@ts-ignore`, `@ts-expect-error` or `as unknown as` unless a comment on the same line explains why. Prefer `unknown` plus narrowing.
- The formatter and linter decide formatting. Do not change their config or add `eslint-disable` / `biome-ignore` to silence a finding unless a comment explains why.
- Follow the naming and file conventions already in the codebase. Do not introduce a second convention.
- No new dependency without asking first. Say what it is for, why the platform or an existing dependency cannot do it, and its install size. Never hand-edit a lockfile.
- Handle every promise: `await` it, return it, or mark it deliberately with `void`. No floating promises.
- Never swallow errors (`catch {}` or `catch (e) { console.log(e) }`). Handle them, or rethrow with context.
- Prefer early returns over nested conditions. Keep functions small enough to read without scrolling.
- No dead code, commented-out code or unused exports. Delete them; git remembers.
- Comments explain why, not what. Do not add comments that repeat the code.
- Do not reformat or rename code outside the task. It hides the real change in the diff.
