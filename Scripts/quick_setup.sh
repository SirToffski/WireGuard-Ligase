#!/usr/bin/env bash

if [ "$EUID" -ne 0 ]; then
  echo "Please run the script as root."
  exit 1
fi

my_wgl_folder=$(find /home -type d -name WireGuard-Ligase)
my_working_dir=$(pwd)
source "$my_wgl_folder"/doc/colours.sh
my_separator="--------------------------------------"
############################ DEFINE VARIABLES ############################
server_private_range="10.10.100.1"
local_interface="eth0"
server_listen_port="9201"
client_dns="1.1.1.1"
number_of_clients="2"
client_private_address_1="10.10.100.2"
client_private_address_2="10.10.100.3"
config_file_name="wg0"
server_subnet="10.10.100.0/24"
check_pub_ip=$(curl https://checkip.amazonaws.com)
##########################################################################

######################## Pre-checks ######################################################
# Check if a directory /keys/ exists, if not, it will be made
check_for_keys_directory=$(ls "$my_working_dir" | grep -c --count keys)
if [[ $check_for_keys_directory == 0 ]]; then
  mkdir keys
fi

# Check if a directory /client_configs/ exists, if not, it will be made
check_for_clients_directory=$(ls "$my_working_dir" | grep -c --count client_configs)

if [[ $check_for_clients_directory == 0 ]]; then
  mkdir client_configs
fi
##########################################################################################

############## Determine OS Type ##############
###############################################
ubuntu_os=$(lsb_release -a | grep -c Ubuntu)
arch_os=$(lsb_release -a | grep -c Arch)
cent_os=$(hostnamectl | grep -c CentOS)
debian_os=$(lsb_release -a | grep -c Debian)
fedora_os=$(lsb_release -a | grep -c Fedora)
manjaro_os=$(lsb_release -a | grep -c Manjaro)

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
  echo -e "The operating system is not supported by this script. The script will continue but will be unable to install Wireguard packages. Hence script's functionality will be limited to generating server / client configurations."
fi
###############################################
###############################################

echo "This script will take you through the steps needed to deploy a new server and configure some clients.

First, let's check if wireguard is installed..."

########### UBUNTU ###########
##############################
if [[ "$distro" == "ubuntu" ]]; then
  check_if_wg_installed=$(dpkg-query -l | grep -i -c wireguard-tools)
  # If WireGuard is NOT installed, offer to install
  if [[ "$check_if_wg_installed" == 0 ]]; then
    echo "
    OS Type: Ubuntu
    Wireguard-Tools: NOT installed

    Would you like to have Wireguard installed?

    ${BWhite}1 = yes, 2 = no${Color_Off}"
    read -r install_wireguard
    if [[ "$install_wireguard" == 1 ]]; then
      # If chosen to install, proceed with installation
      add-apt-repository ppa:wireguard/wireguard
      apt-get update
      apt-get install wireguard
    elif [[ "$install_wireguard" == 2 ]]; then
      # If chosen NOT to install, move along
      echo -e "
      Understood, moving on with the script."
    fi
  fi
##############################
##############################

########### ARCH OR MANJARO ###########
#######################################
elif [[ "$distro" == "arch" ]] || [[ "$distro" == "manjaro" ]]; then
  check_if_wg_installed=$(pacman -Qe | grep -i -c wireguard-tools)
  # If WireGuard is NOT installed, offer to instal
  if [[ "$check_if_wg_installed" == 0 ]]; then
    echo "
    OS Type: $distro
    Wireguard-Tools: NOT installed

    Would you like to have Wireguard installed?

    ${BWhite}1 = yes, 2 = no${Color_Off}"
    read -r install_wireguard
    if [[ "$install_wireguard" == 1 ]]; then
      # If chosen to install, proceed with installation
      pacman -Syyy
      pacman -S wireguard-dkms wireguard-tools --noconfirm
    elif [[ "$install_wireguard" == 2 ]]; then
      # If chosen NOT to install, move along
      echo -e "
      Understood, moving on with the script."
    fi
  fi
#######################################
#######################################

########### CENTOS ###########
##############################
elif [[ "$distro" == "centos" ]]; then
  check_if_wg_installed=$(yum list installed | grep -i -c wireguard-tools)
  # If WireGuard is NOT installed, offer to instal
  if [[ "$check_if_wg_installed" == 0 ]]; then
    echo "
    OS Type: CentOS
    Wireguard-Tools: NOT installed

    Would you like to have Wireguard installed?

    ${BWhite}1 = yes, 2 = no${Color_Off}"
    read -r install_wireguard
    if [[ "$install_wireguard" == 1 ]]; then
      # If chosen to install, proceed with installation
      curl -Lo /etc/yum.repos.d/wireguard.repo https://copr.fedorainfracloud.org/coprs/jdoss/wireguard/repo/epel-7/jdoss-wireguard-epel-7.repo
      yum install epel-release
      yum install wireguard-dkms wireguard-tools
    elif [[ "$install_wireguard" == 2 ]]; then
      # If chosen NOT to install, move along
      echo -e "
      Understood, moving on with the script."
    fi
  fi
##############################
##############################

########### Fedora ###########
##############################
elif [[ "$distro" == "fedora" ]]; then
  check_if_wg_installed=$(dnf list installed | grep -i -c wireguard-tools)
  # If WireGuard is NOT installed, offer to instal
  if [[ "$check_if_wg_installed" == 0 ]]; then
    echo "
    OS Type: Fedora
    Wireguard-Tools: NOT installed

    Would you like to have Wireguard installed?

    ${BWhite}1 = yes, 2 = no${Color_Off}"
    read -r install_wireguard
    if [[ "$install_wireguard" == 1 ]]; then
      # If chosen to install, proceed with installation
      dnf copr enable jdoss/wireguard
      dnf install wireguard-dkms wireguard-tools
    elif [[ "$install_wireguard" == 2 ]]; then
      # If chosen NOT to install, move along
      echo -e "
      Understood, moving on with the script."
    fi
  fi
##############################
##############################

########### Debian ###########
##############################
elif [[ "$distro" == "debian" ]]; then
  check_if_wg_installed=$(dpkg-query -l | grep -i -c wireguard-tools)
  # If WireGuard is NOT installed, offer to instal
  if [[ "$check_if_wg_installed" == 0 ]]; then
    echo "
    OS Type: Debian
    Wireguard-Tools: NOT installed

    Would you like to have Wireguard installed?

    ${BWhite}1 = yes, 2 = no${Color_Off}"
    read -r install_wireguard
    if [[ "$install_wireguard" == 1 ]]; then
      # If chosen to install, proceed with installation
      echo "deb http://deb.debian.org/debian/ unstable main" >/etc/apt/sources.list.d/unstable.list
      printf 'Package: *\nPin: release a=unstable\nPin-Priority: 90\n' >/etc/apt/preferences.d/limit-unstable
      apt update
      apt install wireguard
    elif [[ "$install_wireguard" == 2 ]]; then
      # If chosen NOT to install, move along
      echo -e "
      Understood, moving on with the script."
    fi
  fi
##############################
##############################
fi
############### FINISHED CHECKING OS AND OFFER TO INSTALL WIREGUARD ###############

echo -e "
${IWhite} This script will perform a quick server setup with minimal user input.

The following will be auto-configured:
1) Listen port: UDP ${BRed}$server_listen_port ${IWhite}
2) Server public / private keys
3) Server private IP of ${BRed}$server_private_range/24${IWhite}
4) Two clients (client_1.conf,client_2.conf) each with a public / private key; clients will have IPs of ${BRed}$client_private_address_1/32${IWhite} and ${BRed}$client_private_address_2/32${IWhite}
5) Server PostUp: iptables -A FORWARD -i ${BRed}$config_file_name${IWhite} -j ACCEPT; iptables -t nat -A POSTROUTING $local_interface -j MASQUERADE; ip6tables -A FORWARD -i ${BRed}$config_file_name${IWhite} -j ACCEPT; ip6tables -t nat -A POSTROUTING $local_interface -j MASQUERADE
6) Server PostDown: iptables -D FORWARD -i ${BRed}$config_file_name${IWhite} -j ACCEPT; iptables -t nat -D POSTROUTING $local_interface -j MASQUERADE; ip6tables -D FORWARD -i ${BRed}$config_file_name${IWhite} -j ACCEPT; ip6tables -t nat -D POSTROUTING $local_interface -j MASQUERADE
7) Clients will use Cloudflare public DNS of ${BRed}$client_dns${IWhite}
8) Server config ${BRed}/etc/wireguard/$config_file_name.conf${IWhite}
9) Tunnel interface ${BRed}$config_file_name${IWhite} will be enabled and service configured to enable at startup.
-----------------------------------------------------------------------
${IYellow}chown -v root:root ${BRed}/etc/wireguard/$config_file_name.conf${IYellow}
chmod -v 600 ${BRed}/etc/wireguard/$config_file_name.conf${IYellow}
wg-quick up ${BRed}$config_file_name${IYellow}
systemctl enable wg-quick@${BRed}${IYellow}$config_file_name.service${Color_Off}
-----------------------------------------------------------------------

