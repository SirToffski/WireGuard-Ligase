#!/usr/bin/env bash

echo "
We are going to setup some basic iptables so the server can function correctly.

Please provide the server subnet information to be used.

Example: If you server IP is 10.0.0.1/24, then please type 10.0.0.0/24
"

read -r server_subnet

echo "Please also provide the listen port of your server.

Example: 51820"

read -r listen_port

echo "Finally, specify the interface name to be used for wireguard. Usually it matches your WireGuard *.conf file.

Example: if your server config file is wg0.conf, interface is wg0.

HINT: You can also check using 'ip a' or 'ifconfig' command"

read -r interface_name

echo "
The following iptables will be configured:

# Track VPN connection
iptables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT

# Allow incoming traffic on a specified port
iptables -A INPUT -p udp -m udp --dport $listen_port -m conntrack --ctstate NEW -j ACCEPT

#Forward packets in the VPN tunnel
iptables -A FORWARD -i $interface_name -o $interface_name -m conntrack --ctstate NEW -j ACCEPT

# Enable NAT
iptables -t nat -A POSTROUTING -s $server_subnet -o eth0 -j MASQUERADE

In addition to setting up iptables, the following commands will be executed:

#Enabling IP forwarding
In /etc/sysctl.conf, net.ipv4.ip_forward value will be changed to 1:
net.ipv4.ip_forward=1

#To avoid the need to reboot the server
sysctl -p

-------------------------------------------
"

read -n 1 -s -r -p "
Review the above commands.

Press any key to continue or CTRL+C to stop."

sed -i 's/#net.ipv4.ip_forward=0/net.ipv4.ip_forward=1/g' /etc/sysctl.conf
sysctl -p

iptables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
iptables -A FORWARD -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
iptables -A INPUT -p udp -m udp --dport "$listen_port" -m conntrack --ctstate NEW -j ACCEPT
iptables -A FORWARD -i "$interface_name" -o "$interface_name" -m conntrack --ctstate NEW -j ACCEPT
iptables -t nat -A POSTROUTING -s "$server_subnet" -o eth0 -j MASQUERADE

echo "Done!"

echo "
In order to make the above iptables rules persistent after system reboot,
iptables-persistent need to be installed.

Would you like the script to install iptables-persistent and enabled the service?

Following commands would be used:


apt-get install iptables-persistent
systemctl enable netfilter-persistent
netfilter-persistent save"

read -n 1 -s -r -p "
Review the above commands.

Press any key to continue or CTRL+C to stop."

apt-get install iptables-persistent
systemctl enable netfilter-persistent
netfilter-persistent save

echo "
Ending the script...."
