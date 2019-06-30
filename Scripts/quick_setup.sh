#!/usr/bin/env bash

my_working_dir=$(pwd)
find_colours_dir="$(find ~/*/WireGuard-Ligase/ -name colours.sh)"
source "$find_colours_dir"
my_separator="--------------------------------------"
############################ DEFINE VARIABLES ############################
server_private_range="10.10.100.1"
server_listen_port="9201"
client_dns="1.1.1.1"
number_of_clients="2"
client_private_address_1="10.10.100.2"
client_private_address_2="10.10.100.3"
config_file_name="wg0"
server_subnet="10.10.100.0/24"
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

echo -e "
${IWhite} This script will perform a quick server setup with minimal user input.

The following will be auto-configured:
1) Listen port: UDP ${BRed}$server_listen_port ${IWhite}
2) Server public / private keys
3) Server private IP of ${BRed}$server_private_range/24${IWhite}
4) Two clients (client_1.conf,client_2.conf) each with a public / private key; clients will have IPs of ${BRed}$client_private_address_1/32${IWhite} and ${BRed}$client_private_address_2/32${IWhite}
5) Server PostUp: iptables -A FORWARD -i ${BRed}$config_file_name${IWhite} -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE; ip6tables -A FORWARD -i ${BRed}$config_file_name${IWhite} -j ACCEPT; ip6tables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
6) Server PostDown: iptables -D FORWARD -i ${BRed}$config_file_name${IWhite} -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE; ip6tables -D FORWARD -i ${BRed}$config_file_name${IWhite} -j ACCEPT; ip6tables -t nat -D POSTROUTING -o eth0 -j MASQUERADE
7) Clients will use Cloudflare public DNS of ${BRed}$client_dns${IWhite}
8) Server config ${BRed}/etc/wireguard/$config_file_name.conf${IWhite}
9) Tunnel interface ${BRed}$config_file_name${IWhite} will be enabled and service configured to enable at startup.
-----------------------------------------------------------------------
${IYellow}chown -v root:root ${BRed}/etc/wireguard/$config_file_name.conf${IYellow}
chmod -v 600 ${BRed}/etc/wireguard/$config_file_name.conf${IYellow}
wg-quick up ${BRed}$config_file_name${IYellow}
systemctl enable wg-quick@${BRed}${IYellow}$config_file_name.service${Color_Off}
-----------------------------------------------------------------------
${IWhite}10) iptables:${Color_Off}
# Track VPN connection
${IYellow}iptables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT${Color_Off}

# Allow incoming traffic on a specified port
${IYellow}iptables -A INPUT -p udp -m udp --dport ${BRed}$server_listen_port ${IYellow}-m conntrack --ctstate NEW -j ACCEPT${Color_Off}

#Forward packets in the VPN tunnel
${IYellow}iptables -A FORWARD -i ${BRed}$config_file_name${IYellow} -o ${BRed}$config_file_name ${IYellow}-m conntrack --ctstate NEW -j ACCEPT${Color_Off}

# Enable NAT
${IYellow}iptables -t nat -A POSTROUTING -s ${BRed}$server_subnet ${IYellow}-o eth0 -j MASQUERADE${Color_Off}

In addition to setting up iptables, the following commands will be executed:

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

# Public IP address of the server hosting the WireGuard server
echo -e "
${IWhite}Specify public IP address of the server.${Color_Off}"
echo -e "$my_separator"
read -r server_public_address
echo -e "$my_separator"

echo -e "
${BWhite}Review the above. Do you wish to proceed? (y/n)${Color_Off}"

read -r proceed_quick_setup

case "$proceed_quick_setup" in
  #########################################################################
  #                          CASE ANSWER y/Y STARTS                       #
  #########################################################################
  "y"|"Y")
  # Generating server keys
  echo -e "
  ${BGreen}Generating server keys${Color_Off}"
  sleep 1
  wg genkey | tee "$my_working_dir"/keys/ServerPrivatekey | wg pubkey > "$my_working_dir"/keys/ServerPublickey
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
  PostUp = iptables -A FORWARD -i $config_file_name -j ACCEPT; iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE; ip6tables -A FORWARD -i $config_file_name -j ACCEPT; ip6tables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
  PostDown = iptables -D FORWARD -i $config_file_name -j ACCEPT; iptables -t nat -D POSTROUTING -o eth0 -j MASQUERADE; ip6tables -D FORWARD -i $config_file_name -j ACCEPT; ip6tables -t nat -D POSTROUTING -o eth0 -j MASQUERADE
  ListenPort = $server_listen_port
  PrivateKey = $sever_private_key_output
  ")
  # Saving server config
  sleep 1
  echo -e "
  ${BGreen}Saving server config${Color_Off}"
  echo "$new_server_config" > "$config_file_name".txt && echo "$new_server_config" > /etc/wireguard/"$config_file_name".conf
  # Generating client keys
  for (( i = 1; i <= "$number_of_clients"; i++ )); do
    wg genkey | tee "$my_working_dir"/keys/client_"$i"_Privatekey | wg pubkey > "$my_working_dir"/keys/client_"$i"_Publickey

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
PersistentKeepalive = 21" > "$my_working_dir"/client_configs/client_1.conf

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
PersistentKeepalive = 21" > "$my_working_dir"/client_configs/client_2.conf

# Adding client 1 info to the server config
  sleep 1
  echo -e "
  ${BGreen}Adding client 1 info to the server config${Color_Off}"
  echo -e "
[Peer]
PublicKey = $client_public_key_1
AllowedIPs = $client_private_address_1/32
" >> /etc/wireguard/"$config_file_name".conf

# Adding client 2 info to the server config
sleep 1
echo -e "
${BGreen}Adding client 2 info to the server config${Color_Off}"
echo -e "
[Peer]
PublicKey = $client_public_key_2
AllowedIPs = $client_private_address_2/32
" >> /etc/wireguard/"$config_file_name".conf
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
  iptables -t nat -A POSTROUTING -s "$server_subnet" -o eth0 -j MASQUERADE
  ####### IPTABLES END #######

  sleep 2
  echo -e "${BPurple}
* Server config was generated: /etc/wireguard/wg_0.conf
* Client configs are available in $my_working_dir/client_configs/
* Client info has been added to the server config
* Server/client keys have been saved in $my_working_dir/keys/
* Interface $config_file_name was enabled and service configured
* iptables were configured and IP forwarding was enables ${Color_Off}"

echo -e "${BRed}
TODO:
* You need to install iptables-persistent to keep the above added iptables rules after reboot
* Add configurations to the client devices.
  * For mobile devices, 'qrencode' can be used${Color_Off}"
#########################################################################
#                          CASE ANSWER y/Y ENDS                         #
#########################################################################
    ;;
  "n"|"N")
  echo -e "
  Ending the script...."
  exit
    ;;
  *)
  echo -e "${BRed}Sorry, wrong choise. Rerun the script and try again${Color_Off}"
  exit
esac
