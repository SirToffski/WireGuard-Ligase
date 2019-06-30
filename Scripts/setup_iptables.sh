#!/usr/bin/env bash

find_colours_dir="$(find find ~/*/WireGuard-Ligase/ -name colours.sh)"
source "$find_colours_dir"
my_separator="--------------------------------------"

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

echo -e "
${IWhite}Finally, specify the interface name to be used for wireguard. Usually it matches your WireGuard *.conf file.${Color_Off}

${BWhite}Example: ${IWhite}if your server config file is ${BRed}wg0.conf, ${IWhite}interface is ${BRed}wg0${Color_Off}

${IGreen}HINT: You can also check using 'ip a' or 'ifconfig' command${Color_Off}"

echo -e "$my_separator"
read -r interface_name
echo -e "$my_separator"

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
${IYellow}iptables -t nat -A POSTROUTING -s ${BRed}$server_subnet ${IYellow}-o eth0 -j MASQUERADE${Color_Off}

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
iptables -t nat -A POSTROUTING -s "$server_subnet" -o eth0 -j MASQUERADE

echo -e "${BWhite}Done!${Color_Off}"

echo -e "
${IWhite}In order to make the above iptables rules persistent after system reboot,
${BRed}iptables-persistent ${IWhite} package needs to be installed.

Would you like the script to install iptables-persistent and to enable the service?

${BGreen}NOTE: * At this time this applies to Ubuntu only *

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

echo -e "
Ending the script...."
