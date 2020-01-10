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
${BWhite}Server private address = ${BRed}$server_private_range${Color_Off}
${BWhite}Server listen port = ${BRed}$server_listen_port${Color_Off}
${BWhite}Server public address = ${BRed}$server_public_address${Color_Off}
${BWhite}WAN interface = ${BRed}$local_interface${Color_Off}
${BWhite}WireGuard interface = ${BRed}$wg_serv_iface${Color_Off}
+--------------------------------------------+\n"

  read -n 1 -s -r -p "
Review the above. 
Press any key to continue (everything looks correct)
Press r/R if some variables need to be changed
Press e/E to exit
" your_choice

  case "$your_choice" in
  [Rr]*)
    printf %b\\n "\n${IWhite}We are going to setup some basic firewall rules so the server can
function correctly.

Step 1) Please provide the server subnet information to be used.${Color_Off}

${BWhite}Example:${IWhite} If you server IP is ${BRed}10.0.0.1/24${IWhite}, then please type ${BRed}10.0.0.0/24${Color_Off}\n"

    read -r -p "Server subnet: " server_subnet

    printf '\e[2J\e[H'

    printf %b\\n "
+--------------------------------------------+
${BWhite}Server subnet = ${BRed}$server_subnet${Color_Off}
+--------------------------------------------+

${IWhite}Step 2) Please also provide the listen port of your server.${Color_Off}

${BWhite}Example: ${BRed}51820${Color_Off}"

    read -r -p "Server listen port: " listen_port

    printf '\e[2J\e[H'

    # Public IP address of the server hosting the WireGuard server
    printf %b\\n "
+--------------------------------------------+
${BWhite}Server subnet = ${BRed}$server_subnet${Color_Off}
${BWhite}Server port = ${BRed}$listen_port${Color_Off}
+--------------------------------------------+

${BWhite}Step 3)${Color_Off} ${IWhite}The public IP address of this machine is $check_pub_ip. 
Is this the address you would like to use? ${Color_Off}

${BWhite}1 = yes, 2 = no${Color_Off}"
    read -r -p "Choice: " public_address

    printf %b\\n "$my_separator"

    if [[ "$public_address" == 1 ]]; then
      server_public_address="$check_pub_ip"
    elif [[ "$public_address" == 2 ]]; then
      printf %b\\n "
${IWhite}Please specify the public address of the server.${Color_Off}
"
      read -r -p "Public IP: " server_public_address
    fi

    printf '\e[2J\e[H'

    printf %b\\n "
+--------------------------------------------+
${BWhite}Server subnet = ${BRed}$server_subnet${Color_Off}
${BWhite}Server port = ${BRed}$listen_port${Color_Off}
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

    printf %b\\n "
+--------------------------------------------+
${BWhite}Server subnet = ${BRed}$server_subnet${Color_Off}
${BWhite}Server port = ${BRed}$listen_port${Color_Off}
${BWhite}Server public address = ${BRed}$server_public_address${Color_Off}
${BWhite}WAN Interface = ${BRed}$local_interface${Color_Off}
+--------------------------------------------+

${IWhite}Step 5) Specify wireguard server interface name 
(will be the same as config name, without .conf)${Color_Off}
"

    read -r -p "WireGuard Interface: " wg_serv_iface

    printf '\e[2J\e[H'
    ;;
  [Ee]*)
    exit
    ;;
  *)
    printf %b\\n "\n${IWhite}We are going to setup some basic firewall rules so the server can
function correctly.

Step 1) Please provide the server subnet information to be used.${Color_Off}

${BWhite}Example:${IWhite} If you server IP is ${BRed}10.0.0.1/24${IWhite}, then please type ${BRed}10.0.0.0/24${Color_Off}\n"

    read -r -p "Server subnet: " server_subnet

    printf '\e[2J\e[H'
    ;;
  esac

###############################################
# Else, start from the beginning and gather
# needed info.
###############################################
else

  printf %b\\n "\n${IWhite}We are going to setup some basic firewall rules so the server can
