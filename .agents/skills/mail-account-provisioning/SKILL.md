---
name: mail-account-provisioning
description: Use when adding, removing, listing, or reordering mail accounts, or when changing domains.csv, account templates, server ports, TLS modes, or the mw CLI.
---

# Mail account provisioning

## When to use

Use this skill for changes to `bin/mw` account actions (`-a`, `-l`, `-d`,
`-D`, `-r`), `share/domains.csv`, the `share/*-temp` account templates, the
generated `~/.config/mutt/accounts/<address>.muttrc`, or the account-related
parts of `mw.1`, `README.md`, and the zsh completion.

## Preconditions

- Read `bin/mw` end to end before editing. The add pipeline is
  `checkbasics` -> `askinfo` -> `getboxes` -> `getprofiles` -> `finalize`.
- Read the affected template. `envsubst` replaces only exported variables;
  every `$name` in a `*-temp` file must be initialized in `mw`.
- Never add or delete a real account while developing. Use a disposable
  `HOME`, `XDG_CONFIG_HOME`, `XDG_DATA_HOME`, and `PASSWORD_STORE_DIR`.

## Procedure

1. Trace the action path:
   - Add: address validation, nine-account limit, duplicate check,
     `domains.csv` lookup, port defaults, password handling, mailbox probe,
     template expansion, cache creation.
   - Delete: resolve the exact account, remove mbsync/msmtp/mpop blocks, the
     account muttrc and its `source`/macro lines, the imapnotify YAML, the
     cached headers/bodies, and the `pass` entry (including a `-P` prefix).
   - Reorder: parse the generated `iN` macros, edit the temp file, validate
     numbers are 1-9, and rewrite the muttrc.
2. For a new provider, append one CSV row to `share/domains.csv`:
   `domain,imap-host,imap-port,smtp-host,smtp-port`. Use `*.` only for a real
   wildcard; exact domains are searched before wildcards.
3. Keep port/TLS behavior consistent:
   - IMAP 993 = implicit TLS (`imaps://`, `TLSType IMAPS`).
   - IMAP 143 = STARTTLS (`imap://` plus `--ssl-reqd`).
   - IMAP 1143 = plain text (`TLSType None`); do not probe it as `imaps://`.
   - POP 995 = implicit TLS; POP 110 = STARTTLS.
   - SMTP 465 = implicit TLS; 587/25/2525 = STARTTLS (the template comments
     out `tls_starttls off`).
4. Add or update the account muttrc fields and the matching `mw.1`/`README.md`
   documentation. Record the pass prefix in the account file as
   `# mw-pass-prefix: <prefix>` so deletion can find it.
5. Update `completion/_mutt-wizard.zsh` if a flag or action changes. Keep
   `-X` in the delete group, not under `-a`.

## Validation

Static:

- `git diff --check`.
- Re-read every changed template and confirm each `$variable` is exported by
  `mw`; grep for the name in `bin/mw`.
- Compare `mw -h`, `mw.1`, `README.md`, and the completion against the
  `getopts` string.
- Check the generated path logic for `MBSYNCRC`, `MPOPRC`, `NOTMUCH_CONFIG`,
  and `XDG_*`.

Runtime (only with explicit operator approval and a disposable environment):

- `mw -h` must exit 0.
- Add a fake account with `-f` and fake server names; it must write only under
  the temporary `HOME`.
- `mw -l` must show exactly that account; `mw -D` must remove every generated
  file and the test pass entry.

## Common problems

- A template variable is unset, so `envsubst` writes an empty value or an
  inherited environment value into the config.
- The domain table matches a wildcard before an exact row.
- `-o` and `-p` are combined; they are mutually exclusive.
- An address containing shell metacharacters, whitespace, or `/` reaches
  `PassCmd`, a neomutt macro, or a YAML file. `validaddr` rejects these.
- Deleting an account leaves `~/.config/imapnotify/<address>.yaml` or a
  prefixed `pass` entry behind.
- `mbsync -v` is verbose, not a version query; use `mbsync -V`.
- `mw -l` reads the generated `iN` macros, so a manually removed macro hides
  that account from the listing unless the muttrc has no macros at all (then
  file order is used as a fallback).

## References

- `bin/mw` (`validaddr`, `parsedomains`, `askinfo`, `getboxes`, `delete`,
  `reorder`, `togglecron`)
- `share/domains.csv`
- `share/mutt-temp`, `share/mbsync-temp`, `share/msmtp-temp`,
  `share/mpop-temp`, `share/online-temp`, `share/imapnotify-temp`
- `mw.1`, `README.md`, `completion/_mutt-wizard.zsh`

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
