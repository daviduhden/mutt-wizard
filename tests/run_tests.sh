#!/bin/sh
# mutt-wizard test suite.
#
# These tests verify portability statically (shell syntax, forbidden
# GNU/Linux-only constructs) and functionally, using mocked external
# commands (tests/fakebin) so that no network access, real mail accounts,
# real passwords or root privileges are needed. Platform detection is
# mocked by overriding `uname` through PATH (MW_TEST_OS), so OpenBSD and
# macOS branches can be exercised from Linux without modifying the host.

set -u

ROOT="$(CDPATH= cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d "${TMPDIR:-/tmp}/mw-tests.XXXXXX")" || exit 1
trap 'rm -rf "$TMP"' EXIT HUP INT TERM

FAKEBIN="$ROOT/tests/fakebin"
PREFIX="$TMP/usr/local"
BASE_PATH="$FAKEBIN:/usr/bin:/bin"

PASS=0
FAIL=0
FAILED=""

ok() {
	PASS=$((PASS + 1))
	printf 'ok   - %s\n' "$1"
}

bad() {
	FAIL=$((FAIL + 1))
	FAILED="$FAILED
	- $1"
	printf 'FAIL - %s\n' "$1"
}

# expect DESC cmd args...   (runs cmd, counts pass/fail)
expect() {
	desc="$1"
	shift
	if "$@"; then
		ok "$desc"
	else
		bad "$desc"
	fi
}

# expect_file DESC FILE REGEX
expect_file() {
	expect "$1" grep -q "$3" "$2"
}

# expect_no_file DESC FILE REGEX
expect_no_file() {
	desc="$1"
	if grep -q "$3" "$2" 2>/dev/null; then
		bad "$desc"
	else
		ok "$desc"
	fi
}

# A clean, sanitized environment for running the scripts under test.
# run_env HOME cmd args...
# Unsets common XDG/user variables so tests are hermetic. Test knobs
# (MW_TEST_*, MAILSYNC_MUTE, NOTIFY_LOG, OPENED_LOG, OPENER, EDITOR) are
# passed through as shell-level prefix assignments, e.g.:
#     MW_TEST_OS=OpenBSD mailsync "$H" account@example.com
run_env() {
	home="$1"
	shift
	env \
		-u XDG_CONFIG_HOME -u XDG_DATA_HOME -u XDG_CACHE_HOME -u XDG_STATE_HOME \
		-u XDG_RUNTIME_DIR -u PASSWORD_STORE_DIR -u MBSYNCRC -u MPOPRC \
		-u NOTMUCH_CONFIG -u DBUS_SESSION_BUS_ADDRESS \
		HOME="$home" PATH="$BASE_PATH" "$@"
}

# mw home args... — runs the installed mw in a fresh environment
mw() {
	home="$1"
	shift
	run_env "$home" "$PREFIX/bin/mw" "$@"
}

# mailsync home args...
mailsync() {
	home="$1"
	shift
	run_env "$home" "$PREFIX/bin/mailsync" "$@"
}

# openfile home args...
openfile() {
	home="$1"
	shift
	run_env "$home" "$PREFIX/lib/mutt-wizard/openfile" "$@"
}

# expect_status DESC EXPECTED cmd args... — assert exit status
expect_status() {
	desc="$1"
	want="$2"
	shift 2
	"$@" >"$TMP/cap.out" 2>"$TMP/cap.err"
	rc=$?
	if [ "$rc" -eq "$want" ]; then
		ok "$desc"
	else
		bad "$desc (expected $want, got $rc)"
		sed 's/^/     | /' "$TMP/cap.err" | head -10
	fi
}

# Prepare a home directory with an initialized (mock) pass store.
mkhome() {
	h="$1"
	mkdir -p "$h/.password-store"
	: > "$h/.password-store/.gpg-id"
	printf '%s\n' "$h"
}

section() {
	printf '\n== %s\n' "$1"
}

############################################################
section "Static checks: shell syntax"
############################################################

