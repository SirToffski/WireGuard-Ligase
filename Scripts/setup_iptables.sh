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

############## Determine OS Type ##############
###############################################
ubuntu_os=$(lsb_release -a | grep -i -c Ubuntu)
arch_os=$(hostnamectl | grep -i -c "Arch Linux")
cent_os=$(hostnamectl | grep -i -c CentOS)
debian_os=$(lsb_release -a | grep -i -c Debian)
fedora_os=$(lsb_release -a | grep -i -c Fedora)
manjaro_os=$(hostnamectl | grep -i -c Manjaro)
freebsd_os=$(uname -a | awk '{print $1}' | grep -i -c FreeBSD)

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
elif [[ "$freebsd_os" -gt 0 ]]; then
  distro=freebsd
fi
###############################################
###############################################

my_separator="--------------------------------------"
check_pub_ip=$(curl -s https://checkip.amazonaws.com)

###############################################
# If deploy_new_server.sh script has already been run,
# attempt to source variables used in it to avoid repitition
###############################################
check_for_shared_vars="$my_wgl_folder/shared_vars.sh"
if [[ -f "$check_for_shared_vars" ]]; then
  source "$my_wgl_folder/shared_vars.sh"

  printf '\e[2J\e[H'

  printf %b\\n "\n+--------------------------------------------+
${BW}Server private address = ${BR}$server_private_range${Off}
${BW}Server listen port = ${BR}$server_listen_port${Off}
${BW}Server public address = ${BR}$server_public_address${Off}
${BW}WAN interface = ${BR}$local_interface${Off}
${BW}WireGuard interface = ${BR}$wg_serv_iface${Off}
+--------------------------------------------+\n"

  read -n 1 -s -r -p "
Review the above. 
Press any key to continue (everything looks correct)
Press r/R if some variables need to be changed
Press e/E to exit
" your_choice

  case "$your_choice" in
  ###############################################
  # If some variables need to be changed,
  # start from the beginning and gather the info.
  ###############################################
  [Rr]*)
    printf %b\\n "\n${IW}We are going to setup some basic firewall rules so the server can
function correctly.\n
Step 1) Please provide the server subnet information to be used.${Off}\n
${BW}Example:${IW} If you server IP is ${BR}10.0.0.1/24${IW}, then please type ${BR}10.0.0.0/24${Off}\n"

    read -r -p "Server subnet: " server_subnet

    printf '\e[2J\e[H'

    printf %b\\n "
+--------------------------------------------+
${BW}Server subnet = ${BR}$server_subnet${Off}
+--------------------------------------------+

${IW}Step 2) Please also provide the listen port of your server.${Off}

${BW}Example: ${BR}51820${Off}"

    read -r -p "Server listen port: " listen_port

    printf '\e[2J\e[H'

    # Public IP address of the server hosting the WireGuard server
    printf %b\\n "
+--------------------------------------------+
${BW}Server subnet = ${BR}$server_subnet${Off}
${BW}Server port = ${BR}$listen_port${Off}
+--------------------------------------------+

${BW}Step 3)${Off} ${IW}The public IP address of this machine is $check_pub_ip. 
Is this the address you would like to use? ${Off}

${BW}1 = yes, 2 = no${Off}"
    read -r -p "Choice: " public_address

    printf %b\\n "$my_separator"

    if [[ "$public_address" == 1 ]]; then
      server_public_address="$check_pub_ip"
    elif [[ "$public_address" == 2 ]]; then
      printf %b\\n "
${IW}Please specify the public address of the server.${Off}
"
      read -r -p "Public IP: " server_public_address
    fi

    printf '\e[2J\e[H'

    printf %b\\n "
+--------------------------------------------+
${BW}Server subnet = ${BR}$server_subnet${Off}
${BW}Server port = ${BR}$listen_port${Off}
${BW}Server public address = ${BR}$server_public_address${Off}
+--------------------------------------------+

