---
name: mailsync-and-scheduling
description: Use when changing mail synchronization, account discovery, new-mail detection, notifications, notmuch indexing, exit status, locking, or cron scheduling in mailsync or mw -t.
---

# mailsync and scheduling

## When to use

Use this skill for `bin/mailsync`, `mw -t`/`-T`, `mw -y`/`-Y`, the generated
crontab line, `~/.config/mutt/.mailsynclastrun`, notification code,
`notmuch new`, or the mailsync sections of `mailsync.1` and `README.md`.

## Preconditions

- Read `bin/mailsync` end to end, plus `bin/mw` (`togglecron`, `getprofiles`)
  and the mbsync/mpop templates.
- Know which account types are present: IMAP channels are discovered from
  `^Channel` lines in the mbsync config; POP accounts from `^account` lines in
  the mpop config.
- Never sync, delete, or send real mail. Use fake config files and a
  disposable `HOME` if a runtime check is explicitly authorized.

## Procedure

1. Preserve the split between sync status and presentation:
   - `syncandnotify` returns 1 only when `mbsync`/`mpop` fails;
   - missing tty, absent `notify-send`, a D-Bus failure, or `MAILSYNC_MUTE`
     must not mark the account as failed;
   - `wait` is the only place that increments the failure count.
2. Keep account selection exact:
   - no argument = all discovered accounts;
   - each requested address must match the account name exactly;
   - a missing account must be reported and must make the run exit nonzero;
   - do not rely on the exit status of a zero-iteration `for` loop.
3. Do not advance `lastrun` when any requested account failed. A partial
   failure must not hide that account's new mail from the next run.
4. Keep notification payloads safe: escape AppleScript strings, avoid shell
   evaluation, and stop subject extraction at the header/body separator.
   Disable pathname expansion when iterating over `find` results.
5. Keep the cron interaction safe:
   - only remove the exact generated command (`$PREFIX/bin/mailsync`);
   - do not overwrite the crontab when `crontab -l` fails for a reason other
     than "no crontab";
   - the job must work with a restricted cron `PATH`;
   - under cron, a locked GPG key makes the run exit before syncing.
6. Keep `mailsync` and `mw` using the same `MPOPRC`, `MBSYNCRC`, and XDG
   defaults.

## Validation

Static:

- `git diff --check`.
- Check every `return`/exit path in `syncandnotify`, the `wait` loop, and the
  final status.
- Check that `lastrun` is touched only when `failed` is zero.
- Check that `mailsync` uses `-c "$MBSYNCRC"` for mbsync and `-C "$MPOPRC"` for
  mpop.
- Check the crontab matcher against `mailsync-backup` and commented lines.

Runtime (only with explicit approval and fake data):

- Run `mailsync` with no accounts; it must exit nonzero without touching real
  mail.
- Run it with a fake account and a fake maildir; confirm the exit status and
  notification behavior with and without a tty.
- Run `mw -t`/`mw -T` with a disposable crontab; confirm only the exact line
  is added or removed.

## Common problems

- A function returns the status of its last `tty`/`notify` command, so normal
  cron runs are reported as failures and `notmuch`/`lastrun` are skipped.
- `MAILSYNC_MUTE=1` accidentally makes every account look failed.
- An empty account list suppresses the "not found" diagnostic.
- A partial failure still advances the global `lastrun`.
- The "already running" check covers only `mbsync`, not `mpop`, and prints to
  stdout where cron captures it.
- The crontab toggle deletes unrelated jobs whose text contains `mailsync`.
- `mpop` reads a different config than `mw` wrote because `MPOPRC` is ignored.
- The profile reader only accepts whitelisted `VAR=value` assignments and
  deliberately skips command substitution, separators, redirections and
  unbalanced quotes. `~/.pam_environment` is not shell syntax and is not
  parsed; put those settings in a shell profile.

## References

- `bin/mailsync`
- `bin/mw` (`togglecron`, `getprofiles`)
- `share/mbsync-temp`, `share/mpop-temp`
- `mailsync.1`, `README.md`
