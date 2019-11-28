#!/usr/bin/env bash

if [ "$EUID" -ne 0 ]; then
  echo "Please run the script as root."
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
arch_os=$(lsb_release -a | grep -c Arch)
cent_os=$(hostnamectl | grep -i -c CentOS)
debian_os=$(lsb_release -a | grep -i -c Debian)
fedora_os=$(lsb_release -a | grep -i  -c Fedora)
manjaro_os=$(lsb_release -a | grep -i -c Manjaro)

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
fi
###############################################
###############################################

my_separator="--------------------------------------"
check_pub_ip=$(curl -s https://checkip.amazonaws.com)

printf '\e[2J\e[H'

printf %b\\n "\n${IWhite}We are going to setup some basic firewwall rules so the server can
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
      echo "net.ipv4.ip_forward=1" >>/etc/sysctl.conf
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
      echo "net.ipv4.ip_forward=1" >>/etc/sysctl.conf
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

printf '\e[2J\e[H'
printf %b\\n "
Congrats, everything should be up and running now!

Ending the script...."
