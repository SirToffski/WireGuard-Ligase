#!/usr/bin/env bash

my_working_dir=$(pwd)
source "$(find ~ | grep WireGuard-Ligase/doc/colours.sh)"

######################## Pre-checks ##############################
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
##################### Pre-checks finished #########################

echo "This script will take you through the steps needed to deploy a new server and configure some clients."

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
${BWhite}Step 3)${Color_Off} ${IWhite}Specify public IP address of the server.${Color_Off}"
read -r server_public_address

read -n 1 -s -r -p "
Review the above and press any key to continue"

# This would be the private and public keys of the server. If you are using this script, chances are those have not yet been generated yet.
echo -e "
${IWhite}Do you need to generate server keys?${Color_Off} (If you have not yet configured the server, the probably yes).

${BWhite}1 = yes, 2 = no${Color_Off}
"
read -r generate_server_key

if  [[ "$generate_server_key" == 1 ]] ; then
  wg genkey | tee "$my_working_dir"/keys/ServerPrivatekey | wg pubkey > "$my_working_dir"/keys/ServerPublickey
  chmod 600 "$my_working_dir"/keys/ServerPrivatekey && chmod 600 "$my_working_dir"/keys/ServerPublickey

# The else statement assumes the user already has server keys,
# hence the option to generate them was not chosen.
# For the script to generate a server config, the user is asked
# to provide public/private key pair for the server.

else
  echo -e "
  ${IWhite}Specify server private key.${Color_Off}"
  read -r server_private_key
  echo "$server_private_key" > "$my_working_dir"/keys/ServerPrivatekey
  echo -e "
  ${IWhite}Specify server public key.${Color_Off}"
  read -r server_public_key
  echo "$server_public_key" > "$my_working_dir"/keys/ServerPublickey
  chmod 600 "$my_working_dir"/keys/ServerPrivatekey && chmod 600 "$my_working_dir"/keys/ServerPrivatekey
fi

sever_private_key_output=$(cat "$my_working_dir"/keys/ServerPrivatekey)
sever_public_key_output=$(cat "$my_working_dir"/keys/ServerPublickey)

