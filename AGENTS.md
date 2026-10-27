# AGENTS.md

## Project

mutt-wizard is a POSIX `sh` configurator for terminal email. It provisions
**neomutt**, **isync/mbsync** (IMAP), **mpop** (POP3), **msmtp** (SMTP), and
**pass**/GPG credentials on Linux, macOS, and OpenBSD. This repository is a
fork; keep upstream copyright notices and GPLv3 headers intact.

## Architecture

- `bin/mw` — account CLI: add, list, delete, reorder, cron toggle, and the
  deprecated `-y`/`-Y` sync actions. `askinfo`, `getboxes`, `getprofiles`, and
  `finalize` form the add pipeline; `delete`, `reorder`, and `togglecron` are
  the other mutating paths.
- `bin/mailsync` — syncs configured accounts, detects new mail, sends optional
  notifications, indexes with notmuch, and is designed to run from cron.
- `lib/openfile` — copies an attachment to the cache and launches an opener.
- `share/*-temp` — `envsubst` templates for neomutt, mbsync, msmtp, mpop,
  notmuch, imapnotify, and online-only accounts. `share/domains.csv` maps
  domains to server defaults; `share/mutt-wizard.muttrc` and
  `share/switch.muttrc` are installed neomutt configuration.
- `completion/_mutt-wizard.zsh` — zsh completion for `mw`.
- `mw.1`, `mailsync.1`, `Makefile` — manual pages and portable install rules.

Runtime files live under `${XDG_CONFIG_HOME:-~/.config}`, `${XDG_DATA_HOME:-~/.local/share}`,
and `${XDG_CACHE_HOME:-~/.cache}`; the mbsync config defaults to
`${MBSYNCRC:-~/.mbsyncrc}` and the mpop config to `${MPOPRC:-~/.config/mpop/config}`.

## Conventions

- Write POSIX `sh`, not Bash. Do not add `[[`, arrays, `local`, process
  substitution, `set -o pipefail`, or Bash-only parameter expansion.
- Do not assume GNU coreutils. Avoid `sed -i`, `readlink -f`, `grep -P`,
  `pgrep -a`, `setsid`, `/proc`, and GNU-only `find`/`awk` extensions.
- Keep `share/*-temp` variables in sync with the variables exported by `bin/mw`
  (`set -a` is used deliberately for `envsubst`). Prefer initializing defaults
  explicitly so an inherited environment cannot leak into a template.
- Quote parameter expansions; use `printf`, not `echo -e`; use newline-safe
  loops for lists. Use `mktemp` with a template and clean up with the `EXIT`
  trap.
- Preserve the existing tab-based indentation, lowercase shell variables,
  function naming, and comment style. Keep user-facing text in US English.
- Update every affected interface together: `bin/mw`, templates, `mw.1`,
  `mailsync.1`, `README.md`, and `completion/_mutt-wizard.zsh`.

## Commands

There is no compile step. `make all` and `make clean` are no-ops because the
project produces no build artifacts; `make test` runs the shared agent-validator
contract suite.

- `sudo make install` (Linux/macOS) or `doas make install` (OpenBSD) installs
  the scripts, templates, man pages, and zsh completion. On OpenBSD use
  `doas make install MANPREFIX=/usr/local/man`.
- `sudo make uninstall` / `doas make uninstall` removes the installed files.
- `mw -h` prints help and exits 0. `mw -a you@example.com` adds an account;
  `mw -l`, `mw -d`, `mw -D address`, `mw -r`, `mw -t 30`, and `mw -T` are the
  other user-facing actions.
- `mailsync` syncs all configured accounts; `mailsync address` syncs one.
- `make install` installs the scripts and support files; plain `make` retains
  `install` as its default target.
- Static review: `git diff --check` for whitespace/conflict markers. If the
  operator permits execution, `sh -n bin/mw bin/mailsync lib/openfile` checks
  shell syntax only; `shellcheck -s sh` and `mandoc -Tlint mw.1 mailsync.1`
  are optional when installed.