function correctly.

Step 1) Please provide the server subnet information to be used.${Color_Off}

${BWhite}Example:${IWhite} If you server IP is ${BRed}10.0.0.1/24${IWhite}, then please type ${BRed}10.0.0.0/24${Color_Off}\n"

  read -r -p "Server subnet: " server_subnet

  printf '\e[2J\e[H'

  printf %b\\n "
+--------------------------------------------+
${BWhite}Server subnet = ${BRed}$server_subnet${Color_Off}
+--------------------------------------------+

${IWhite}Step 2) Please also provide the listen port of your server.${Color_Off}

${BWhite}Example: ${BRed}51820${Color_Off}"

  read -r -p "Server listen port: " listen_port

  printf '\e[2J\e[H'

  # Public IP address of the server hosting the WireGuard server
  printf %b\\n "
+--------------------------------------------+
${BWhite}Server subnet = ${BRed}$server_subnet${Color_Off}
${BWhite}Server port = ${BRed}$listen_port${Color_Off}
+--------------------------------------------+

${BWhite}Step 3)${Color_Off} ${IWhite}The public IP address of this machine is $check_pub_ip. 
Is this the address you would like to use? ${Color_Off}

${BWhite}1 = yes, 2 = no${Color_Off}"
  read -r -p "Choice: " public_address

  printf %b\\n "$my_separator"

  if [[ "$public_address" == 1 ]]; then
    server_public_address="$check_pub_ip"
  elif [[ "$public_address" == 2 ]]; then
    printf %b\\n "
${IWhite}Please specify the public address of the server.${Color_Off}
"
    read -r -p "Public IP: " server_public_address
  fi

  printf '\e[2J\e[H'

  printf %b\\n "
+--------------------------------------------+
${BWhite}Server subnet = ${BRed}$server_subnet${Color_Off}
${BWhite}Server port = ${BRed}$listen_port${Color_Off}
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

  printf %b\\n "
+--------------------------------------------+
${BWhite}Server subnet = ${BRed}$server_subnet${Color_Off}
${BWhite}Server port = ${BRed}$listen_port${Color_Off}
${BWhite}Server public address = ${BRed}$server_public_address${Color_Off}
${BWhite}WAN Interface = ${BRed}$local_interface${Color_Off}
+--------------------------------------------+

${IWhite}Step 5) Specify wireguard server interface name 
(will be the same as config name, without .conf)${Color_Off}
"

  read -r -p "WireGuard Interface: " wg_serv_iface

  printf '\e[2J\e[H'

fi

