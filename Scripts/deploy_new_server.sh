#!/usr/bin/env bash

if [ "$EUID" -ne 0 ]; then
  echo -e "Please run the script as root."
  exit 1
fi

echo "+--------------------------------------------+"
my_wgl_folder=$(find /home -ignore_readdir_race -type d -name WireGuard-Ligase)
my_working_dir=$(pwd)
check_pub_ip=$(curl -s https://checkip.amazonaws.com)

source "$my_wgl_folder"/doc/functions.sh
# Setting the colours function
colours

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

printf '\e[2J\e[H'

echo -e "This script will take you through the steps needed to deploy a new server
and configure some clients.

First, let's check if wireguard is installed..."

############## Determine OS Type ##############
# see /doc/functions.sh for more info
###############################################
determine_os
############### FINISHED CHECKING OS AND OFFER TO INSTALL WIREGUARD ###############

# Private address could be any address within RFC 1918, usually the first useable address in a /24 range. This however is completely up to you.
echo -e "
${BWhite}Step 1)${Color_Off} ${IWhite}Please specify the private address of the WireGuard server.${Color_Off}"
read -r -p "Address: " server_private_range

printf '\e[2J\e[H'

# This would be a UDP port the WireGuard server would listen on.
echo -e "
+--------------------------------------------+
${BWhite}Server private address = ${BRed}$server_private_range${Color_Off}
+--------------------------------------------+

${BWhite}Step 2)${Color_Off} ${IWhite}Please specify listen port of the server.${Color_Off}"
read -r -p "Listen port: " server_listen_port

printf '\e[2J\e[H'

# Public IP address of the server hosting the WireGuard server
echo -e "
+--------------------------------------------+
${BWhite}Server private address = ${BRed}$server_private_range${Color_Off}
${BWhite}Server listen port = ${BRed}$server_listen_port${Color_Off}
+--------------------------------------------+

${BWhite}Step 3)${Color_Off} ${IWhite}The public IP address of this machine is $check_pub_ip. 
Is this the address you would like to use? ${Color_Off}

${BWhite}1 = yes, 2 = no${Color_Off}"
read -r -p "Choice: " public_address

echo "+--------------------------------------------+"

if [[ "$public_address" == 1 ]]; then
  server_public_address="$check_pub_ip"
elif [[ "$public_address" == 2 ]]; then
  echo -e "
${IWhite}Please specify the public address of the server.${Color_Off}
"
  read -r -p "Public IP: " server_public_address
  echo "+--------------------------------------------+"
fi

printf '\e[2J\e[H'

# Internet facing iface of the server hosting the WireGuard server
echo -e "
+--------------------------------------------+
${BWhite}Server private address = ${BRed}$server_private_range${Color_Off}
${BWhite}Server listen port = ${BRed}$server_listen_port${Color_Off}
${BWhite}Server public address = ${BRed}$server_public_address${Color_Off}
+--------------------------------------------+

${BWhite}Step 4)${IWhite} Please also provide the internet facing interface of the server. 
${BWhite}Example: ${BRed}eth0${Color_Off}

Available interfaces are:
+--------------------+
$(ip -br a | awk '{print $1}')
+--------------------+
"

read -r -p "Interface: " local_interface

printf '\e[2J\e[H'

echo -e "
+--------------------------------------------+
${BWhite}Server private address = ${BRed}$server_private_range${Color_Off}
${BWhite}Server listen port = ${BRed}$server_listen_port${Color_Off}
${BWhite}Server public address = ${BRed}$server_public_address${Color_Off}
${BWhite}WAN interface = ${BRed}$local_interface${Color_Off}
+--------------------------------------------+
"

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

echo -e "
+--------------------------------------------+
${BWhite}Server private address = ${BRed}$server_private_range${Color_Off}
${BWhite}Server listen port = ${BRed}$server_listen_port${Color_Off}
${BWhite}Server public address = ${BRed}$server_public_address${Color_Off}
${BWhite}WAN interface = ${BRed}$local_interface${Color_Off}
+--------------------------------------------+
"