================================================
For Arch, Debian, Fedora, Manjaro and Ubuntu
================================================
${IWhite}10) iptables:${Color_Off}
# Track VPN connection
${IYellow}iptables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT${Color_Off}

# Allow incoming traffic on a specified port
${IYellow}iptables -A INPUT -p udp -m udp --dport ${BRed}$server_listen_port ${IYellow}-m conntrack --ctstate NEW -j ACCEPT${Color_Off}

#Forward packets in the VPN tunnel
${IYellow}iptables -A FORWARD -i ${BRed}$config_file_name${IYellow} -o ${BRed}$config_file_name ${IYellow}-m conntrack --ctstate NEW -j ACCEPT${Color_Off}

# Enable NAT
${IYellow}iptables -t nat -A POSTROUTING -s ${BRed}$server_subnet ${IYellow}$local_interface -j MASQUERADE${Color_Off}

In addition to setting up iptables, the following commands will be executed:

# Enabling IP forwarding
# In /etc/sysctl.conf, net.ipv4.ip_forward value will be changed to 1:
${IYellow}net.ipv4.ip_forward=1${Color_Off}

#To avoid the need to reboot the server
${IYellow}sysctl -p${Color_Off}

================================================
For CentOS
================================================

The following firewall rules will be configured:${Color_Off}

