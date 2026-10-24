---
name: credential-and-gpg-protection
description: Use when changing password storage, pass entries, GPG handling, secret-bearing command lines, generated file permissions, or authentication probes in mw and mailsync.
---

# Credential and GPG protection

## When to use

Use this skill for any change touching `pass`, `gpg`/`gpg2`, `-x`, `-P`,
`PASSWORD_STORE_DIR`, `GNUPGHOME`, `passwordeval`, `PassCmd`, `imap_pass`,
authentication probes, temporary credential files, or generated file modes.

## Preconditions

- Read `bin/mw` (`checkbasics`, `askinfo`, `insertpass`, `getpass`,
  `getboxes`, `delete`) and `bin/mailsync` (GPG probe and environment
  reconstruction).
- Read every template that consumes `$password`, `$passprefix`, or `$login`.
- Do not use a real `pass` store, GPG key, or mail account. Use a disposable
  `PASSWORD_STORE_DIR` and `GNUPGHOME` if a runtime check is explicitly
  authorized.

## Procedure

1. Trace the secret from input to storage to use:
   - `-x` -> `password` shell variable -> `pass insert` (non-interactive).
   - interactive -> `pass insert` (never assign it to a variable).
   - existing entry -> `pass <prefix><address>` for the curl probe and
     `pass`/`PassCmd`/`passwordeval` for runtime.
2. Keep secrets out of:
   - `argv` (`ps`, `/proc/<pid>/cmdline`),
   - exported environment (`set -a` plus `password=...`),
   - logs, notifications, error messages, and generated configs.
3. For the curl connectivity probe, write a mode-600 `curl` config file with
   `chmod 600`, feed it via `--config`, remove it immediately, and clean it in
   the `EXIT` trap. Escape `\` and `"` in the credential.
4. Store the pass prefix with the account (`# mw-pass-prefix:`) so deletion
   removes the correct entry. `-P` must not force the `add` action.
5. Respect `umask 077`. The account cache, curl config, and attachment cache
   must not be world-readable.
6. Under cron there is no terminal for a passphrase. Probe an actual `pass`
   entry with `gpg --batch --decrypt` (or the same key/options `pass` uses)
   before syncing. A locked key must make cron exit without syncing, not fall
   through to `mbsync` and fail per account.

## Validation

Static:

- `grep -R` for `password`, `pass `, `PassCmd`, `passwordeval`, `imap_pass`,
  `gpg`, `GPG`, `PASSWORD_STORE`, and `GNUPGHOME` in `bin/`, `lib/`, and
  `share/`.
- Confirm no secret is expanded into a command name or argument. The curl
  credential must not appear in `curl "$@"`.
- Confirm `-x` is assigned with allexport disabled and `unset password` runs
  before template expansion.
- Confirm every generated secret file has mode 600 or stricter.

Runtime (only with explicit approval and a disposable environment):

- Add a fake account with a throwaway pass store; confirm `pass show` works
  and the plaintext never appears in `ps` output during the probe.
- Delete the account; confirm the prefixed entry is gone.
- Run `mailsync` with a locked test key; confirm it exits before any sync.

## Common problems

- `set -a` exports `password` to every child until it is unset.
- `curl --user "login:$(pass ...)"` leaks the password through `argv`.
- A temporary credential file is created before `chmod 600` or is left behind
  on interruption.
- `gpg` is hard-coded while the system only provides `gpg2`.
- The probe signs with the default key instead of decrypting the pass entry.
- `pass rm` uses an empty prefix because `-P` was rejected for delete.
- A generated account muttrc or imapnotify YAML is world-readable.

## References

- `bin/mw` (`checkbasics`, `askinfo`, `insertpass`, `getpass`, `getboxes`,
  `delete`, `cleanup`)
- `bin/mailsync` (GPG probe, environment reconstruction)
- `share/msmtp-temp`, `share/mbsync-temp`, `share/online-temp`,
  `share/imapnotify-temp`
- `mw.1`, `mailsync.1`, `README.md`
