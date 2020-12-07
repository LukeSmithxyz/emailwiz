#!/bin/sh

# THE SETUP

# Mail will be stored in non-retarded Maildirs because it's $currentyear.  This
# makes it easier for use with isync, which is what I care about so I can have
# an offline repo of mail.

# The mailbox names are: Inbox, Sent, Drafts, Archive, Junk, Trash

# Use the typical unix login system for mail users. Users will log into their
# email with their passnames on the server. No usage of a redundant mySQL
# database to do this.

# DEPENDENCIES BEFORE RUNNING

# 1. Have a Debian system with a static IP and all that. Pretty much any
# default VPS offered by a company will have all the basic stuff you need. This
# script might run on Ubuntu as well. Haven't tried it. If you have, tell me
# what happens.

# 2. Have a Let's Encrypt SSL certificate for $maildomain. You might need one
# for $domain as well, but they're free with Let's Encypt so you should have
# them anyway.

# 3. If you've been toying around with your server settings trying to get
# postfix/dovecot/etc. working before running this, I recommend you `apt purge`
# everything first because this script is build on top of only the defaults.
# Clear out /etc/postfix and /etc/dovecot yourself if needbe.

# NOTE WHILE INSTALLING

# On installation of Postfix, select "Internet Site" and put in TLD (without
# `mail.` before it).

echo "Installing programs..."
apt install postfix dovecot-imapd dovecot-sieve opendkim spamassassin spamc
# Check if OpenDKIM is installed and install it if not.
which opendkim-genkey >/dev/null 2>&1 || apt install opendkim-tools
domain="$(cat /etc/mailname)"
subdom=${MAIL_SUBDOM:-mail}
maildomain="$subdom.$domain"
certdir="/etc/letsencrypt/live/$maildomain"

[ ! -d "$certdir" ] && certdir="$(dirname "$(certbot certificates 2>/dev/null | grep "$maildomain\|*.$domain" -A 2 | awk '/Certificate Path/ {print $3}' | head -n1)")"

[ ! -d "$certdir" ] && echo "Note! You must first have a Let's Encrypt Certbot HTTPS/SSL Certificate for $maildomain.

Use Let's Encrypt's Certbot to get that and then rerun this script.

You may need to set up a dummy $maildomain site in nginx or Apache for that to work." && exit

# NOTE ON POSTCONF COMMANDS

# The `postconf` command literally just adds the line in question to
# /etc/postfix/main.cf so if you need to debug something, go there. It replaces
# any other line that sets the same setting, otherwise it is appended to the
# end of the file.

echo "Configuring Postfix's main.cf..."

# Change the cert/key files to the default locations of the Let's Encrypt cert/key
postconf -e "smtpd_tls_key_file=$certdir/privkey.pem"
postconf -e "smtpd_tls_cert_file=$certdir/fullchain.pem"
postconf -e "smtpd_use_tls = yes"
postconf -e "smtpd_tls_auth_only = yes"
postconf -e "smtp_tls_security_level = may"
postconf -e "smtp_tls_loglevel = 1"
postconf -e "smtp_tls_CAfile=$certdir/cert.pem"
postconf -e "smtpd_tls_mandatory_protocols = !SSLv2, !SSLv3, !TLSv1, !TLSv1.1"
postconf -e "smtp_tls_mandatory_protocols = !SSLv2, !SSLv3, !TLSv1, !TLSv1.1"
postconf -e "smtpd_tls_protocols = !SSLv2, !SSLv3, !TLSv1, !TLSv1.1"
postconf -e "smtp_tls_protocols = !SSLv2, !SSLv3, !TLSv1, !TLSv1.1"
postconf -e "tls_preempt_cipherlist = yes"
postconf -e "smtpd_tls_exclude_ciphers = aNULL, LOW, EXP, MEDIUM, ADH, AECDH, MD5,
                            DSS, ECDSA, CAMELLIA128, 3DES, CAMELLIA256,
                            RSA+AES, eNULL"

# Here we tell Postfix to look to Dovecot for authenticating users/passwords.
# Dovecot will be putting an authentication socket in /var/spool/postfix/private/auth
postconf -e "smtpd_sasl_auth_enable = yes"
postconf -e "smtpd_sasl_type = dovecot"
postconf -e "smtpd_sasl_path = private/auth"

#postconf -e "smtpd_recipient_restrictions = permit_sasl_authenticated, permit_mynetworks, reject_unauth_destination"


# NOTE: the trailing slash here, or for any directory name in the home_mailbox
# command, is necessary as it distinguishes a maildir (which is the actual
# directories that what we want) from a spoolfile (which is what old unix
# boomers want and no one else).
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


# By default, dovecot has a bunch of configs in /etc/dovecot/conf.d/ These
# files have nice documentation if you want to read it, but it's a huge pain to
# go through them to organize.  Instead, we simply overwrite
# /etc/dovecot/dovecot.conf because it's easier to manage. You can get a backup
# of the original in /usr/share/dovecot if you want.

echo "Creating Dovecot config..."

echo "# Dovecot config
# Note that in the dovecot conf, you can use:
# %u for username
# %n for the name in name@domain.tld
# %d for the domain
# %h the user's home directory

