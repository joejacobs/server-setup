Server Setup
============
Debian server setup. Initially based on the blog post by [Bryan Kennedy][1] but
it has since been expanded to include more setup tasks. It currently does the
following:

1. Change root password
2. Create new user
3. Disable root login over ssh
4. Setup fail2ban
5. Setup ufw
6. Set timezone
7. Install curl
8. Install rsync
9. Install htop
10. Setup vim: including vimrc for root and user
11. Setup borg: backup to local dir and upload to b2

TODO
----
1. Setup AIDE
2. Setup Logwatch
3. Add ssh keys and disable password logins over ssh

License
-------
Copyright (c) 2018-2019, Joe Jacobs. All rights reserved.

Released under a [3-clause BSD License](LICENSE).

[1]: https://plusbryan.com/my-first-5-minutes-on-a-server-or-essential-security-for-linux-servers
