#!/usr/bin/env bash

if [ "$EUID" -ne 0 ]; then
  printf %s\\n "Please run the script as root."
  exit 1
fi

my_wgl_folder="$(cd "$(dirname "${BASH_SOURCE[0]}")" && cd .. >/dev/null 2>&1 && pwd)"

check_for_full_clone="$my_wgl_folder/configure-wireguard.sh"
if [[ ! -f "$check_for_full_clone" ]]; then
  my_wgl_folder="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
else
  source "$my_wgl_folder"/doc/functions.sh
  # Setting the colours function
  colours
fi
my_separator="--------------------------------------"
############################ DEFINE VARIABLES ############################
### The first three octets of server_private_address, private_range
# and server_subnet HAVE to be same for all subnets starting from /24
# and up. The way this works now is not ideal and will be re-written
# at some point. For the time being, if you change ## server address,
# remember to change the private_range and server_subnet as well

private_range="10.10.100"
server_private_address="$private_range.1"
server_subnet="$private_range.0/25"
### If you need more than five clients, your best bet is to use a subnet of /27 or larger
### With the current script logic /28 will support max 5 clients
# The reason is how the script handles the fourth octet in client addresses
# it will start with ".10" aka 9 + 1 (minimum possible number of clients), incrementing
#  by 1  for every new client. In other words if five clients are to be configured
# their fourth octets would be 10,11,12,13,14
# client_fourth_octet="$((i + 9))" --- this is un-used at the moment and reserved for future
number_of_clients="4"
function create_client_ip_range() {
  for ((i = 1; i <= "$number_of_clients"; i++)); do
    printf %b\\n "\n${BR}$private_range.$((i + 9))"
  done
}
local_interface="eth0"
server_listen_port="51820"
client_dns="1.1.1.1"
config_file_name="wg0"
ssh_port="22"
## Local DNS variable is specifically for EC2 FreeBSD firewall rules
local_dns=$(grep -Eo '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' /etc/resolv.conf | awk '{print $1}')
check_pub_ip=$(curl -s https://checkip.amazonaws.com)
##########################################################################

######################## Pre-checks ######################################################
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

mkdir -p /etc/wireguard
##########################################################################################

printf '\e[2J\e[H'

printf %b\\n "This script will take you through the steps needed to deploy a new server and configure some clients.
\nFirst, let's check if wireguard is installed..."

############## Determine OS Type ##############
# see /doc/functions.sh for more info
###############################################
determine_os
############### FINISHED CHECKING OS AND OFFER TO INSTALL WIREGUARD ###############

printf %b\\n "\n${IW} This script will perform a quick server setup with minimal user input.\n
The following will be auto-configured:
1) Listen port: UDP ${BR}$server_listen_port ${IW}
2) Server public / private keys
3) Server private IP of ${BR}$server_private_address/24${IW}
4) $number_of_clients clients each with a public / private key; clients will have IPs of:"
# {
create_client_ip_range
# }
printf %b\\n "5) Clients will use DNS server: ${BR}$client_dns${IW}
6) Server config ${BR}/etc/wireguard/$config_file_name.conf${IW}
7) Tunnel interface ${BR}$config_file_name${IW} will be enabled and service configured to enable at startup.
8) For Arch, Debian, Fedora, Manjaro, and CentOS (if firewalld is not installed) - iptables will be used to configure firewall
8.1) On CentOS if firewalld is installed - it will be used for firewall rules
8.2) On FreeBSD - IPWF will be used.${Off}"

printf %b\\n "$my_separator"

read -n 1 -s -r -p "
Review the above.

Press any key to continue or CTRL+C to stop."
printf %b\\n "$my_separator"
printf %b\\n "
${IW}The public IP address of this machine is $check_pub_ip. Is this the address you would like to use? ${Off}

${BW}1 = yes, 2 = no${Off}"
read -r public_address
if [[ "$public_address" == 1 ]]; then
  server_public_address="$check_pub_ip"
elif [[ "$public_address" == 2 ]]; then
  printf %b\\n "\n${IW}Please specify the public address of the server.${Off}"
  read -r server_public_address
fi

printf %b\\n "$my_separator"

printf %b\\n "\n${BW}Review the above. Do you wish to proceed? (y/n)${Off}"

read -r proceed_quick_setup