# This would be the private and public keys of the server. If you are using this script, chances are those have not yet been generated yet.
echo -e "
${IWhite}Do you need to generate server keys?${Color_Off} 
(If you have not yet configured the server, the probably yes).

${BWhite}1 = yes, 2 = no${Color_Off}
"
read -r -p "Choice: " generate_server_key
echo "+--------------------------------------------+"

if [[ "$generate_server_key" == 1 ]]; then
  wg genkey | tee "$my_working_dir"/keys/ServerPrivatekey | wg pubkey >"$my_working_dir"/keys/ServerPublickey
  chmod 600 "$my_working_dir"/keys/ServerPrivatekey && chmod 600 "$my_working_dir"/keys/ServerPublickey

# The else statement assumes the user already has server keys,
# hence the option to generate them was not chosen.
# For the script to generate a server config, the user is asked
# to provide public/private key pair for the server.

else
  echo -e "
${IWhite}Specify server private key.${Color_Off}
"
  read -r -p "Server private key: " server_private_key
  echo -e "$server_private_key" >"$my_working_dir"/keys/ServerPrivatekey
  echo "+--------------------------------------------+"
  echo -e "
${IWhite}Specify server public key.${Color_Off}
"
  read -r -p "Server public key: " server_public_key
  echo -e "$server_public_key" >"$my_working_dir"/keys/ServerPublickey
  chmod 600 "$my_working_dir"/keys/ServerPrivatekey && chmod 600 "$my_working_dir"/keys/ServerPrivatekey
  echo "+--------------------------------------------+"

fi

sever_private_key_output=$(cat "$my_working_dir"/keys/ServerPrivatekey)
sever_public_key_output=$(cat "$my_working_dir"/keys/ServerPublickey)

echo -e "
${IWhite}Specify wireguard server interface name 
(will be the same as config name, without .conf)${Color_Off}
"

read -r -p "WireGuard Interface: " wg_serv_iface

printf '\e[2J\e[H'

echo -e "
+--------------------------------------------+
${BWhite}Server private address = ${BRed}$server_private_range${Color_Off}
${BWhite}Server listen port = ${BRed}$server_listen_port${Color_Off}
${BWhite}Server public address = ${BRed}$server_public_address${Color_Off}
${BWhite}WAN interface = ${BRed}$local_interface${Color_Off}
${BWhite}WireGuard interface = ${BRed}$wg_serv_iface${Color_Off}
+--------------------------------------------+
"

echo -e "
Generating server config file...."

sleep 2

