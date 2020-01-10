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
  * [Changelog](#changelog)
  * [TODO](#todo)
  * [Disclaimer](#disclaimer)

## Why use Wireguard-Ligase?

Main reasons behind using this script:

* Bash is installed and configured as a default shell on nearly any Linux distro.
* As of July 9th 2019 this script supports Arch, CentOS, Debian, Fedora, Manjaro, and Ubuntu
  * The script will check if it's running on a supported OS, then check if WireGuard is already installed.
  * If WireGuard is not installed, the script will offer to install it.
  * For Arch, Debian, Fedora, Manjaro, and Ubuntu - the script will choose an appropriate way to save netfilter rules in order for those to persist after reboot. See [Changelog](#changelog) for details.
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
$ sudo bash configure-wireguard.sh # (3) Run the script.
```

The script will guide you through the rest of the process.

## Installing Wireguard

The script has an ability to detect and install Wireguard of the following distributions:
* Arch Linux
* CentOS
* Debian
* Fedora
* Manjaro
* Ubuntu
* FreeBSD 12
  * Only normal mode has been implemented (including firewall rules). Quick-setup will be implemented at a later date.


For installation on other Operating Systems, please check the [**Wiki**](https://github.com/SirToffski/WireGuard-Ligase/wiki/Getting-Started).

## Changelog

See [**changelog**](/Changelog.md).

## TODO

  - [x] Add an option for a quick hands-free server deployment / host configuration. Especially useful for people who dont want to answer a lot of questions and are not too fussy about naming clients, etc.
  - [x] Customize server config depending on the distro in use (Arch vs Ubuntu, vs RHEL, etc)
  - [ ] Add option to configure other UNIX OS types (such as OpenBSD) - work in progress. Initial FreeBSD support has been added.

## Disclaimer

The plan is to keep this updated and add features until the project reaches its logical conclusion.

Everyone is welcome to fork / contribute / use any or all parts of the project.