expect "bin/mw parses as POSIX sh" sh -n "$ROOT/bin/mw"
expect "bin/mailsync parses as POSIX sh" sh -n "$ROOT/bin/mailsync"
expect "lib/openfile parses as POSIX sh" sh -n "$ROOT/lib/openfile"
if command -v dash >/dev/null 2>&1; then
	expect "bin/mw parses with dash" dash -n "$ROOT/bin/mw"
	expect "bin/mailsync parses with dash" dash -n "$ROOT/bin/mailsync"
	expect "lib/openfile parses with dash" dash -n "$ROOT/lib/openfile"
fi

############################################################
section "Static checks: no bashisms / GNU-only constructs"
############################################################

check_forbidden() {
	# check_forbidden DESC REGEX FILE...
	desc="$1"
	pat="$2"
	shift 2
	# Skip comment lines (they cannot contain executable constructs);
	# '#!' shebang lines are exempted and checked separately.
	if grep -vE '^[[:space:]]*#[^!]' "$@" | grep -nE "$pat" > "$TMP/forbidden" 2>/dev/null; then
		bad "$desc"
		sed 's/^/     | /' "$TMP/forbidden"
	else
		ok "$desc"
	fi
}

SHELL_FILES="$ROOT/bin/mw $ROOT/bin/mailsync $ROOT/lib/openfile"
TEMPLATE_FILES="$ROOT/Makefile $ROOT/share/mailcap $ROOT/share/mbsync-temp $ROOT/share/msmtp-temp $ROOT/share/mpop-temp $ROOT/share/mutt-temp $ROOT/share/online-temp $ROOT/share/notmuch-temp $ROOT/share/imapnotify-temp $ROOT/share/mutt-wizard.muttrc $ROOT/share/switch.muttrc"

check_forbidden "no bash shebangs" '^#!.*(bash|zsh)' $SHELL_FILES
check_forbidden "no [[ test operator" '\[\[ ' $SHELL_FILES
check_forbidden "no &> redirect" '&>' $SHELL_FILES
check_forbidden "no source builtin" '^[[:space:]]*source[[:space:]]' $SHELL_FILES
check_forbidden "no function keyword" '^function[[:space:]]' $SHELL_FILES
check_forbidden 'no ${var/repl} expansion' '\$\{[A-Za-z_][A-Za-z0-9_]*(\[|//|/|\^|,,)' $SHELL_FILES
check_forbidden "no readarray/mapfile/shopt" 'readarray|mapfile|shopt' $SHELL_FILES
check_forbidden "no read -p" 'read[[:space:]]+-[a-z]*p' $SHELL_FILES
check_forbidden "no declare/local assignments" '(^|[;[:space:]])declare[[:space:]]+-[aA]|(^|[;[:space:]])local[[:space:]]+[A-Za-z_][A-Za-z0-9_]*=' $SHELL_FILES
check_forbidden "no readlink" 'readlink[[:space:]]' $SHELL_FILES
check_forbidden "no realpath" 'realpath[[:space:]]' $SHELL_FILES
check_forbidden "no sed -i" 'sed[[:space:]]+-i($|[[:space:]])' $SHELL_FILES
check_forbidden "no grep -P" 'grep[[:space:]]+-P' $SHELL_FILES
check_forbidden "no xargs -r" 'xargs[[:space:]]+-r' $SHELL_FILES
check_forbidden "no find -printf" 'find[[:space:]].*-printf' $SHELL_FILES
check_forbidden "no stat -c" 'stat[[:space:]]+-c' $SHELL_FILES
check_forbidden "no date -d" 'date[[:space:]]+-d' $SHELL_FILES
check_forbidden "no sort -V" 'sort[[:space:]]+-V' $SHELL_FILES
check_forbidden "no getent" 'getent[[:space:]]' $SHELL_FILES
check_forbidden "no systemd tools" 'systemctl|loginctl|hostnamectl' $SHELL_FILES
check_forbidden "no setsid" 'setsid[[:space:]]' $SHELL_FILES
check_forbidden "no /proc or /sys usage" '/proc/|/sys/' $SHELL_FILES
# Package-manager names inside echo strings are fine (user guidance); only
# flag lines that could actually execute them.
if grep -vE 'echo[[:space:]]' $SHELL_FILES | grep -nE '(apt-get|apt|pacman|dnf|yum|brew)[[:space:]]' > "$TMP/forbidden" 2>/dev/null; then
	bad "no package manager calls"
	sed 's/^/     | /' "$TMP/forbidden"
