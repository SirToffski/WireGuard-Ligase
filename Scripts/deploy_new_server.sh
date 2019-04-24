#!/bin/bash

my_working_dir=$(pwd)

echo "This script will take you through the steps needed to deploy a new server and configure some clients."

echo "Step 1) Please specify the private address of the WireGuard server."
read -r server_private_range

echo "
Step 2) Please specify listen port of the server."
read -r server_listen_port

echo "
Step 3) Specify public IP address of the server"
read -r server_public_address

read -n 1 -s -r -p "
Review the above and press any key to continue"

echo "
Do you need to generate server keys? (If you have not yet configured the server, the probably yes).

1 = yes, 2 = no
"
read -r generate_server_key

check_for_keys_directory=$(ls "$my_working_dir" | grep -c --count keys)

if  [[ "$generate_server_key" == 1 ]] && [[ $check_for_keys_directory -ge 1 ]]; then
  wg genkey | tee "$my_working_dir"/keys/ServerPrivatekey | wg pubkey > "$my_working_dir"/keys/ServerPublickey
  chmod 600 "$my_working_dir"/keys/ServerPrivatekey && chmod 600 "$my_working_dir"/keys/ServerPublickey
  
elif [[ "$generate_server_key" == 1 ]] && [[ $check_for_keys_directory == 0 ]]; then
  mkdir keys
  wg genkey | tee "$my_working_dir"/keys/ServerPrivatekey | wg pubkey > "$my_working_dir"/keys/ServerPublickey
  chmod 600 "$my_working_dir"/keys/ServerPrivatekey && chmod 600 "$my_working_dir"/keys/ServerPublickey
  
else
  echo "
  Specify server private key."
  read -r server_private_key
  echo "$server_private_key" > "$my_working_dir"/keys/ServerPrivatekey
  echo "
  Specify server public key."
  read -r server_public_key
  echo "$server_public_key" > "$my_working_dir"/keys/ServerPublickey
  chmod 600 "$my_working_dir"/keys/ServerPrivatekey && chmod 600 "$my_working_dir"/keys/ServerPrivatekey
fi

sever_private_key_output=$(cat "$my_working_dir"/keys/ServerPrivatekey)
sever_public_key_output=$(cat "$my_working_dir"/keys/ServerPublickey)

new_server_config=$(echo "
[Interface]
Address = $server_private_range
SaveConfig = true
PostUp = iptables -A FORWARD -i wg0 -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE; ip6tables -A FORWARD -i wg0 -j ACCEPT; ip6tables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
PostDown = iptables -D FORWARD -i wg0 -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE; ip6tables -D FORWARD -i wg0 -j ACCEPT; ip6tables -t nat -D POSTROUTING -o eth0 -j MASQUERADE
ListenPort = $server_listen_port
PrivateKey = $sever_private_key_output
")

echo "Congrats! Server config is ready:

------------------------

$new_server_config

------------------------

Save config to /etc/wireguard/?

1 = yes, 2 = no

NOTE: Choosing to save the config under the same file-name as an existing config will overrite it.

This script will check if a config file with the same name already exists and will back existing config up before overriting it.
"

read -r save_server_config
if [[ "$save_server_config" == 1 ]]; then
  echo "
  Provide file name of the config, without the .conf part.

  Example: wg0
  "
  read -r config_file_name
  check_for_existing_config=$(ls /etc/wireguard/ | grep -c --count "$config_file_name".conf)
  if [[ $save_server_config == 1 ]] && [[ $save_server_config -ge $check_for_existing_config ]]; then
    echo "
    Found existing config file with the same name. Backing up to /etc/wireguard/$config_file_name.conf.bak"

    mv /etc/wireguard/"$config_file_name".conf /etc/wireguard/"$config_file_name".conf.bak
  fi
  echo "$new_server_config" > /etc/wireguard/"$config_file_name".conf
fi

echo "
Configure clients?

1=yes, 2=no"

read -r client_config_answer

check_for_clients_directory=$(ls "$my_working_dir" | grep -c --count client_configs)

if [[ $check_for_clients_directory == 0 ]]; then
  mkdir client_configs
fi

if [[ "$client_config_answer" == 1 ]]; then
  echo "
  How many clients would you like to configure?
  "
  read -r number_of_clients
  echo "
  Specify the DNS server your clients will use.
  "
  read -r client_dns
  echo "
  Next steps will ask to provide private address and a name for each client, one at a time.
  "
  for (( i = 1; i <= "$number_of_clients"; i++ )); do
    echo "
    Private address of a client (do NOT include /32):
    "
    read -r client_private_address_[$i]
    echo "
    Provide the name of the client
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
  echo "
  Awesome!
  Client config files were saved to $my_working_dir/client_configs/
   Before ending this script, would you like to setup IPTABLES for the new server?

  1 = yes, 2 = no
  "
  read -r iptables_setup
  if [[ $iptables_setup == 1 ]]; then
    sudo bash setup_iptables.sh
  fi
  exit
fi

echo "
Would you link to add client info to the server config now?

1 = yes, 2 = no"
read -r configure_server_with_clients
check_server_config_name=$(ls /etc/wireguard/ | grep -c --count wg0.conf)
if [[ $configure_server_with_clients == 1 ]] && [[ $save_server_config == 1 ]]; then
  for a in $(seq 1 "$number_of_clients"); do
    echo "
[Peer]
PublicKey = ${client_public_key_["$a"]}
AllowedIPd = ${client_private_address_["$a"]}/32
" >> /etc/wireguard/"$config_file_name".conf
  done
elif [[ $configure_server_with_clients == 1 ]] && [[ $check_server_config_name == 1 ]]; then
  echo "
  Found an existing config file wg0.conf. Backing up the file to /etc/wireguard/wg0.conf.bak and adding client info.
  "
  mv /etc/wireguard/wg0.conf /etc/wireguard/wg0.conf.bak

  for b in $(seq 1 "$number_of_clients"); do
    echo "
[Peer]
PublicKey = ${client_public_key_["$b"]}
AllowedIPd = ${client_private_address_["$b"]}/32
" >> /etc/wireguard/wg0.conf
  done

elif [[  $configure_server_with_clients == 1 ]] && [[ $check_server_config_name == 0 ]]; then
  echo "
  It appears th script is not sure what config file the save client info to Please type the file name without .conf to save the client info to
  "
  read -r server_file_for_clients
  for c in $(seq 1 "$number_of_clients"); do
    echo "
[Peer]
PublicKey = ${client_public_key_["$c"]}
AllowedIPd = ${client_private_address_["$c"]}/32
" >> /etc/wireguard/"$server_file_for_clients".conf
  done
else
  echo "
  Alright, you may add the following to a server config file to setup clients.

  -----------------
  "
  for d in $(seq 1 "$number_of_clients"); do
    echo "
[Peer]
PublicKey = ${client_public_key_["$d"]}
AllowedIPs = ${client_private_address_["$d"]}/32
"
  done
fi

echo "-----------------"

echho "Before ending this script, would you like to setup IPTABLES for the new server?

1 = yes, 2 = no
"
read -r iptables_setup
if [[ $iptables_setup == 1 ]]; then
 sudo bash setup_iptables.sh
else
  echo "Sounds good. Ending the scritp..."
fi
exit
