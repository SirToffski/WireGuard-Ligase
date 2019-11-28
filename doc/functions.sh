#!/usr/bin/env bash

function determine_os() {
  {
    ubuntu_os=$(lsb_release -a | grep -i -c Ubuntu)
    arch_os=$(hostnamectl | grep -i -c "Arch Linux")
    cent_os=$(hostnamectl | grep -i -c CentOS)
    debian_os=$(lsb_release -a | grep -i -c Debian)
    fedora_os=$(lsb_release -a | grep -i -c Fedora)
    manjaro_os=$(hostnamectl | grep -i -c Manjaro)
  } &>/dev/null
  if [[ "$ubuntu_os" -gt 0 ]]; then
    distro=ubuntu
  elif [[ "$arch_os" -gt 0 ]]; then
    distro=arch
  elif [[ "$cent_os" -gt 0 ]]; then
    distro=centos
  elif [[ "$debian_os" -gt 0 ]]; then
    distro=debian
  elif [[ "$fedora_os" -gt 0 ]]; then
    distro=fedora
  elif [[ "$manjaro_os" -gt 0 ]]; then
    distro=manjaro
  else
    printf %b\\n "The operating system is not supported by this script.
    The script will continue but will be unable to install Wireguard packages. 
    Hence script's functionality will be limited to generating server and client configurations."
  fi

  ########### UBUNTU ###########
  ##############################
  if [[ "$distro" == "ubuntu" ]]; then
    check_if_wg_installed=$(dpkg-query -l | grep -i -c wireguard-tools)
    # If WireGuard is NOT installed, offer to install
    if [[ "$check_if_wg_installed" == 0 ]]; then
      printf %b\\n "
  +---------------------------------------------+
      ${BWhite}OS Type: Ubuntu
      Wireguard-Tools: NOT installed${Color_Off}
  +---------------------------------------------+
        ${BWhite}Would you like to have Wireguard installed?${Color_Off}
  +---------------------------------------------+
      ${BWhite}1 = yes, 2 = no${Color_Off}"
      read -r install_wireguard
      if [[ "$install_wireguard" == 1 ]]; then
        # If chosen to install, proceed with installation
        add-apt-repository ppa:wireguard/wireguard
        apt-get update
        apt-get install wireguard
      elif [[ "$install_wireguard" == 2 ]]; then
        # If chosen NOT to install, move along
        printf %b\\n "
        Understood, moving on with the script."
      fi
    else
      printf %b\\n "
  +---------------------------------------------+
      ${BWhite}OS Type: Ubuntu
      Wireguard-Tools: Installed${Color_Off}
  +---------------------------------------------+
  "
    fi
  ##############################
  ##############################

  ########### ARCH OR MANJARO ###########
  #######################################
  elif [[ "$distro" == "arch" ]] || [[ "$distro" == "manjaro" ]]; then
    check_if_wg_installed=$(pacman -Qe | grep -i -c wireguard-tools)
    # If WireGuard is NOT installed, offer to instal
    if [[ "$check_if_wg_installed" == 0 ]]; then
      printf %b\\n "
  +---------------------------------------------+
      ${BWhite}OS Type: $distro
      Wireguard-Tools: NOT installed${Color_Off}
  +---------------------------------------------+
      ${BWhite}Would you like to have Wireguard installed?${Color_Off}
  +---------------------------------------------+
      ${BWhite}1 = yes, 2 = no${Color_Off}"
      read -r install_wireguard
      if [[ "$install_wireguard" == 1 ]]; then
        # If chosen to install, proceed with installation
        pacman -Syyy
        pacman -S wireguard-dkms wireguard-tools --noconfirm
      elif [[ "$install_wireguard" == 2 ]]; then
        # If chosen NOT to install, move along
        printf %b\\n "
        Understood, moving on with the script."
      fi
    else
      printf %b\\n "
  +---------------------------------------------+
      ${BWhite}OS Type: $distro
      Wireguard-Tools: Installed${Color_Off}
  +---------------------------------------------+
  "
    fi
  #######################################
  #######################################

  ########### CENTOS ###########
  ##############################
  elif [[ "$distro" == "centos" ]]; then
    check_if_wg_installed=$(yum list installed | grep -i -c wireguard-tools)
    mkdir /etc/wireguard/
    # If WireGuard is NOT installed, offer to instal
    if [[ "$check_if_wg_installed" == 0 ]]; then
      printf %b\\n "
  +---------------------------------------------+
        ${BWhite}OS Type: CentOS
      Wireguard-Tools: NOT installed${Color_Off}
  +---------------------------------------------+
        ${BWhite}Would you like to have Wireguard installed?${Color_Off}
  +---------------------------------------------+
      ${BWhite}1 = yes, 2 = no${Color_Off}"
      read -r install_wireguard
      if [[ "$install_wireguard" == 1 ]]; then
        # If chosen to install, proceed with installation
        curl -Lo /etc/yum.repos.d/wireguard.repo https://copr.fedorainfracloud.org/coprs/jdoss/wireguard/repo/epel-7/jdoss-wireguard-epel-7.repo
        yum install epel-release
        yum install wireguard-dkms wireguard-tools
      elif [[ "$install_wireguard" == 2 ]]; then
        # If chosen NOT to install, move along
        printf %b\\n "
        Understood, moving on with the script."
      fi
    else
      printf %b\\n "
  +---------------------------------------------+
      ${BWhite}OS Type: CentOS
      Wireguard-Tools: Installed${Color_Off}
  +---------------------------------------------+
  "
    fi
  ##############################
  ##############################

  ########### Fedora ###########
  ##############################
  elif [[ "$distro" == "fedora" ]]; then
    check_if_wg_installed=$(dnf list installed | grep -i -c wireguard-tools)
    # If WireGuard is NOT installed, offer to instal
    if [[ "$check_if_wg_installed" == 0 ]]; then
      printf %b\\n "
  +---------------------------------------------+
        ${BWhite}OS Type: Fedora
      Wireguard-Tools: NOT installed${Color_Off}
  +---------------------------------------------+
        ${BWhite}Would you like to have Wireguard installed?${Color_Off}
  +---------------------------------------------+
      ${BWhite}1 = yes, 2 = no${Color_Off}"
      read -r install_wireguard
      if [[ "$install_wireguard" == 1 ]]; then
        # If chosen to install, proceed with installation
        dnf copr enable jdoss/wireguard
        dnf install wireguard-dkms wireguard-tools
      elif [[ "$install_wireguard" == 2 ]]; then
        # If chosen NOT to install, move along
        printf %b\\n "
        Understood, moving on with the script."
      fi
    else
      printf %b\\n "
  +---------------------------------------------+
      ${BWhite}OS Type: Fedora
      Wireguard-Tools: Installed${Color_Off}
  +---------------------------------------------+
  "
    fi
  ##############################
  ##############################

  ########### Debian ###########
  ##############################
  elif [[ "$distro" == "debian" ]]; then
    check_if_wg_installed=$(dpkg-query -l | grep -i -c wireguard-tools)
    # If WireGuard is NOT installed, offer to instal
    if [[ "$check_if_wg_installed" == 0 ]]; then
      printf %b\\n "
  +---------------------------------------------+
      ${BWhite}OS Type: Debian
      Wireguard-Tools: NOT installed${Color_Off}
  +---------------------------------------------+
      ${BWhite}Would you like to have Wireguard installed?${Color_Off}
  +---------------------------------------------+
      ${BWhite}1 = yes, 2 = no${Color_Off}"
      read -r install_wireguard
      if [[ "$install_wireguard" == 1 ]]; then
        # If chosen to install, proceed with installation
        printf %s\\n "deb http://deb.debian.org/debian/ unstable main" >/etc/apt/sources.list.d/unstable.list
        printf 'Package: *\nPin: release a=unstable\nPin-Priority: 90\n' >/etc/apt/preferences.d/limit-unstable
        apt update
        apt install wireguard
      elif [[ "$install_wireguard" == 2 ]]; then
        # If chosen NOT to install, move along
        printf %b\\n "
        Understood, moving on with the script."
      fi
    else
      printf %b\\n "
  +---------------------------------------------+
      ${BWhite}OS Type: Debian
      Wireguard-Tools: Installed${Color_Off}
  +---------------------------------------------+
  "
    fi
  ##############################
  ##############################
  fi
}