else
	ok "no package manager calls"
fi
check_forbidden "no bare mktemp (template required)" 'mktemp[[:space:]]*\)' $SHELL_FILES
check_forbidden "no pgrep -a (Linux-only flag)" 'pgrep[[:space:]]+-a' $SHELL_FILES
check_forbidden "no hardcoded /usr/bin paths" '/usr/bin/(neomutt|msmtp|mbsync|mpop|pass|notmuch)' $SHELL_FILES
check_forbidden "no echo -e/-n/-E" 'echo[[:space:]]+-[eEnN]' $SHELL_FILES
check_forbidden "no \$RANDOM" '\$RANDOM' $SHELL_FILES
check_forbidden "no pushd/popd" 'pushd|popd' $SHELL_FILES
if grep -vE '^[[:space:]]*#' $SHELL_FILES | grep -nF '\|' > "$TMP/forbidden" 2>/dev/null; then
	bad "no GNU BRE alternation (\|) in patterns"
	sed 's/^/     | /' "$TMP/forbidden"
else
	ok "no GNU BRE alternation (\|) in patterns"
fi
if grep -nF '\s' $SHELL_FILES > "$TMP/forbidden" 2>/dev/null; then
	bad "no \s shorthand in patterns"
	sed 's/^/     | /' "$TMP/forbidden"
else
	ok "no \s shorthand in patterns"
fi
if grep -nF '\S' $SHELL_FILES > "$TMP/forbidden" 2>/dev/null; then
	bad "no \S shorthand in patterns"
	sed 's/^/     | /' "$TMP/forbidden"
else
	ok "no \S shorthand in patterns"
fi

# Templates are consumed by envsubst into neomutt/isync/msmtp/mpop configs;
# only non-shell platform assumptions apply there.
check_forbidden "no setsid in templates" 'setsid[[:space:]]' $TEMPLATE_FILES
check_forbidden "no hardcoded /usr/bin paths in templates" '/usr/bin/(neomutt|msmtp|mbsync|mpop|pass|notmuch)' $TEMPLATE_FILES
check_forbidden "no systemd tools in templates" 'systemctl|loginctl|hostnamectl' $TEMPLATE_FILES

if command -v shellcheck >/dev/null 2>&1; then
	section "Static checks: shellcheck"
	expect "shellcheck bin/mw (POSIX)" sh -c 'shellcheck -s sh -e SC2034,SC2016 "$1" >/dev/null 2>&1' x "$ROOT/bin/mw"
	expect "shellcheck bin/mailsync (POSIX)" sh -c 'shellcheck -s sh -e SC2086,SC2194,SC2155 "$1" >/dev/null 2>&1' x "$ROOT/bin/mailsync"
	expect "shellcheck lib/openfile (POSIX)" sh -c 'shellcheck -s sh "$1" >/dev/null 2>&1' x "$ROOT/lib/openfile"
fi

############################################################
section "Install via Makefile"
############################################################

expect "make install into test prefix" make -C "$ROOT" install PREFIX="$PREFIX" >/dev/null 2>&1
expect "installed bin/mw exists" test -x "$PREFIX/bin/mw"
expect "installed bin/mailsync exists" test -x "$PREFIX/bin/mailsync"
expect "installed lib/mutt-wizard/openfile exists" test -x "$PREFIX/lib/mutt-wizard/openfile"
expect "installed share/mutt-wizard templates exist" test -f "$PREFIX/share/mutt-wizard/mbsync-temp"
expect "installed man pages exist" test -f "$PREFIX/share/man/man1/mw.1"
expect "installed zsh completion exists" test -f "$PREFIX/share/zsh/site-functions/_mutt-wizard.zsh"
expect_file "prefix substituted in installed mw" "$PREFIX/bin/mw" "^prefix=\"$PREFIX\""
expect_no_file "no @WKS@ marker left in installed muttrc" "$PREFIX/share/mutt-wizard/mutt-wizard.muttrc" '@WKS@'
expect_file "gpg-wks-client resolved in installed muttrc" "$PREFIX/share/mutt-wizard/mutt-wizard.muttrc" 'gpg-wks-client'
expect_file "prefix substituted in installed muttrc" "$PREFIX/share/mutt-wizard/mutt-wizard.muttrc" "$PREFIX/share/mutt-wizard/mailcap"
expect_file "prefix substituted in installed mailcap" "$PREFIX/share/mutt-wizard/mailcap" "$PREFIX/lib/mutt-wizard/openfile"
expect "installed files carry expected permissions" test "$(ls -l "$PREFIX/bin/mw" | cut -c4)" = "x"

