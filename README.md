# mutt-wizard

https://muttwizard.com/

Get this great stuff without effort:

- A full-featured and autoconfigured email client on the terminal built with neomutt
- Mail stored offline enabling the ability to:
    * view and write emails while you're away from
      the internet
    * make backups
- Provides a `mailsync` script that can be scheduled to run as often as you
  like, which downloads/syncs mail and optionally notifies you when new mail has arrived.

Specifically, this wizard:

- Determines your email server's IMAP and SMTP servers and ports
- Creates dotfiles for `neomutt`, `isync`, and `msmtp` appropriate for your
  email address
- Encrypts and locally stores your password for easy remote access, accessible
  only by your GPG key
- Handles as many as nine separate email accounts automatically
- Auto-creates bindings to switch between accounts or between mailboxes
- Provides sensible defaults and an attractive appearance for the neomutt email
  client
- If mutt-wizard doesn't know your server's IMAP/SMTP info by default, it will
  prompt you for them and will put them in all the right places.

## Install

mutt-wizard runs on Linux, macOS and OpenBSD. All of its scripts are POSIX
`sh` and use no GNU-specific utilities, so no Bash or GNU coreutils are
required.

#### Dependencies

- `neomutt` - the email client. (If you are using Gentoo GNU/Linux, you will need the `sasl` use flag to be enabled)
- `curl` - tests connections (required at install).
- `isync` - downloads and syncs the mail (required if storing IMAP mail locally).
- `msmtp` - sends the email.
- `pass` - safely encrypts passwords (required at install).
- `gpg` (GnuPG) - used by `pass` to encrypt passwords (required).
- `envsubst` (from `gettext`) - writes config files (required).
- `ca-certificates` - required for SSL. Already in the OpenBSD base system as
  `/etc/ssl/cert.pem`; on Linux it is usually installed already.

**Note**: There's a chance of errors if you use a slow-release distro like
Ubuntu, Debian, or Mint. If you get errors in `neomutt`, install the most
recent version manually or manually remove the offending lines in the config in
`/usr/local/share/mutt-wizard/mutt-wizard.muttrc`.

```bash
git clone https://github.com/LukeSmithxyz/mutt-wizard
cd mutt-wizard
sudo make install # on OpenBSD: doas make install
```

The Makefile is portable between GNU make and BSD make, so `make` on
OpenBSD works as-is (no `gmake` needed).