- `checkmake.ini` allows the existing install recipe's current 46-line body;
  keep this bound exact so the linter still catches subsequent growth.
- Build/install validation must use a temporary `DESTDIR` or a disposable
  prefix. Never install over a live system as part of an agent task.

## Security and testing policy

- Never print, log, or commit passwords, passphrases, decrypted `pass` output,
  or GPG secret material. Do not put secrets in process arguments; prefer
  `pass` and mode-600 temporary files or stdin.
- `mw -x` is inherently visible in the process list and shell history. Document
  the risk; do not add new secret-bearing flags.
- Respect `umask 077` for generated credentials and caches.
- Do not use real accounts, real mailboxes, or real GPG keys in tests. Never
  send test mail, delete mail, or modify `~/.config`, `~/.local/share`, or a
  real `pass` store. Use a disposable `HOME`, `XDG_*`, `PASSWORD_STORE_DIR`,
  and `GNUPGHOME` if a runtime check is explicitly authorized.
- Distinguish static analysis, build/install, tests, and a real end-to-end
  check. Do not claim a test passed unless it was actually run. The former
  application mock-based suite was removed; the shared agent-validator contract
  suite now lives in `tests/agent_knowledge_validator/`.

## Pre-existing changes

Run `git status --short` and `git diff` before editing. Treat uncommitted
changes and untracked files as user work: do not revert, overwrite, or reformat
them. Do not commit, push, or rewrite history unless explicitly asked.

## Skills

Load the relevant skill before changing a subsystem:

- [mail-account-provisioning](.agents/skills/mail-account-provisioning/SKILL.md)
- [credential-and-gpg-protection](.agents/skills/credential-and-gpg-protection/SKILL.md)
- [portable-posix-shell](.agents/skills/portable-posix-shell/SKILL.md)
- [mailsync-and-scheduling](.agents/skills/mailsync-and-scheduling/SKILL.md)
- [manual-pages-and-install-tests](.agents/skills/manual-pages-and-install-tests/SKILL.md)

## Continuous Agent & Skills Maintenance

Every repository change MUST trigger an Agent & Skills Maintenance Review.
Agent instructions and skills are living repository artifacts. Before
completing any repository modification, review all applicable `AGENTS.md`
files, specialized agents, and `SKILL.md` files. Update the affected knowledge
artifacts to reflect the implementation, correct outdated instructions, and
incorporate reusable knowledge. A task is incomplete until knowledge
synchronization has been performed and validated. Never skip synchronization
silently or claim that unexecuted checks have passed.

After each change:

1. Identify and review the applicable agents and skills, even when no update
   initially appears necessary.
2. Update relevant operational guidance, reusable procedures, references,
   commands, and paths; remove stale or contradictory instructions.
3. Do not use whitespace-only, timestamp-only, empty, or otherwise cosmetic
   edits to satisfy synchronization. For a project change, at least one
   relevant knowledge artifact must receive a substantive update.
4. Run `python3 scripts/validate-agent-knowledge.py --scope worktree` and the
   applicable project checks. For a pull request, CI compares the base and head
   revisions with `--scope range --base BASE_SHA --head HEAD_SHA`.
5. Review the validator output and final diff, then report the synchronization
   result. Warnings require human review; a structural pass does not establish
   semantic relevance.

Run the validator tests with
`python3 -m unittest discover -s tests/agent_knowledge_validator -p 'test_*.py'`.
The validator is read-only and uses Python 3.11+ and the standard library. It
must not be confused with project-specific validation or installation tools.
See [Agent Knowledge Validation Contract](docs/agent-knowledge-validation.md)
for AK001–AK006, JSON schema, exit codes, configuration, and maintenance rules.

All repositories must implement the same Agent Knowledge Validation CLI
contract, rule identifiers, output conventions and exit codes. Repository-
specific validations may extend the canonical behavior but must not silently
redefine it. Any change to the validator contract must be reflected in the
repository's agent instructions, related skills and tests.
