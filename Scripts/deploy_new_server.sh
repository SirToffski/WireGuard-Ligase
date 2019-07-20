#!/usr/bin/env bash

if [ "$EUID" -ne 0 ]; then
  echo -e "Please run the script as root."
  exit 1
fi

############## Determine OS Type ##############
###############################################
ubuntu_os=$(lsb_release -a | grep -c Ubuntu)
arch_os=$(lsb_release -a | grep -c Arch)
cent_os=$(lsb_release -a | grep -c CentOS)
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

my_wgl_folder=$(find /home -type d -name WireGuard-Ligase)
my_working_dir=$(pwd)
check_pub_ip=$(curl https://checkip.amazonaws.com)

source "$my_wgl_folder"/doc/colours.sh

######################## Pre-checks ##############################
# Check if a directory /keys/ exists, if not, it will be made
check_for_keys_directory=$(ls "$my_working_dir" | grep -c keys)
if [[ "$check_for_keys_directory" == 0 ]]; then
  mkdir keys
fi

# Check if a directory /client_configs/ exists, if not, it will be made
check_for_clients_directory=$(ls "$my_working_dir" | grep -c client_configs)

if [[ "$check_for_clients_directory" == 0 ]]; then
  mkdir client_configs
fi
##################### Pre-checks finished #########################

echo -e "This script will take you through the steps needed to deploy a new server and configure some clients.

First, let's check if wireguard is installed..."

########### UBUNTU ###########
##############################
if [[ "$distro" == "ubuntu" ]]; then
  check_if_wg_installed=$(dpkg-query -l | grep -i -c wireguard-tools)
  # If WireGuard is NOT installed, offer to install
  if [[ "$check_if_wg_installed" == 0 ]]; then
    echo -e "
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
    echo -e "
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
    echo -e "
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
    echo -e "
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
    echo -e "
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

# Private address could be any address within RFC 1918, usually the first useable address in a /24 range. This however is completely up to you.
echo -e "
${BWhite}Step 1)${Color_Off} ${IWhite}Please specify the private address of the WireGuard server.${Color_Off}"
read -r server_private_range

# This would be a UDP port the WireGuard server would listen on.
echo -e "
${BWhite}Step 2)${Color_Off} ${IWhite}Please specify listen port of the server.${Color_Off}"
read -r server_listen_port

# Public IP address of the server hosting the WireGuard server
echo -e "
${BWhite}Step 3)${Color_Off} ${IWhite}The public IP address of this machine is $check_pub_ip. Is this the address you would like to use? ${Color_Off}

${BWhite}1 = yes, 2 = no${Color_Off}"
read -r public_address
if [[ "$public_address" == 1 ]]; then
  server_public_address="$check_pub_ip"
elif [[ "$public_address" == 2 ]]; then
  echo -e "
  ${IWhite}Please specify the public address of the server.${Color_Off}"
  read -r server_public_address
fi

# Internet facing iface of the server hosting the WireGuard server
echo -e "
${BWhite}Step 4)${IWhite}Please also provide the internet facing interface of the server. Can be obrained with ${BRed}ip a ${IWhite}or ${BRed}ifconfig${Color_Off}

${BWhite}Example: ${BRed}eth0${Color_Off}"

echo -e "$my_separator"
read -r local_interface
echo -e "$my_separator"

read -n 1 -s -r -p "
Review the above and press any key to continue"

# This would be the private and public keys of the server. If you are using this script, chances are those have not yet been generated yet.
echo -e "
${IWhite}Do you need to generate server keys?${Color_Off} (If you have not yet configured the server, the probably yes).

${BWhite}1 = yes, 2 = no${Color_Off}
"
read -r generate_server_key

if [[ "$generate_server_key" == 1 ]]; then
  wg genkey | tee "$my_working_dir"/keys/ServerPrivatekey | wg pubkey >"$my_working_dir"/keys/ServerPublickey
  chmod 600 "$my_working_dir"/keys/ServerPrivatekey && chmod 600 "$my_working_dir"/keys/ServerPublickey