A user of Arch-based distros can also install the current mutt-wizard release from the AUR as
[mutt-wizard](https://aur.archlinux.org/packages/mutt-wizard), or the Github master branch, [mutt-wizard-git](https://aur.archlinux.org/packages/mutt-wizard-git/).

### OpenBSD

OpenBSD is a supported platform. The scripts are plain POSIX `sh` and have
been audited against the OpenBSD base system: no `readlink -f`, no GNU
`sed -i`, no GNU grep extensions, no `pgrep -a`, no `setsid`, no
`/proc`, no systemd, and no hardcoded Linux paths. Ports-installed tools
live in `/usr/local/bin` and are located through `PATH` (and `command -v`),
which the `mailsync` script fixes up itself when running from cron.

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
- `gnupg` — security/gnupg (gpg; pulls in the gettext runtime that provides `envsubst`)
- `gettext` — devel/gettext (provides `envsubst`; already installed as a dependency of gnupg)
- CA certificates — part of the base system (`/etc/ssl/cert.pem`); no package needed

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

Scheduling mail syncing works with the base-system cron: `mw -t 30` adds a
crontab entry, `mw -t 30` again removes it. The generated job invokes
`/usr/local/bin/mailsync`, and the script re-establishes a sane `PATH`
itself, so no cron-specific environment setup is needed.

Known OpenBSD specifics:

- Desktop notifications rely on `notify-send` (libnotify) and a D-Bus
  session; without them `mailsync` silently skips notifications.
- `gpg-wks-client` is resolved at install time; OpenBSD's gnupg port
  installs it into `/usr/local/bin`, where it is found automatically.
- On OpenBSD, `/etc/ssl/cert.pem` is used as the certificate bundle for
  mbsync/msmtp instead of the various Linux paths.

**Compatibility status**: the OpenBSD compatibility work was developed and
verified through static analysis from Linux (POSIX conformance, the OpenBSD
man pages, and the OpenBSD ports tree), plus mocked platform tests. It has
*not* been executed on an actual OpenBSD system; OpenBSD-specific branches
are exercised in the test suite through a mocked `uname`.

### Optional Dependencies

- `goimapnotify` - required for push notifications.
  [Check here for reference](https://wiki.archlinux.org/title/Isync#With_imapnotify).
- `pam-gnupg` - Automatically logs you into your GPG key on login so you will
  never need to input your password once logged on to your system. Check the
  repo and directions out [here](https://github.com/cruegge/pam-gnupg).
  (Linux/PAM only.)
- `lynx` - view HTML email in neomutt.
- `notmuch` - index and search mail. Install it and run `notmuch setup`, tell
  it that your mail is in `~/.local/share/mail/` (although `mw` will do this
  automatically if you haven't set notmuch up before). You can run it in mutt
  with <kbd>ctrl-f</kbd>. Run `notmuch new` to process new mail.
- `abook` - a terminal-based address book. Pressing tab while typing an address
  to send mail to will suggest contacts that are in your abook.
- `urlview` - outputs urls in mail to browser.
- `cronie` - (or any other major cronjob manager) to set up automatic mail
  syncing. On OpenBSD the base-system cron is used.


## Usage

The mutt-wizard runs via the command `mw`. Once setup is complete, you'll use
`neomutt` to access your mail.

- `mw -a you@email.com` -- add a new email account
- `mw -l` -- list existing accounts
- `mw -d` -- choose an account to delete
- `mw -D your@email.com` -- delete account settings without confirmation
- `mw -t 30` -- toggle automatic mailsync to every 30 minutes
- `mw -T` -- toggle mailsync without specifying minutes (default is 10)
- `mw -r` -- reorder account shortcut numbers
- `pass edit mw-your@email.com` -- revise an account's password
- `mailsync` -- sync all configured email accounts. Also gives notifications of new mail and indexes new mail with notmuch silently.
- `mailsync your@email.com` -- sync a particular (or several) email account(s).

### Options usable when adding an account

#### Providing arguments

- `-u` -- Give an account username if different from the email address.
- `-n` -- A real name to be used by the account. Put in quotations if multiple
  words.
- `-i` -- IMAP server address
- `-I` -- IMAP server port (otherwise assumed to be 993)
- `-s` -- SMTP server address
- `-S` -- SMTP server port (otherwise assumed to be 465)
- `-m` -- Maximum number of emails to be kept offline. No maximum is default
  functionality.
- `-x` -- Account password. You will be prompted for it otherwise.

#### General Settings

- `-f` -- Assume mailbox names and force account configuration without
  connecting online at all.
- `-o` -- Configure mutt for an account, but do not keep mail offline.
- `-p` -- Use POP protocol instead of IMAP (requires `mpop` installed).
- `mailsync` gives visual messages of new mail by default. Or, set
  `MAILSYNC_MUTE=1` as an environmental variable if you prefer not having them.

## Neomutt user interface

To give you an example of the interface, here's an idea:

- <kbd>m</kbd> - send mail (uses your default `$EDITOR` to write)
- <kbd>j</kbd>/<kbd>k</kbd> and <kbd>d</kbd>/<kbd>u</kbd> - vim-like bindings to go down and up (or <kbd>d</kbd>/<kbd>u</kbd> to go
  down/up a page).
- <kbd>l</kbd> - open mail, or attachment page or attachment
- <kbd>h</kbd> - the opposite of <kbd>l</kbd>
- <kbd>r</kbd>/<kbd>R</kbd> - reply/reply all to highlighted mail
- <kbd>s</kbd> - save selected mail or selected attachment
- <kbd>gs</kbd>,<kbd>gi</kbd>,<kbd>ga</kbd>,<kbd>gd</kbd>,<kbd>gS</kbd> - Press <kbd>g</kbd> followed by another letter to change
  mailbox: <kbd>s</kbd>ent, <kbd>i</kbd>nbox, <kbd>a</kbd>rchive, <kbd>d</kbd>rafts, <kbd>S</kbd>pam, etc.
- <kbd>M</kbd> and <kbd>C</kbd> - For <kbd>M</kbd>ove and <kbd>C</kbd>opy: follow them with one of the mailbox
  letters above, i.e. <kbd>MS</kbd> means "move to Spam".
- <kbd>i#</kbd> - Press <kbd>i</kbd> followed by a number 1-9 to go to a different account. If you
  add 9 accounts via mutt-wizard, they will each be assigned a number.
- <kbd>a</kbd> to add address/person to abook and <kbd>Tab</kbd> while typing address to complete
  one from abook.
- <kbd>?</kbd> - see all keyboard shortcuts
- <kbd>ctrl-j</kbd>/<kbd>ctrl-k</kbd> - move up and down in sidebar, <kbd>ctrl-o</kbd> opens mailbox.
- <kbd>ctrl-b</kbd> - open a menu to select a URL you want to open in your browser.
- <kbd>p</kbd> - encrypt/sign your message (in compose view, before sending the email).

## Enable push notifications per mail
**Note**: Replace the `fulladdrs` with your actual email address. You have to do this for each new mail you want to setup instant notifications.
```bash
systemctl enable --user goimapnotify@fulladdrs.service
```
This systemd user-service method is Linux-only. On OpenBSD, run
`goimapnotify` from a session startup script (e.g. `~/.xsession`) instead;
`mw` generates the per-account configuration in
`~/.config/imapnotify/<address>.yaml` either way.

## Additional functionality

- `pam-gnupg` - Automatically logs you into your GPG key on login, so you will
  never need to input your password once logged on to your system. Check the
  repo and directions out [here](https://github.com/cruegge/pam-gnupg).
- `lynx` - View HTML email in neomutt.
- `notmuch` - Index and search mail. Install it and run `notmuch setup`, tell it
  that your mail is in `~/.local/share/mail/` (although `mw` will do this
  automatically if you haven't set notmuch up before). You can run it in mutt
  with <kbd>ctrl-f</kbd>. Run `notmuch new` to process new mail.
- `abook` - A terminal-based address book. Pressing tab while typing an address
  to send mail to will suggest contacts that are in your abook.
- `urlview` - Outputs URLs in an email to your browser.

## New stuff and improvements since the original release

- `mw` is now scriptable with command-line options and can run successfully
  without any interaction, making it possible to deploy in a script.
- `isync`/`mbsync` has replaced `offlineimap` as the backend. Offlineimap was
  error-prone, bloated, used obsolete Python 2 modules, and required separate
  steps to install the system.
- `mw` is now an installed program instead of just a script needed to be kept in
  your mutt folder.
- `dialog` is no longer used and the interface is simply text commands.
- More autogenerated shortcuts that allow quickly moving and copying mail
  between boxes.
- More elegant attachment handling. Image/video/pdf attachments without relying
  on the neomutt instance.
- abook integration by default.
- The messy template files and other directories have been moved or removed,
  leaving a clean config folder.
- msmtp configs moved to `~/.config/` and mail default location moved to
  `~/.local/share/mail/`, reducing mess in `~`.
- `pass` is used as a password manager instead of separately saving passwords.
- Script is POSIX sh compliant.
- Error handling for the many people who don't read or follow directions. Fewer
  errors generally.
- Addition of a manual `man mw`
- Now handles POP protocol via `mpop` for those who prefer it (add an account
  with the `-p` option). POP configs are still generated automatically.

## Testing

A static-analysis and mocked functional test suite ships in `tests/`:

```
make test
```

It verifies POSIX shell syntax (with `sh -n` and dash where available),
runs ShellCheck when installed, greps for a list of forbidden
bashisms/GNU/Linux-only constructs, exercises a full `make install` into a
sandboxed prefix, and then drives `mw`, `mailsync` and `openfile` end to
end using mocked external commands (`tests/fakebin`). OpenBSD and macOS
branches are exercised by mocking `uname` through `PATH`; no network, mail
accounts or root privileges are required.

## Help the Project!


- Try mutt-wizard out on weird machines and weird email addresses and report any
  errors.
- Open a PR to add new server information into `domains.csv` so their users can
  more easily use mutt-wizard.
- If nothing else, donate:
	- XMR: `8AzeWXhJvYJ1VeENHcNXCR1dLMgDALreZ1BdooZVjRKndv6myr3t1ue6C4ML2an5fWSpcP1sTDA9nKUMevkukDXG6chRjNv`
	- BTC: `bc1qacqfp36ffv9mafechmvk8f6r8qy4tual6rcm9p`

## Details for Tinkerers

- The critical `mutt`/`neomutt` files are in `~/.config/mutt/`.
- Put whatever global settings you want in `muttrc`. mutt-wizard will add some
  lines to this file, which you shouldn't remove unless you know what you're
  doing, but you can move them up/down over your config lines if you need to. If
  you get binding conflict errors in mutt, you might need to do this.
- Each of the accounts that mutt-wizard generates will have custom settings set
  in a separate file in `accounts/`. You can edit these freely if you want to
  tinker with settings specific to an account.
- In `/usr/local/share/mutt-wizard` (or `$PREFIX/share/mutt-wizard` if you
  installed with a custom prefix) are several global config files, including
  `mutt-wizard`'s default settings. You can override this in your `muttrc` if
  you wish.

## Watch out for these things

- Gmail accounts need to create an
  [App Password](https://support.google.com/accounts/answer/185833?hl=en) to
  use with  "less secure" applications. This password is single-use (i.e.
  for setup) and will be stored and encrypted locally. Enabling third-party
  applications requires turning off two-factor authentication and this will
  circumvent that. You might also need to manually "Enable IMAP" in the
  settings.
  To create an App Password for your Google account,
  you can directly visit the [App Passwords](https://myaccount.google.com/apppasswords) page in your Google Account settings.
- If you have a university email or enterprise-hosted email for work, there
  might be other hurdles or two-factor authentication you have to jump through.
  Some, for example, will want you to create a separate IMAP password, etc.
- `isync` is not fully UTF-8 compatible, so non-Latin characters may be garbled
  (although sync should succeed). `mw` will also not auto-create mailbox
  shortcuts since it is looking for English mailbox names. I strongly recommend
  you to set your email language to English on your mail server to avoid these
  problems.

## License

mutt-wizard is free/libre software. This program is released under the GPLv3
license, which you can find in the file [LICENSE](LICENSE).