${IYellow}
firewall-cmd --zone=public --add-port=$listen_port/udp
firewall-cmd --zone=trusted --add-source=$server_subnet
firewall-cmd --permanent --zone=public --add-port=$listen_port/udp
firewall-cmd --permanent --zone=trusted --add-source=$server_subnet
firewall-cmd --direct --add-rule ipv4 nat POSTROUTING 0 -s $server_subnet ! -d $server_subnet -j SNAT --to $server_public_address
firewall-cmd --permanent --direct --add-rule ipv4 nat POSTROUTING 0 -s $server_subnet ! -d $server_subnet -j SNAT --to $server_public_address
${Color_Off}

# Enabling IP forwarding
# In /etc/sysctl.conf, net.ipv4.ip_forward value will be changed to 1:
${IYellow}net.ipv4.ip_forward=1${Color_Off}

#To avoid the need to reboot the server
${IYellow}sysctl -p${Color_Off}
"

echo -e "$my_separator"

read -n 1 -s -r -p "
Review the above commands.

Press any key to continue or CTRL+C to stop."
echo -e "$my_separator"
echo -e "
${IWhite}The public IP address of this machine is $check_pub_ip. Is this the address you would like to use? ${Color_Off}

${BWhite}1 = yes, 2 = no${Color_Off}"
read -r public_address
if [[ "$public_address" == 1 ]]; then
  server_public_address="$check_pub_ip"
elif [[ "$public_address" == 2 ]]; then
  echo -e "
  ${IWhite}Please specify the public address of the server.${Color_Off}"
  read -r server_public_address
fi

echo -e "$my_separator"

echo -e "
${BWhite}Review the above. Do you wish to proceed? (y/n)${Color_Off}"

read -r proceed_quick_setup

