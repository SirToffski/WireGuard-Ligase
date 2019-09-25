#!/usr/bin/env bash

if [ "$EUID" -ne 0 ]; then
  echo "Please run the script as root."
  exit 1
fi

my_wgl_folder=$(find /home -type d -name WireGuard-Ligase)
my_working_dir=$(pwd)
source "$my_wgl_folder"/doc/functions.sh
my_separator="--------------------------------------"
############################ DEFINE VARIABLES ############################
### The first three octets of server_private_address, client_private_range
# and server_subnet HAVE to be same for all subnets starting from /24
# and up. The way this works now is not ideal and will be re-written
# at some point. For the time being, if you change ## server address,
# remember to change the client_private_range and server_subnet as well

server_private_address="10.10.100.1"
client_private_range="10.10.100"
### If you need more than five clients, your best bet is not go go over /27
### With the current script logic /28 will support max 5 clients
# The reason is how the script handles the fourth octet in client addresses
# it will start with ".10" aka 9 + 1 (minimum possible number of clients), incrementing
#  by 1  for every new client. In other words if five clients are to be configured
# their fourth octets would be 10,11,12,13,14
server_subnet="10.10.100.0/25"
# client_fourth_octet="$((i + 9))" --- this is un-used at the moment and reserved for future
local_interface="eth0"
server_listen_port="9201"
client_dns="1.1.1.1"
number_of_clients="4"
config_file_name="wg0"
check_pub_ip=$(curl -s https://checkip.amazonaws.com)
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

printf '\e[2J\e[H'

echo -e "This script will take you through the steps needed to deploy a new server and configure some clients.

First, let's check if wireguard is installed..."

############## Determine OS Type ##############
# see /doc/functions.sh for more info
###############################################
determine_os
############### FINISHED CHECKING OS AND OFFER TO INSTALL WIREGUARD ###############

function create_client_ip_range() {
  for i in $(seq 1 "$number_of_clients"); do
    echo -e "
  ${BRed}$client_private_range.$((i + 9))"
  done
}

echo -e "
${IWhite} This script will perform a quick server setup with minimal user input.

The following will be auto-configured:
1) Listen port: UDP ${BRed}$server_listen_port ${IWhite}
2) Server public / private keys
3) Server private IP of ${BRed}$server_private_address/24${IWhite}
4) $number_of_clients clients each with a public / private key; clients will have IPs of:"
create_client_ip_range
echo -e "
5) Server PostUp: iptables -A FORWARD -i ${BRed}$config_file_name${IWhite} -j ACCEPT; iptables -t nat -A POSTROUTING -o $local_interface -j MASQUERADE; ip6tables -A FORWARD -i ${BRed}$config_file_name${IWhite} -j ACCEPT; ip6tables -t nat -A POSTROUTING -o $local_interface -j MASQUERADE
6) Server PostDown: iptables -D FORWARD -i ${BRed}$config_file_name${IWhite} -j ACCEPT; iptables -t nat -D POSTROUTING -o $local_interface -j MASQUERADE; ip6tables -D FORWARD -i ${BRed}$config_file_name${IWhite} -j ACCEPT; ip6tables -t nat -D POSTROUTING -o $local_interface -j MASQUERADE
7) Clients will use Cloudflare public DNS of ${BRed}$client_dns${IWhite}
8) Server config ${BRed}/etc/wireguard/$config_file_name.conf${IWhite}
9) Tunnel interface ${BRed}$config_file_name${IWhite} will be enabled and service configured to enable at startup.
-----------------------------------------------------------------------
${IYellow}chown -v root:root ${BRed}/etc/wireguard/$config_file_name.conf${IYellow}
chmod -v 600 ${BRed}/etc/wireguard/$config_file_name.conf${IYellow}
wg-quick up ${BRed}$config_file_name${IYellow}
systemctl enable wg-quick@${BRed}${IYellow}$config_file_name.service${Color_Off}
-----------------------------------------------------------------------

=============================================================================
For Arch, Debian, Fedora, Manjaro, and CentOS (if firewalld is not installed)
=============================================================================
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
For CentOS (firewalld is installed)
================================================

The following firewall rules will be configured:${Color_Off}

${IYellow}
firewall-cmd --zone=public --add-port=$server_listen_port/udp
firewall-cmd --zone=trusted --add-source=$server_subnet
firewall-cmd --permanent --zone=public --add-port=$server_listen_port/udp
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
  Address = $server_private_address
  SaveConfig = true
  PostUp = iptables -A FORWARD -i $config_file_name -j ACCEPT; iptables -t nat -A POSTROUTING -o $local_interface -j MASQUERADE; ip6tables -A FORWARD -i $config_file_name -j ACCEPT; ip6tables -t nat -A POSTROUTING -o $local_interface -j MASQUERADE
  PostDown = iptables -D FORWARD -i $config_file_name -j ACCEPT; iptables -t nat -D POSTROUTING -o $local_interface -j MASQUERADE; ip6tables -D FORWARD -i $config_file_name -j ACCEPT; ip6tables -t nat -D POSTROUTING -o $local_interface -j MASQUERADE
  ListenPort = $server_listen_port
  PrivateKey = $sever_private_key_output
  ")
  # Saving server config
  sleep 1
  echo -e "
  ${BGreen}Saving server config${Color_Off}"
  echo "$new_server_config" >"$config_file_name".txt && echo "$new_server_config" >/etc/wireguard/"$config_file_name".conf
  # Generating client keys
  for i in $(seq 1 "$number_of_clients"); do
    wg genkey | tee "$my_working_dir"/keys/client_"$i"_Privatekey | wg pubkey >"$my_working_dir"/keys/client_"$i"_Publickey

    chmod 600 "$my_working_dir"/keys/client_"$i"_Privatekey
    chmod 600 "$my_working_dir"/keys/client_"$i"_Publickey

    client_private_key_["$i"]=$(cat "$my_working_dir"/keys/client_"$i"_Privatekey)
    client_public_key_["$i"]=$(cat "$my_working_dir"/keys/client_"$i"_Publickey)

    # Generating client config
    sleep 1
    echo -e "
