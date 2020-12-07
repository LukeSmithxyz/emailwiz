# Email server setup script

I wrote this script during the grueling process of installing and setting up
an email server. It perfectly reproduces my successful steps to ensure the
same setup time and time again, now with many improvements.

I'm glad to say that dozens, hundreds of people have now used it and there is a
sizeable network of people with email servers thanks to this script.

I've linked this file on Github to a shorter, more memorable address on my
website so you can get it on your machine with this short command:

```sh
curl -LO lukesmith.xyz/emailwiz.sh
```

When prompted by a dialog menu at the beginning, select "Internet Site", then
give your full domain without any subdomain, i.e. `lukesmith.xyz`.

## This script installs

- **Postfix** to send and receive mail.
- **Dovecot** to get mail to your email client (mutt, Thunderbird, etc.).
- Config files that link the two above securely with native log-ins.
- **Spamassassin** to prevent spam and allow you to make custom filters.
- **OpenDKIM** to validate you so you can send to Gmail and other big sites.

## This script does _not_

- use a SQL database or anything like that.
- set up a graphical interface for mail like Roundcube or Squirrel Mail. If you
  want that, you'll have to install it yourself. I just use
  [isync/msmtp/mutt-wizard](https://github.com/lukesmithxyz/mutt-wizard) to
  have an offline mirror of my email setup and I recommend the same. There are
  other ways of doing it though, like Thunderbird, etc.

## Requirements

1. A **Debian or Ubuntu server**. I've tested this on a
   [Vultr](https://www.vultr.com/?ref=8384069-6G) Debian server and one running
   Ubuntu and their setup works, but I suspect other VPS hosts will have
   similar/possibly identical default settings which will let you run this on
   them. Note that the affiliate link there to Vultr gives you a $100 credit
   for the first month to play around.
2. **A Let's Encrypt SSL certificate for your site's `mail.` subdomain**.
3. You need two little DNS records set on your domain registrar's site/DNS
   server: (1) an **MX record** pointing to your own main domain/IP and (2) a
   **CNAME record** for your `mail.` subdomain.
4. **A Reverse DNS entry for your site.** Go to your VPS settings and add an
   entry for your IPv4 Reverse DNS that goes from your IP address to
   `<yourdomain.com>` (not mail subdomain). If you would like IPv6, you can do
   the same for that. This has been tested on Vultr, and all decent VPS hosts
   will have a section on their instance settings page to add a reverse DNS PTR
   entry.
   You can use the 'Test Email Server' or ':smtp' tool on
   [mxtoolbox](https://mxtoolbox.com/SuperTool.aspx) to test if you set up
   a reverse DNS correctly. This step is not required for everyone, but some
   big email services like Gmail will stop emails coming from mail servers
   with no/invalid rDNS lookups. This means your email will fail to even
   make it to the recipients spam folder; it will never make it to them.
5. `apt purge` all your previous (failed) attempts to install and configure a
   mail server. Get rid of _all_ your system settings for Postfix, Dovecot,
   OpenDKIM and everything else. This script builds off of a fresh install.
6. Some VPS providers block mail port numbers like 25, 933 or 587 by default.
   You may need to request these ports be opened to send mail successfully.
   Vultr and most other VPS providers will respond immediately and open the
   ports for you if you open a support ticket.

## Post-install requirement!

- After the script runs, you'll have to add additional DNS TXT records which
  are displayed at the end when the script is complete. They will help ensure
  your mail is validated and secure.

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

## Logging in from Thunderbird or mutt (and others) remotely

Let's say you want to access your mail with Thunderbird or mutt or another
email program. For my domain, the server information will be as follows:

- SMTP server: `mail.lukesmith.xyz`
- SMTP port: 587
- IMAP server: `mail.lukesmith.xyz`
- IMAP port: 993

In previous versions of emailwiz, you also had to log on with *only* your
username (i.e. `luke`) rather than your whole email address (i.e.
`luke@lukesmith.xyz`), which caused some confusion. This is no longer the
case.

## Benefited from this?

I am always glad to hear this script is still making life easy for people!  If
this script or documentation has saved you some frustration, you can donate to
support me at [lukesmith.xyz/donate](https://lukesmith.xyz/donate.html).

## Troubleshooting -- Can't send mail?

- Always check `journalctl -xe` to see the specific problem.
- Check with your VPS host and ask them to enable mail ports. Some providers
  disable them by default. It shouldn't take any time.
- Go to [this site](https://appmaildev.com/en/dkim) to test your TXT records.
  If your DKIM, SPF or DMARC tests fail you probably copied in the TXT records
  incorrectly.
- If everything looks good and you *can* send mail, but it still goes to Gmail
  or another big provider's spam directory, your domain (especially if it's a
  new one) might be on a public spam list.  Check
  [this site](https://mxtoolbox.com/blacklists.aspx) to see if it is. Don't
  worry if you are: sometimes especially new domains are automatically assumed
  to be spam temporarily. If you are blacklisted by one of these, look into it
  and it will explain why and how to remove yourself.
- Check your DNS settings using [this site](https://intodns.com/), it'll report
  any issues with your MX records
- Ensure that port 25 is open on your server.
  [Vultr](https://www.vultr.com/docs/what-ports-are-blocked) for instance
  blocks this by default, you need to open a support ticket with them to open
  it. You can't send mail if 25 is blocked