${BW}Step 4)${IW} Please also provide the internet facing interface of the server. 
${BW}Example: ${BR}eth0${Off}

Available interfaces are:
+--------------------+
$(ip -br a | awk '{print $1}')
+--------------------+
"

    read -r -p "Interface: " local_interface
    printf '\e[2J\e[H'

    printf %b\\n "
+--------------------------------------------+
${BW}Server subnet = ${BR}$server_subnet${Off}
${BW}Server port = ${BR}$listen_port${Off}
${BW}Server public address = ${BR}$server_public_address${Off}
${BW}WAN Interface = ${BR}$local_interface${Off}
+--------------------------------------------+

${IW}Step 5) Specify wireguard server interface name 
(will be the same as config name, without .conf)${Off}
"

    read -r -p "WireGuard Interface: " wg_serv_iface

    printf '\e[2J\e[H'
    ;;
  [Ee]*)
    exit
    ;;
  *)
    printf %b\\n "\n${IW}We are going to setup some basic firewall rules so the server can
function correctly.\n
Step 1) Please provide the server subnet information to be used.${Off}\n
${BW}Example:${IW} If you server IP is ${BR}10.0.0.1/24${IW}, then please type ${BR}10.0.0.0/24${Off}\n"

    read -r -p "Server subnet: " server_subnet

    printf '\e[2J\e[H'
    ;;
  esac

###############################################
# If no changes are needed,
# source variables from shared_vars.sh
###############################################
else

  printf %b\\n "\n${IW}We are going to setup some basic firewall rules so the server can
function correctly.\n
Step 1) Please provide the server subnet information to be used.${Off}\n
${BW}Example:${IW} If you server IP is ${BR}10.0.0.1/24${IW}, then please type ${BR}10.0.0.0/24${Off}\n"

  read -r -p "Server subnet: " server_subnet

  printf '\e[2J\e[H'

  printf %b\\n "
+--------------------------------------------+
${BW}Server subnet = ${BR}$server_subnet${Off}
+--------------------------------------------+\n
${IW}Step 2) Please also provide the listen port of your server.${Off}\n
${BW}Example: ${BR}51820${Off}"

  read -r -p "Server listen port: " listen_port

  printf '\e[2J\e[H'

  # Public IP address of the server hosting the WireGuard server
  printf %b\\n "
+--------------------------------------------+
${BW}Server subnet = ${BR}$server_subnet${Off}
${BW}Server port = ${BR}$listen_port${Off}
+--------------------------------------------+

${BW}Step 3)${Off} ${IW}The public IP address of this machine is $check_pub_ip. 
Is this the address you would like to use? ${Off}\n
${BW}1 = yes, 2 = no${Off}"
  read -r -p "Choice: " public_address

  printf %b\\n "$my_separator"

  if [[ "$public_address" == 1 ]]; then
    server_public_address="$check_pub_ip"
  elif [[ "$public_address" == 2 ]]; then
    printf %b\\n "\n${IW}Please specify the public address of the server.${Off}\n"
    read -r -p "Public IP: " server_public_address
  fi

  printf '\e[2J\e[H'

  printf %b\\n "
+--------------------------------------------+
${BW}Server subnet = ${BR}$server_subnet${Off}
${BW}Server port = ${BR}$listen_port${Off}
${BW}Server public address = ${BR}$server_public_address${Off}
+--------------------------------------------+

${BW}Step 4)${IW} Please also provide the internet facing interface of the server. 
${BW}Example: ${BR}eth0${Off}\n
Available interfaces are:
+--------------------+
$(ip -br a | awk '{print $1}')
+--------------------+\n"

  read -r -p "Interface: " local_interface
  printf '\e[2J\e[H'

  printf %b\\n "
+--------------------------------------------+
${BW}Server subnet = ${BR}$server_subnet${Off}
${BW}Server port = ${BR}$listen_port${Off}
${BW}Server public address = ${BR}$server_public_address${Off}
${BW}WAN Interface = ${BR}$local_interface${Off}
+--------------------------------------------+\n
${IW}Step 5) Specify wireguard server interface name 
(will be the same as config name, without .conf)${Off}\n"

  read -r -p "WireGuard Interface: " wg_serv_iface

  printf '\e[2J\e[H'

