![shell screenshot with logo](/doc/icon-left-font-monochrome-black.svg)
> Wireguard Ligase is a collection of bash scripts designed to easily deploy Wireguard server and configure multiple clients in one go.

The main goals of Wireguard Ligase are:
- To make it easy for everyone to deploy and configure a Wireguard server and clients.
- To provide a platform for me to learn bash.
- To show that deploying your own VPN can be as easy as that.

For a comprehensive overview and guide, check out the [**Wiki**](https://github.com/SirToffski/WireGuard-Ligase/wiki).

Table of Contents
=================

  * [Using the script](#using-the-script)
     * [Pre-requisites](#pre-requisites)
     * [Usage](#usage)
  * [Why would I use this script?](#why-use-wireguard-ligase)
  * [Installing Wireguard](#installing-wireguard)
     * [Arch](#arch)
     * [Ubuntu](#ubuntu)
     * [RHEL / CentOS](#rhel--centos)
     * [Fedora](#fedora)
     * [Others](#others)
  * [Changelog](#changelog)
  * [TODO](#todo)
  * [Disclaimer](#disclaimer)

## Why use Wireguard-Ligase?

Main reasons behind using this script:

* Bash is installed and configured as a default shell on nearly any Linux distro.
* As of July 9th 2019 this script supports Arch, CentOS, Debian, Fedora, Manjaro, and Ubuntu
  * The script will check if it's running on a supported OS, then check if WireGuard is already installed.
  * If WireGuard is not installed, the script will offer to install it.
* You are in control
  * Any system changes are shown to the user and user confirmation is required BEFORE any changes are made.
* Easily readable
  * It's easy to understand the inner workings of the script because bash is a very popular language.
  * Annotations will be added to obscure parts of the script to clarify the logic behind certain operations.

## Using the script

Using the script is fairly simple. There are a number of requirements for running the script and making everything work.

### Pre-requisites

1.  A server with a public IP address, either physical or cloud (DigitalOcean, LightSail, Vultr, etc), running Linux.

2.  The script will check if WireGuard is installed on Arch, CentOS, Debian, Fedora, Manjaro and Ubuntu. On other distributions, WireGuard must be installed BEFORE running the script. See [Installing Wireguard](#installing-wireguard) for more info.

3.  A user with sudo privileges for making any system changes.

### Usage

As mentioned before, using the script is very simple.
```bash
$ git clone https://github.com/SirToffski/WireGuard-Ligase.git # (1) Clone the repository.
$ cd WireGuard-Ligase/ # (2) cd into the repository.
$ bash configure-wireguard.sh # (3) Run the script.
```


The script will guide you through the rest of the process.

## Installing Wireguard

The script has an ability to detect and install Wireguard of the following distributins:
* Arch Linux
* CentOS
* Debian
* Fedora
* Manjaro
* Ubuntu

For installation on other Operating Systems, please check the [**Wiki**](https://github.com/SirToffski/WireGuard-Ligase/wiki/Getting-Started).

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

## TODO

  - [x] Add an option for a quick hands-free server deployment / host configuration. Especially useful for people who dont want to answer a lot of questions and are not too fussy about naming clients, etc.
  - [x] Customize server config depending on the distro in use (Arch vs Ubuntu, vs RHEL, etc)
  - [ ] Add option to configure other UNIX OS types (such as OpenBSD)

## Disclaimer

The plan is to keep this updated and add features until the project reaches its logical conclusion.

Everyone is welcome to fork / contribute / use any or all parts of the project.
