# Portable Makefile: works with both GNU make and BSD make (as found on
# OpenBSD and macOS), so `make install` behaves the same everywhere.

.POSIX:

PREFIX ?= /usr/local
MANPREFIX = $(PREFIX)/share/man

install:
	mkdir -p $(DESTDIR)$(PREFIX)/bin
	mkdir -p $(DESTDIR)$(PREFIX)/lib/mutt-wizard
	mkdir -p $(DESTDIR)$(PREFIX)/share/mutt-wizard
	cp -f bin/mailsync $(DESTDIR)$(PREFIX)/bin
	cp -f lib/openfile $(DESTDIR)$(PREFIX)/lib/mutt-wizard
	chmod 755 $(DESTDIR)$(PREFIX)/share/mutt-wizard
	for shared in share/*; do \
		cp -f $$shared $(DESTDIR)$(PREFIX)/share/mutt-wizard/; \
		chmod 644 $(DESTDIR)$(PREFIX)/share/mutt-wizard/$${shared##*/}; \
	done
	# Resolve the gpg-wks-client location at install time. OpenBSD's
	# gnupg port installs it into /usr/local/bin (i.e. on PATH); on most
	# Linux distributions it lives under libexec and is not on PATH.
	wks="$$(command -v gpg-wks-client 2>/dev/null || true)"; \
	if [ -z "$$wks" ]; then \
		for p in /usr/libexec/gpg-wks-client /usr/local/libexec/gnupg/gpg-wks-client /usr/lib/gnupg/gpg-wks-client; do \
			[ -x "$$p" ] && { wks="$$p"; break; }; \
		done; \
	fi; \
	[ -n "$$wks" ] || wks="gpg-wks-client"; \
	sed -e 's:/usr/local:$(PREFIX):g' -e "s|@WKS@|$$wks|" < share/mutt-wizard.muttrc > $(DESTDIR)$(PREFIX)/share/mutt-wizard/mutt-wizard.muttrc
	mkdir -p $(DESTDIR)$(MANPREFIX)/man1
	cp -f mailsync.1 $(DESTDIR)$(MANPREFIX)/man1/mailsync.1
	sed 's:/usr/local:$(PREFIX):g' < share/mailcap > $(DESTDIR)$(PREFIX)/share/mutt-wizard/mailcap
	sed 's:/usr/local:$(PREFIX):g' < bin/mw > $(DESTDIR)$(PREFIX)/bin/mw
	sed 's:/usr/local:$(PREFIX):g' < mw.1 > $(DESTDIR)$(MANPREFIX)/man1/mw.1
	chmod 644 $(DESTDIR)$(MANPREFIX)/man1/mw.1 $(DESTDIR)$(MANPREFIX)/man1/mailsync.1
	chmod 755 $(DESTDIR)$(PREFIX)/bin/mw $(DESTDIR)$(PREFIX)/bin/mailsync $(DESTDIR)$(PREFIX)/lib/mutt-wizard/openfile
	mkdir -p $(DESTDIR)$(PREFIX)/share/zsh/site-functions/
	chmod 755 $(DESTDIR)$(PREFIX)/share/zsh/site-functions/
	cp -f completion/_mutt-wizard.zsh $(DESTDIR)$(PREFIX)/share/zsh/site-functions/_mutt-wizard.zsh
	chmod 644 $(DESTDIR)$(PREFIX)/share/zsh/site-functions/_mutt-wizard.zsh

uninstall:
	rm -f $(DESTDIR)$(PREFIX)/bin/mw $(DESTDIR)$(PREFIX)/bin/mailsync $(DESTDIR)$(PREFIX)/lib/mutt-wizard/openfile
	rm -rf $(DESTDIR)$(PREFIX)/share/mutt-wizard  $(DESTDIR)$(PREFIX)/lib/mutt-wizard
	rm -f $(DESTDIR)$(MANPREFIX)/man1/mw.1  $(DESTDIR)$(MANPREFIX)/man1/mailsync.1
	rm -f $(DESTDIR)$(PREFIX)/share/zsh/site-functions/_mutt-wizard.zsh

test:
	sh tests/run_tests.sh

.PHONY: install uninstall test