fi

if [[ "$cent_os" -gt 0 ]]; then
  check_if_firewalld_installed=$(yum list installed | grep -i -c firewalld)
  if [[ "$check_if_firewalld_installed" == 1 ]]; then
    printf %b\\n "
    ${IW}
    OS Type: CentOS
    Firewalld: installed
    The following firewall rules will be configured:${Off}

    ${IY}
    firewall-cmd --zone=public --add-port=$listen_port/udp
    firewall-cmd --zone=trusted --add-source=$server_subnet
    firewall-cmd --permanent --zone=public --add-port=$listen_port/udp
    firewall-cmd --permanent --zone=trusted --add-source=$server_subnet
    firewall-cmd --direct --add-rule ipv4 nat POSTROUTING 0 -s $server_subnet ! -d $server_subnet -j SNAT --to $server_public_address
    firewall-cmd --permanent --direct --add-rule ipv4 nat POSTROUTING 0 -s $server_subnet ! -d $server_subnet -j SNAT --to $server_public_address
    ${Off}

    # Enabling IP forwarding
    # In /etc/sysctl.conf, net.ipv4.ip_forward value will be changed to 1:
    ${IY}net.ipv4.ip_forward=1${Off}

    #To avoid the need to reboot the server
    ${IY}sysctl -p${Off}\n"

    read -n 1 -s -r -p "
  Review the above. 
  Press any key to continue 
  Press r/R to restart the script
  Press e/E to exit
  " your_choice

    case "$your_choice" in
    [Rr]*)
      sudo bash "$my_wgl_folder"/Scripts/setup_iptables.sh
      ;;
    [Ee]*)
      exit
      ;;
    *)
      sed -i -E 's/.net.ipv4.ip_forward.*//g' /etc/sysctl.conf
      printf %s\\n "net.ipv4.ip_forward=1" | tee -a /etc/sysctl.conf >/dev/null
      sysctl -p

      firewall-cmd --zone=public --add-port="$listen_port"/udp
      firewall-cmd --zone=trusted --add-source="$server_subnet"
      firewall-cmd --permanent --zone=public --add-port="$listen_port"/udp
      firewall-cmd --permanent --zone=trusted --add-source="$server_subnet"
      firewall-cmd --direct --add-rule ipv4 nat POSTROUTING 0 -s "$server_subnet" ! -d "$server_subnet" -j SNAT --to "$server_public_address"
      firewall-cmd --permanent --direct --add-rule ipv4 nat POSTROUTING 0 -s "$server_subnet" ! -d "$server_subnet" -j SNAT --to "$server_public_address"
      printf '\e[2J\e[H'
      printf %b\\n "${BW}Done!${Off}"
      ;;
    esac

  elif [[ "$check_if_firewalld_installed" == 0 ]]; then
    printf %b\\n "
    ${IW}
    OS Type: CentOS
    Firewalld: NOT installed - using iptables
    The following firewall rules will be configured:${Off}"

    printf %b\\n "
    ${IW}The following iptables will be configured:${Off}

    # Track VPN connection
    ${IY}iptables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
    iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT${Off}

    # Allow incoming traffic on a specified port
    ${IY}iptables -A INPUT -p udp -m udp --dport ${BR}$listen_port ${IY}-m conntrack --ctstate NEW -j ACCEPT${Off}

    #Forward packets in the VPN tunnel
    ${IY}iptables -A FORWARD -i ${BR}$wg_serv_iface${IY} -o ${BR}$wg_serv_iface ${IY}-m conntrack --ctstate NEW -j ACCEPT${Off}

    # Enable NAT
    ${IY}iptables -t nat -A POSTROUTING -s ${BR}$server_subnet ${IY}-o $local_interface -j MASQUERADE${Off}

    In addition to setting up iptables, the following commands will be executed:

    # Enabling IP forwarding
    # In /etc/sysctl.conf, net.ipv4.ip_forward value will be changed to 1:
    ${IY}net.ipv4.ip_forward=1${Off}

    #To avoid the need to reboot the server
    ${IY}sysctl -p${Off}

    -------------------------------------------
    "
    read -n 1 -s -r -p "
  Review the above. 
  Press any key to continue 
  Press r/R to restart the script
  Press e/E to exit
  " your_choice

    case "$your_choice" in
    [Rr]*)
      sudo bash "$my_wgl_folder"/Scripts/setup_iptables.sh
      ;;
    [Ee]*)
      exit
      ;;
    *)
      sed -i -E 's/.net.ipv4.ip_forward.*//g' /etc/sysctl.conf
      printf %s\\n "net.ipv4.ip_forward=1" | tee -a /etc/sysctl.conf >/dev/null
      sysctl -p

      iptables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
      iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
      iptables -A INPUT -p udp -m udp --dport "$listen_port" -m conntrack --ctstate NEW -j ACCEPT
      iptables -A FORWARD -i "$wg_serv_iface" -o "$wg_serv_iface" -m conntrack --ctstate NEW -j ACCEPT
      iptables -t nat -A POSTROUTING -s "$server_subnet" -o "$local_interface" -j MASQUERADE
      printf '\e[2J\e[H'
      printf %b\\n "${BW}Done!${Off}"
      ;;
    esac
  fi