############################################################
section "mw: adding accounts"
############################################################

H1=$(mkhome "$TMP/h1")

expect_status "mw -h shows help and exits nonzero" 1 mw "$H1" -h
expect_status "mw -l with no accounts fails" 1 mw "$H1" -l

expect "mw adds an IMAP account" \
	mw "$H1" -a user@example.com -f -x s3cret -i mail.example.com -s smtp.example.com

ACC="$H1/.config/mutt/accounts/user@example.com.muttrc"
MUTTRC="$H1/.config/mutt/muttrc"
expect "account muttrc created" test -f "$ACC"
expect_file "account muttrc has from address" "$ACC" 'set from = "user@example.com"'
expect_file "account muttrc has mailboxes" "$ACC" 'mailboxes "=INBOX"'
expect_file "account muttrc sources switch.muttrc" "$ACC" "$PREFIX/share/mutt-wizard/switch.muttrc"
expect_file "muttrc sources shared settings" "$MUTTRC" "source $PREFIX/share/mutt-wizard/mutt-wizard.muttrc"
expect_file "muttrc sources account file" "$MUTTRC" "source $H1/.config/mutt/accounts/user@example.com.muttrc"
expect_file "muttrc has switch macro i1" "$MUTTRC" 'macro index,pager i1'
expect_file "muttrc sets lmdb header cache" "$MUTTRC" 'set header_cache_backend = "lmdb"'
expect_file "mbsyncrc has channel" "$H1/.mbsyncrc" '^Channel user@example.com$'
expect_file "mbsyncrc uses Far/Near for mbsync 1.4.4" "$H1/.mbsyncrc" '^Far :user@example.com-remote:$'
expect_file "mbsyncrc quotes the maildir path" "$H1/.mbsyncrc" '^Path "/.*/h1/.local/share/mail/user@example.com/"$'
expect_file "msmtp config has account" "$H1/.config/msmtp/config" '^account user@example.com$'
expect_file "msmtp config uses passwordeval" "$H1/.config/msmtp/config" '^passwordeval "pass user@example.com"$'
expect_file "msmtp config quotes logfile" "$H1/.config/msmtp/config" '^logfile ".*/msmtp.log"$'
expect "password stored via pass" test "$(cat "$H1/.password-store/user@example.com.gpg")" = "s3cret"
expect "maildir directories created" test -d "$H1/.local/share/mail/user@example.com/INBOX/cur"
expect "header cache directory created" test -d "$H1/.cache/mutt-wizard/user_example.com/bodies"
expect "notmuch config created" test -f "$H1/.notmuch-config"
expect "imapnotify config created" test -f "$H1/.config/imapnotify/user@example.com.yaml"
expect "urlview config created" test -f "$H1/.urlview"
expect "config files are not group/world readable" sh -c 'stat -c "%a" "$1" | grep -qE "^[67]00$"' x "$MUTTRC"

mw "$H1" -l > "$TMP/cap.out" 2>/dev/null
expect "mw lists the added account" grep -q user@example.com "$TMP/cap.out"
expect "second account gets number i2" \
	mw "$H1" -a second@example.com -f -x s3cret -i mail2.example.com -s smtp.example.com
expect_file "muttrc has switch macro i2" "$MUTTRC" 'macro index,pager i2'

expect_status "mw refuses duplicate account" 1 \
	mw "$H1" -a user@example.com -f -x s3cret -i m -s s

############################################################
section "mw: old mbsync versions get Master/Slave"
############################################################

H2=$(mkhome "$TMP/h2")
MW_MBSYNC_VERSION="mbsync 1.3.6" expect "mw adds account with mbsync 1.3.6" \
	mw "$H2" -a old@example.com -f -x p -i i.example.com -s s.example.com
expect_file "mbsyncrc uses Master/Slave for mbsync 1.3.6" "$H2/.mbsyncrc" '^Master :old@example.com-remote:$'

