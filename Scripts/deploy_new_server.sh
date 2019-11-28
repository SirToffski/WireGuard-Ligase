#!/usr/bin/env bash

if [ "$EUID" -ne 0 ]; then
  printf %b\\n "Please run the script as root."
  exit 1
fi

printf %s\\n "+--------------------------------------------+"
# Default working directory of the script.
## Requirements: Cloning the entire repository.
my_wgl_folder="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. >/dev/null 2>&1 && pwd)"
# A simple check if the entire repo was cloned.
## If not, working directory is a directory of the currently running script.
check_for_full_clone="$my_wgl_folder/configure-wireguard.sh"
if [[ ! -f "$check_for_full_clone" ]]; then
  my_wgl_folder="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
else
  source "$my_wgl_folder"/doc/functions.sh
  # Setting the colours function
  colours
fi

# Determine the public IP of the host.
check_pub_ip=$(curl -s https://checkip.amazonaws.com)

######################## Pre-checks ##############################
# Check if a directory /keys/ exists, if not, it will be made
check_for_keys_directory=$("$my_wgl_folder"/keys)
if [[ ! -d "$check_for_keys_directory" ]]; then
  mkdir -p "$my_wgl_folder"/keys
fi

# Check if a directory /client_configs/ exists, if not, it will be made
check_for_clients_directory=$("$my_wgl_folder"/client_configs)

if [[ ! -d "$check_for_clients_directory" ]]; then
  mkdir -p "$my_wgl_folder"/client_configs
fi
##################### Pre-checks finished #########################

printf '\e[2J\e[H'

printf %b\\n "This script will take you through the steps needed to deploy a new server
and configure some clients."

if [[ -f "$check_for_full_clone" ]]; then
  printf %b\\n "\n First, let's check if wireguard is installed..."

  ############## Determine OS Type ##############
  # see /doc/functions.sh for more info
  ###############################################
  determine_os
  ############### FINISHED CHECKING OS AND OFFER TO INSTALL WIREGUARD ###############
  printf '\e[2J\e[H'
fi

# Private address could be any address within RFC 1918,
# usually the first useable address in a /24 range.
# This however is completely up to you.
printf %b\\n "\n ${BWhite}Step 1)${Color_Off} ${IWhite}Please specify the private address of the WireGuard server.${Color_Off}"
read -r -p "Address: " server_private_range

printf '\e[2J\e[H'

# This would be a UDP port the WireGuard server would listen on.
printf %b\\n "\n+--------------------------------------------+
${BWhite}Server private address = ${BRed}$server_private_range${Color_Off}
+--------------------------------------------+
\n${BWhite}Step 2)${Color_Off} ${IWhite}Please specify listen port of the server.${Color_Off}\n"
read -r -p "Listen port: " server_listen_port

printf '\e[2J\e[H'

# Public IP address of the server hosting the WireGuard server
printf %b\\n "\n+--------------------------------------------+
${BWhite}Server private address = ${BRed}$server_private_range${Color_Off}
${BWhite}Server listen port = ${BRed}$server_listen_port${Color_Off}
+--------------------------------------------+
\n${BWhite}Step 3)${Color_Off} ${IWhite}The public IP address of this machine is $check_pub_ip. 
Is this the address you would like to use? ${Color_Off}
\n${BWhite}1 = yes, 2 = no${Color_Off}"
read -r -p "Choice: " public_address

printf %s\\n "+--------------------------------------------+"

if [[ "$public_address" == 1 ]]; then
  server_public_address="$check_pub_ip"
elif [[ "$public_address" == 2 ]]; then
  printf %b\\n "\n${IWhite}Please specify the public address of the server.${Color_Off}"
  read -r -p "Public IP: " server_public_address
  printf %s\\n "+--------------------------------------------+"
fi

printf '\e[2J\e[H'