elif [[ "$distro" == "freebsd" ]]; then
  local_dns=$(grep -Eo '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' /etc/resolv.conf | awk '{print $1}')
  printf %b\\n "
    ${IW}
    OS Type: FreeBSD
    IPFW will be used.
    ${Off}"

  printf %b\\n "${IW}\nFreeBSD IPFW requires some fine-tuning for optimal security.\n
In order to make sure you do not get locked out of the server,
please specify the port used for SSH. Default is 22.${Off}"

  read -r -p "SSH Port: " ssh_port

  printf %b\\n "${IW}\nFinally, we will manually allow forwarding DNS traffic
from WireGuard peers to the external DNS server.\n
Please specify the DNS to be used by WireGuard peers.${Off}"

  read -r -p "Peer DNS: " pub_dns

  printf %b\\n "${IW}\nThe following firewall rules will be configured:\n${Off}"

  printf %b\\n "\n
# 1) First, we'll make sure the following is present in /etc/rc.conf

firewall_enable=\"YES\"
firewall_nat_enable=\"YES\"
firewall_script=\"/usr/local/etc/IPFW.rules\"
firewall_logging=\"YES\"

# The above will be achieved with the following commands:
${IY}
## Make sure we dont have any duplicates
sed -i -E 's/firewall_enable=.*//g' /etc/rc.conf
sed -i -E 's/firewall_nat_enable=.*//g' /etc/rc.conf
sed -i -E 's/firewall_script=.*//g' /etc/rc.conf
sed -i -E 's/firewall_logging=.*//g' /etc/rc.conf

## Insert rules
printf %b\\n \"firewall_enable=\"YES\"
firewall_nat_enable=\"YES\"
firewall_script=\"/usr/local/etc/IPFW.rules\"
firewall_logging=\"YES\"\" | tee -a /etc/rc.conf > /dev/null 
${Off}

# 2) Second, we'll disable TCP offset fragmentation and enable IP forwarding.

${IY}
## Disable TCP segmentation offloading to use in-kernel NAT
## See 30.4.4. In-kernel NAT in https://www.freebsd.org/doc/handbook/firewalls-ipfw.html
$ sudo sysctl net.inet.tcp.tso=\"0\"
## Enable IP forwarding
$ sudo sysctl net.inet.ip.forwarding=\"1\"
${Off}

