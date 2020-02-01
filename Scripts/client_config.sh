#!/usr/bin/env bash

if [ "$EUID" -ne 0 ]; then
  printf %b\\n "Please run the script as root."
  exit 1
fi

my_wgl_folder="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. >/dev/null 2>&1 && pwd)"
# A simple check if the entire repo was cloned.
## If not, working directory is a directory of the currently running script.
check_for_full_clone="$my_wgl_folder/configure-wireguard.sh"
if [ ! -f "$check_for_full_clone" ]; then
  my_wgl_folder="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
else
  source "$my_wgl_folder"/doc/functions.sh
  # Setting the colours function
  colours
fi
######################## Pre-checks ##############################
# Check if a directory /keys/ exists, if not, it will be made
check_for_keys_directory=$("$my_wgl_folder"/keys)
if [ ! -d "$check_for_keys_directory" ]; then
  mkdir -p "$my_wgl_folder"/keys
fi

# Check if a directory /client_configs/ exists, if not, it will be made
check_for_clients_directory=$("$my_wgl_folder"/client_configs)

if [ ! -d "$check_for_clients_directory" ]; then
  mkdir -p "$my_wgl_folder"/client_configs
fi
##################### Pre-checks finished #########################

printf %b\\n "This script will help in easily generating client config for WireGuard."

printf %b\\n "\nWhat is the server's public key?\n"

read -r sever_public_key_output

printf %b\\n "\nWhat is the server listen port and public IP address?
\nExample: If public IP is 1.1.1.1 and listet port is 9201 -- type 1.1.1.1:9201"

read -r server_details

printf %b\\n "\nHow many clients would you like to configure?\n"
read -r number_of_clients
printf %b\\n "\nSpecify the DNS server your clients will use.\n"
read -r client_dns
printf %b\\n "\nNext steps will ask to provide private address and a name for each client, one at a time.\n"
for i in $(seq 1 "$number_of_clients"); do
  printf %b\\n "\nPrivate address of a client (do NOT include /32):\n"
  read -r client_private_address_["$i"]
  printf %b\\n "\nProvide the name of the client\n"

  read -r client_name_["$i"]

  wg genkey | tee "$my_wgl_folder"/keys/"${client_name_["$i"]}"Privatekey | wg pubkey >"$my_wgl_folder"/keys/"${client_name_["$i"]}"Publickey

  chmod 600 "$my_wgl_folder"/keys/"${client_name_["$i"]}"Privatekey
  chmod 600 "$my_wgl_folder"/keys/"${client_name_["$i"]}"Publickey

  client_private_key_["$i"]="$(cat "$my_wgl_folder"/keys/"${client_name_["$i"]}"Privatekey)"
  client_public_key_["$i"]="$(cat "$my_wgl_folder"/keys/"${client_name_["$i"]}"Publickey)"

  printf %b\\n "\n[Interface]
Address = ${client_private_address_["$i"]}
PrivateKey = ${client_private_key_["$i"]}
DNS = $client_dns
\n[Peer]
PublicKey = $sever_public_key_output
Endpoint = $server_details
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 21" >"$my_wgl_folder"/client_configs/"${client_name_["$i"]}".conf
done

printf %b\\n "\nAwesome!\nClient config files were saved to $my_wgl_folder/client_configs/"

printf %b\\n "\nWould you link to add client info to the server config now?\n
1 = yes, 2 = no"
read -r configure_server_with_clients

if [ "$configure_server_with_clients" = 1 ]; then
  printf %b\\n "\nPlease specify the file name of the server config located in /etc/wireguard/ WITHOUT the  '.conf'.

  EXAMPLE:

  If your server config file is 'wg0.conf', type 'wg0'\n
  
  NOTE: You need to disable server WireGuard interface before changing the config."

  read -r server_file_for_clients
  for c in $(seq 1 "$number_of_clients"); do
    printf %b\\n "
[Peer]
PublicKey = ${client_public_key_["$c"]}
AllowedIPs = ${client_private_address_["$c"]}/32
  " | tee -a /etc/wireguard/"$server_file_for_clients".conf >/dev/null
  done
else
  printf %b\\n "
  Alright, you may add the following to a server config file to setup clients.

  -----------------
  "
  for d in $(seq 1 "$number_of_clients"); do
    printf %b\\n "
[Peer]
PublicKey = ${client_public_key_["$d"]}
AllowedIPs = ${client_private_address_["$d"]}/32
"
  done
  printf %b\\n "-----------------"
fi