if [[ "$cent_os" -gt 0 ]]; then
  check_if_firewalld_installed=$(yum list installed | grep -i -c firewalld)
  if [[ "$check_if_firewalld_installed" == 1 ]]; then
    printf %b\\n "
    ${IWhite}
    OS Type: CentOS
    Firewalld: installed
    The following firewall rules will be configured:${Color_Off}

    ${IYellow}
    firewall-cmd --zone=public --add-port=$listen_port/udp
    firewall-cmd --zone=trusted --add-source=$server_subnet
    firewall-cmd --permanent --zone=public --add-port=$listen_port/udp
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
      sed -i 's/net.ipv4.ip_forward=0//g' /etc/sysctl.conf
      sed -i 's/#net.ipv4.ip_forward=0//g' /etc/sysctl.conf
      sed -i 's/#net.ipv4.ip_forward=1//g' /etc/sysctl.conf
      printf %s\\n "net.ipv4.ip_forward=1" >>/etc/sysctl.conf
      sysctl -p

      firewall-cmd --zone=public --add-port="$listen_port"/udp
      firewall-cmd --zone=trusted --add-source="$server_subnet"
      firewall-cmd --permanent --zone=public --add-port="$listen_port"/udp
      firewall-cmd --permanent --zone=trusted --add-source="$server_subnet"
      firewall-cmd --direct --add-rule ipv4 nat POSTROUTING 0 -s "$server_subnet" ! -d "$server_subnet" -j SNAT --to "$server_public_address"
      firewall-cmd --permanent --direct --add-rule ipv4 nat POSTROUTING 0 -s "$server_subnet" ! -d "$server_subnet" -j SNAT --to "$server_public_address"
      printf '\e[2J\e[H'
      printf %b\\n "${BWhite}Done!${Color_Off}"
      ;;
    esac

  elif [[ "$check_if_firewalld_installed" == 0 ]]; then
    printf %b\\n "
    ${IWhite}
    OS Type: CentOS
    Firewalld: NOT installed - using iptables
    The following firewall rules will be configured:${Color_Off}"

    printf %b\\n "
    ${IWhite}The following iptables will be configured:${Color_Off}

    # Track VPN connection
    ${IYellow}iptables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
    iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT${Color_Off}

    # Allow incoming traffic on a specified port
    ${IYellow}iptables -A INPUT -p udp -m udp --dport ${BRed}$listen_port ${IYellow}-m conntrack --ctstate NEW -j ACCEPT${Color_Off}

    #Forward packets in the VPN tunnel
    ${IYellow}iptables -A FORWARD -i ${BRed}$wg_serv_iface${IYellow} -o ${BRed}$wg_serv_iface ${IYellow}-m conntrack --ctstate NEW -j ACCEPT${Color_Off}

    # Enable NAT
    ${IYellow}iptables -t nat -A POSTROUTING -s ${BRed}$server_subnet ${IYellow}-o $local_interface -j MASQUERADE${Color_Off}

    In addition to setting up iptables, the following commands will be executed:

    # Enabling IP forwarding
    # In /etc/sysctl.conf, net.ipv4.ip_forward value will be changed to 1:
    ${IYellow}net.ipv4.ip_forward=1${Color_Off}

    #To avoid the need to reboot the server
    ${IYellow}sysctl -p${Color_Off}

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
      sed -i 's/net.ipv4.ip_forward=0//g' /etc/sysctl.conf
      sed -i 's/#net.ipv4.ip_forward=0//g' /etc/sysctl.conf
      sed -i 's/#net.ipv4.ip_forward=1//g' /etc/sysctl.conf
      printf %s\\n "net.ipv4.ip_forward=1" >>/etc/sysctl.conf
      sysctl -p

      iptables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
      iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
      iptables -A INPUT -p udp -m udp --dport "$listen_port" -m conntrack --ctstate NEW -j ACCEPT
      iptables -A FORWARD -i "$wg_serv_iface" -o "$wg_serv_iface" -m conntrack --ctstate NEW -j ACCEPT
      iptables -t nat -A POSTROUTING -s "$server_subnet" -o "$local_interface" -j MASQUERADE
      printf '\e[2J\e[H'
      printf %b\\n "${BWhite}Done!${Color_Off}"
      ;;
    esac
  fi