# 3) Finally, we will create a file /usr/local/etc/IPFW.rules with the following firewall rules:
---------------------
${IY}
#!/bin/sh
# ipfw config/rules
# from FBSD Handbook, rc.firewall, et. al.
# Flush all rules before we begin.
ipfw -q -f flush
# Set rules command prefix
cmd=\"ipfw -q add \"
# Used for outboud NAT rules
skip=\"skipto 1000\"


# Allow NAT
ipfw disable one_pass
ipfw -q nat 1 config if ${BR}$local_interface${IY}same_ports unreg_only reset
# allow all for localhost
\$cmd 00010 allow ip from any to any via lo0
\$cmd 00011 allow ip from any to any via ${BR}$wg_serv_iface${IY}
# NAT-specifig rules
\$cmd 00099 reass all from any to any in       # reassamble inbound packets
\$cmd 00100 nat 1 ip from any to any in via ${BR}$local_interface${IY}# NAT any inbound packets
# checks stateful rules.  If marked as \"keep-state\" the packet has
# already passed through filters and is \"OK\" without futher
# rule matching
\$cmd 00101 check-state
# allow DNS out
\$cmd 00110 \$skip tcp from any to ${BR}$pub_dns${IY}dst-port 53 out via ${BR}$local_interface${IY}setup keep-state
\$cmd 00111 \$skip udp from any to ${BR}$pub_dns${IY}dst-port 53 out via ${BR}$local_interface${IY}keep-state
\$cmd 00112 \$skip tcp from any to ${BR}$pub_dns${IY}dst-port 53 out via ${BR}$local_interface${IY}setup keep-state
\$cmd 00113 \$skip udp from any to ${BR}$pub_dns${IY}dst-port 53 out via ${BR}$local_interface${IY}keep-state
# allow dhclient connection out (port numbers are important)
\$cmd 00120 \$skip udp from me 68 to any dst-port 67 out via ${BR}$local_interface${IY}keep-state
# allow HTTP HTTPS replies
\$cmd 00200 \$skip tcp from any to any dst-port 80 out via ${BR}$local_interface${IY}setup keep-state
\$cmd 00220 \$skip tcp from any to any dst-port 443 out via ${BR}$local_interface${IY}setup keep-state
# allow outbound mail
\$cmd 00230 \$skip tcp from any to any dst-port 25 out via ${BR}$local_interface${IY}setup keep-state
\$cmd 00231 \$skip tcp from any to any dst-port 465 out via ${BR}$local_interface${IY}setup keep-state
\$cmd 00232 \$skip tcp from any to any dst-port 587 out via ${BR}$local_interface${IY}setup keep-state
# allow WG
\$cmd 00233 \$skip udp from any to any src-port ${BR}$listen_port${IY}out via ${BR}$local_interface${IY}keep-state
\$cmd 00234 \$skip udp from ${BR}$server_subnet${IY}to any out via ${BR}$local_interface${IY}keep-state
\$cmd 00235 \$skip tcp from ${BR}$server_subnet${IY}to any out via ${BR}$local_interface${IY}setup keep-state
# allow icmp re: ping, et. al. 
# comment this out to disable ping, et.al.
\$cmd 00250 \$skip icmp from any to any out via ${BR}$local_interface${IY}keep-state
# alllow timeserver out
\$cmd 00260 \$skip tcp from any to any dst-port 37 out via ${BR}$local_interface${IY}setup keep-state
# allow ntp out
\$cmd 00270 \$skip udp from any to any dst-port 123 out via ${BR}$local_interface${IY}keep-state
# allow outbound SSH traffic
\$cmd 00280 \$skip tcp from any to any dst-port 22 out via ${BR}$local_interface${IY}setup keep-state
# otherwise deny outbound packets
# outbound catchall.  
\$cmd 00299 deny log ip from any to any out via ${BR}$local_interface${IY}
# inbound rules
# deny inbound traffic to restricted addresses
\$cmd 00300 deny ip from 192.168.0.0/16 to any in via ${BR}$local_interface${IY}
\$cmd 00301 deny all from 172.16.0.0/12 to any in via ${BR}$local_interface${IY}     #RFC 1918 private IP
\$cmd 00302 deny ip from 10.0.0.0/8 to any in via ${BR}$local_interface${IY}
\$cmd 00303 deny ip from 127.0.0.0/8 to any in via ${BR}$local_interface${IY}
\$cmd 00304 deny ip from 0.0.0.0/8 to any in via ${BR}$local_interface${IY}
\$cmd 00305 deny ip from 169.254.0.0/16 to any in via ${BR}$local_interface${IY}
\$cmd 00306 deny ip from 192.0.2.0/24 to any in via ${BR}$local_interface${IY}
\$cmd 00307 deny ip from 204.152.64.0/23 to any in via ${BR}$local_interface${IY}
\$cmd 00308 deny ip from 224.0.0.0/3 to any in via ${BR}$local_interface${IY}
# deny inbound packets on these ports
# auth 113, netbios (services) 137/138/139, hosts-nameserver 81 
\$cmd 00315 deny tcp from any to any dst-port 113 in via ${BR}$local_interface${IY}
\$cmd 00320 deny tcp from any to any dst-port 137 in via ${BR}$local_interface${IY}
\$cmd 00321 deny tcp from any to any dst-port 138 in via ${BR}$local_interface${IY}
\$cmd 00322 deny tcp from any to any dst-port 139 in via ${BR}$local_interface${IY}
\$cmd 00323 deny tcp from any to any dst-port 81 in via ${BR}$local_interface${IY}
# deny partial packets
\$cmd 00330 deny ip from any to any frag in via ${BR}$local_interface${IY}
\$cmd 00332 deny tcp from any to any established in via ${BR}$local_interface${IY}
# allowing icmp re: ping, etc.
\$cmd 00310 allow icmp from any to any in via ${BR}$local_interface${IY}
# allowing inbound mail, dhcp, http, https
\$cmd 00370 allow udp from any 67 to me dst-port 68 in via ${BR}$local_interface${IY}keep-state
# allow inbound ssh, mail. PROTECTED SERVICES: numbered ABOVE sshguard blacklist range 
\$cmd 700 allow tcp from any to me dst-port $ssh_port in via ${BR}$local_interface${IY}setup limit src-addr 2
\$cmd 702 allow udp from any to any dst-port ${BR}$listen_port${IY}in via ${BR}$local_interface${IY}keep-state
# deny everything else, and log it
# inbound catchall
\$cmd 999 deny log ip from any to any in via ${BR}$local_interface${IY}
# NAT
\$cmd 1000 nat 1 ip from any to any out via ${BR}$local_interface${IY}# skipto location for outbound stateful rules
\$cmd 1001 allow ip from any to any
# ipfw built-in default, don't uncomment
# \$cmd 65535 deny ip from any to any\n ${Off} " | less

  read -n 1 -s -r -p "
  Review the above. 
  Press any key to continue 
  Press r/R to restart the script
  Press e/E to exit
  " your_choice

  case "$your_choice" in
  [Rr]*)
    sudo bash "$my_wgl_folder"/Scripts/setup_iptables.sh
    ;;
  [Ee]*)
    exit
    ;;
  *)
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
wg_serv_iface=$wg_serv_iface
local_interface=$local_interface
pub_dns=$pub_dns
local_dns=$local_dns
ssh_port=$ssh_port
server_subnet=$server_subnet
listen_port=$listen_port

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

    printf %b\\n "\n Done!