new_server_config=$(echo -e "
[Interface]
Address = $server_private_range
SaveConfig = true
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE; ip6tables -A FORWARD -i wg0 -j ACCEPT; ip6tables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE; ip6tables -D FORWARD -i wg0 -j ACCEPT; ip6tables -t nat -D POSTROUTING -o eth0 -j MASQUERADE
ListenPort = $server_listen_port
PrivateKey = $sever_private_key_output
")

echo "$new_server_config" > server_config.txt
echo -e "Congrats! Server config is ready. The config is shown below. It has also been written to a file server_config.txt

------------------------

${IYellow}$new_server_config${Color_Off}

------------------------

${IWhite}Save config to /etc/wireguard/?${Color_Off}

${BWhite}1 = yes, 2 = no${Color_Off}

NOTE: ${UWhite}Choosing to save the config under the same file-name as an existing config will overrite it.${Color_Off}

This script will check if a config file with the same name already exists and will back existing config up before overriting it.
"

read -r save_server_config
if [[ "$save_server_config" == 1 ]]; then
  echo -e "
  ${IWhite}Provide file name of the config, without the .conf part.${Color_Off}

  Example: wg0
  "
  read -r config_file_name
  check_for_existing_config=$(ls /etc/wireguard/ | grep -c --count "$config_file_name")

  # The if statement checks whether a config with the same filename already exists.
  # If it does, the falue will always be less than zero, hence it needs to be backed up.
  if [[ $save_server_config == 1 ]] && [[ $check_for_existing_config -ge $save_server_config ]]; then
    echo "
    Found existing config file with the same name. Backing up to /etc/wireguard/$config_file_name.conf.bak"

    mv /etc/wireguard/"$config_file_name".conf /etc/wireguard/"$config_file_name".conf.bak
  fi
  echo "$new_server_config" > /etc/wireguard/"$config_file_name".conf
fi

echo -e "
${IWhite}Configure clients?${Color_Off}

${BWhite}1=yes, 2=no"${Color_Off}

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
  for (( i = 1; i <= "$number_of_clients"; i++ )); do
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
    wg genkey | tee "$my_working_dir"/keys/"${client_name_["$i"]}"Privatekey | wg pubkey > "$my_working_dir"/keys/"${client_name_["$i"]}"Publickey

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
PersistentKeepalive = 21" > "$my_working_dir"/client_configs/"${client_name_["$i"]}".conf
  done
else
  echo -e "
Awesome!
Client config files were saved to ${IWhite}$my_working_dir/client_configs/${Color_Off}

${IWhite}Before ending this script, would you like to setup IPTABLES for the new server?${Color_Off}

${BWhite}1 = yes, 2 = no${Color_Off}
  "
  read -r iptables_setup
  if [[ $iptables_setup == 1 ]]; then
    sudo bash setup_iptables.sh
  fi
  exit
fi

echo -e "
${IWhite}Would you like to add client info to the server config now?${Color_Off}

${BWhite}1 = yes, 2 = no${Color_Off}"
read -r configure_server_with_clients
check_server_config_name=$(ls /etc/wireguard/ | grep -c --count wg0.conf)
# If you chose to add client info to the server config AND to save the server config
# to /etc/wireguard/, then the script will add the clients to that config
if [[ $configure_server_with_clients == 1 ]] && [[ $save_server_config == 1 ]]; then
  for a in $(seq 1 "$number_of_clients"); do
    echo "
[Peer]
PublicKey = ${client_public_key_["$a"]}
AllowedIPs = ${client_private_address_["$a"]}/32
" >> /etc/wireguard/"$config_file_name".conf
  done
# If there is already a config wg0.conf in /etc/wireguard/, then the script will back it up
# and will add client info to it
elif [[ $configure_server_with_clients == 1 ]] && [[ $check_server_config_name == 1 ]]; then
  echo "
  Found an existing config file wg0.conf. Backing up the file to /etc/wireguard/wg0.conf.bak and adding client info.
  "
  mv /etc/wireguard/wg0.conf /etc/wireguard/wg0.conf.bak

  for b in $(seq 1 "$number_of_clients"); do
    echo "
[Peer]
PublicKey = ${client_public_key_["$b"]}
AllowedIPs = ${client_private_address_["$b"]}/32
" >> /etc/wireguard/wg0.conf
  done
# If you chose to add client info to the server config and the script is not sure to which
# file the info needs to be added, you will be asked to specify the filename
elif [[  $configure_server_with_clients == 1 ]] && [[ $check_server_config_name == 0 ]]; then
  echo -e "
  ${IWhite}It appears the script is not sure what config file the save client info to Please type the file name without .conf to save the client info to.${Color_Off}
  "
  read -r server_file_for_clients
  for c in $(seq 1 "$number_of_clients"); do
    echo "
[Peer]
PublicKey = ${client_public_key_["$c"]}
AllowedIPs = ${client_private_address_["$c"]}/32
" >> /etc/wireguard/"$server_file_for_clients".conf
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

if [[ $enable_on_boot == 1 ]] && [[ $check_for_existing_config -ge $enable_on_boot ]]; then
  echo -e "
  ${IYellow}chown -v root:root /etc/wireguard/$config_file_name.conf
  chmod -v 600 /etc/wireguard/$config_file_name.conf
  wg-quick up $config_file_name
  systemctl enable wg-quick@$config_file_name.service${Color_Off}"
  read -n 1 -s -r -p "
  Review the above commands.

  Press any key to continue or CTRL+C to stop."
  chown -v root:root /etc/wireguard/"$config_file_name".conf
  chmod -v 600 /etc/wireguard/"$config_file_name".conf
  wg-quick up "$config_file_name"
  systemctl enable wg-quick@"$config_file_name".service
# Conversely, if the script cannot find the server config in /etc/wireguard/
# the used will be asked to specify the config name
elif [[ $enable_on_boot == 1 ]] && [[ $check_for_existing_config -le "0" ]]; then
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
elif [[ $enable_on_boot == 2 ]] && [[ $check_for_existing_config -ge $save_server_config ]]; then
  echo -e "${IWhite} To manually enable the service and bring tunnel interface up, the following commands can be used:${Color_Off}"
  echo -e "
  ${IYellow}chown -v root:root /etc/wireguard/$config_file_name.conf
  chmod -v 600 /etc/wireguard/$config_file_name.conf
  wg-quick up $config_file_name
  systemctl enable wg-quick@$config_file_name.service${Color_Off}"
fi

echo -e "${IWhite}Before ending this script, would you like to setup IPTABLES for the new server?${Color_Off}

${BWhite}1 = yes, 2 = no${Color_Off}
"
read -r iptables_setup
if [[ $iptables_setup == 1 ]]; then
 sudo bash "$my_working_dir"/Scripts/setup_iptables.sh
else
  echo "Sounds good. Ending the scritp..."
fi
exit
