# Email server setup script

I wrote this script during the gruelling process of installing and setting up an email server.
It perfectly reproduces my successful steps to ensure the same setup time and time again.

I've linked this file on Github to a shorter, more memorable address on my website so you can get it on your machine with this short command:

```
curl -LO lukesmith.xyz/emailwiz.sh
```

When prompted by a dialog menu at the beginning, select "Internet Site", then give your full domain without any subdomain, i.e. `lukesmith.xyz`.

Read this readme and peruse the script's comments before running it.
Expect it to fail and you have to do bug testing and you will be very happy when it actually works perfectly.

## This script...

- Installs a **Dovecot/Postfix mail server** for your domain of choice
- Sets up **sensible default mailboxes** located in `~/Mail`
- Installs and sets up **Spam Assassin**
- Installs and sets up **OpenDKIM** which validates your emails so you can send to Google and other sites with picky spam filters

## This script does _not_

- ...install or use a mySQL databse, instead uses the traditional Unix/PAM/login system where every user can be an email address on the domain.
- ...set up a graphical interface for mail like Roundcube or Squirrel Mail. If you want that, you'll have to install it yourself. I just use [isync/msmtp/mutt-wizard](https://github.com/lukesmithxyz/mutt-wizard) to have an offline mirror of my email setup and I recommend the same. There are other ways of doing it though, like Thunderbird, etc.
- ...offer any frills. If you want to change something, open the script up and change some variables.

## Requirements

- `apt purge` all your previous (failed) attempts to install and configure a mailserver. Get rid of _all_ your system settings for Postfix, Dovecot, OpenDKIM and everything else. This script builds off of a fresh install.
- A **Debian or Ubuntu server**. I've tested this on a [Vultr](https://www.vultr.com/?ref=7914655-4F) Debian server and their setup works, but I suspect other VPS hosts will have similar/possibly identical default settings which will let you run this on them.
- An **MX record** in your DNS settings that points to your own main domain/IP. Unless you have your own DNS server, you'll put this setting on your domain registrar's site. Look up their documentation on how to do this, but it's usually really easy.
- **SSL for your site's mail subdomain**, specifically for mail.yourdomain.tld with Let's Encrypt. The script will look to Let's Encrypt's generated configs. If you have some other SSL system, you can manually change the SSL locations in the script before running it and it should be fine. You might want to create a dummy Apache/nginx record for your mail domain as this makes running Let's Encrypt's Certbot easier.
- After the script runs, you'll have to add an *additional DNS TXT record* which involves the OpenDKIM key that it generates during the script.

## Caveats

My intention is to have this script working for me on my Debian web server which I have with Vultr.
Different VPS hosts or distros might have a startup config that's a little different and I'm sure as heck not going to make sure everything works on every possible machine out there, please do not even ask.
If a lot of people try this script and see that it works as expected everywhere, then I might try to label it as such and try to make it universal, but think of this script as a script that works on my exact setup that has some educational comments for the uninitiated and only _might_ work as intended.

If you decide to start a VPS, specifically Vultr since I made this script and have tempered it most on their default setup,
use [this referal link of mine](https://www.vultr.com/?ref=8384069-6G) because you get a free $100 credit for a month, and if you stay on the site, eventually I get a smaller kickback too.
I honestly have no really strong preference of Vultr over other VPS providers, but they're about as cheap and reliable as it gets and if we can get free money, lol whatever click the link 👏👏.

## Details

- A user's mail is in `~/Mail`. Want a new email address? Create a new user and just add them to the mail group, be sure to give them a password with `passwd <name>` as well. Now they can send and receive mail. Look up using aliases too if you want for more cool stuff. Dovecot should autocreate the directories as needed.
- All dovecot configuration is just in `/etc/dovecot/dovecot.conf` instead of a dozen little config files. You can read those in `/etc/dovecot/conf.d/` for more info, but they are not called by default after running this script and the needed settings are edited into the main config.
- Your IMAP/SMTP server will be `mail.yourdomain.tld` and your ports will be the typical ones: 993 for IMAP and 587 for SMTP.
- Using non-encrypted ports is not allowed for safety! The login is with plaintext because that's simpler and more robust given SSL's security.
- As is, you will use your name, not full email to log in. E.g., for my `luke@lukesmith.xyz` address, `luke` is my login.

If this script or documentation has saved you some frustration, you can donate to support me at [lukesmith.xyz/donate](https://lukesmith.xyz/donate.html).
No refunds if the process of having a mail server causes you another kind of frustration! 😉
