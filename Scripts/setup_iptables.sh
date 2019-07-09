#!/usr/bin/env bash

if [ "$EUID" -ne 0 ]; then
    echo "Please run the script as root."
    exit 1
fi

############## Determine OS Type ##############
###############################################
ubuntu_os=$(lsb_release -a | grep -c Ubuntu)
arch_os=$(lsb_release -a | grep -c Arch)
cent_os=$(lsb_release -a | grep -c CentOS)
debian_os=$(lsb_release -a | grep -c Debian)
fedora_os=$(lsb_release -a | grep -c Fedora)
manjaro_os=$(lsb_release -a | grep -c Manjaro)

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

my_wgl_folder=$(find /home -type d -name WireGuard-Ligase)
source "$my_wgl_folder"/doc/colours.sh
my_separator="--------------------------------------"
check_pub_ip=$(curl https://checkip.amazonaws.com)

echo -e "
${IWhite}We are going to setup some basic iptables so the server can function correctly.

Please provide the server subnet information to be used.${Color_Off}

${BWhite}Example:${IWhite} If you server IP is ${BRed}10.0.0.1/24${IWhite}, then please type ${BRed}10.0.0.0/24${Color_Off}
"
echo -e "$my_separator"
read -r server_subnet
echo -e "$my_separator"

echo -e "
${IWhite}Please also provide the listen port of your server.${Color_Off}

${BWhite}Example: ${BRed}51820${Color_Off}"

echo -e "$my_separator"
read -r listen_port
echo -e "$my_separator"

# Public IP address of the server hosting the WireGuard server
echo -e "
${IWhite}The public IP address of this machine is $check_pub_ip. Is this the address you would like to use? ${Color_Off}

${BWhite}1 = yes, 2 = no${Color_Off}"
read -r public_address
if [[ "$public_address" == 1 ]]; then
  server_public_address=$check_pub_ip
elif [[ "$public_address" == 2 ]]; then
  echo -e "
  ${IWhite}Please specify the public address of the server.${Color_Off}"
  read -r server_public_address
fi

echo -e "$my_separator"

echo -e "
${IWhite}Please also provide the internet facing interface of the server. Can be obrained with ${BRed}ip a ${IWhite}or ${BRed}ifconfig${Color_Off}

${BWhite}Example: ${BRed}eth0${Color_Off}"

echo -e "$my_separator"
read -r local_interface
echo -e "$my_separator"


echo -e "
${IWhite}Finally, specify the interface name to be used for wireguard. Usually it matches your WireGuard *.conf file.${Color_Off}

${BWhite}Example: ${IWhite}if your server config file is ${BRed}wg0.conf, ${IWhite}interface is ${BRed}wg0${Color_Off}

${IGreen}HINT: You can also check using 'ip a' or 'ifconfig' command${Color_Off}"

echo -e "$my_separator"
read -r interface_name
echo -e "$my_separator"

if [[ "$cent_os" -gt 0 ]]; then
  echo -e "
  ${IWhite}
  OS Type: CentOS
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
  Review the above commands.

  Press any key to continue or CTRL+C to stop."

  sed -i 's/net.ipv4.ip_forward=0/net.ipv4.ip_forward=1/g' /etc/sysctl.conf
  sed -i 's/#net.ipv4.ip_forward=0/net.ipv4.ip_forward=1/g' /etc/sysctl.conf
  sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g' /etc/sysctl.conf
  sysctl -p

  firewall-cmd --zone=public --add-port="$listen_port"/udp
  firewall-cmd --zone=trusted --add-source="$server_subnet"
  firewall-cmd --permanent --zone=public --add-port="$listen_port"/udp
  firewall-cmd --permanent --zone=trusted --add-source="$server_subnet"
  firewall-cmd --direct --add-rule ipv4 nat POSTROUTING 0 -s "$server_subnet" ! -d "$server_subnet" -j SNAT --to "$server_public_address"
  firewall-cmd --permanent --direct --add-rule ipv4 nat POSTROUTING 0 -s "$server_subnet" ! -d "$server_subnet" -j SNAT --to "$server_public_address"

  echo -e "
  ${BWhite}Done!${Color_Off}"
else
  echo -e "
  ${IWhite}The following iptables will be configured:${Color_Off}

  # Track VPN connection
  ${IYellow}iptables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
  iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT${Color_Off}

  # Allow incoming traffic on a specified port
  ${IYellow}iptables -A INPUT -p udp -m udp --dport ${BRed}$listen_port ${IYellow}-m conntrack --ctstate NEW -j ACCEPT${Color_Off}

  #Forward packets in the VPN tunnel
  ${IYellow}iptables -A FORWARD -i ${BRed}$interface_name${IYellow} -o ${BRed}$interface_name ${IYellow}-m conntrack --ctstate NEW -j ACCEPT${Color_Off}

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
  Review the above commands.

  Press any key to continue or CTRL+C to stop."

  sed -i 's/net.ipv4.ip_forward=0/net.ipv4.ip_forward=1/g' /etc/sysctl.conf
  sed -i 's/#net.ipv4.ip_forward=0/net.ipv4.ip_forward=1/g' /etc/sysctl.conf
  sed -i 's/#net.ipv4.ip_forward=1/net.ipv4.ip_forward=1/g' /etc/sysctl.conf
  sysctl -p

  iptables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
  iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
  iptables -A INPUT -p udp -m udp --dport "$listen_port" -m conntrack --ctstate NEW -j ACCEPT
  iptables -A FORWARD -i "$interface_name" -o "$interface_name" -m conntrack --ctstate NEW -j ACCEPT
  iptables -t nat -A POSTROUTING -s "$server_subnet" -o "$local_interface" -j MASQUERADE

  echo -e "${BWhite}Done!${Color_Off}"
fi

if [[ "$distro" = "ubuntu" ]] || [[ "$distro" = "debian" ]]; then
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
elif [[ "$distro" = "fedora" ]]; then
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

elif [[ "$distro" = "arch" ]] || [[ "$distro" = "manjaro" ]]; then
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
  iptables-save > /etc/iptables/iptables.rules
  systemctl restart iptables.service
fi

echo -e "
Ending the script...."