# Internet facing iface of the server hosting the WireGuard server
printf %b\\n "\n+--------------------------------------------+
${BWhite}Server private address = ${BRed}$server_private_range${Color_Off}
${BWhite}Server listen port = ${BRed}$server_listen_port${Color_Off}
${BWhite}Server public address = ${BRed}$server_public_address${Color_Off}
+--------------------------------------------+
\n${BWhite}Step 4)${IWhite} Please also provide the internet facing interface of the server. 
${BWhite}Example: ${BRed}eth0${Color_Off}
\n Available interfaces are:
+--------------------+
$(ip -br a | awk '{print $1}')
+--------------------+"

read -r -p "Interface: " local_interface

printf '\e[2J\e[H'

printf %b\\n "\n+--------------------------------------------+
${BWhite}Server private address = ${BRed}$server_private_range${Color_Off}
${BWhite}Server listen port = ${BRed}$server_listen_port${Color_Off}
${BWhite}Server public address = ${BRed}$server_public_address${Color_Off}
${BWhite}WAN interface = ${BRed}$local_interface${Color_Off}
+--------------------------------------------+ \n"

read -n 1 -s -r -p "
Review the above. 
Press any key to continue 
Press r/R to try again
Press e/E to exit
" your_choice

case "$your_choice" in
[Rr]*)
  sudo bash "$my_wgl_folder"/Scripts/deploy_new_server.sh
  ;;
[Ee]*)
  exit
  ;;
*)
  printf '\e[2J\e[H'
  ;;
esac

printf %b\\n "\n+--------------------------------------------+
${BWhite}Server private address = ${BRed}$server_private_range${Color_Off}
${BWhite}Server listen port = ${BRed}$server_listen_port${Color_Off}
${BWhite}Server public address = ${BRed}$server_public_address${Color_Off}
${BWhite}WAN interface = ${BRed}$local_interface${Color_Off}
+--------------------------------------------+"

# This would be the private and public keys of the server.
# If you are using this script, chances are those have not yet been generated yet.

printf %b\\n "\n${IWhite}Do you need to generate server keys?${Color_Off} 
(If you have not yet configured the server, the probably yes).

${BWhite}1 = yes, 2 = no${Color_Off}\n"

read -r -p "Choice: " generate_server_key
printf %s\\n "+--------------------------------------------+"

if [[ "$generate_server_key" == 1 ]]; then
  wg genkey | tee "$my_wgl_folder"/keys/ServerPrivatekey | wg pubkey >"$my_wgl_folder"/keys/ServerPublickey
  chmod 600 "$my_wgl_folder"/keys/ServerPrivatekey && chmod 600 "$my_wgl_folder"/keys/ServerPublickey

# The else statement assumes the user already has server keys,
# hence the option to generate them was not chosen.
# For the script to generate a server config, the user is asked
# to provide public/private key pair for the server.

else
  printf %b\\n "\n${IWhite}Specify server private key.${Color_Off}\n"
  read -r -p "Server private key: " server_private_key
  printf %b\\n "$server_private_key" >"$my_wgl_folder"/keys/ServerPrivatekey
  printf %s\\n "+--------------------------------------------+"
  printf %b\\n "\n${IWhite}Specify server public key.${Color_Off}\n"
  read -r -p "Server public key: " server_public_key
  printf %b\\n "$server_public_key" >"$my_wgl_folder"/keys/ServerPublickey
  chmod 600 "$my_wgl_folder"/keys/ServerPrivatekey && chmod 600 "$my_wgl_folder"/keys/ServerPrivatekey
  printf %s\\n "+--------------------------------------------+"

fi

sever_private_key_output=$(cat "$my_wgl_folder"/keys/ServerPrivatekey)
sever_public_key_output=$(cat "$my_wgl_folder"/keys/ServerPublickey)

printf %b\\n "\n${IWhite}Specify wireguard server interface name 
(will be the same as config name, without .conf)${Color_Off}\n"

read -r -p "WireGuard Interface: " wg_serv_iface

printf '\e[2J\e[H'