############################################################
section "mw: POP and online accounts"
############################################################

H3=$(mkhome "$TMP/h3")
expect "mw adds a POP account" \
	mw "$H3" -a pop@example.com -f -p -x p -i pop.example.com -s smtp.example.com
expect_file "mpoprc has POP account" "$H3/.config/mpop/config" '^account pop@example.com$'
expect_file "mpoprc quotes the delivery path" "$H3/.config/mpop/config" '^delivery maildir "/.*/pop@example.com/INBOX"$'
expect "no mbsync channel for POP account" test ! -s "$H3/.mbsyncrc"

H4=$(mkhome "$TMP/h4")
expect "mw adds an online-only account" \
	mw "$H4" -a online@example.com -f -o -x p -i imap.example.com -s smtp.example.com
expect "no mbsyncrc for online account" test ! -f "$H4/.mbsyncrc"
expect_file "online account keeps mail on the server" "$H4/.config/mutt/accounts/online@example.com.muttrc" 'set imap_user = "online@example.com"'
expect_file "online account has imaps folder" "$H4/.config/mutt/accounts/online@example.com.muttrc" 'set folder = "imaps://online@example.com@imap.example.com:993"'

############################################################
section "mw: mailbox discovery through curl"
############################################################

H5=$(mkhome "$TMP/h5")
expect "mw adds account using curl for mailbox discovery" \
	mw "$H5" -a curl@example.com -x p -i imap.example.com -s smtp.example.com
expect_file "discovered mailboxes in account muttrc" "$H5/.config/mutt/accounts/curl@example.com.muttrc" '"=INBOX"'
expect_file "Junk mailbox configured" "$H5/.config/mutt/accounts/curl@example.com.muttrc" '"=Junk"'
expect "discovered mailbox directory created" test -d "$H5/.local/share/mail/curl@example.com/Junk/cur"

############################################################
section "mw: paths containing spaces"
############################################################

H6=$(mkhome "$TMP/My Home")
expect "mw adds account with spaces in HOME" \
	mw "$H6" -a spaced@example.com -f -x p -i i.example.com -s s.example.com
expect_file "mbsyncrc quotes spaced maildir path" "$H6/.mbsyncrc" '^Path "/.*/My Home/.local/share/mail/spaced@example.com/"$'
expect_file "msmtp config quotes spaced logfile" "$H6/.config/msmtp/config" '^logfile "/.*/My Home/.*msmtp.log"$'

############################################################
section "mw: missing envsubst is reported"
############################################################

H7=$(mkhome "$TMP/h7")
# A PATH containing every fake except envsubst and a minimal /bin shim
# without the host's real envsubst, to test the dependency check. The
# system directories cannot be used directly because many distributions
# (including Fedora) ship envsubst in /usr/bin.
mkdir -p "$TMP/fakebin-noenv" "$TMP/sysbin"
for f in "$FAKEBIN"/*; do
	[ "$(basename "$f")" = "envsubst" ] || ln -s "$f" "$TMP/fakebin-noenv/$(basename "$f")"
done
for c in sh grep sed awk cat mkdir rm mv cp find cut tr head sort nl paste basename dirname wc xargs mktemp; do
	loc="$(command -v "$c" 2>/dev/null || true)"
	[ -n "$loc" ] && ln -s "$loc" "$TMP/sysbin/$c"
done
env -u XDG_CONFIG_HOME -u XDG_DATA_HOME -u XDG_CACHE_HOME -u XDG_STATE_HOME \
	-u PASSWORD_STORE_DIR -u MBSYNCRC -u MPOPRC -u NOTMUCH_CONFIG \
	HOME="$H7" PATH="$TMP/fakebin-noenv:$TMP/sysbin" \
	"$PREFIX/bin/mw" -a noenv@example.com -f -x p -i i -s s \
	>"$TMP/cap.out" 2>"$TMP/cap.err"
rc=$?
expect "mw reports missing envsubst" sh -c 'test "$1" -ne 0 && grep -q envsubst "$2"' x "$rc" "$TMP/cap.err"

############################################################
section "mw: deleting accounts"
############################################################

H8=$(mkhome "$TMP/h8")
mw "$H8" -a del@example.com -f -x p -i i.example.com -s s.example.com >/dev/null 2>&1
mw "$H8" -a keep@example.com -f -x p -i i.example.com -s s.example.com >/dev/null 2>&1
expect "mw -D removes an account" mw "$H8" -D del@example.com
expect "account muttrc removed" test ! -f "$H8/.config/mutt/accounts/del@example.com.muttrc"
expect "other account untouched" test -f "$H8/.config/mutt/accounts/keep@example.com.muttrc"
expect_no_file "mbsyncrc channel removed" "$H8/.mbsyncrc" 'del@example.com'
expect_file "mbsyncrc keeps other channel" "$H8/.mbsyncrc" '^Channel keep@example.com$'
expect_no_file "msmtp account block removed" "$H8/.config/msmtp/config" '^account del@example.com$'
expect_file "msmtp keeps other account" "$H8/.config/msmtp/config" '^account keep@example.com$'
expect_no_file "muttrc macro removed" "$H8/.config/mutt/muttrc" 'del@example.com'
expect "password removed" test ! -f "$H8/.password-store/del@example.com.gpg"

############################################################
section "mw: cron toggle"
############################################################

H9=$(mkhome "$TMP/h9")
expect "mw -t 15 adds a cron job" mw "$H9" -t 15
expect_file "cron job uses installed mailsync" "$H9/.crontab" "\*/15 \* \* \* \* $PREFIX/bin/mailsync"
expect "mw -t 15 removes the cron job again" mw "$H9" -t 15
expect_no_file "cron job removed from crontab" "$H9/.crontab" 'mailsync'

