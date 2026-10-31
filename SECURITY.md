# Security policy

## Reporting a vulnerability

Please do not open a public issue for a security problem. Email [hi@vito.koeln](mailto:hi@vito.koeln) with:

- what is affected (plugin or template, file, version or commit),
- how to reproduce it,
- what an attacker could do with it.

You will get a reply. Once the issue is confirmed, a fix is released and the report is credited, unless you prefer not to be named.

## Scope

In scope are the guard and check hooks, the permission rules, the installer, the repo-check read-only hook and scanner, and the CI workflows the kit installs.

Known limits, not vulnerabilities:

- The kit's hooks and permissions are pattern-based. A determined command can get past them; the [sandbox](plugins/agentic-workflow-kit/docs/customizing.md#turn-on-the-sandbox) provides OS-level isolation.
- In a folder Claude Code has not been trusted for, it ignores the project's hooks and allow rules.
- The single-file repo-check prompt relies on instructions only. The read-only guarantee is enforced only by the plugin's hook.