elif [[ "$distro" == "freebsd" ]]; then
  cmd="ipfw -q add "
  skip="skipto 1000"
  local_dns=$(cat /etc/resolv.conf | grep -Eo '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | awk '{print $1}')

  printf %b\\n "
    ${IWhite}
    OS Type: FreeBSD
    IPFW will be used.
    ${Color_Off}"

  printf %b\\n "${IWhite}\nFreeBSD IPFW requires some fine-tuning for optimal security.\n
In order to make sure you do not get locked out of the server, please specify the port used for SSH. Default is 22.${Color_Off}"

  read -r -p "SSH Port: " ssh_port

  printf %b\\n "${IWhite}\nFinally, we will manually allow forwarding DNS traffic from WireGuard peers to the external DNS server.\n
Please specify the DNS to be used by WireGuard peers.${Color_Off}"

  read -r -p "Peer DNS: " pub_dns

  printf %b\\n "${IWhite}\nThe following firewall rules will be configured:\n${Color_Off}"

  printf %b\\n "\n
# 1) First, we'll make sure the following is present in /etc/rc.conf

firewall_enable=\"YES\"
firewall_nat_enable=\"YES\"
firewall_script=\"/usr/local/etc/IPFW.rules\"
firewall_logging=\"YES\"

# The above will be achieved with the following commands:
${IYellow}
## Make sure we dont have any duplicates
sed -i -E 's/firewall_enable=.*//g' /etc/rc.conf
sed -i -E 's/firewall_nat_enable=.*//g' /etc/rc.conf
sed -i -E 's/firewall_script=.*//g' /etc/rc.conf
sed -i -E 's/firewall_logging=.*//g' /etc/rc.conf

## Insert rules
printf %b \\n \"firewall_enable=\"YES\"
firewall_nat_enable=\"YES\"
firewall_script=\"/usr/local/etc/IPFW.rules\"
firewall_logging=\"YES\"\" | tee -a /etc/rc.conf > /dev/null 
${Color_Off}

# 2) Second, we'll disable TCP offset fragmentation and enable IP forwarding.

${IYellow}
## Disable TCP segmentation offloading to use in-kernel NAT
## See 30.4.4. In-kernel NAT in https://www.freebsd.org/doc/handbook/firewalls-ipfw.html
$ sudo sysctl net.inet.tcp.tso=\"0\"
## Enable IP forwarding
$ sudo sysctl net.inet.ip.forwarding=\"1\"
${Color_Off}

# 3) Finally, we will create a file /usr/local/etc/IPFW.rules with the following firewall rules:
---------------------
${IYellow}
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
ipfw -q nat 1 config if ${BRed}$local_interface${IYellow}same_ports unreg_only reset
# allow all for localhost
\$cmd 00010 allow ip from any to any via lo0
\$cmd 00011 allow ip from any to any via ${BRed}$wg_serv_iface${IYellow}
# NAT-specifig rules
\$cmd 00099 reass all from any to any in       # reassamble inbound packets
\$cmd 00100 nat 1 ip from any to any in via ${BRed}$local_interface${IYellow}# NAT any inbound packets
# checks stateful rules.  If marked as \"keep-state\" the packet has
# already passed through filters and is \"OK\" without futher
# rule matching
\$cmd 00101 check-state
# allow DNS out
\$cmd 00110 \$skip tcp from any to ${BRed}$pub_dns${IYellow}dst-port 53 out via ${BRed}$local_interface${IYellow}setup keep-state
\$cmd 00111 \$skip udp from any to ${BRed}$pub_dns${IYellow}dst-port 53 out via ${BRed}$local_interface${IYellow}keep-state
\$cmd 00112 \$skip tcp from any to ${BRed}$pub_dns${IYellow}dst-port 53 out via ${BRed}$local_interface${IYellow}setup keep-state
\$cmd 00113 \$skip udp from any to ${BRed}$pub_dns${IYellow}dst-port 53 out via ${BRed}$local_interface${IYellow}keep-state
# allow dhclient connection out (port numbers are important)
\$cmd 00120 \$skip udp from me 68 to any dst-port 67 out via ${BRed}$local_interface${IYellow}keep-state
# allow HTTP HTTPS replies
\$cmd 00200 \$skip tcp from any to any dst-port 80 out via ${BRed}$local_interface${IYellow}setup keep-state
\$cmd 00220 \$skip tcp from any to any dst-port 443 out via ${BRed}$local_interface${IYellow}setup keep-state
# allow outbound mail
\$cmd 00230 \$skip tcp from any to any dst-port 25 out via ${BRed}$local_interface${IYellow}setup keep-state
\$cmd 00231 \$skip tcp from any to any dst-port 465 out via ${BRed}$local_interface${IYellow}setup keep-state
\$cmd 00232 \$skip tcp from any to any dst-port 587 out via ${BRed}$local_interface${IYellow}setup keep-state
# allow WG
\$cmd 00233 \$skip udp from any to any src-port ${BRed}$listen_port${IYellow}out via ${BRed}$local_interface${IYellow}keep-state
\$cmd 00234 \$skip udp from ${BRed}$server_subnet${IYellow}to any out via ${BRed}$local_interface${IYellow}keep-state
\$cmd 00235 \$skip tcp from ${BRed}$server_subnet${IYellow}to any out via ${BRed}$local_interface${IYellow}setup keep-state
# allow icmp re: ping, et. al. 
# comment this out to disable ping, et.al.
\$cmd 00250 \$skip icmp from any to any out via ${BRed}$local_interface${IYellow}keep-state
# alllow timeserver out
\$cmd 00260 \$skip tcp from any to any dst-port 37 out via ${BRed}$local_interface${IYellow}setup keep-state
# allow ntp out
\$cmd 00270 \$skip udp from any to any dst-port 123 out via ${BRed}$local_interface${IYellow}keep-state
# allow outbound SSH traffic
\$cmd 00280 \$skip tcp from any to any dst-port 22 out via ${BRed}$local_interface${IYellow}setup keep-state
# otherwise deny outbound packets
# outbound catchall.  
\$cmd 00299 deny log ip from any to any out via ${BRed}$local_interface${IYellow}
# inbound rules
# deny inbound traffic to restricted addresses
\$cmd 00300 deny ip from 192.168.0.0/16 to any in via ${BRed}$local_interface${IYellow}
\$cmd 00301 deny all from 172.16.0.0/12 to any in via ${BRed}$local_interface${IYellow}     #RFC 1918 private IP
\$cmd 00302 deny ip from 10.0.0.0/8 to any in via ${BRed}$local_interface${IYellow}
\$cmd 00303 deny ip from 127.0.0.0/8 to any in via ${BRed}$local_interface${IYellow}
\$cmd 00304 deny ip from 0.0.0.0/8 to any in via ${BRed}$local_interface${IYellow}
\$cmd 00305 deny ip from 169.254.0.0/16 to any in via ${BRed}$local_interface${IYellow}
\$cmd 00306 deny ip from 192.0.2.0/24 to any in via ${BRed}$local_interface${IYellow}
\$cmd 00307 deny ip from 204.152.64.0/23 to any in via ${BRed}$local_interface${IYellow}
\$cmd 00308 deny ip from 224.0.0.0/3 to any in via ${BRed}$local_interface${IYellow}
# deny inbound packets on these ports
# auth 113, netbios (services) 137/138/139, hosts-nameserver 81 
\$cmd 00315 deny tcp from any to any dst-port 113 in via ${BRed}$local_interface${IYellow}
\$cmd 00320 deny tcp from any to any dst-port 137 in via ${BRed}$local_interface${IYellow}
\$cmd 00321 deny tcp from any to any dst-port 138 in via ${BRed}$local_interface${IYellow}
\$cmd 00322 deny tcp from any to any dst-port 139 in via ${BRed}$local_interface${IYellow}
\$cmd 00323 deny tcp from any to any dst-port 81 in via ${BRed}$local_interface${IYellow}
# deny partial packets
\$cmd 00330 deny ip from any to any frag in via ${BRed}$local_interface${IYellow}
\$cmd 00332 deny tcp from any to any established in via ${BRed}$local_interface${IYellow}
# allowing icmp re: ping, etc.
\$cmd 00310 allow icmp from any to any in via ${BRed}$local_interface${IYellow}
# allowing inbound mail, dhcp, http, https
\$cmd 00370 allow udp from any 67 to me dst-port 68 in via ${BRed}$local_interface${IYellow}keep-state
# allow inbound ssh, mail. PROTECTED SERVICES: numbered ABOVE sshguard blacklist range 
\$cmd 700 allow tcp from any to me dst-port $ssh_port in via ${BRed}$local_interface${IYellow}setup limit src-addr 2
\$cmd 702 allow udp from any to any dst-port ${BRed}$listen_port${IYellow}in via ${BRed}$local_interface${IYellow}keep-state
# deny everything else, and log it
# inbound catchall
\$cmd 999 deny log ip from any to any in via ${BRed}$local_interface${IYellow}
# NAT
\$cmd 1000 nat 1 ip from any to any out via ${BRed}$local_interface${IYellow}# skipto location for outbound stateful rules
\$cmd 1001 allow ip from any to any
# ipfw built-in default, don't uncomment
# \$cmd 65535 deny ip from any to any\n ${Color_Off} " | more

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
    

    printf %b \\n "gateway_enable=\"YES\"
firewall_enable=\"YES\"
firewall_nat_enable=\"YES\"
firewall_script=\"/usr/local/etc/IPFW.rules\"
firewall_logging=\"YES\"" | tee -a /etc/rc.conf >/dev/null


# Disable TCP segmentation offloading
# See https://www.freebsd.org/doc/handbook/firewalls-ipfw.html
# 30.4.4 In-kernet NAT
printf %b \\n "net.inet.tcp.tso=0" | tee -a /etc/sysctl.conf >/dev/null

    sudo sysctl net.inet.tcp.tso="0"
    sudo sysctl net.inet.ip.forwarding="1"

    printf %b \\n "#!/bin/sh
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

    printf %b \\n "\n Done!

After script is finished, you will need to enable firewall using the following command:\n
$ ${BRed}sudo service ipfw start${Color_Off}\n

Once firewall is enabled, you will likely loose connection to the VPS. Simply SSH into the server again.

You will also likely need to reboot the server."
    ;;
  esac

else

  printf %b\\n "
  ${IWhite}The following iptables will be configured:${Color_Off}

  # Track VPN connection
  ${IYellow}iptables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
  iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT${Color_Off}

  # Allow incoming traffic on a specified port
  ${IYellow}iptables -A INPUT -p udp -m udp --dport ${BRed}$listen_port ${IYellow}-m conntrack --ctstate NEW -j ACCEPT${Color_Off}

  #Forward packets in the VPN tunnel
  ${IYellow}iptables -A FORWARD -i ${BRed}$wg_serv_iface${IYellow} -o ${BRed}$wg_serv_iface ${IYellow}-m conntrack --ctstate NEW -j ACCEPT${Color_Off}

  # Enable NAT
  ${IYellow}iptables -t nat -A POSTROUTING -s ${BRed}$server_subnet ${IYellow}-o ${BRed}$local_interface ${IYellow}-j MASQUERADE${Color_Off}

  In addition to setting up iptables, the following commands will be executed:

  # Enabling IP forwarding
  # In /etc/sysctl.conf, net.ipv4.ip_forward value will be changed to 1:
  ${IYellow}net.ipv4.ip_forward=1${Color_Off}

  #To avoid the need to reboot the server
  ${IYellow}sysctl -p${Color_Off}

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
    sed -i 's/net.ipv4.ip_forward=0/net.ipv4.ip_forward=1/g' /etc/sysctl.conf
    sed -i 's/#net.ipv4.ip_forward=0/net.ipv4.ip_forward=1/g' /etc/sysctl.conf
    sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g' /etc/sysctl.conf
    sysctl -p

    iptables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
    iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
    iptables -A INPUT -p udp -m udp --dport "$listen_port" -m conntrack --ctstate NEW -j ACCEPT
    iptables -A FORWARD -i "$wg_serv_iface" -o "$wg_serv_iface" -m conntrack --ctstate NEW -j ACCEPT
    iptables -t nat -A POSTROUTING -s "$server_subnet" -o "$local_interface" -j MASQUERADE
    printf '\e[2J\e[H'
    printf %b\\n "${BWhite}Done!${Color_Off}"
    ;;
  esac

fi

if [[ "$distro" == "ubuntu" ]] || [[ "$distro" == "debian" ]]; then
  printf %b\\n "
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
  printf %b\\n "
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
  printf %b\\n "
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
elif [[ "$distro" == "centos" ]]; then
  if [[ "$check_if_firewalld_installed" == 0 ]]; then
    printf %b\\n "
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
fi

printf %b\\n "
Congrats, everything should be up and running now!

Ending the script...."