############################################################
section "mw: reordering accounts"
############################################################

H10=$(mkhome "$TMP/h10")
mw "$H10" -a one@example.com -f -x p -i i1.example.com -s s1.example.com >/dev/null 2>&1
mw "$H10" -a two@example.com -f -x p -i i2.example.com -s s2.example.com >/dev/null 2>&1
mkdir -p "$TMP/mwtmp"
EDITOR=/bin/true TMPDIR="$TMP/mwtmp" expect "mw -r reorders accounts" mw "$H10" -r
expect_file "muttrc regenerated with i1 macro" "$H10/.config/mutt/muttrc" 'macro index,pager i1'
expect_file "muttrc regenerated with i2 macro" "$H10/.config/mutt/muttrc" 'macro index,pager i2'
expect_file "default account sourced first" "$H10/.config/mutt/muttrc" "source $H10/.config/mutt/accounts/one@example.com.muttrc"
expect_file "all accounts still sourced" "$H10/.config/mutt/muttrc" 'two@example.com.muttrc'
expect "reorder tempfile cleaned up" sh -c 'test -z "$(ls -A "$1" 2>/dev/null)"' x "$TMP/mwtmp"

############################################################
section "mailsync: syncing and notifications"
############################################################

H11=$(mkhome "$TMP/h11")
cat > "$H11/.mbsyncrc" <<'EOF'
Channel imap@example.com
EOF
mkdir -p "$H11/.config/mpop"
cat > "$H11/.config/mpop/config" <<'EOF'
account pop@example.com
host pop.example.com
EOF
NOTIFY_LOG="$H11/notify.log"

MAILSYNC_MUTE=1 NOTIFY_LOG="$NOTIFY_LOG" expect "mailsync syncs a single account (muted)" \
	mailsync "$H11" imap@example.com </dev/null
expect "lastrun timestamp created" test -f "$H11/.config/mutt/.mailsynclastrun"
expect "notmuch indexed mail" grep -q 'notmuch new --quiet' "$H11/notmuch.log"
expect "no notifications when muted" test ! -f "$NOTIFY_LOG"

NOTIFY_LOG="$NOTIFY_LOG" expect "mailsync notifies about new mail" \
	mailsync "$H11" imap@example.com </dev/null
expect_file "notification mentions the account" "$NOTIFY_LOG" 'imap@example.com'
expect_file "notification contains the subject" "$NOTIFY_LOG" 'Hello imap@example.com'

NOTIFY_LOG="$NOTIFY_LOG" expect "mailsync syncs a POP account" \
	mailsync "$H11" pop@example.com </dev/null
expect_file "POP mail detected" "$NOTIFY_LOG" 'POP hello pop@example.com'

