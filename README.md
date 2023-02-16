# Email server setup script

This script installs an email server with all the features required in the
modern web.

I've linked this file on Github to a shorter, more memorable address on my
website so you can get it on your machine with this short command:

```sh
curl -LO lukesmith.xyz/emailwiz.sh
```

When prompted by a dialog menu at the beginning, select "Internet Site", then
give your full domain without any subdomain, e.g. `lukesmith.xyz`.

I'm glad to say that dozens, hundreds of people have now used it and there is a
sizeable network of people with email servers thanks to this script.

## This script installs

- **Postfix** to send and receive mail.
- **Dovecot** to get mail to your email client (mutt, Thunderbird, etc.).
- Config files that link the two above securely with native PAM log-ins.
- **Spamassassin** to prevent spam and allow you to make custom filters.
- **OpenDKIM** to validate you so you can send to Gmail and other big sites.
- **Certbot** SSL certificates, if not already present.
- **fail2ban** to increase server security, with enabled modules for the above
  programs.

## This script does _not_...

- use a SQL database or anything like that. We keep it simple and use normal
  Unix system users for accounts and passwords.
- set up a graphical web interface for mail like Roundcube or Squirrel Mail.
  You are expected to use a normal mail client like Thunderbird or K-9 for
  Android or good old mutt with
  [mutt-wizard](https://github.com/lukesmithxyz/mutt-wizard). Note that there
  is a guide for [Rainloop](https://landchad.net/rainloop/) on
  [LandChad.net](https://landchad.net) for those that want such a web
  interface.

## Prerequisites for Installation

1. Debian or Ubuntu server. I suited this script for
   [Vultr](https://www.vultr.com/?ref=8940911-8H) servers originally, but it
   seems to work on most other default setups on different VPS providers.
2. DNS records that point at least your domain's `mail.` subdomain to your
   server's IP (IPv4 and IPv6). This is required on initial run for certbot to
   get an SSL certificate for your `mail.` subdomain.

## Mandatory Finishing Touches

### Unblock your ports

While the script enables your mail ports on your server, it is common practice
for all VPS providers to block mail ports on their end by default. Open a help
ticket with your VPS provider asking them to open your mail ports and they will
do it in short order.

### DNS records

At the end of the script, you will be given some DNS records to add to your DNS
server/registrar's website. These are mostly for authenticating your emails as
non-spam. The 4 records are:

1. An MX record directing to `mail.yourdomain.tld`.
2. A TXT record for SPF (to reduce mail spoofing).
3. A TXT record for DMARC policies.
4. A TXT record with your public DKIM key. This record is long and **uniquely
   generated** while running `emailwiz.sh` and thus must be added after
   installation.

They will look something like this:

```
@	MX	10	mail.example.org
mail._domainkey.example.org    TXT     v=DKIM1; k=rsa; p=anextremelylongsequenceoflettersandnumbersgeneratedbyopendkim
_dmarc.example.org     TXT     v=DMARC1; p=reject; rua=mailto:dmarc@example.org; fo=1
example.org    TXT     v=spf1 mx a: -all
```

The script will create a file, `~/dns_emailwiz` that will list our the records
for your convenience, and also prints them at the end of the script.

### Add a rDNS/PTR record as well!

Set a reverse DNS or PTR record to avoid getting spammed. You can do this at
your VPS provider, and should set it to `mail.yourdomain.tld`. Note that you
should set this for both IPv4 and IPv6.

## Making new users/mail accounts

Let's say we want to add a user Billy and let him receive mail, run this:

```
useradd -m -G mail billy
passwd billy
```

Any user added to the `mail` group will be able to receive mail. Suppose a user
Cassie already exists and we want to let her receive mail too. Just run:

```
usermod -a -G mail cassie
```

A user's mail will appear in `~/Mail/`. If you want to see your mail while ssh'd
in the server, you could just install mutt, add `set spoolfile="+Inbox"` to
your `~/.muttrc` and use mutt to view and reply to mail. You'll probably want
to log in remotely though:

## Logging in from email clients (Thunderbird/mutt/etc)

Let's say you want to access your mail with Thunderbird or mutt or another
email program. For my domain, the server information will be as follows:

- SMTP server: `mail.lukesmith.xyz`
- SMTP port: 465
- IMAP server: `mail.lukesmith.xyz`
- IMAP port: 993

## Benefited from this?

I am always glad to hear this script is still making life easy for people. If
this script or documentation has saved you some frustration, donate here:

- btc: `bc1qzw6mk80t3vrp2cugmgfjqgtgzhldrqac5axfh4`
- xmr: `8A5v4Ci11Lz7BDoE2z2oPqMoNHzr5Zj8B3Q2N2qzqrUKhAKgNQYGSSaZDnBUWg6iXCiZyvC9mVCyGj5kGMJTi1zGKGM4Trm`

## Sites for Troubleshooting

Can't send or receive mail? Getting marked as spam? There are tools to double-check your DNS records and more:

- Always check `journalctl -xe` first for specific errors.
- [Check your DNS](https://intodns.com/)
- [Test your TXT records via mail](https://appmaildev.com/en/dkim)
- [Is your IP blacklisted?](https://mxtoolbox.com/blacklists.aspx)
- [mxtoolbox](https://mxtoolbox.com/SuperTool.aspx)
