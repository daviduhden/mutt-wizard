---
name: manual-pages-and-install-tests
description: Use when changing mw.1, mailsync.1, README.md, the Makefile, install/uninstall behavior, man-page paths, packaging, completion, or documentation validation.
---

# Manual pages and install tests

## When to use

Use this skill for `mw.1`, `mailsync.1`, `README.md`, `Makefile`, `LICENSE`,
the zsh completion, or any change to installed paths, permissions, or
documentation that describes `mw`/`mailsync` behavior.

## Preconditions

- Read `bin/mw -h`, the `getopts` string, `bin/mailsync`, the affected man
  page, and the README section together.
- Know the install layout: `PREFIX` (default `/usr/local`), `MANPREFIX`
  (default `$(PREFIX)/share/man`), `DESTDIR`, `share/mutt-wizard`, and
  `lib/mutt-wizard`.
- Do not install over a live system. Use a temporary `DESTDIR` or a
  disposable prefix.

## Procedure

1. Keep the interfaces synchronized:
   - every implemented flag appears in `mw -h`, `mw.1`, and the README;
   - `-X` is documented with `-d`/`-D`, not with `-a`;
   - `-P` is documented for both add and delete;
   - deprecated `-y`/`-Y` stay marked deprecated;
   - `-h` exits 0 and is documented.
2. Check roff syntax and references:
   - `.BR name (section)` entries need the correct section (`neomuttrc` is 5);
   - use commas between SEE ALSO entries;
   - use `\-` for a literal hyphen in command names.
3. Check the Makefile:
   - `PREFIX ?=` and `MANPREFIX ?=` remain overridable;
   - the first target remains `install`, preserving plain `make` behavior;
   - `all` and `clean` stay no-ops because the project has no build artifacts;
   - `test` runs the shared agent-validator contract suite;
   - `checkmake.ini` keeps the install-body limit at its exact current size;
   - OpenBSD users install man pages with
     `doas make install MANPREFIX=/usr/local/man`;
   - install and uninstall lists match, including `LICENSE` and completion;
   - directories created under `DESTDIR` are mode 755 even under a restrictive
     umask;
   - the `mw.1` prefix substitution must not rewrite OpenBSD port paths such
     as `/usr/local/bin` that are not mutt-wizard paths.
4. Update the completion when flags or actions change. Keep value-taking
   options declared with their arguments.
5. Preserve the GPLv3 text and copyright headers. Install a copy of `LICENSE`
   with the program.

## Validation

Static:

- `git diff --check`.
- Compare the `getopts` string, `mwinfo`, `mw.1`, `README.md`, and the
  completion one flag at a time.
- Check every `$(PREFIX)`/`$(MANPREFIX)` replacement in the Makefile against
  the literal paths in the man pages.
- Check `make uninstall` removes every path that `make install` creates.

Build/install (only with explicit approval):

- `make -n install DESTDIR=/tmp/mw-stage PREFIX=/usr/local` prints the
  recipe without touching the system.
- `make install DESTDIR=/tmp/mw-stage PREFIX=/usr/local MANPREFIX=/usr/local/man`
  then inspect the stage tree; never run it as root on a live system.
- `mandoc -Tlint mw.1 mailsync.1` or `man -l mw.1` if available.

Real end-to-end checks require a disposable account and are out of scope for
documentation-only changes.

## Common problems

- A new flag is implemented but missing from help, the man page, the README,
  or the completion.
- `.BR neomuttrc (1)` should be `(5)`; missing commas merge SEE ALSO entries.
- OpenBSD `man(1)` does not search `/usr/local/share/man`.
- A blanket `sed s:/usr/local:$(PREFIX):` rewrites unrelated OpenBSD paths.
- `mkdir -p` inherits a restrictive umask, leaving installed directories
  inaccessible to non-root users.
- `make uninstall` forgets `LICENSE`, the completion, or one man page.
- The README still documents a removed binding (for example `gS`/`MS` instead
  of `gj`/`Mj`).

## References

- `Makefile`
- `mw.1`, `mailsync.1`
- `README.md`
- `completion/_mutt-wizard.zsh`
- `LICENSE`
- `bin/mw` (`mwinfo`, option parser)

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
