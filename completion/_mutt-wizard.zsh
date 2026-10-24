#compdef mw

_mw_accounts() {
	local -a accounts
	accounts=(${(f)"$(mw -l 2>/dev/null | sed 's/^[[:space:]]*[0-9][0-9]*[[:space:]]*//')"})
	_describe 'account' accounts
}

_arguments -s -S \
	'-a[Add an email address]:email:' \
	'-l[List email addresses configured]' \
	'-d[Remove an already added address]' \
	'-D[Force remove account without confirmation]:email:_mw_accounts' \
	'-y[Sync mail for account by name (deprecated)]:email:_mw_accounts' \
	'-Y[Sync mail for all accounts (deprecated)]' \
	'-t[Toggle automatic mailsync every <number> minutes]:minutes:' \
	'-T[Toggle automatic mailsync every 10 minutes]' \
	'-r[Reorder account numbers]' \
	'-h[Display help]' \
	'-u[Account login name if not full address]:login:' \
	'-n[Real name to be on the email account]:name:' \
	'-i[IMAP/POP server address]:host:' \
	'-I[IMAP/POP server port]:port:' \
	'-s[SMTP server address]:host:' \
	'-S[SMTP server port]:port:' \
	'-x[Password for account (visible in the process list)]:password:' \
	'-P[Pass prefix (prefix of the password store entry)]:prefix:' \
	'-p[Add for a POP server instead of IMAP]' \
	'-o[Configure address, but keep mail online]' \
	'-f[Assume typical English mailboxes without attempting log-on]' \
	'-m[Maximum number of emails to be kept offline]:number:' \
	'-R[Use a proxy server for curl]:proxy:' \
	'-X[With -d/-D, delete the account'"'"'s local email too]'
