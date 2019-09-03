#!/bin/sh

# THE SETUP

# - Mail will be stored in non-retarded Maildirs because it's $currentyear. This makes it easier for use with isync, which is what I care about so I can have an offline repo of mail.
# - Mail boxes will be sensible: Inbox, Sent, Drafts, Archive, Junk, Trash
# - Use the typical unix login system for mail users. Users will log into their email with their passnames on the server. No usage of a redundant mySQL database to do this.


# BEFORE YOU RUN THIS
# - Have a Debian system with a static IP and all that. Pretty much any default VPS offered by a company will have all the basic stuff you need. This script might run on Ubuntu as well. Haven't tried it.
# - Have a Let's Encrypt SSL certificate for $maildomain. You might need one for $domain as well, but they're free with Let's Encypt so you should have them anyway.
# - If you've been toying around with your server settings trying to get postfix/dovecot/etc. working before running this, I recommend you `apt purge` everything first because this script is build on top of only the defaults. Clearr out /etc/postfix and /etc/dovecot yourself if needbe.


# On installation of Postfix, select "Internet Site" and put in TLD (without before it mail.)

echo "Installing programs..."
apt install postfix dovecot-imapd opendkim spamassassin spamc
# Install another requirement for opendikm only if the above command didn't get it already
[ -e $(which opendkim-genkey) ] || apt install opendkim-tools
domain="$(cat /etc/mailname)"
subdom="mail"
maildomain="$subdom.$domain"


# NOTE ON POSTCONF COMMANDS

# The `postconf` command literally just adds the line in question to /etc/postfix/main.cf so if you need to debug something, go there.
# It replaces any other line that sets the same setting, otherwise it is appended to the end of the file.

echo "Configuring Postfix's main.cf..."

# Change the cert/key files to the default locations of the Let's Encrypt cert/key
postconf -e "smtpd_tls_key_file=/etc/letsencrypt/live/$maildomain/privkey.pem"
postconf -e "smtpd_tls_cert_file=/etc/letsencrypt/live/$maildomain/fullchain.pem"
postconf -e "smtpd_use_tls = yes"
postconf -e "smtpd_tls_auth_only = yes"

# Here we tell Postfix to look to Dovecot for authenticating users/passwords.
# Dovecot will be putting an authentication socket in /var/spool/postfix/private/auth
postconf -e "smtpd_sasl_auth_enable = yes"
postconf -e "smtpd_sasl_type = dovecot"
postconf -e "smtpd_sasl_path = private/auth"

#postconf -e "smtpd_recipient_restrictions = permit_sasl_authenticated, permit_mynetworks, reject_unauth_destination"


# NOTE: the trailing slash here, or for any directory name in the home_mailbox command, is necessary as it distinguishes a maildir (which is the actual directories that what we want) from a spoolfile (which is what old unix boomers want and no one else).
postconf -e "home_mailbox = Mail/Inbox/"

# Research this one:
#postconf -e "mailbox_command ="


# master.cf

echo "Configuring Postfix's master.cf..."

sed -i "/^\s*-o/d;/^\s*submission/d;/^\s*smtp/d" /etc/postfix/master.cf

echo "smtp unix - - n - - smtp
smtp inet n - y - - smtpd
  -o content_filter=spamassassin
submission inet n       -       y       -       -       smtpd
  -o syslog_name=postfix/submission
  -o smtpd_tls_security_level=encrypt
  -o smtpd_sasl_auth_enable=yes
  -o smtpd_tls_auth_only=yes
smtps     inet  n       -       y       -       -       smtpd
  -o syslog_name=postfix/smtps
  -o smtpd_tls_wrappermode=yes
  -o smtpd_sasl_auth_enable=yes
spamassassin unix -     n       n       -       -       pipe
  user=debian-spamd argv=/usr/bin/spamc -f -e /usr/sbin/sendmail -oi -f \${sender} \${recipient}" >> /etc/postfix/master.cf


# By default, dovecot has a bunch of configs in /etc/dovecot/conf.d/
# These files have nice documentation if you want to read it, but it's a huge pain to go through them to organize.
# Instead, we simply overwrite /etc/dovecot/dovecot.conf because it's easier to manage. You can get a backup of the original in /usr/share/dovecot if you want.

echo "Creating Dovecot config..."

echo "# Dovecot config
# Note that in the dovecot conf, you can use:
# %u for username
# %n for the name in name@domain.tld
# %d for the domain
# %h the user's home directory

# If you're not a brainlet, SSL must be set to required.
ssl = required
ssl_cert = </etc/letsencrypt/live/$maildomain/fullchain.pem
ssl_key = </etc/letsencrypt/live/$maildomain/privkey.pem
# Plaintext login. This is safe and easy thanks to SSL.
auth_mechanisms = plain

protocols = \$protocols imap

# Search for valid users in /etc/passwd
userdb {
	driver = passwd
}
# Use plain old PAM to find user passwords
passdb {
	driver = pam
}

