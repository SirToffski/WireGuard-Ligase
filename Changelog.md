## Changelog

* April 24th, 2019
  * Script to deploy the server would exit with an error if $pwd/keys/ and $pwd/client_confings/ did not exist during key creation.Logic to pre-check if the directory exists and to create one if needed was added. Script is now fully functional.
* April 29th, 2019
  * Similar pre-check as the above was added to the scipt to configure clients only.
  * All bash was updated with a new shebang.
  * New image generated with Carbon-cli instead of a screenshot.
  * Text colours and styling were added to improve readability.
* May 6th, 2019
  * Bugfixes:
    * Client config portion of the script had a syntax error reading `AllowedIPd` instead of `AllowedIPs`. This has been corrected.
    * Option to enable IP forwarding would change the value to `net.ipv4.ip_forward=1`, but would not uncomment it. This was fixed.
  * New features:
    * An option to install iptables-persistent and to enable systemctl service was added.
    * An option to enable WireGuard tunnel interface and to enable the interface on boot was added.
* May 20th, 2019
  * New Features:
    * Option for a quick-setup was added!
* July 9th, 2019
  * The script now checks if running as root.
  * New features:
    * Public IP of the machine on which the script is runnign is now automatically fetched via AWS `curl https://checkip.amazonaws.com`
    * Script now also checks if it's running on a supported OS and whether WireGuard is installed. If WireGuard is not installed, the script will offer to install it.
    * The script now customizes firewall rules based on the disstribution. On CentOS `firewall-cmd` will ne used. On Arch, Debian, Fedora, Manjaro and Ubuntu netfilter `iptables` are used. Furthermore, for the latter distributions, the script chooses an appropriate way to save netfilter rules. For example, on Debian and Ubuntu, `iptables-persistent` will be installed. On Fedora, netfilter rules are saved with `/sbin/service iptables save`. Finally, on Arch and Manjaro, systemd `iptables.service` is used with configuration saved to `/etc/iptables/iptables.rules`.
* July 22nd, 2019
  * Tons of minor bug fixes and some re-writes to save config logic
  * The script has been officially tested on CentOS 7 running in EC2 for the first time. Tons of minor adjustments had to be made.
    * CentOS 7 in EC2 does not have `firewalld` pre-installed and instead uses `iptables`. The iptables script has been written to take this into account. If OS type is CentOS and `firewalld` is installed, then `firewall-cmd` commands are used. If `firewalld` is not installed, `iptables` will be used by default. Also, the user will be offered to have `iptables-service` installed and enabled via `systemd` to have the rules persist after reboot.
* Oct 10th, 2019
  * It's been a while since the changelog has been updated; yet the work hasn't stopped.
  * Most of the commits were to improve user experience.
    * The look of the script has changed somewhat. The terminal screen is now cleared when needed and important parts summarized - easier to see than to explain.. but it's a lot better now.
    * Finally a good solution has been found to check for the directory where the script is running. See commit [7d2d61c](https://github.com/SirToffski/WireGuard-Ligase/commit/7d2d61c61949089a6b4aa363e422a5d53ac0423f). Find worked well on a brand new OS installation. However on a system with plenty of files and directories - it was a mess.
    * For the time being, work will continue concentrating on improvements to user interface, experience, and overall stability. New features will be implemented at a slower pace until the author is satisfied with UX.
* Jan 8th, 2020
  * Added initial support for FreeBSD.
* Jan 9th, 2020
  * BSD firewall ruless did not enable gateway mode in `/etc/rc.conf` and TCP segmentaion offloading in `/etc/sysctl.conf` - hence those settings were not preserved with server reboot. Both were fixed.
  * Using normal server setup mode now exports most of the variables to `shared_vars.sh`. This will prevent having to ask repetitive questions when setting up firewall rules.
* Jan 12th, 2020
  * FreeBSD support has been added to quick-setup mode.
  * Various syntax improvements in the shell code.