# mutt-wizard

mutt-wizard is a POSIX `sh` program that provisions a fully-featured, autoconfigured terminal email client based on **neomutt**, with offline mail storage and automated synchronization. Contributions are welcome.

## What This Wizard Sets Up

- A fully-featured and autoconfigured terminal email client built on **neomutt**.
- Offline mail storage, which enables reading and writing email without an
  internet connection and simplifies backups.
- A `mailsync` script that can be scheduled to run as often as desired; it
  downloads and syncs mail and can optionally notify when new mail has arrived.

Specifically, mutt-wizard:

- Determines your email server's IMAP and SMTP servers and ports.
- Creates dotfiles for **neomutt**, **isync**, and **msmtp** appropriate for
  your email address.
- Encrypts and locally stores your password with **pass**, accessible only
  with your GPG key.
- Handles up to nine separate email accounts automatically.
- Auto-creates bindings to switch between accounts or between mailboxes.
- Provides sensible defaults and an attractive appearance for the neomutt
  email client.
- If mutt-wizard does not know your server's IMAP/SMTP details by default, it
  prompts for them and places them in the appropriate configuration files.

## Installation

mutt-wizard runs on Linux, macOS, and OpenBSD. All of its scripts are POSIX
`sh` and use no GNU-specific utilities, so no Bash or GNU coreutils are
required.

### Dependencies

- **neomutt** — the email client. (On Gentoo GNU/Linux, the `sasl` use flag
  must be enabled.)
- **curl** — tests connections (required at install).
- **isync** — downloads and syncs mail (required for storing IMAP mail
  locally).
- **msmtp** — sends email.
- **pass** — securely encrypts passwords (required at install).
- **gpg** (GnuPG) — used by `pass` to encrypt passwords (required).
- **envsubst** (from `gettext`) — writes configuration files (required).
- **ca-certificates** — required for SSL. Included in the OpenBSD base system
  as `/etc/ssl/cert.pem`; on Linux it is usually installed already.

**Note**: Slow-release distributions such as Ubuntu, Debian, or Mint may ship
an outdated `neomutt` that produces errors. If so, install the most recent
version manually or remove the offending lines in the configuration in
`/usr/local/share/mutt-wizard/mutt-wizard.muttrc`.

### From Source

```bash
git clone https://github.com/LukeSmithxyz/mutt-wizard
cd mutt-wizard
sudo make install # on OpenBSD: doas make install
```

The Makefile is portable between GNU make and BSD make, so `make` on OpenBSD
works as-is (no `gmake` needed).

### Arch Linux