# The else statement assumes the user already has server keys,
# hence the option to generate them was not chosen.
# For the script to generate a server config, the user is asked
# to provide public/private key pair for the server.

else
  echo -e "
  ${IWhite}Specify server private key.${Color_Off}"
  read -r server_private_key
  echo "$server_private_key" >"$my_working_dir"/keys/ServerPrivatekey
  echo -e "
  ${IWhite}Specify server public key.${Color_Off}"
  read -r server_public_key
  echo "$server_public_key" >"$my_working_dir"/keys/ServerPublickey
  chmod 600 "$my_working_dir"/keys/ServerPrivatekey && chmod 600 "$my_working_dir"/keys/ServerPrivatekey
fi

sever_private_key_output=$(cat "$my_working_dir"/keys/ServerPrivatekey)
sever_public_key_output=$(cat "$my_working_dir"/keys/ServerPublickey)

echo -e "Specify wireguard server interface name (will be the same as config name, without .conf)"

read -r wg_sev_iface

echo -e "Generating server config file...."

new_server_config=$(echo -e "
[Interface]
Address = $server_private_range
SaveConfig = true
PostUp = iptables -A FORWARD -i $wg_sev_iface -j ACCEPT; iptables -t nat -A POSTROUTING -o $local_interface -j MASQUERADE; ip6tables -A FORWARD -i $wg_sev_iface -j ACCEPT; ip6tables -t nat -A POSTROUTING -o $local_interface -j MASQUERADE
PostDown = iptables -D FORWARD -i $wg_sev_iface -j ACCEPT; iptables -t nat -D POSTROUTING -o $local_interface -j MASQUERADE; ip6tables -D FORWARD -i $wg_sev_iface -j ACCEPT; ip6tables -t nat -D POSTROUTING -o $local_interface -j MASQUERADE
ListenPort = $server_listen_port
PrivateKey = $sever_private_key_output
  ")

echo "$new_server_config" >"$my_working_dir"/server_config.txt
chmod 600 "$my_working_dir"/server_config.txt

echo -e "Server config has been written to a file $my_working_dir/server_config.txt"

echo -e "
${IWhite}Save config to /etc/wireguard/?${Color_Off}

${BWhite}1 = yes, 2 = no${Color_Off}

NOTE: ${UWhite}Choosing to save the config under the same file-name as an existing config will overrite it.${Color_Off}

This script will check if a config file with the same name already exists and will back existing config up before overriting it.
"

check_for_existing_config=$(ls /etc/wireguard/ | grep -c "$wg_sev_iface".conf)

read -r save_server_config

# The if statement checks whether a config with the same filename already exists.
# If it does, the falue will always be less than zero, hence it needs to be backed up.
if [[ "$save_server_config" == 1 ]] && [[ "$check_for_existing_config" -gt 0 ]]; then
  echo "
  !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    Found existing config file with the same name. Backing up to /etc/wireguard/$wg_sev_iface.conf.bak
  !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
  sleep 1
  mv /etc/wireguard/"$wg_sev_iface".conf /etc/wireguard/"$wg_sev_iface".conf.bak
  sleep 1
  echo "$new_server_config" >/etc/wireguard/"$wg_sev_iface".conf
elif [[ "$save_server_config" -eq 1 ]] && [[ "$check_for_existing_config" -eq 0 ]]; then
  sleep 1
  echo "$new_server_config" >/etc/wireguard/"$wg_sev_iface".conf
fi
echo -e "Congrats! Server config is ready and saved to /etc/wireguard/$wg_sev_iface.conf. The config is shown below.

  ------------------------

  ${IYellow}$new_server_config${Color_Off}

  ------------------------
"

echo -e "
${IWhite}Configure clients?${Color_Off}

${BWhite}1=yes, 2=no${Color_Off}"

read -r client_config_answer

if [[ "$client_config_answer" == 1 ]]; then
  echo -e "
${IWhite}How many clients would you like to configure?${Color_Off}
  "
  read -r number_of_clients
  echo -e "
${IWhite}Specify the DNS server your clients will use.${Color_Off}
  "
  # This would usually be a public DNS server, for example 1.1.1.1,
  # 8.8.8.8, etc.
  read -r client_dns
  echo "
Next steps will ask to provide private address and a name for each client, one at a time.
  "
  # Private address would be within the RFC 1918 range of the server.
  # For example if the server IP is 10.10.10.1/24, the first client
  # would usually have an IP of 10.10.10.2; though this can be any
  # address as long as it's within the range specified for the server.
  for ((i = 1; i <= "$number_of_clients"; i++)); do
    echo -e "
${IWhite}Private address of a client (do NOT include /32):${Color_Off}
    "
    read -r client_private_address_[$i]
    # Client name can be anything, mainly to easily identify the device
    # to be used. Some exampmles are:
    # Tom_iPhone
    # Wendy_laptop
    echo -e "
${IWhite}Provide the name of the client${Color_Off}
    "
    read -r client_name_[$i]
    wg genkey | tee "$my_working_dir"/keys/"${client_name_["$i"]}"Privatekey | wg pubkey >"$my_working_dir"/keys/"${client_name_["$i"]}"Publickey

    chmod 600 "$my_working_dir"/keys/"${client_name_["$i"]}"Privatekey
    chmod 600 "$my_working_dir"/keys/"${client_name_["$i"]}"Publickey

    client_private_key_["$i"]=$(cat "$my_working_dir"/keys/"${client_name_["$i"]}"Privatekey)
    client_public_key_["$i"]=$(cat "$my_working_dir"/keys/"${client_name_["$i"]}"Publickey)

    echo "
[Interface]
Address = ${client_private_address_["$i"]}
PrivateKey = ${client_private_key_["$i"]}
DNS = $client_dns

[Peer]
PublicKey = $sever_public_key_output
Endpoint = $server_public_address:$server_listen_port
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 21" >"$my_working_dir"/client_configs/"${client_name_["$i"]}".conf
  done
  echo -e "
Awesome!
Client config files were saved to ${IWhite}$my_working_dir/client_configs/${Color_Off}"
else
  echo -e "
${IWhite}Before ending this script, would you like to setup IPTABLES for the new server?${Color_Off}

${BWhite}1 = yes, 2 = no${Color_Off}
  "
  read -r iptables_setup
  if [[ "$iptables_setup" == 1 ]]; then
    sudo bash setup_iptables.sh
  fi
  echo -e "Ending the script...."
  exit
fi

echo -e "
${IWhite}Would you like to add client info to the server config now?${Color_Off}

${BWhite}1 = yes, 2 = no${Color_Off}"
read -r configure_server_with_clients

# If you chose to add client info to the server config AND to save the server config
# to /etc/wireguard/, then the script will add the clients to that config
if [[ "$configure_server_with_clients" -eq 1 ]] && [[ "$check_for_existing_config" -gt 0 ]]; then
  for a in $(seq 1 "$number_of_clients"); do
    echo "
[Peer]
PublicKey = ${client_public_key_["$a"]}
AllowedIPs = ${client_private_address_["$a"]}/32
" >>/etc/wireguard/"$wg_sev_iface".conf
  done
elif [[ "$configure_server_with_clients" -eq 1 ]] && [[ "$check_for_existing_config" -eq 0 ]]; then
  echo -e "
  ${IWhite}It appears the script is not sure what config file the save client info to Please type the file name without .conf to save the client info to.${Color_Off}
  "
  read -r server_file_for_clients
  for c in $(seq 1 "$number_of_clients"); do
    echo "
[Peer]
PublicKey = ${client_public_key_["$c"]}
AllowedIPs = ${client_private_address_["$c"]}/32
" >>/etc/wireguard/"$server_file_for_clients".conf
  done
# If you chose not to add the client info to the server config at this time,
# the script will show the information which will have to be added to the
# server config manually by the user.
else
  echo "
Alright, you may add the following to a server config file to setup clients.

-----------------
  "
  for d in $(seq 1 "$number_of_clients"); do
    echo -e "${IYellow}
[Peer]
PublicKey = ${client_public_key_["$d"]}
AllowedIPs = ${client_private_address_["$d"]}/32${Color_Off}
"
  done
fi

echo "-----------------"

# This assumes the WireGuard is already installed on the server.
# The script checks is there is config in /etc/wireguard/, if there is one,
# the value of the grep will be greater than or equal to 1, means it can be used
# to bring up the WireGuard tunnel interface.
echo -e "${IWhite}Almost done! Would you like to bring WireGuard interface up and to enable the service on boot?${Color_Off}

${BWhite}1 = yes, 2 = no${Color_Off}
"

read -r enable_on_boot

if [[ "$enable_on_boot" -eq 1 ]] && [[ "$check_for_existing_config" -gt 0 ]]; then
  echo -e "
  ${IYellow}chown -v root:root /etc/wireguard/$wg_sev_iface.conf
  chmod -v 600 /etc/wireguard/$wg_sev_iface.conf
  wg-quick up $wg_sev_iface
  systemctl enable wg-quick@$wg_sev_iface.service${Color_Off}"
  read -n 1 -s -r -p "
  Review the above commands.

  Press any key to continue or CTRL+C to stop."
  chown -v root:root /etc/wireguard/"$wg_sev_iface".conf
  chmod -v 600 /etc/wireguard/"$wg_sev_iface".conf
  wg-quick up "$wg_sev_iface"
  systemctl enable wg-quick@"$wg_sev_iface".service
# Conversely, if the script cannot find the server config in /etc/wireguard/
# the used will be asked to specify the config name
elif [[ "$enable_on_boot" -eq 1 ]] && [[ "$check_for_existing_config" -eq 0 ]]; then
  echo -e "${IWhite} Existing config/interface was not found. Please specify server config filename without .conf part.

  Example: for /etc/wireguard/wg0.conf, type wg0${Color_Off}"
  read -r existing_server_interface
  echo -e "
  ${IYellow}chown -v root:root /etc/wireguard/$existing_server_interface.conf
  chmod -v 600 /etc/wireguard/$existing_server_interface.conf
  wg-quick up $existing_server_interface
  systemctl enable wg-quick@$existing_server_interface.service${Color_Off}"
  read -n 1 -s -r -p "
  Review the above commands.

  Press any key to continue or CTRL+C to stop."
  chown -v root:root /etc/wireguard/"$existing_server_interface".conf
  chmod -v 600 /etc/wireguard/"$existing_server_interface".conf
  wg-quick up "$existing_server_interface"
  systemctl enable wg-quick@"$existing_server_interface".service
# Finally, if the user chose not to enable WireGuard tunnel interface, but the script
# has found a config file which can be used. Then the script will provide the commands
# to issue manually.
elif [[ "$enable_on_boot" == 2 ]] && [[ "$check_for_existing_config" -gt 0 ]]; then
  echo -e "${IWhite} To manually enable the service and bring tunnel interface up, the following commands can be used:${Color_Off}"
  echo -e "
  ${IYellow}chown -v root:root /etc/wireguard/$wg_sev_iface.conf
  chmod -v 600 /etc/wireguard/$wg_sev_iface.conf
  wg-quick up $wg_sev_iface
  systemctl enable wg-quick@$wg_sev_iface.service${Color_Off}"
fi

echo -e "${IWhite}Before ending this script, would you like to setup firewall rules for the new server? (recommended)${Color_Off}

${BWhite}1 = yes, 2 = no${Color_Off}
"
read -r iptables_setup
if [[ "$iptables_setup" == 1 ]]; then
  sudo bash "$my_wgl_folder"/Scripts/setup_iptables.sh
else
  echo "Sounds good. Ending the scritp..."
fi
exit