expect_status "mailsync fails for unknown account" 1 mailsync "$H11" nope@example.com </dev/null

H12=$(mkhome "$TMP/h12")
cat > "$H12/.mbsyncrc" <<'EOF'
Channel locked@example.com
EOF
MW_TEST_GPG_FAIL=1 expect_status "mailsync bails out when GPG is locked" 1 \
	mailsync "$H12" locked@example.com </dev/null
expect "no sync happened with locked GPG" sh -c '! find "$1/.local/share/mail" -type f 2>/dev/null | grep -q .' x "$H12"

############################################################
section "mailsync: XDG_DATA_HOME from .profile"
############################################################

H13=$(mkhome "$TMP/h13")
cat > "$H13/.mbsyncrc" <<'EOF'
Channel xdg@example.com
EOF
printf 'export XDG_DATA_HOME=%s/maildata\n' "$H13" > "$H13/.profile"
NOTIFY_LOG="$H13/notify.log"
NOTIFY_LOG="$NOTIFY_LOG" expect "mailsync honors XDG_DATA_HOME from .profile" \
	mailsync "$H13" xdg@example.com </dev/null
expect "mail created under XDG_DATA_HOME" test -d "$H13/maildata/mail/xdg@example.com/INBOX/new"

############################################################
section "mailsync: simulated OpenBSD"
############################################################

H14=$(mkhome "$TMP/h14")
cat > "$H14/.mbsyncrc" <<'EOF'
Channel bsd@example.com
EOF
NOTIFY_LOG="$H14/notify.log"
MW_TEST_OS=OpenBSD expect "mailsync runs under simulated OpenBSD" \
	mailsync "$H14" bsd@example.com </dev/null
# The first run never notifies (the lastrun stamp does not exist yet);
# run again to exercise the notification path under OpenBSD.
MW_TEST_OS=OpenBSD NOTIFY_LOG="$NOTIFY_LOG" expect "mailsync notifies under simulated OpenBSD" \
	mailsync "$H14" bsd@example.com </dev/null
expect_file "OpenBSD notification delivered via notify-send" "$NOTIFY_LOG" 'bsd@example.com'
expect "mail downloaded under simulated OpenBSD" sh -c 'ls "$1"/.local/share/mail/bsd@example.com/INBOX/new/testmail-* >/dev/null 2>&1' x "$H14"

############################################################
section "openfile"
############################################################

H15=$(mkhome "$TMP/h15")
printf 'hello\n' > "$TMP/attach file.txt"
OPENED_LOG="$H15/opened.log"
OPENED_LOG="$OPENED_LOG" expect "openfile copies and opens a file (Linux)" \
	openfile "$H15" "$TMP/attach file.txt"
expect "file copied into cache" test -f "$H15/.cache/mutt-wizard/files/attach file.txt"
# openfile detaches the opener into the background, so poll for the log.
i=0
while [ ! -s "$OPENED_LOG" ] && [ "$i" -lt 10 ]; do
	sleep 1
	i=$((i + 1))
done
expect_file "xdg-open invoked with cached file" "$OPENED_LOG" 'attach file.txt'

MW_TEST_OS=Darwin OPENED_LOG="$OPENED_LOG" expect "openfile uses macOS open on Darwin" \
	openfile "$H15" "$TMP/attach file.txt"
i=0
while [ "$(wc -l < "$OPENED_LOG" 2>/dev/null || echo 0)" -lt 2 ] && [ "$i" -lt 10 ]; do
	sleep 1
	i=$((i + 1))
done
expect_file "macOS open recorded" "$OPENED_LOG" 'attach file.txt'

OPENER=/bin/true expect "openfile honors \$OPENER" \
	openfile "$H15" "$TMP/attach file.txt"

############################################################
section "Makefile: uninstall"
############################################################

expect "make uninstall from test prefix" make -C "$ROOT" uninstall PREFIX="$PREFIX" >/dev/null 2>&1
expect "installed files removed" test ! -e "$PREFIX/bin/mw"
expect "installed share removed" test ! -e "$PREFIX/share/mutt-wizard"

############################################################
printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
if [ "$FAIL" -gt 0 ]; then
	printf 'Failed tests:%s\n' "$FAILED"
	exit 1
fi
exit 0