# If you're not a brainlet, SSL must be set to required.
ssl = required
ssl_cert = <$certdir/fullchain.pem
ssl_key = <$certdir/privkey.pem
ssl_min_protocol = TLSv1.2
ssl_cipher_list = ALL:!RSA:!CAMELLIA:!aNULL:!eNULL:!LOW:!3DES:!MD5:!EXP:!PSK:!SRP:!DSS:!RC4:!SHA1:!SHA256:!SHA384:!LOW@STRENGTH
ssl_prefer_server_ciphers = yes
ssl_dh = </usr/share/dovecot/dh.pem
# Plaintext login. This is safe and easy thanks to SSL.
auth_mechanisms = plain login
auth_username_format = %n

protocols = \$protocols imap

# Search for valid users in /etc/passwd
userdb {
	driver = passwd
}
#Fallback: Use plain old PAM to find user passwords
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

cut -d: -f1 /etc/passwd | grep -q "^vmail" || useradd vmail
chown -R vmail:vmail /var/lib/dovecot
sievec /var/lib/dovecot/sieve/default.sieve

echo "Preparing user authentication..."
grep -q nullok /etc/pam.d/dovecot ||
echo "auth    required        pam_unix.so nullok
account required        pam_unix.so" >> /etc/pam.d/dovecot

# OpenDKIM

# A lot of the big name email services, like Google, will automatically reject
# as spam unfamiliar and unauthenticated email addresses. As in, the server
# will flatly reject the email, not even delivering it to someone's Spam
# folder.

# OpenDKIM is a way to authenticate your email so you can send to such services
# without a problem.

# TODO: add opendkim-tools ?

# Create an OpenDKIM key in the proper place with proper permissions.
echo "Generating OpenDKIM keys..."
mkdir -p /etc/postfix/dkim
opendkim-genkey -D /etc/postfix/dkim/ -d "$domain" -s "$subdom"
chgrp opendkim /etc/postfix/dkim/*
chmod g+r /etc/postfix/dkim/*

# Generate the OpenDKIM info:
echo "Configuring OpenDKIM..."
grep -q "$domain" /etc/postfix/dkim/keytable 2>/dev/null ||
echo "$subdom._domainkey.$domain $domain:$subdom:/etc/postfix/dkim/$subdom.private" >> /etc/postfix/dkim/keytable

grep -q "$domain" /etc/postfix/dkim/signingtable 2>/dev/null ||
echo "*@$domain $subdom._domainkey.$domain" >> /etc/postfix/dkim/signingtable

grep -q "127.0.0.1" /etc/postfix/dkim/trustedhosts 2>/dev/null ||
	echo "127.0.0.1
10.1.0.0/16
1.2.3.4/24" >> /etc/postfix/dkim/trustedhosts

# ...and source it from opendkim.conf
grep -q "^KeyTable" /etc/opendkim.conf 2>/dev/null || echo "KeyTable file:/etc/postfix/dkim/keytable
SigningTable refile:/etc/postfix/dkim/signingtable
InternalHosts refile:/etc/postfix/dkim/trustedhosts" >> /etc/opendkim.conf

sed -i '/^#Canonicalization/s/simple/relaxed\/simple/' /etc/opendkim.conf
sed -i '/^#Canonicalization/s/^#//' /etc/opendkim.conf

sed -e '/Socket/s/^#*/#/' -i /etc/opendkim.conf
grep -q "^Socket\s*inet:12301@localhost" /etc/opendkim.conf || echo "Socket inet:12301@localhost" >> /etc/opendkim.conf

# OpenDKIM daemon settings, removing previously activated socket.
sed -i "/^SOCKET/d" /etc/default/opendkim && echo "SOCKET=\"inet:12301@localhost\"" >> /etc/default/opendkim

# Here we add to postconf the needed settings for working with OpenDKIM
echo "Configuring Postfix with OpenDKIM settings..."
postconf -e "smtpd_sasl_security_options = noanonymous, noplaintext"
postconf -e "smtpd_sasl_tls_security_options = noanonymous"
postconf -e "myhostname = $maildomain"
postconf -e "milter_default_action = accept"
postconf -e "milter_protocol = 6"
postconf -e "smtpd_milters = inet:localhost:12301"
postconf -e "non_smtpd_milters = inet:localhost:12301"
postconf -e "mailbox_command = /usr/lib/dovecot/deliver"

for x in dovecot postfix opendkim spamassassin; do
	printf "Restarting %s..." "$x"
	service "$x" restart && printf " ...done\\n"
done

pval="$(tr -d "\n" </etc/postfix/dkim/$subdom.txt | sed "s/k=rsa.* \"p=/k=rsa; p=/;s/\"\s*\"//;s/\"\s*).*//" | grep -o "p=.*")"
dkimentry="$subdom._domainkey.$domain	TXT	v=DKIM1; k=rsa; $pval"
dmarcentry="_dmarc.$domain	TXT	v=DMARC1; p=none; rua=mailto:dmarc@$domain; fo=1"
spfentry="@	TXT	v=spf1 mx a:$maildomain -all"

useradd -m -G mail dmarc

echo "$dkimentry
$dmarcentry
$spfentry" > "$HOME/dns_emailwizard"

echo "
 _   _
| \ | | _____      ___
|  \| |/ _ \ \ /\ / (_)
| |\  | (_) \ V  V / _
|_| \_|\___/ \_/\_/ (_)

Add these three records to your DNS TXT records on either your registrar's site
or your DNS server:

$dkimentry

$dmarcentry

$spfentry

NOTE: You may need to omit the \`.$domain\` portion at the beginning if
inputting them in a registrar's web interface.

Also saving these to ~/dns_emailwizard in case you want them in a file.

Once you do that, you're done! Check the README for how to add users/accounts
and how to log in."