printf %b\\n "\n+--------------------------------------------+
${BWhite}Server private address = ${BRed}$server_private_range${Color_Off}
${BWhite}Server listen port = ${BRed}$server_listen_port${Color_Off}
${BWhite}Server public address = ${BRed}$server_public_address${Color_Off}
${BWhite}WAN interface = ${BRed}$local_interface${Color_Off}
${BWhite}WireGuard interface = ${BRed}$wg_serv_iface${Color_Off}
+--------------------------------------------+\n"

printf %b\\n "\n Generating server config file...."

sleep 2

new_server_config=$(printf %b\\n "
[Interface]
Address = $server_private_range
SaveConfig = true
PostUp = iptables -A FORWARD -i $wg_serv_iface -j ACCEPT; iptables -t nat -A POSTROUTING -o $local_interface -j MASQUERADE; ip6tables -A FORWARD -i $wg_serv_iface -j ACCEPT; ip6tables -t nat -A POSTROUTING -o $local_interface -j MASQUERADE
PostDown = iptables -D FORWARD -i $wg_serv_iface -j ACCEPT; iptables -t nat -D POSTROUTING -o $local_interface -j MASQUERADE; ip6tables -D FORWARD -i $wg_serv_iface -j ACCEPT; ip6tables -t nat -D POSTROUTING -o $local_interface -j MASQUERADE
ListenPort = $server_listen_port
PrivateKey = $sever_private_key_output
  ")

printf %b\\n "$new_server_config" >"$my_wgl_folder"/"$wg_serv_iface".conf
chmod 600 "$my_wgl_folder"/"$wg_serv_iface".conf

printf %b\\n "Server config has been written to a file $my_wgl_folder/$wg_serv_iface.conf"
printf %s\\n "+--------------------------------------------+"

sleep 2

printf %b\\n "\n ${IWhite}Save config to /etc/wireguard/?${Color_Off}\n
NOTE: ${UWhite}Choosing to save the config under the same file-name as
an existing config will ${BRed}overrite it.${Color_Off}\n
This script will check if a config file with the same name already
exists. It will back the existing config up before overriting it.
+--------------------------------------------+\n
Save config: ${BWhite}1 = yes, 2 = no${Color_Off}\n"

check_for_existing_config="/etc/wireguard/$wg_serv_iface.conf"

read -r -p "Choice: " save_server_config

# The if statement checks whether a config with the same filename already exists.
# If it does, the falue will always be less than zero, hence it needs to be backed up.
if [[ "$save_server_config" == 1 ]] && [[ -f "$check_for_existing_config" ]]; then
  printf %b\\n "
  !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    Found existing config file with the same name. 
    Backing up to /etc/wireguard/$wg_serv_iface.conf.bak
  !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
  sleep 2
  mv /etc/wireguard/"$wg_serv_iface".conf /etc/wireguard/"$wg_serv_iface".conf.bak
  sleep 1
  printf %b\\n "$new_server_config" >/etc/wireguard/"$wg_serv_iface".conf
  printf '\e[2J\e[H'
  printf %b\\n "\nCongrats! Server config is ready and saved to \n/etc/wireguard/$wg_serv_iface.conf... The config is shown below."
elif [[ "$save_server_config" == 1 ]] && [[ ! -f "$check_for_existing_config" ]]; then
  printf %b\\n "$new_server_config" >/etc/wireguard/"$wg_serv_iface".conf
  printf '\e[2J\e[H'
  printf %b\\n "\nCongrats! Server config is ready and saved to \n/etc/wireguard/$wg_serv_iface.conf... The config is shown below."
elif [[ "$save_server_config" == 2 ]]; then
  printf '\e[2J\e[H'
  printf %b\\n "\nUnderstood! Server config copy \nis located in $my_wgl_folder/server_config.txt.\nThe config is shown below."
fi

printf %b\\n "

  ${IYellow}$new_server_config${Color_Off}

"
printf %s\\n "+--------------------------------------------+"

printf %b\\n "\n${IWhite}Configure clients?${Color_Off}
${BWhite}1=yes, 2=no${Color_Off}"

read -r -p "Choice: " client_config_answer
printf %s\\n "+--------------------------------------------+"

if [[ "$client_config_answer" == 1 ]]; then
  printf '\e[2J\e[H'
  printf %b\\n "\n${IWhite}How many clients would you like to configure?${Color_Off}\n"
  read -r -p "Number of clients: " number_of_clients

  printf %s\\n "+--------------------------------------------+"

  printf %b\\n "\n${IWhite}Specify the DNS server your clients will use.${Color_Off}\n"
  # This would usually be a public DNS server, for example 1.1.1.1,
  # 8.8.8.8, etc.
  read -r -p "DNS server: " client_dns
  printf '\e[2J\e[H'
  printf %b\\n "\nNext steps will ask to provide \nprivate address and a name for each client, one at a time.\n"
  printf %s\\n "+--------------------------------------------+"

  # Private address would be within the RFC 1918 range of the server.
  # For example if the server IP is 10.10.10.1/24, the first client
  # would usually have an IP of 10.10.10.2; though this can be any
  # address as long as it's within the range specified for the server.

  for ((i = 1; i <= "$number_of_clients"; i++)); do
    printf %b\\n "\n${IWhite}Private address of client # $i (do NOT include /32):${Color_Off}\n"
    read -r -p "Client $i IP: " client_private_address_[$i]
    # Client name can be anything, mainly to easily identify the device
    # to be used. Some exampmles are:
    # Tom_iPhone
    # Wendy_laptop

    printf %s\\n "+--------------------------------------------+"

    printf %b\\n "\n${IWhite}Provide the name of the client # $i ${Color_Off}\n"
    read -r -p "Client $i name: " client_name_[$i]

    printf %s\\n "+--------------------------------------------+"

    wg genkey | tee "$my_wgl_folder"/keys/"${client_name_["$i"]}"Privatekey | wg pubkey >"$my_wgl_folder"/keys/"${client_name_["$i"]}"Publickey

    chmod 600 "$my_wgl_folder"/keys/"${client_name_["$i"]}"Privatekey
    chmod 600 "$my_wgl_folder"/keys/"${client_name_["$i"]}"Publickey

    client_private_key_["$i"]=$(cat "$my_wgl_folder"/keys/"${client_name_["$i"]}"Privatekey)
    client_public_key_["$i"]=$(cat "$my_wgl_folder"/keys/"${client_name_["$i"]}"Publickey)

    printf %b\\n "\n[Interface]
Address = ${client_private_address_["$i"]}
PrivateKey = ${client_private_key_["$i"]}
DNS = $client_dns\n
[Peer]
PublicKey = $sever_public_key_output
Endpoint = $server_public_address:$server_listen_port
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 21" >"$my_wgl_folder"/client_configs/"${client_name_["$i"]}".conf
    printf '\e[2J\e[H'
  done
  printf %b\\n "\nAwesome!\nClient config files were saved to ${IWhite}$my_wgl_folder/client_configs/${Color_Off}"
else
  printf %s\\n "+--------------------------------------------+"
  printf %b\\n "${IWhite}Before ending this script,\nwould you like to setup firewall rules for the new server? (recommended)${Color_Off}\n
  ${BWhite}1 = yes, 2 = no${Color_Off}\n"
  read -r -p "Choice: " iptables_setup
  if [[ "$iptables_setup" == 1 ]]; then
    sudo bash "$my_wgl_folder"/Scripts/setup_iptables.sh
  else
    printf %b\\n "Sounds good. Ending the scritp..."
    exit
  fi
fi
printf %b\\n "\n${IWhite}If you've got qrencode installed, the script can generate QR codes for
the client configs.\n\n Would you like to have QR codes generated?
\n1= yes, 2 = no${Color_Off}"

read -r -p "Choice: " generate_qr_code

if [[ "$generate_qr_code" == 1 ]]; then
  for ((q = 1; q <= "$number_of_clients"; q++)); do
    printf %b\\n "${BRed}${client_name_[$q]}${Color_Off}\n"
    qrencode -t ansiutf8 <"$my_wgl_folder"/client_configs/"${client_name_["$q"]}".conf
    printf %s\\n "+--------------------------------------------+"
  done
elif [[ "$generate_qr_code" == 2 ]]; then
  printf %b\\n "\nAlright.. Moving on!\n+--------------------------------------------+"
else
  printf %b\\n "Sorry, wrong choice! Moving on with the script."
fi

printf %b\\n "\n${IWhite}Would you like to add client info to the server config now?${Color_Off}
\n${BWhite}1 = yes, 2 = no${Color_Off}"
read -r -p "Choice: " configure_server_with_clients

# If you chose to add client info to the server config AND to save the server config
# to /etc/wireguard/, then the script will add the clients to that config
if [[ "$configure_server_with_clients" == 1 ]]; then
  for ((a = 1; a <= "$number_of_clients"; a++)); do
    printf %b\\n "\n[Peer]
PublicKey = ${client_public_key_["$a"]}
AllowedIPs = ${client_private_address_["$a"]}/32\n" >>/etc/wireguard/"$wg_serv_iface".conf
  done
elif [[ "$configure_server_with_clients" == 2 ]]; then
  printf %b\\n "\nAlright, you may add the following to a server config file to setup clients.
\n-----------------\n"
  for ((d = 1; d <= "$number_of_clients"; d++)); do
    printf %b\\n "\n${IYellow}[Peer]
PublicKey = ${client_public_key_["$d"]}
AllowedIPs = ${client_private_address_["$d"]}/32${Color_Off}\n"
  done
fi

printf %b\\n "-----------------"

# This assumes the WireGuard is already installed on the server.
# The script checks is there is config in /etc/wireguard/, if there is one,
# the value of the grep will be greater than or equal to 1, means it can be used
# to bring up the WireGuard tunnel interface.
printf %b\\n "${IWhite}Almost done! Would you like to bring WireGuard interface up and to enable the service on boot?${Color_Off}
\n${BWhite}1 = yes, 2 = no${Color_Off}\n"

read -r -p "Choice: " enable_on_boot
printf '\e[2J\e[H'
if [[ "$enable_on_boot" == 1 ]]; then
  printf %b\\n "\n${IYellow}chown -v root:root /etc/wireguard/$wg_serv_iface.conf
  chmod -v 600 /etc/wireguard/$wg_serv_iface.conf
  wg-quick up $wg_serv_iface
  systemctl enable wg-quick@$wg_serv_iface.service${Color_Off}\n"

  read -n 1 -s -r -p "
  Review the above. 
  Press any key to continue 
  Press r/R to restart the script
  Press e/E to exit
  " your_choice

  case "$your_choice" in
  [Rr]*)
    sudo bash "$my_wgl_folder"/Scripts/deploy_new_server.sh
    ;;
  [Ee]*)
    exit
    ;;
  *)
    chown -v root:root /etc/wireguard/"$wg_serv_iface".conf
    chmod -v 600 /etc/wireguard/"$wg_serv_iface".conf
    wg-quick up "$wg_serv_iface"
    systemctl enable wg-quick@"$wg_serv_iface".service
    ;;
  esac
elif [[ "$enable_on_boot" == 2 ]]; then
  printf %b\\n "\n${IWhite} To manually enable the service and bring tunnel interface up, the following commands can be used:${Color_Off}"
  printf %b\\n "\n${IYellow}chown -v root:root /etc/wireguard/$wg_serv_iface.conf
chmod -v 600 /etc/wireguard/$wg_serv_iface.conf
wg-quick up $wg_serv_iface
systemctl enable wg-quick@$wg_serv_iface.service${Color_Off}"
fi

printf %b\\n "\n${IWhite}Before ending this script, would you like to setup firewall rules for the new server? (recommended)${Color_Off}
\n${BWhite}1 = yes, 2 = no${Color_Off}\n"

read -r -p "Choice: " iptables_setup
if [[ "$iptables_setup" == 1 ]]; then
  sudo bash "$my_wgl_folder"/Scripts/setup_iptables.sh
else
  printf %b\\n "Sounds good. Ending the script..."
fi
exit
