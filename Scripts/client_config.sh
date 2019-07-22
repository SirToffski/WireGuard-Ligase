#!/usr/bin/env bash

if [ "$EUID" -ne 0 ]; then
  echo "Please run the script as root."
  exit 1
fi

my_working_dir=$(pwd)

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

if [[ $check_for_keys_directory == 0 ]]; then
  mkdir keys
fi

echo " This script will help in easily generating client config for WireGuard."

echo "
What is the server's public key?
"

read -r sever_public_key_output

echo "
What is the server listen port and public IP address?

Example: If public IP is 8.8.8.8 and listet port is 443 -- type 8.8.8.8:443"

read -r server_details

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
for ((i = 1; i <= "$number_of_clients"; i++)); do
  echo "
  Private address of a client (do NOT include /32):
  "
  read -r client_private_address_[$i]
  echo "
  Provide the name of the client
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
Endpoint = $server_details
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 21" >"$my_working_dir"/client_configs/"${client_name_["$i"]}".conf
done

echo "
Awesome!
Client config files were saved to $my_working_dir/client_configs/"

echo "
Would you link to add client info to the server config now?

1 = yes, 2 = no"
read -r configure_server_with_clients

if [[ $configure_server_with_clients == 1 ]]; then
  echo "
  Please specify the file name of the server config located in /etc/wireguard/ WITHOUT the  '.conf'.

  EXAMPLE:

  If your server config file is 'wg0.conf', type 'wg0'
  "
  read -r server_file_for_clients
  for c in $(seq 1 "$number_of_clients"); do
    echo "
[Peer]
PublicKey = ${client_public_key_["$c"]}
AllowedIPs = ${client_private_address_["$c"]}/32
  " >>/etc/wireguard/"$server_file_for_clients".conf
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
  echo "-----------------"
fi