Users of Arch-based distributions can install the current release from the
AUR as [mutt-wizard](https://aur.archlinux.org/packages/mutt-wizard), or the
GitHub master branch as
[mutt-wizard-git](https://aur.archlinux.org/packages/mutt-wizard-git/).

### OpenBSD

OpenBSD is a supported platform. The scripts are plain POSIX `sh` and have
been audited against the OpenBSD base system: no `readlink -f`, no GNU
`sed -i`, no GNU grep extensions, no `pgrep -a`, no `setsid`, no
`/proc`, no systemd, and no hardcoded Linux paths. Ports-installed tools
reside in `/usr/local/bin` and are located through `PATH` (and `command -v`),
which the `mailsync` script re-establishes itself when running from cron.

Installation:

```
doas pkg_add neomutt curl isync msmtp password-store gnupg gettext
doas make install
```

- `neomutt` — mail/neomutt
- `curl` — net/curl
- `isync` — mail/isync (mbsync)
- `msmtp` — mail/msmtp
- `password-store` — security/password-store (pass)
- `gnupg` — security/gnupg (gpg; pulls in the gettext runtime that provides
  `envsubst`)
- `gettext` — devel/gettext (provides `envsubst`; already installed as a
  dependency of gnupg)
- CA certificates — part of the base system (`/etc/ssl/cert.pem`); no package
  needed

Optional packages (all available in ports):

- `notmuch` — mail/notmuch — index and search mail.
- `mpop` — mail/mpop — POP3 support (`mw -p`).
- `abook` — mail/abook — address book integration.
- `urlview` — www/urlview — open URLs from mail.
- `lynx` — www/lynx — view HTML mail (w3m is another option: www/w3m).
- `mpv` — multimedia/mpv — play video/audio attachments.
- `libnotify` — x11/libnotify — desktop notifications from `mailsync`
  (optional; mail syncing works without it).
- `xdg-utils` — x11/xdg-utils — `xdg-open` for opening attachments
  (`gio open` and the `$OPENER` environment variable are honored as
  fallbacks).
- `goimapnotify` — mail/goimapnotify — push notifications (see below).

Mail syncing is scheduled with the base-system cron: `mw -t 30` adds a
crontab entry; running it again removes the entry. The generated job invokes
`/usr/local/bin/mailsync`, and the script re-establishes a sane `PATH`
itself, so no cron-specific environment setup is needed.

Known OpenBSD specifics:

- Desktop notifications rely on `notify-send` (libnotify) and a D-Bus
  session; without them `mailsync` silently skips notifications.
- `gpg-wks-client` is resolved at install time; OpenBSD's gnupg port
  installs it into `/usr/local/bin`, where it is found automatically.
- On OpenBSD, `/etc/ssl/cert.pem` is used as the certificate bundle for
  mbsync/msmtp instead of the various Linux paths.

### Optional Dependencies

- **goimapnotify** — required for push notifications. [See here for
  reference](https://wiki.archlinux.org/title/Isync#With_imapnotify).
- **pam-gnupg** — automatically unlocks your GPG key on login, so the
  password is never requested after logging in. See the repository and
  instructions [here](https://github.com/cruegge/pam-gnupg). (Linux/PAM
  only.)
- **lynx** — view HTML email in neomutt.
- **notmuch** — index and search mail. Install it and run `notmuch setup`,
  pointing it at `~/.local/share/mail/` (`mw` does this automatically if
  notmuch has not been set up previously). Run it in mutt with
  <kbd>ctrl-f</kbd>. Run `notmuch new` to process new mail.
- **abook** — a terminal-based address book. Pressing tab while typing a
  recipient's address suggests contacts from abook.
- **urlview** — opens URLs in mail with the browser.
- **cronie** — (or any other major cron daemon) to set up automatic mail
  syncing. On OpenBSD the base-system cron is used.

## Usage

mutt-wizard is invoked through the `mw` command. Once setup is complete,
mail is read with `neomutt`.

- `mw -a you@email.com` — add a new email account
- `mw -l` — list existing accounts
- `mw -d` — choose an account to delete
- `mw -D your@email.com` — delete account settings without confirmation
- `mw -t 30` — toggle automatic mailsync to every 30 minutes
- `mw -T` — toggle mailsync without specifying minutes (default is 10)
- `mw -r` — reorder account shortcut numbers
- `pass edit mw-your@email.com` — revise an account's password
- `mailsync` — sync all configured email accounts, notify of new mail, and
  silently index new mail with notmuch.
- `mailsync your@email.com` — sync a particular email account (or several).

### Options for Adding an Account

#### Account Arguments

- `-u` — account username, if different from the email address.
- `-n` — a real name to be used by the account. Put in quotations if multiple
  words.
- `-i` — IMAP server address
- `-I` — IMAP server port (otherwise assumed to be 993)
- `-s` — SMTP server address
- `-S` — SMTP server port (otherwise assumed to be 465)
- `-m` — maximum number of emails to be kept offline. No maximum is the
  default.
- `-x` — account password. You will be prompted for it otherwise.

#### General Settings

- `-f` — assume mailbox names and force account configuration without
  connecting online at all.
- `-o` — configure mutt for an account, but do not keep mail offline.
- `-p` — use POP protocol instead of IMAP (requires `mpop` installed).
- `mailsync` gives visual messages of new mail by default. Set
  `MAILSYNC_MUTE=1` as an environment variable to disable them.

## Neomutt User Interface

The default keybindings are as follows:

- <kbd>m</kbd> — send mail (uses your default `$EDITOR` to write)
- <kbd>j</kbd>/<kbd>k</kbd> and <kbd>d</kbd>/<kbd>u</kbd> — vim-like bindings
  to go down and up (or <kbd>d</kbd>/<kbd>u</kbd> to go down/up a page).
- <kbd>l</kbd> — open mail, or attachment page or attachment
- <kbd>h</kbd> — the opposite of <kbd>l</kbd>
- <kbd>r</kbd>/<kbd>R</kbd> — reply/reply all to highlighted mail
- <kbd>s</kbd> — save selected mail or selected attachment
- <kbd>gs</kbd>,<kbd>gi</kbd>,<kbd>ga</kbd>,<kbd>gd</kbd>,<kbd>gS</kbd> —
  press <kbd>g</kbd> followed by another letter to change mailbox:
  <kbd>s</kbd>ent, <kbd>i</kbd>nbox, <kbd>a</kbd>rchive, <kbd>d</kbd>rafts,
  <kbd>S</kbd>pam, etc.
- <kbd>M</kbd> and <kbd>C</kbd> — for <kbd>M</kbd>ove and <kbd>C</kbd>opy:
  follow them with one of the mailbox letters above, i.e. <kbd>MS</kbd> means
  "move to Spam".
- <kbd>i#</kbd> — press <kbd>i</kbd> followed by a number 1-9 to go to a
  different account. If 9 accounts are added via mutt-wizard, they will each
  be assigned a number.
- <kbd>a</kbd> to add address/person to abook and <kbd>Tab</kbd> while typing
  address to complete one from abook.
- <kbd>?</kbd> — see all keyboard shortcuts
- <kbd>ctrl-j</kbd>/<kbd>ctrl-k</kbd> — move up and down in sidebar,
  <kbd>ctrl-o</kbd> opens mailbox.
- <kbd>ctrl-b</kbd> — open a menu to select a URL you want to open in your
  browser.
- <kbd>p</kbd> — encrypt/sign your message (in compose view, before sending
  the email).

## Push Notifications

**Note**: Replace `fulladdrs` with your actual email address. Repeat this for
each account for which instant notifications are desired.

```bash
systemctl enable --user goimapnotify@fulladdrs.service
```

This systemd user-service method is Linux-only. On OpenBSD, run
`goimapnotify` from a session startup script (e.g. `~/.xsession`) instead;
`mw` generates the per-account configuration in
`~/.config/imapnotify/<address>.yaml` either way.

## Improvements Over the Original Release

- `mw` is now scriptable with command-line options and can run successfully
  without any interaction, making it possible to deploy in a script.
- `isync`/`mbsync` has replaced `offlineimap` as the backend. Offlineimap was
  error-prone, bloated, used obsolete Python 2 modules, and required separate
  steps to install the system.
- `mw` is now an installed program rather than a script that must be kept in
  the mutt directory.
- `dialog` is no longer used and the interface is simply text commands.
- More autogenerated shortcuts that allow quickly moving and copying mail
  between boxes.
- More elegant attachment handling of image/video/PDF attachments without
  relying on the neomutt instance.
- abook integration by default.
- The template files and other directories have been moved or removed,
  leaving a clean configuration directory.
- msmtp configuration moved to `~/.config/` and the default mail location
  moved to `~/.local/share/mail/`, reducing clutter in the home directory.
- `pass` is used as a password manager instead of separately saving
  passwords.
- Script is POSIX sh compliant.
- Improved error handling; fewer errors generally.
- Addition of a manual `man mw`.
- Now handles POP protocol via `mpop` for those who prefer it (add an account
  with the `-p` option). POP configs are still generated automatically.

## Testing

A static-analysis and mocked functional test suite is included in `tests/`:

```
make test
```

It verifies POSIX shell syntax (with `sh -n` and dash where available), runs
ShellCheck when installed, greps for a list of forbidden bashisms/GNU/Linux-
only constructs, exercises a full `make install` into a sandboxed prefix, and
then drives `mw`, `mailsync` and `openfile` end to end using mocked external
commands (`tests/fakebin`). OpenBSD and macOS branches are exercised by
mocking `uname` through `PATH`; no network, mail accounts or root privileges
are required.

## Contributing

- Test mutt-wizard on unusual machines and email setups and report any errors
  encountered.
- Open a PR to add new server information to `domains.csv` so that users of
  those providers can more easily use mutt-wizard.

## Configuration File Layout

- The critical `mutt`/`neomutt` files are in `~/.config/mutt/`.
- Put whatever global settings you want in `muttrc`. mutt-wizard will add
  some lines to this file, which you shouldn't remove unless you know what
  you're doing, but you can move them up/down over your config lines if you
  need to. If you get binding conflict errors in mutt, you might need to do
  this.
- Each of the accounts that mutt-wizard generates will have custom settings
  set in a separate file in `accounts/`. You can edit these freely if you
  want to tinker with settings specific to an account.
- In `/usr/local/share/mutt-wizard` (or `$PREFIX/share/mutt-wizard` if you
  installed with a custom prefix) are several global config files, including
  mutt-wizard's default settings. You can override this in your `muttrc` if
  you wish.

## Known Issues

- Gmail accounts need to create an
  [App Password](https://support.google.com/accounts/answer/185833?hl=en) to
  use with "less secure" applications. This password is single-use (i.e.
  for setup) and will be stored and encrypted locally. Enabling third-party
  applications requires turning off two-factor authentication and this will
  circumvent that. You might also need to manually "Enable IMAP" in the
  settings. To create an App Password for your Google account, you can
  directly visit the
  [App Passwords](https://myaccount.google.com/apppasswords) page in your
  Google Account settings.
- If you have a university email or enterprise-hosted email for work, there
  may be additional hurdles, such as two-factor authentication or the need to
  create a separate IMAP password.
- `isync` is not fully UTF-8 compatible, so non-Latin characters may be
  garbled (although sync should succeed). `mw` will also not auto-create
  mailbox shortcuts since it is looking for English mailbox names. It is
  strongly recommended to set the mailbox language to English on your mail
  server to avoid these problems.

## License

mutt-wizard is free/libre software. This program is released under the GPLv3
license, which you can find in the file [LICENSE](LICENSE).