${BGreen}Generating client $i config${Color_Off}"
    echo "
[Interface]
Address = $client_private_range.$((i + 9))
PrivateKey = ${client_private_key_["$i"]}
DNS = $client_dns

[Peer]
PublicKey = $sever_public_key_output
Endpoint = $server_public_address:$server_listen_port
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 21" >"$my_working_dir"/client_configs/client_["$i"].conf

    # Adding client info to the server config
    sleep 1
    echo -e "
${BGreen}Adding client info to the server config${Color_Off}"
    echo -e "
[Peer]
PublicKey = ${client_public_key_["$i"]}
AllowedIPs = $client_private_range.$((i + 9))/32
" >>/etc/wireguard/"$config_file_name".conf

  done

  ####### ENABLE WireGuard INTERFACE AND SERVICE  BEGINS #######
  sleep 1
  echo -e "
  ${BGreen}ENABLE $config_file_name INTERFACE AND SERVICE${Color_Off}"
  chown -v root:root /etc/wireguard/"$config_file_name".conf
  chmod -v 600 /etc/wireguard/"$config_file_name".conf
  wg-quick up "$config_file_name"
  systemctl enable wg-quick@"$config_file_name".service
  ####### ENABLE wg_0 INTERFACE AND SERVICE  ENDS #######

  ####### IPTABLES BEGIN #######
  if [[ "$distro" == centos ]]; then
    check_if_firewalld_installed=$(yum list installed | grep -i -c firewalld)
    sed -i 's/net.ipv4.ip_forward=0//g' /etc/sysctl.conf
    sed -i 's/#net.ipv4.ip_forward=0//g' /etc/sysctl.conf
    sed -i 's/#net.ipv4.ip_forward=1//g' /etc/sysctl.conf
    echo "net.ipv4.ip_forward=1" >>/etc/sysctl.conf
    sysctl -p
    if [[ "$check_if_firewalld_installed" == 0 ]]; then
      iptables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
      iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
      iptables -A INPUT -p udp -m udp --dport "$server_listen_port" -m conntrack --ctstate NEW -j ACCEPT
      iptables -A FORWARD -i "$config_file_name" -o "$config_file_name" -m conntrack --ctstate NEW -j ACCEPT
      iptables -t nat -A POSTROUTING -s "$server_subnet" -o "$local_interface" -j MASQUERADE
    elif [[ "$check_if_firewalld_installed" == 1 ]]; then
      firewall-cmd --zone=public --add-port="$server_listen_port"/udp
      firewall-cmd --zone=trusted --add-source="$server_subnet"
      firewall-cmd --permanent --zone=public --add-port="$server_listen_port"/udp
      firewall-cmd --permanent --zone=trusted --add-source="$server_subnet"
      firewall-cmd --direct --add-rule ipv4 nat POSTROUTING 0 -s "$server_subnet" ! -d "$server_subnet" -j SNAT --to "$server_public_address"
      firewall-cmd --permanent --direct --add-rule ipv4 nat POSTROUTING 0 -s "$server_subnet" ! -d "$server_subnet" -j SNAT --to "$server_public_address"
    fi
  else
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
    iptables -t nat -A POSTROUTING -s "$server_subnet" -o "$local_interface" -j MASQUERADE
  fi
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
  elif [[ "$distro" == "centos" ]]; then
    if [[ "$check_if_firewalld_installed" == 0 ]]; then
      echo -e "
  ${IWhite}In order to make the above iptables rules persistent after system reboot,
  netfilter rules will need to be saved.

  First, iptables-service needs to be intalled.

  Would you like the script to install iptables-service and save the netfilter rules?

  ${IWhite}Following commands would be used:

  ${IYellow}
  sudo yum install iptables-services
  sudo systemctl enable iptables
  sudo service iptables save
  ${Color_Off}
  "
      read -n 1 -s -r -p "
  Review the above commands.

  Press any key to continue or CTRL+C to stop."
      sudo yum install iptables-services
      sudo systemctl enable iptables
      sudo service iptables save
    fi
  else
    echo -e "${BRed}
  TODO:
  * Add configurations to the client devices.
    * For mobile devices, qrencode can be used${Color_Off}"
  fi

  echo -e "
  ${IWhite}If you've got qrencode installed, the script can generate QR codes for the client configs.

  Would you like to have QR codes generated?

  1= yes, 2 = no${Color_Off}"

  read -r generate_qr_code

  if [[ "$generate_qr_code" == 1 ]]; then
      for q in $(seq 1 "$number_of_clients"); do
        qrencode -t ansiutf8 < "$my_working_dir"/client_configs/client_["$q"].conf
    done
  elif [[ "$generate_qr_code" == 2 ]]; then
    echo -e "
    Understood!"
  else
    echo -e "Sorry, wrong choice! Moving on with the script."
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