case "$proceed_quick_setup" in
#########################################################################
#                          CASE ANSWER y/Y STARTS                       #
#########################################################################
"y" | "Y")

  # Generating server keys

  printf %b\\n "\n${BG}Generating server keys${Off}"
  sleep 1
  wg genkey | tee "$my_wgl_folder"/keys/ServerPrivatekey | wg pubkey >"$my_wgl_folder"/keys/ServerPublickey
  chmod 600 "$my_wgl_folder"/keys/ServerPrivatekey && chmod 600 "$my_wgl_folder"/keys/ServerPublickey
  sever_private_key_output=$(cat "$my_wgl_folder"/keys/ServerPrivatekey)
  sever_public_key_output=$(cat "$my_wgl_folder"/keys/ServerPublickey)

  # Generating server config

  sleep 1
  printf %b\\n "\n${BG}Generating server config${Off}"
  if [[ "$distro" != "freebsd" ]]; then
    new_server_config=$(printf %b\\n "\n[Interface]
  Address = $server_private_address
  SaveConfig = true
  PostUp = iptables -A FORWARD -i $config_file_name -j ACCEPT; iptables -t nat -A POSTROUTING -o $local_interface -j MASQUERADE; ip6tables -A FORWARD -i $config_file_name -j ACCEPT; ip6tables -t nat -A POSTROUTING -o $local_interface -j MASQUERADE
  PostDown = iptables -D FORWARD -i $config_file_name -j ACCEPT; iptables -t nat -D POSTROUTING -o $local_interface -j MASQUERADE; ip6tables -D FORWARD -i $config_file_name -j ACCEPT; ip6tables -t nat -D POSTROUTING -o $local_interface -j MASQUERADE
  ListenPort = $server_listen_port
  PrivateKey = $sever_private_key_output\n")

  else
    new_server_config=$(printf %b\\n "\n[Interface]
  Address = $server_private_address
  SaveConfig = true
  ListenPort = $server_listen_port
  PrivateKey = $sever_private_key_output\n")
  fi

  # Saving server config

  sleep 1
  printf %b\\n "\n${BG}Saving server config${Off}"
  printf %s\\n "$new_server_config" >"$config_file_name".txt && printf %s\\n "$new_server_config" >/etc/wireguard/"$config_file_name".conf

  # Generating client keys

  for ((i = 1; i <= "$number_of_clients"; i++)); do
    wg genkey | tee "$my_wgl_folder"/keys/client_"$i"_Privatekey | wg pubkey >"$my_wgl_folder"/keys/client_"$i"_Publickey

    chmod 600 "$my_wgl_folder"/keys/client_"$i"_Privatekey
    chmod 600 "$my_wgl_folder"/keys/client_"$i"_Publickey

    client_private_key_["$i"]="$(cat "$my_wgl_folder"/keys/client_"$i"_Privatekey)"
    client_public_key_["$i"]="$(cat "$my_wgl_folder"/keys/client_"$i"_Publickey)"

    # Generating client config

    sleep 1
    printf %b\\n "\n${BG}Generating client $i config${Off}"
    printf %b\\n "\n[Interface]
Address = $private_range.$((i + 9))
PrivateKey = ${client_private_key_["$i"]}
DNS = $client_dns
\n[Peer]
PublicKey = $sever_public_key_output
Endpoint = $server_public_address:$server_listen_port
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 21" >"$my_wgl_folder"/client_configs/client_["$i"].conf

    # Adding client info to the server config
    sleep 1
    printf %b\\n "\n${BG}Adding client info to the server config${Off}"
    printf %b\\n "\n[Peer]
PublicKey = ${client_public_key_["$i"]}
AllowedIPs = $private_range.$((i + 9))/32\n" | tee -a /etc/wireguard/"$config_file_name".conf >/dev/null

  done

  ####### ENABLE WireGuard INTERFACE AND SERVICE  BEGINS #######
  sleep 1
  printf %b\\n "\n${BG}ENABLE $config_file_name INTERFACE AND SERVICE${Off}"
  if [[ "$distro" != "freebsd" ]]; then
    chown -v root:root /etc/wireguard/"$config_file_name".conf
    chmod -v 600 /etc/wireguard/"$config_file_name".conf
    wg-quick up "$config_file_name"
    systemctl enable wg-quick@"$config_file_name".service
  else
    chown -v root:root /etc/wireguard/"$config_file_name".conf
    chmod -v 600 /etc/wireguard/"$config_file_name".conf
    sysrc wireguard_enable="YES"
    sysrc wireguard_interfaces="$config_file_name"
    service wireguard start
  fi
  ####### ENABLE WireGuard INTERFACE AND SERVICE  ENDS #######
  if [[ "$distro" != "freebsd" ]]; then
    ####### IPTABLES BEGIN #######
    ## $distro is defined in doc/functions.sh, which is sourced at the beginning of the script
    if [[ "$distro" == centos ]]; then
      check_if_firewalld_installed=$(yum list installed | grep -i -c firewalld)
      sed -i -E 's/.net.ipv4.ip_forward.*//g' /etc/sysctl.conf
      printf %s\\n "net.ipv4.ip_forward=1" | tee -a /etc/sysctl.conf >/dev/nullf
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
      printf %b\\n "\n ${BG}Configuring iptables and IP forwarding${Off}"
      sed -i -E 's/.net.ipv4.ip_forward.*//g' /etc/sysctl.conf
      printf %s\\n "net.ipv4.ip_forward=1" | tee -a /etc/sysctl.conf >/dev/null
      sysctl -p

      iptables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
      iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
      iptables -A INPUT -p udp -m udp --dport "$server_listen_port" -m conntrack --ctstate NEW -j ACCEPT
      iptables -A FORWARD -i "$config_file_name" -o "$config_file_name" -m conntrack --ctstate NEW -j ACCEPT
      iptables -t nat -A POSTROUTING -s "$server_subnet" -o "$local_interface" -j MASQUERADE
    fi
    ####### IPTABLES END #######
  else
    ####### IPFW BEGINS #######
    sed -i -E 's/firewall_enable=.*//g' /etc/rc.conf
    sed -i -E 's/firewall_nat_enable=.*//g' /etc/rc.conf
    sed -i -E 's/firewall_script=.*//g' /etc/rc.conf
    sed -i -E 's/firewall_logging=.*//g' /etc/rc.conf
    sed -i -E 's/gateway_enable=.*//g' /etc/rc.conf

    sed -i -E 's/net.inet.tcp.tso=.*//g' /etc/sysctl.conf

    printf %b\\n "gateway_enable=\"YES\"
firewall_enable=\"YES\"
firewall_nat_enable=\"YES\"
firewall_script=\"/usr/local/etc/IPFW.rules\"
firewall_logging=\"YES\"" | tee -a /etc/rc.conf >/dev/null

    # Disable TCP segmentation offloading
    # See https://www.freebsd.org/doc/handbook/firewalls-ipfw.html
    # 30.4.4 In-kernet NAT
    printf %b\\n "net.inet.tcp.tso=0" | tee -a /etc/sysctl.conf >/dev/null

    sudo sysctl net.inet.tcp.tso="0"
    sudo sysctl net.inet.ip.forwarding="1"

    ####### IPFW rules ########
    printf %b\\n "#!/bin/sh
# ipfw config/rules
# from FBSD Handbook, rc.firewall, et. al.
# Flush all rules before we begin.
ipfw -q -f flush

# Make sure forwarding and tcp offset fragmentation are configured.
sysctl net.inet.tcp.tso=0
sudo sysctl net.inet.ip.forwarding=1

# Set rules command prefix
cmd=\"ipfw -q add \"
# Used for outboud NAT rules
skip=\"skipto 1000\"
# WG specific rules
wg_serv_iface=$config_file_name
local_interface=$local_interface
pub_dns=$client_dns
local_dns=$local_dns
ssh_port=$ssh_port
server_subnet=$server_subnet
listen_port=$server_listen_port

# Allow NAT
ipfw disable one_pass
ipfw -q nat 1 config if \$local_interface same_ports unreg_only reset
# allow all for localhost
\$cmd 00010 allow ip from any to any via lo0
\$cmd 00011 allow ip from any to any via \$wg_serv_iface 
# NAT-specifig rules
\$cmd 00099 reass all from any to any in       # reassamble inbound packets
\$cmd 00100 nat 1 ip from any to any in via \$local_interface # NAT any inbound packets
# checks stateful rules.  If marked as \"keep-state\" the packet has
# already passed through filters and is \"OK\" without futher
# rule matching
\$cmd 00101 check-state
# allow DNS out
\$cmd 00110 \$skip tcp from any to \$pub_dns dst-port 53 out via \$local_interface setup keep-state
\$cmd 00111 \$skip udp from any to \$pub_dns dst-port 53 out via \$local_interface keep-state
\$cmd 00112 \$skip tcp from any to \$pub_dns dst-port 53 out via \$local_interface setup keep-state
\$cmd 00113 \$skip udp from any to \$pub_dns dst-port 53 out via \$local_interface keep-state
# allow dhclient connection out (port numbers are important)
\$cmd 00120 \$skip udp from me 68 to any dst-port 67 out via \$local_interface keep-state
# allow HTTP HTTPS replies
\$cmd 00200 \$skip tcp from any to any dst-port 80 out via \$local_interface setup keep-state
\$cmd 00220 \$skip tcp from any to any dst-port 443 out via \$local_interface setup keep-state
# allow outbound mail
\$cmd 00230 \$skip tcp from any to any dst-port 25 out via \$local_interface setup keep-state
\$cmd 00231 \$skip tcp from any to any dst-port 465 out via \$local_interface setup keep-state
\$cmd 00232 \$skip tcp from any to any dst-port 587 out via \$local_interface setup keep-state
# allow WG
\$cmd 00233 \$skip udp from any to any src-port \$listen_port out via \$local_interface keep-state
\$cmd 00234 \$skip udp from \$server_subnet to any out via \$local_interface keep-state
\$cmd 00235 \$skip tcp from \$server_subnet to any out via \$local_interface setup keep-state
# allow icmp re: ping, et. al. 
# comment this out to disable ping, et.al.
\$cmd 00250 \$skip icmp from any to any out via \$local_interface keep-state
# alllow timeserver out
\$cmd 00260 \$skip tcp from any to any dst-port 37 out via \$local_interface setup keep-state
# allow ntp out
\$cmd 00270 \$skip udp from any to any dst-port 123 out via \$local_interface keep-state
# allow outbound SSH traffic
\$cmd 00280 \$skip tcp from any to any dst-port 22 out via \$local_interface setup keep-state
# otherwise deny outbound packets
# outbound catchall.  
\$cmd 00299 deny log ip from any to any out via \$local_interface 
# inbound rules
# deny inbound traffic to restricted addresses
\$cmd 00300 deny ip from 192.168.0.0/16 to any in via \$local_interface 
\$cmd 00301 deny all from 172.16.0.0/12 to any in via \$local_interface      #RFC 1918 private IP
\$cmd 00302 deny ip from 10.0.0.0/8 to any in via \$local_interface 
\$cmd 00303 deny ip from 127.0.0.0/8 to any in via \$local_interface 
\$cmd 00304 deny ip from 0.0.0.0/8 to any in via \$local_interface 
\$cmd 00305 deny ip from 169.254.0.0/16 to any in via \$local_interface 
\$cmd 00306 deny ip from 192.0.2.0/24 to any in via \$local_interface 
\$cmd 00307 deny ip from 204.152.64.0/23 to any in via \$local_interface 
\$cmd 00308 deny ip from 224.0.0.0/3 to any in via \$local_interface 
# deny inbound packets on these ports
# auth 113, netbios (services) 137/138/139, hosts-nameserver 81 
\$cmd 00315 deny tcp from any to any dst-port 113 in via \$local_interface 
\$cmd 00320 deny tcp from any to any dst-port 137 in via \$local_interface 
\$cmd 00321 deny tcp from any to any dst-port 138 in via \$local_interface 
\$cmd 00322 deny tcp from any to any dst-port 139 in via \$local_interface 
\$cmd 00323 deny tcp from any to any dst-port 81 in via \$local_interface 
# deny partial packets
\$cmd 00330 deny ip from any to any frag in via \$local_interface 
\$cmd 00332 deny tcp from any to any established in via \$local_interface 
# allowing icmp re: ping, etc.
\$cmd 00310 allow icmp from any to any in via \$local_interface 
# allowing inbound mail, dhcp, http, https
\$cmd 00370 allow udp from any 67 to me dst-port 68 in via \$local_interface keep-state
# allow inbound ssh, mail. PROTECTED SERVICES: numbered ABOVE sshguard blacklist range 
\$cmd 700 allow tcp from any to me dst-port \$ssh_port in via \$local_interface setup limit src-addr 2
\$cmd 702 allow udp from any to any dst-port \$listen_port in via \$local_interface keep-state
# deny everything else, and log it
# inbound catchall
\$cmd 999 deny log ip from any to any in via \$local_interface 
# NAT
\$cmd 1000 nat 1 ip from any to any out via \$local_interface # skipto location for outbound stateful rules
\$cmd 1001 allow ip from any to any
# ipfw built-in default, don't uncomment
# \$cmd 65535 deny ip from any to any" | tee -a /usr/local/etc/IPFW.rules >/dev/null
  fi

  sleep 2
  printf %b\\n "${BP}
  :: Server config was generated: /etc/wireguard$config_file_name.conf
  :: Client configs are available in $my_wgl_folder/client_configs/
  :: Client info has been added to the server config
  :: Server/client keys have been saved in $my_wgl_folder/keys/
  :: Interface $config_file_name was enabled and service configured
  :: Firewall has been configured and IP forwarding was enables ${Off}\n"

  if [[ "$distro" != "centos" ]] && [[ "$distro" != "freebsd" ]]; then
    printf %b\\n "\n${IW} Netfilter iptables rules will need to be saved to persist after reboot.
  \n${BW} Save rules now? \n1 = yes, 2 = no${Off}\n"
    read -r save_netfilter
    if [[ "$save_netfilter" == 1 ]]; then
      if [[ "$distro" == "ubuntu" ]] || [[ "$distro" == "debian" ]]; then
        printf %b\\n "\n${IW}In order to make the above iptables rules persistent after system reboot,
      ${BR}iptables-persistent ${IW} package needs to be installed.

      Would you like the script to install iptables-persistent and to enable the service?

      ${IW}Following commands would be used:


      ${IY}apt-get install iptables-persistent
      systemctl enable netfilter-persistent
      netfilter-persistent save${Off}"

        read -n 1 -s -r -p "
      Review the above commands.

      Press any key to continue or CTRL+C to stop."

        apt-get install iptables-persistent
        systemctl enable netfilter-persistent
        netfilter-persistent save
      elif [[ "$distro" == "fedora" ]]; then
        printf %b\\n "\n${IW}In order to make the above iptables rules persistent after system reboot,
      netfilter rules will need to be saved.

      Would you like the script to save the netfilter rules?

      ${IW}Following commands would be used:


      ${IY}/sbin/service iptables save${Off}"
        read -n 1 -s -r -p "
      Review the above commands.

      Press any key to continue or CTRL+C to stop."

        /sbin/service iptables save

      elif [[ "$distro" == "arch" ]] || [[ "$distro" == "manjaro" ]]; then
        printf %b\\n "\n${IW}In order to make the above iptables rules persistent after system reboot,
      netfilter rules will need to be saved.

      Would you like the script to save the netfilter rules?

      ${IW}Following commands would be used:

      # Check if iptables.rules file exists and create if needed
      ${IY}check_iptables_rules=\$(ls /etc/iptables/ | grep -c iptables.rules)
      if [[ \$check_iptables_rules == 0 ]]; then
        touch /etc/iptables/iptables.rules
      fi

      systemctl enable iptables.service
      systemctl start iptables.service
      iptables-save > /etc/iptables/iptables.rules
      systemctl restart iptables.service
      ${Off}\n"
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
      printf %b\\n "\n${BR}TODO:
    * Add configurations to the client devices.
      * For mobile devices, 'qrencode' can be used${Off}"
    fi
  elif [[ "$distro" == "centos" ]]; then
    if [[ "$check_if_firewalld_installed" == 0 ]]; then
      printf %b\\n "\n${IW}In order to make the above iptables rules persistent after system reboot,
  netfilter rules will need to be saved.

  First, iptables-service needs to be intalled.

  Would you like the script to install iptables-service and save the netfilter rules?

  ${IW}Following commands would be used:

  ${IY}
  sudo yum install iptables-services
  sudo systemctl enable iptables
  sudo service iptables save
  ${Off}\n"
      read -n 1 -s -r -p "
Review the above commands.

  Press any key to continue or CTRL+C to stop."
      sudo yum install iptables-services
      sudo systemctl enable iptables
      sudo service iptables save
    fi
  else
    printf %b\\n "${BR}\nTODO:
  * Add configurations to the client devices.
    * For mobile devices, qrencode can be used${Off}"
  fi

  printf %b\\n "\n${IW}If you've got qrencode installed, the script can generate QR codes for the client configs.

  Would you like to have QR codes generated?

  1= yes, 2 = no${Off}"

  read -r generate_qr_code

  if [[ "$generate_qr_code" == 1 ]]; then
    for ((q = 1; q <= "$number_of_clients"; q++)); do
      printf %b\\n "${BR}client_[$q]${Off}\n"
      qrencode -t ansiutf8 <"$my_wgl_folder"/client_configs/client_["$q"].conf
      printf %s\\n "+--------------------------------------------+"
    done
  elif [[ "$generate_qr_code" == 2 ]]; then
    printf %b\\n "\nAlright.. Moving on!\n+--------------------------------------------+"
  else
    printf %b\\n "Sorry, wrong choice! Moving on with the script."
  fi

  #########################################################################
  #                          CASE ANSWER y/Y ENDS                         #
  #########################################################################
  ;;
"n" | "N")
  printf %b\\n "
  Ending the script...."
  exit
  ;;
*)
  printf %b\\n "${BR}Sorry, wrong choise. Rerun the script and try again${Off}"
  exit
  ;;
esac