case "$proceed_quick_setup" in
#########################################################################
#                          CASE ANSWER y/Y STARTS                       #
#########################################################################
"y" | "Y")
  # Generating server keys
  echo -e "
  ${BGreen}Generating server keys${Color_Off}"
  sleep 1
  wg genkey | tee "$my_working_dir"/keys/ServerPrivatekey | wg pubkey >"$my_working_dir"/keys/ServerPublickey
  chmod 600 "$my_working_dir"/keys/ServerPrivatekey && chmod 600 "$my_working_dir"/keys/ServerPublickey
  sever_private_key_output=$(cat "$my_working_dir"/keys/ServerPrivatekey)
  sever_public_key_output=$(cat "$my_working_dir"/keys/ServerPublickey)
  # Generating server config
  sleep 1
  echo -e "
  ${BGreen}Generating server config${Color_Off}"
  new_server_config=$(echo -e "
  [Interface]
  Address = $server_private_range
  SaveConfig = true
  PostUp = iptables -A FORWARD -i $config_file_name -j ACCEPT; iptables -t nat -A POSTROUTING $local_interface -j MASQUERADE; ip6tables -A FORWARD -i $config_file_name -j ACCEPT; ip6tables -t nat -A POSTROUTING $local_interface -j MASQUERADE
  PostDown = iptables -D FORWARD -i $config_file_name -j ACCEPT; iptables -t nat -D POSTROUTING $local_interface -j MASQUERADE; ip6tables -D FORWARD -i $config_file_name -j ACCEPT; ip6tables -t nat -D POSTROUTING $local_interface -j MASQUERADE
  ListenPort = $server_listen_port
  PrivateKey = $sever_private_key_output
  ")
  # Saving server config
  sleep 1
  echo -e "
  ${BGreen}Saving server config${Color_Off}"
  echo "$new_server_config" >"$config_file_name".txt && echo "$new_server_config" >/etc/wireguard/"$config_file_name".conf
  # Generating client keys
  for ((i = 1; i <= "$number_of_clients"; i++)); do
    wg genkey | tee "$my_working_dir"/keys/client_"$i"_Privatekey | wg pubkey >"$my_working_dir"/keys/client_"$i"_Publickey

    chmod 600 "$my_working_dir"/keys/client_"$i"_Privatekey
    chmod 600 "$my_working_dir"/keys/client_"$i"_Publickey

    client_private_key_1=$(cat "$my_working_dir"/keys/client_1_Privatekey)
    client_private_key_2=$(cat "$my_working_dir"/keys/client_2_Privatekey)
    client_public_key_1=$(cat "$my_working_dir"/keys/client_1_Publickey)
    client_public_key_2=$(cat "$my_working_dir"/keys/client_2_Publickey)
  done
  # Generating client 1 config
  sleep 1
  echo -e "
${BGreen}Generating client 1 config${Color_Off}"
  echo "
[Interface]
Address = $client_private_address_1
PrivateKey = $client_private_key_1
DNS = $client_dns

[Peer]
PublicKey = $sever_public_key_output
Endpoint = $server_public_address:$server_listen_port
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 21" >"$my_working_dir"/client_configs/client_1.conf

  # Generating client 1 config
  sleep 1
  echo -e "
${BGreen}Generating client 2 config${Color_Off}"
  echo "
[Interface]
Address = $client_private_address_2
PrivateKey = $client_private_key_2
DNS = $client_dns

[Peer]
PublicKey = $sever_public_key_output
Endpoint = $server_public_address:$server_listen_port
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 21" >"$my_working_dir"/client_configs/client_2.conf

  # Adding client 1 info to the server config
  sleep 1
  echo -e "
  ${BGreen}Adding client 1 info to the server config${Color_Off}"
  echo -e "
[Peer]
PublicKey = $client_public_key_1
AllowedIPs = $client_private_address_1/32
" >>/etc/wireguard/"$config_file_name".conf

  # Adding client 2 info to the server config
  sleep 1
  echo -e "
${BGreen}Adding client 2 info to the server config${Color_Off}"
  echo -e "
[Peer]
PublicKey = $client_public_key_2
AllowedIPs = $client_private_address_2/32
" >>/etc/wireguard/"$config_file_name".conf
  ####### ENABLE wg_0 INTERFACE AND SERVICE  BEGINS #######
  sleep 1
  echo -e "
  ${BGreen}ENABLE wg_0 INTERFACE AND SERVICE${Color_Off}"
  chown -v root:root /etc/wireguard/"$config_file_name".conf
  chmod -v 600 /etc/wireguard/"$config_file_name".conf
  wg-quick up "$config_file_name"
  systemctl enable wg-quick@"$config_file_name".service
  ####### ENABLE wg_0 INTERFACE AND SERVICE  ENDS #######

  ####### IPTABLES BEGIN #######
  sleep 1
  echo -e "
  ${BGreen}Configuring iptables and IP forwarding${Color_Off}"
  sed -i 's/net.ipv4.ip_forward=0/net.ipv4.ip_forward=1/g' /etc/sysctl.conf
  sed -i 's/#net.ipv4.ip_forward=0/net.ipv4.ip_forward=1/g' /etc/sysctl.conf
  sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g' /etc/sysctl.conf
  sysctl -p

  iptables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
  iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
  iptables -A INPUT -p udp -m udp --dport "$server_listen_port" -m conntrack --ctstate NEW -j ACCEPT
  iptables -A FORWARD -i "$config_file_name" -o "$config_file_name" -m conntrack --ctstate NEW -j ACCEPT
  iptables -t nat -A POSTROUTING -s "$server_subnet" "$local_interface" -j MASQUERADE
  ####### IPTABLES END #######

  sleep 2
  echo -e "${BPurple}
* Server config was generated: /etc/wireguard/wg_0.conf
* Client configs are available in $my_working_dir/client_configs/
* Client info has been added to the server config
* Server/client keys have been saved in $my_working_dir/keys/
* Interface $config_file_name was enabled and service configured
* iptables were configured and IP forwarding was enables ${Color_Off}
"

  if [[ "$distro" != "centos" ]]; then
    echo -e "
  ${IWhite} Netfilter iptables rules will need to be saved to persist after reboot.

  ${BWhite} Save rules now?
  1 = yes, 2 = no${Color_Off}
  "
    read -r save_netfilter
    if [[ "$save_netfilter" == 1 ]]; then
      if [[ "$distro" == "ubuntu" ]] || [[ "$distro" == "debian" ]]; then
        echo -e "
      ${IWhite}In order to make the above iptables rules persistent after system reboot,
      ${BRed}iptables-persistent ${IWhite} package needs to be installed.

      Would you like the script to install iptables-persistent and to enable the service?

      ${IWhite}Following commands would be used:


      ${IYellow}apt-get install iptables-persistent
      systemctl enable netfilter-persistent
      netfilter-persistent save${Color_Off}"

        read -n 1 -s -r -p "
      Review the above commands.

      Press any key to continue or CTRL+C to stop."

        apt-get install iptables-persistent
        systemctl enable netfilter-persistent
        netfilter-persistent save
      elif [[ "$distro" == "fedora" ]]; then
        echo -e "
      ${IWhite}In order to make the above iptables rules persistent after system reboot,
      netfilter rules will need to be saved.

      Would you like the script to save the netfilter rules?

      ${IWhite}Following commands would be used:


      ${IYellow}/sbin/service iptables save${Color_Off}"
        read -n 1 -s -r -p "
      Review the above commands.

      Press any key to continue or CTRL+C to stop."

        /sbin/service iptables save

      elif [[ "$distro" == "arch" ]] || [[ "$distro" == "manjaro" ]]; then
        echo -e "
      ${IWhite}In order to make the above iptables rules persistent after system reboot,
      netfilter rules will need to be saved.

      Would you like the script to save the netfilter rules?

      ${IWhite}Following commands would be used:

      # Check if iptables.rules file exists and create if needed
      ${IYellow}check_iptables_rules=\$(ls /etc/iptables/ | grep -c iptables.rules)
      if [[ \$check_iptables_rules == 0 ]]; then
        touch /etc/iptables/iptables.rules
      fi

      systemctl enable iptables.service
      systemctl start iptables.service
      iptables-save > /etc/iptables/iptables.rules
      systemctl restart iptables.service
      ${Color_Off}
      "
        read -n 1 -s -r -p "
      Review the above commands.

      Press any key to continue or CTRL+C to stop."

        check_iptables_rules=$(ls /etc/iptables/ | grep -c iptables.rules)
        if [[ "$check_iptables_rules" == 0 ]]; then
          touch /etc/iptables/iptables.rules
        fi
        systemctl enable iptables.service
        systemctl start iptables.service
        iptables-save >/etc/iptables/iptables.rules
        systemctl restart iptables.service
      fi
    elif [[ "$save_netfilter" == 2 ]]; then
      echo -e "${BRed}
    TODO:
    * Add configurations to the client devices.
      * For mobile devices, 'qrencode' can be used${Color_Off}"
    fi
  else
    echo -e "${BRed}
  TODO:
  * Add configurations to the client devices.
    * For mobile devices, qrencode can be used${Color_Off}"
  fi

  #########################################################################
  #                          CASE ANSWER y/Y ENDS                         #
  #########################################################################
  ;;
"n" | "N")
  echo -e "
  Ending the script...."
  exit
  ;;
*)
  echo -e "${BRed}Sorry, wrong choise. Rerun the script and try again${Color_Off}"
  exit
  ;;
esac
