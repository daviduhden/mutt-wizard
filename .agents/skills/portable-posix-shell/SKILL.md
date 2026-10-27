---
name: portable-posix-shell
description: Use when editing shell code or external command usage, especially for macOS, OpenBSD, cron, sed/awk/find portability, quoting, temporary files, or signal handling.
---

# Portable POSIX shell

## When to use

Use this skill for any change to `bin/mw`, `bin/mailsync`, `lib/openfile`, or
shell fragments in `Makefile` and `share/`. It is especially important when a
change introduces a new utility, option, or shell construct.

## Preconditions

- Read the entire script, not only the diff. Note its shebang, `set` options,
  `IFS`, traps, and global variables.
- Check the target platforms: Linux, macOS, and OpenBSD. Do not assume GNU
  coreutils.
- Prefer POSIX utilities and documented portable options. If an option is
  uncertain, choose a portable alternative instead of guessing.

## Procedure

1. Keep the shebang `#!/bin/sh` and write POSIX grammar:
   - no `[[ ]]`, arrays, `local`, `let`, process substitution, `source`,
     `set -o pipefail`, `$'...'`, or `${var,,}`;
   - use `case`, `if`, `while`, `printf`, and `${var:-default}`.
2. Quote expansions, especially paths, addresses, and values read from
   configs. Use `--` before operands where the tool supports it, or validate
   the value so it cannot begin with `-`.
3. Avoid GNU-only behavior:
   - `sed -i` (use a temp file in the same directory and write it back);
   - `readlink -f`, `grep -P`, `pgrep -a`, `setsid`, `/proc`;
   - `find -delete` (use `-exec rm -f {} +`);
   - GNU `awk` extensions such as `gensub`, `IGNORECASE`, or `asort`.
4. Use `mktemp "${TMPDIR:-/tmp}/name.XXXXXX"` and clean up through a single
   `EXIT` trap. For signals, call the cleanup and then `exit`.
5. Handle newline-separated data explicitly. Set `IFS` deliberately, or use
   `while IFS= read -r line`; disable globbing with `set -f` when expanding a
   list of paths.
6. Keep `envsubst` variables exported on purpose (`set -a`), but do not let
   secrets or unrelated ambient variables enter a template. Initialize
   defaults explicitly.
7. Check every command's exit status that matters. Do not let a notification
   or terminal write determine whether a sync succeeded.

## Validation

Static:

- `git diff --check`.
- Manually inspect every new external command and flag against POSIX and the
  BSD/macOS variants. For sed, check the delimiter, BRE/ERE mode, and whether
  the script relies on GNU alternation.
- Confirm all temporary paths use `mktemp`, have restrictive modes when
  needed, and are removed on success, failure, and signals.
- Confirm `$@`/`$*`, `IFS`, and unquoted expansions are intentional.

Runtime (only if explicitly authorized):

- `sh -n bin/mw bin/mailsync lib/openfile` (syntax only).
- `shellcheck -s sh bin/mw bin/mailsync lib/openfile` if installed.
- Exercise the changed path with a temporary `HOME` and fake configs; never
  run against a real mail account.

## Common problems

- A "portable" rewrite still uses `mv` over a symlink, `sed -i`, or a GNU
  `find` predicate.
- A `for file in $list` loop expands glob characters in maildir names.
- `tty -s` is used where its output or status is misunderstood.
- A trap cleans up on `HUP`/`INT`/`TERM` but does not exit, so the script
  continues with a half-written temp file.
- `mktemp` is called without a template or in a directory that may not exist.
- `eval` of profile lines executes metacharacters or fails on a multi-line
  quoted value.

## References

- `bin/mw` (`rewrite`, `delete_block`, `togglecron`, traps)
- `bin/mailsync` (background jobs, `wait`, profile reconstruction, `set -f`)
- `lib/openfile` (opener selection, `nohup`, cache cleanup)
- `Makefile` (portable install rules)

## Maintenance & Continuous Learning

Whenever this skill is used to change the repository, review this skill after
the implementation. Correct procedures that proved wrong, update commands,
paths, configuration and examples, incorporate reusable findings, and remove
outdated assumptions. Review the applicable root and nested `AGENTS.md` files,
specialized agents and related skills; update only the knowledge affected by
the work. Validate local references and run
`python3 scripts/validate-agent-knowledge.py --scope worktree` plus the
applicable project checks. For pull request comparisons, use the documented
`--scope range --base BASE_REF --head HEAD_REF` command. The canonical validator
is read-only and is required even when a task restricts execution of project
scripts; this does not authorize running installers or changing the host.
Report checks actually performed. A structural pass does not prove semantic
relevance, and a task is incomplete until synchronization is validated.
