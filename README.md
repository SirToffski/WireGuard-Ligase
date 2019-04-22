# Wireguard Ligase


> Wireguard Ligase is a collection of bash scripts designed to easily deploy Wireguard server and configure multiple clients in one go.
> ![shell screenshot with logo](/doc/shell-screenshot-with-logo.png)


The main goals of Wireguard Ligase are:
- To make it easy for everyone to deploy and configure a Wireguard server and clients.
- To provide a platform for me to learn bash.
- To show that deploying your own VPN can be as easy as that.

Table of Contents
=================

   * [Wireguard Ligase](#wireguard-ligase)
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
      * [Disclaimer](#disclaimer)

## Why use Wireguard-Ligase?

Main reasons behind using this script:

* No need to install anything
  * Bash is installed and configured as a default shell on nearly any Linux distro.
  * This script does NOT install any software on your system. It's designed to create .conf config files and add some iptables rules.
* You are in control
  * Any system changes are shown to the user and user confirmation is required BEFORE any changes are made.
* Easily readable
  * It's easy to understand the inner workings of the script because bash is a very popular language.
  * Annotations will be added to obscure parts of the script to clarify the logic behind certain operations.

## Using the script

Using the script is fairly simple. There are a number of requirements for running the script and making everything work.

### Pre-requisites

1.  A server with a public IP address (DigitalOcean, LightSail, Vultr, etc) running Linux.

2.  Wireguard MUST be installed on the server before running the script. See installation guides for popular Linux distros.

3.  A user with sudo privileges for making any system changes.

### Usage

As mentioned before, using the script is very simple.

    $ git clone https://github.com/SirToffski/WireGuard-Ligase.git (1)
    $ cd WireGuard-Ligase/ (2)
    $ bash configure-wireguard.sh (3)

1. Clone the repository.
2. cd into the repository.
3. Run the script.

The script will guide you through the rest of the process.

## Installing Wireguard

### Arch

    $ sudo pacman -S wireguard-tools

### Ubuntu

    $ sudo add-apt-repository ppa:wireguard/wireguard
    $ sudo apt-get update
    $ sudo apt-get install wireguard

### RHEL / CentOS

    $ sudo curl -Lo /etc/yum.repos.d/wireguard.repo https://copr.fedorainfracloud.org/coprs/jdoss/wireguard/repo/epel-7/jdoss-wireguard-epel-7.repo
    $ sudo yum install epel-release
    $ sudo yum install wireguard-dkms wireguard-tools

### Fedora

    $ sudo dnf copr enable jdoss/wireguard
    $ sudo dnf install wireguard-dkms wireguard-tools

### Others

For other Operating Systems, please check the [**official website**](https://www.wireguard.com/install/).

## Disclaimer

The plan is to keep this updated and add features until the project reaches its logical conclusion.

Everyone is welcome to fork / contribute / use parts any or all parts of the project.