# Our mail for each user will be in ~/Mail, and the inbox will be ~/Mail/Inbox
# The LAYOUT option is also important because otherwise, the boxes will be \`.Sent\` instead of \`Sent\`.
mail_location = maildir:~/Mail:INBOX=~/Mail/Inbox:LAYOUT=fs
namespace inbox {
	inbox = yes
	mailbox Drafts {
	special_use = \\Drafts
	auto = subscribe
}
	mailbox Junk {
	special_use = \\Junk
	auto = subscribe
	autoexpunge = 30d
}
	mailbox Sent {
	special_use = \\Sent
	auto = subscribe
}
	mailbox Trash {
	special_use = \\Trash
}
	mailbox Archive {
	special_use = \\Archive
}
}

# Here we let Postfix use Dovecot's authetication system.

service auth {
  unix_listener /var/spool/postfix/private/auth {
	mode = 0660
	user = postfix
	group = postfix
}
}

protocol lda {
  mail_plugins = \$mail_plugins sieve
}

protocol lmtp {
  mail_plugins = \$mail_plugins sieve
}

plugin {
	sieve = ~/.dovecot.sieve
	sieve_default = /var/lib/dovecot/sieve/default.sieve
	#sieve_global_path = /var/lib/dovecot/sieve/default.sieve
	sieve_dir = ~/.sieve
	sieve_global_dir = /var/lib/dovecot/sieve/
}
" > /etc/dovecot/dovecot.conf

mkdir /var/lib/dovecot/sieve/

echo "require [\"fileinto\", \"mailbox\"];
if header :contains \"X-Spam-Flag\" \"YES\"
	{
		fileinto \"Junk\";
	}" > /var/lib/dovecot/sieve/default.sieve

chown -R vmail:vmail /var/lib/dovecot
sievec /var/lib/dovecot/sieve/default.sieve

echo "Preparing user authetication..."
grep nullok /etc/pam.d/dovecot >/dev/null ||
echo "auth    required        pam_unix.so nullok
account required        pam_unix.so" >> /etc/pam.d/dovecot

# OpenDKIM

# A lot of the big name email services, like Google, will automatically rejectmark as spam unfamiliar and unauthenticated email addresses. As in, the server will flattly reject the email, not even deliverring it to someone's Spam folder.

# OpenDKIM is a way to authenticate your email so you can send to such services without a problem.

# add opendkim-tools ?

# Create an OpenDKIM key and put in in the proper place with proper permissions.
echo "Generating OpenDKIM keys..."
mkdir -p /etc/postfix/dkim
opendkim-genkey -D /etc/postfix/dkim/ -d $ "$domain" -s "$subdom"
chgrp opendkim /etc/postfix/dkim/*
chmod g+r /etc/postfix/dkim/*

# Generate the OpenDKIM info:
echo "Configuring OpenDKIM..."
grep "$domain" >/dev/null 2>&1 /etc/postfix/dkim/keytable ||
echo "$subdom._domainkey.$domain $domain:mail:/etc/postfix/dkim/mail.private" >> /etc/postfix/dkim/keytable

grep "$domain" >/dev/null 2>&1 /etc/postfix/dkim/signingtable ||
echo "*@$domain $subdom._domainkey.$domain" >> /etc/postfix/dkim/signingtable

grep "127.0.0.1" >/dev/null 2>&1 /etc/postfix/dkim/trustedhosts ||
	echo "127.0.0.1
10.1.0.0/16
1.2.3.4/24" >> /etc/postfix/dkim/trustedhosts

# ...and source it from opendkim.conf
grep ^KeyTable /etc/opendkim.conf >/dev/null || echo "KeyTable file:/etc/postfix/dkim/keytable
SigningTable refile:/etc/postfix/dkim/signingtable
InternalHosts refile:/etc/postfix/dkim/trustedhosts" >> /etc/opendkim.conf

# OpenDKIM daemon settings, removing previously activated socket.
sed -i "/^SOCKET/d" /etc/default/opendkim && echo "SOCKET=\"inet:8891@localhost\"" >> /etc/default/opendkim

# Here we add to postconf the needed settings for working with OpenDKIM
echo "Configuring Postfix with OpenDKIM settings..."
postconf -e "milter_default_action = accept"
postconf -e "milter_protocol = 2"
postconf -e "smtpd_milters = inet:localhost:8891"
postconf -e "non_smtpd_milters = inet:localhost:8891"
postconf -e "mailbox_command = /usr/lib/dovecot/deliver"

echo "Restarting Dovecot..."
service dovecot restart && echo "Dovecot restarted."
echo "Restarting Postfix..."
service postfix restart && echo "Postfix restarted."
echo "Restarting OpenDKIM..."
service opendkim restart && echo "OpenDKIM restarted."
echo "Restarting Spam Assassin..."
service spamassassin restart && echo "Spamassassin restarted."

pval="$(tr -d "\n" </etc/postfix/dkim/mail.txt | sed "s/k=rsa.* \"p=/k=rsa; p=/;s/\"\s*\"//;s/\"\s*).*//" | grep -o p=.*)"
echo "Here is your TXT entry:"
echo
echo
echo
printf "Record Name\\tRecord Type\\tText of entry\\n"
printf "%s._domainkey\\tTXT\\t\\tv=DKIM1; k=rsa; %s\\n" "$subdom" "$pval"
echo
echo
echo "$pval"