After script is finished, you will need to enable firewall using the following command:\n
\$${BR}sudo service ipfw start${Off}\n
\nOnce firewall is enabled, you will likely loose connection to the VPS. Simply SSH into the server again.\n
You may also need to reboot the server."
    ;;
  esac

else

  printf %b\\n "\n${IW}The following iptables will be configured:${Off}

  # Track VPN connection
  ${IY}iptables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
  iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT${Off}

  # Allow incoming traffic on a specified port
  ${IY}iptables -A INPUT -p udp -m udp --dport ${BR}$listen_port ${IY}-m conntrack --ctstate NEW -j ACCEPT${Off}

  #Forward packets in the VPN tunnel
  ${IY}iptables -A FORWARD -i ${BR}$wg_serv_iface${IY} -o ${BR}$wg_serv_iface ${IY}-m conntrack --ctstate NEW -j ACCEPT${Off}

  # Enable NAT
  ${IY}iptables -t nat -A POSTROUTING -s ${BR}$server_subnet ${IY}-o ${BR}$local_interface ${IY}-j MASQUERADE${Off}

  In addition to setting up iptables, the following commands will be executed:

  # Enabling IP forwarding
  # In /etc/sysctl.conf, net.ipv4.ip_forward value will be changed to 1:
  ${IY}net.ipv4.ip_forward=1${Off}

  #To avoid the need to reboot the server
  ${IY}sysctl -p${Off}

  -------------------------------------------
  "

  read -n 1 -s -r -p "
  Review the above. 
  Press any key to continue 
  Press r/R to restart the script
  Press e/E to exit
  " your_choice

  case "$your_choice" in
  [Rr]*)
    sudo bash "$my_wgl_folder"/Scripts/setup_iptables.sh
    ;;
  [Ee]*)
    exit
    ;;
  *)
    sed -i -E 's/.net.ipv4.ip_forward.*//g' /etc/sysctl.conf
    printf %s\\n "net.ipv4.ip_forward=1" | tee -a /etc/sysctl.conf >/dev/null
    sysctl -p

    iptables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
    iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
    iptables -A INPUT -p udp -m udp --dport "$listen_port" -m conntrack --ctstate NEW -j ACCEPT
    iptables -A FORWARD -i "$wg_serv_iface" -o "$wg_serv_iface" -m conntrack --ctstate NEW -j ACCEPT
    iptables -t nat -A POSTROUTING -s "$server_subnet" -o "$local_interface" -j MASQUERADE
    printf '\e[2J\e[H'
    printf %b\\n "${BW}Done!${Off}"
    ;;
  esac