new_server_config=$(echo -e "
[Interface]
Address = $server_private_range
SaveConfig = true
PostUp = iptables -A FORWARD -i $wg_serv_iface -j ACCEPT; iptables -t nat -A POSTROUTING -o $local_interface -j MASQUERADE; ip6tables -A FORWARD -i $wg_serv_iface -j ACCEPT; ip6tables -t nat -A POSTROUTING -o $local_interface -j MASQUERADE
PostDown = iptables -D FORWARD -i $wg_serv_iface -j ACCEPT; iptables -t nat -D POSTROUTING -o $local_interface -j MASQUERADE; ip6tables -D FORWARD -i $wg_serv_iface -j ACCEPT; ip6tables -t nat -D POSTROUTING -o $local_interface -j MASQUERADE
ListenPort = $server_listen_port
PrivateKey = $sever_private_key_output
  ")

echo -e "$new_server_config" >"$my_wgl_folder"/"$wg_serv_iface".conf
chmod 600 "$my_wgl_folder"/"$wg_serv_iface".conf

echo -e "Server config has been written to a file $my_wgl_folder/$wg_serv_iface.conf"
echo "+--------------------------------------------+"

sleep 2

echo -e "
${IWhite}Save config to /etc/wireguard/?${Color_Off}

NOTE: ${UWhite}Choosing to save the config under the same file-name as
an existing config will ${BRed}overrite it.${Color_Off}

This script will check if a config file with the same name already
exists. It will back the existing config up before overriting it.
+--------------------------------------------+

Save config: ${BWhite}1 = yes, 2 = no${Color_Off}

"

check_for_existing_config=$(ls /etc/wireguard/ | grep -c "$wg_serv_iface".conf)

read -r -p "Choice: " save_server_config

# The if statement checks whether a config with the same filename already exists.
# If it does, the falue will always be less than zero, hence it needs to be backed up.
if [[ "$save_server_config" == 1 ]] && [[ "$check_for_existing_config" == 1 ]]; then
  echo -e "
  !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    Found existing config file with the same name. Backing up to /etc/wireguard/$wg_serv_iface.conf.bak
  !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
  sleep 2
  mv /etc/wireguard/"$wg_serv_iface".conf /etc/wireguard/"$wg_serv_iface".conf.bak
  sleep 1
  echo -e "$new_server_config" >/etc/wireguard/"$wg_serv_iface".conf
  printf '\e[2J\e[H'
  echo -e "
Congrats! Server config is ready and saved to
/etc/wireguard/$wg_serv_iface.conf. The config is shown below."
elif [[ "$save_server_config" == 1 ]] && [[ "$check_for_existing_config" == 0 ]]; then
  echo -e "$new_server_config" >/etc/wireguard/"$wg_serv_iface".conf
  printf '\e[2J\e[H'
  echo -e "
Congrats! Server config is ready and saved to
/etc/wireguard/$wg_serv_iface.conf. The config is shown below."
elif [[ "$save_server_config" == 2 ]]; then
  printf '\e[2J\e[H'
  echo -e "
Understood! Server config copy 
is located in $my_wgl_folder/server_config.txt.

The config is shown below."
fi

echo -e "

  ${IYellow}$new_server_config${Color_Off}

"
echo "+--------------------------------------------+"

echo -e "
${IWhite}Configure clients?${Color_Off}
${BWhite}1=yes, 2=no${Color_Off}"

read -r -p "Choice: " client_config_answer
echo "+--------------------------------------------+"

if [[ "$client_config_answer" == 1 ]]; then
  printf '\e[2J\e[H'
  echo -e "
${IWhite}How many clients would you like to configure?${Color_Off}
  "
  read -r -p "Number of clients: " number_of_clients

  echo "+--------------------------------------------+"

  echo -e "
${IWhite}Specify the DNS server your clients will use.${Color_Off}
  "
  # This would usually be a public DNS server, for example 1.1.1.1,
  # 8.8.8.8, etc.
  read -r -p "DNS server: " client_dns
  printf '\e[2J\e[H'
  echo -e "
Next steps will ask to provide 
private address and a name for each client, one at a time.
  "
  echo "+--------------------------------------------+"
  # Private address would be within the RFC 1918 range of the server.
  # For example if the server IP is 10.10.10.1/24, the first client
  # would usually have an IP of 10.10.10.2; though this can be any
  # address as long as it's within the range specified for the server.
  for ((i = 1; i <= "$number_of_clients"; i++)); do
    echo -e "
${IWhite}Private address of client # $i (do NOT include /32):${Color_Off}
    "
    read -r -p "Client $i IP: " client_private_address_[$i]
    # Client name can be anything, mainly to easily identify the device
    # to be used. Some exampmles are:
    # Tom_iPhone
    # Wendy_laptop

    echo "+--------------------------------------------+"

    echo -e "
${IWhite}Provide the name of the client # $i ${Color_Off}
    "
    read -r -p "Client $i name: " client_name_[$i]

    echo "+--------------------------------------------+"

    wg genkey | tee "$my_working_dir"/keys/"${client_name_["$i"]}"Privatekey | wg pubkey >"$my_working_dir"/keys/"${client_name_["$i"]}"Publickey

    chmod 600 "$my_working_dir"/keys/"${client_name_["$i"]}"Privatekey
    chmod 600 "$my_working_dir"/keys/"${client_name_["$i"]}"Publickey

    client_private_key_["$i"]=$(cat "$my_working_dir"/keys/"${client_name_["$i"]}"Privatekey)
    client_public_key_["$i"]=$(cat "$my_working_dir"/keys/"${client_name_["$i"]}"Publickey)

    echo -e "
[Interface]
Address = ${client_private_address_["$i"]}
PrivateKey = ${client_private_key_["$i"]}
DNS = $client_dns

[Peer]
PublicKey = $sever_public_key_output
Endpoint = $server_public_address:$server_listen_port
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 21" >"$my_working_dir"/client_configs/"${client_name_["$i"]}".conf
    printf '\e[2J\e[H'
  done
  echo -e "
Awesome!
Client config files were saved to ${IWhite}$my_working_dir/client_configs/${Color_Off}"
else
  echo "+--------------------------------------------+"
  echo -e "${IWhite}Before ending this script, 
  would you like to setup firewall rules for the new server? (recommended)${Color_Off}

  ${BWhite}1 = yes, 2 = no${Color_Off}
  "
  read -r -p "Choice: " iptables_setup
  if [[ "$iptables_setup" == 1 ]]; then
    sudo bash "$my_wgl_folder"/Scripts/setup_iptables.sh
  else
    echo -e "Sounds good. Ending the scritp..."
    exit
  fi
fi
echo -e "
${IWhite}If you've got qrencode installed, the script can generate QR codes for
the client configs.

Would you like to have QR codes generated?

1= yes, 2 = no${Color_Off}"

read -r -p "Choice: " generate_qr_code

if [[ "$generate_qr_code" == 1 ]]; then
  for q in $(seq 1 "$number_of_clients"); do
    echo -e "${BRed}${client_name_[$i]}${Color_Off}
    "
    qrencode -t ansiutf8 <"$my_working_dir"/client_configs/"${client_name_["$q"]}".conf
    echo "+--------------------------------------------+"
  done
elif [[ "$generate_qr_code" == 2 ]]; then
  echo -e "
Alright.. Moving on!
+--------------------------------------------+"
else
  echo -e "Sorry, wrong choice! Moving on with the script."
fi

echo -e "
${IWhite}Would you like to add client info to the server config now?${Color_Off}

${BWhite}1 = yes, 2 = no${Color_Off}"
read -r -p "Choice: " configure_server_with_clients

# If you chose to add client info to the server config AND to save the server config
# to /etc/wireguard/, then the script will add the clients to that config
if [[ "$configure_server_with_clients" == 1 ]]; then
  for a in $(seq 1 "$number_of_clients"); do
    echo -e "
[Peer]
PublicKey = ${client_public_key_["$a"]}
AllowedIPs = ${client_private_address_["$a"]}/32
" >>/etc/wireguard/"$wg_serv_iface".conf
  done
elif [[ "$configure_server_with_clients" == 2 ]]; then
  echo -e "
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

echo -e "-----------------"

# This assumes the WireGuard is already installed on the server.
# The script checks is there is config in /etc/wireguard/, if there is one,
# the value of the grep will be greater than or equal to 1, means it can be used
# to bring up the WireGuard tunnel interface.
echo -e "${IWhite}Almost done! Would you like to bring WireGuard interface up and to enable the service on boot?${Color_Off}

${BWhite}1 = yes, 2 = no${Color_Off}
"

read -r -p "Choice: " enable_on_boot
printf '\e[2J\e[H'
if [[ "$enable_on_boot" == 1 ]]; then
  echo -e "
  ${IYellow}chown -v root:root /etc/wireguard/$wg_serv_iface.conf
  chmod -v 600 /etc/wireguard/$wg_serv_iface.conf
  wg-quick up $wg_serv_iface
  systemctl enable wg-quick@$wg_serv_iface.service${Color_Off}
  "
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
  echo -e "
${IWhite} To manually enable the service and bring tunnel interface up, the following commands can be used:${Color_Off}"
  echo -e "
${IYellow}chown -v root:root /etc/wireguard/$wg_serv_iface.conf
chmod -v 600 /etc/wireguard/$wg_serv_iface.conf
wg-quick up $wg_serv_iface
systemctl enable wg-quick@$wg_serv_iface.service${Color_Off}"
fi

echo -e "
${IWhite}Before ending this script, would you like to setup firewall rules for the new server? (recommended)${Color_Off}

${BWhite}1 = yes, 2 = no${Color_Off}
"
read -r -p "Choice: " iptables_setup
if [[ "$iptables_setup" == 1 ]]; then
  sudo bash "$my_wgl_folder"/Scripts/setup_iptables.sh
else
  echo -e "Sounds good. Ending the script..."
fi
exit