function colours() {
  # Borrowed from https://gist.github.com/nbrew/9278728

  # Reset
  Color_Off="\033[0m"      # Text Reset

  # Regular Colors
  Black="\033[0;30m"       # Black
  Red="\033[0;31m"         # Red
  Green="\033[0;32m"       # Green
  Yellow="\033[0;33m"      # Yellow
  Blue="\033[0;34m"        # Blue
  Purple="\033[0;35m"      # Purple
  Cyan="\033[0;36m"        # Cyan
  White="\033[0;37m"       # White

  # Bold
  BBlack="\033[1;30m"      # Black
  BRed="\033[1;31m"        # Red
  BGreen="\033[1;32m"      # Green
  BYellow="\033[1;33m"     # Yellow
  BBlue="\033[1;34m"       # Blue
  BPurple="\033[1;35m"     # Purple
  BCyan="\033[1;36m"       # Cyan
  BWhite="\033[1;37m"      # White

  # Underline
  UBlack="\033[4;30m"      # Black
  URed="\033[4;31m"        # Red
  UGreen="\033[4;32m"      # Green
  UYellow="\033[4;33m"     # Yellow
  UBlue="\033[4;34m"       # Blue
  UPurple="\033[4;35m"     # Purple
  UCyan="\033[4;36m"       # Cyan
  UWhite="\033[4;37m"      # White

  # Background
  On_Black="\033[40m"      # Black
  On_Red="\033[41m"        # Red
  On_Green="\033[42m"      # Green
  On_Yellow="\033[43m"     # Yellow
  On_Blue="\033[44m"       # Blue
  On_Purple="\033[45m"     # Purple
  On_Cyan="\033[46m"       # Cyan
  On_White="\033[47m"      # White

  # High Intensty
  IBlack="\033[0;90m"      # Black
  IRed="\033[0;91m"        # Red
  IGreen="\033[0;92m"      # Green
  IYellow="\033[0;93m"     # Yellow
  IBlue="\033[0;94m"       # Blue
  IPurple="\033[0;95m"     # Purple
  ICyan="\033[0;96m"       # Cyan
  IWhite="\033[0;97m"      # White

  # Bold High Intensty
  BIBlack="\033[1;90m"     # Black
  BIRed="\033[1;91m"       # Red
  BIGreen="\033[1;92m"     # Green
  BIYellow="\033[1;93m"    # Yellow
  BIBlue="\033[1;94m"      # Blue
  BIPurple="\033[1;95m"    # Purple
  BICyan="\033[1;96m"      # Cyan
  BIWhite="\033[1;97m"     # White

  # High Intensty backgrounds
  On_IBlack="\033[0;100m"  # Black
  On_IRed="\033[0;101m"    # Red
  On_IGreen="\033[0;102m"  # Green
  On_IYellow="\033[0;103m" # Yellow
  On_IBlue="\033[0;104m"   # Blue
  On_IPurple="\033[10;95m" # Purple
  On_ICyan="\033[0;106m"   # Cyan
  On_IWhite="\033[0;107m"  # White

}