fi

if [[ "$distro" == "ubuntu" ]] || [[ "$distro" == "debian" ]]; then
  printf %b\\n "\n${IW}In order to make the above iptables rules persistent after system reboot,
  ${BR}iptables-persistent${IW} package needs to be installed.\n
  Would you like the script to install iptables-persistent and to enable the service?\n
  ${IW}Following commands would be used:\n

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
  netfilter rules will need to be saved.\n
  Would you like the script to save the netfilter rules?\n
  ${IW}Following commands would be used:\n

  ${IY}/sbin/service iptables save${Off}"
  read -n 1 -s -r -p "
  Review the above commands.

  Press any key to continue or CTRL+C to stop."

  /sbin/service iptables save

elif [[ "$distro" == "arch" ]] || [[ "$distro" == "manjaro" ]]; then
  printf %b\\n "\n${IW}In order to make the above iptables rules persistent after system reboot,
  netfilter rules will need to be saved.\n
  Would you like the script to save the netfilter rules?\n
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
  ${Off}
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
elif [[ "$distro" == "centos" ]]; then
  if [[ "$check_if_firewalld_installed" == 0 ]]; then
    printf %b\\n "
  ${IW}In order to make the above iptables rules persistent after system reboot,
  netfilter rules will need to be saved.

First, iptables-service needs to be intalled.

  Would you like the script to install iptables-service and save the netfilter rules?

  ${IW}Following commands would be used:

  ${IY}
  sudo yum install iptables-services
  sudo systemctl enable iptables
  sudo service iptables save
  ${Off}
  "
    read -n 1 -s -r -p "
  Review the above commands.

  Press any key to continue or CTRL+C to stop."
    sudo yum install iptables-services
    sudo systemctl enable iptables
    sudo service iptables save
  fi
fi

printf %b\\n "
Congrats, everything should be up and running now!

Ending the script...."
