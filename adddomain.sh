#!/bin/sh

domain="$1"
[ -z "$1" ] && exit

domain="$1"
subdom="mail"

# Add the domain to the valid postfix addresses.
grep -q "^mydestination.*$domain" /etc/postfix/main.cf ||
	sed -i "s/^mydestination.*/&, $domain/" /etc/postfix/main.cf

# Create DKIM for new domain.
mkdir -p "/etc/postfix/dkim/$domain"
opendkim-genkey -D "/etc/postfix/dkim/$domain" -d "$domain" -s "$subdom"
chgrp -R opendkim /etc/postfix/dkim/*
chmod -R g+r /etc/postfix/dkim/*

# Add entries to keytable and signing table.
echo "$subdom._domainkey.$domain $domain:$subdom:/etc/postfix/dkim/$domain/$subdom.private" >> /etc/postfix/dkim/keytable
echo "*@$domain $subdom._domainkey.$domain" >> /etc/postfix/dkim/signingtable

systemctl reload opendkim postfix

# Print out DKIM TXT entry.
pval="$(tr -d '\n' <"/etc/postfix/dkim/$domain/$subdom.txt" | sed "s/k=rsa.* \"p=/k=rsa; p=/;s/\"\s*\"//;s/\"\s*).*//" | grep -o 'p=.*')"

dkimentry="$subdom._domainkey.$domain	TXT	v=DKIM1; k=rsa; $pval"
dmarcentry="_dmarc.$domain	TXT	v=DMARC1; p=reject; rua=mailto:dmarc@$domain; fo=1"
spfentry="$domain	TXT	v=spf1 mx a:$maildomain -all"
mxentry="$domain	MX	10	$maildomain	300"

echo "$dkimentry
$dmarcentry
$spfentry
$mxentry" >> "$HOME/dns_emailwizard_added"

echo "=== ADD THE FOLLOWING TO YOUR DNS TXT RECORDS ==="
echo "$dkimentry
$dmarcentry
$spfentry
$mxentry"
echo "They have also been stored in ~/dns_emailwizard_added"
