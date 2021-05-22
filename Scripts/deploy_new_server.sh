#!/usr/bin/env bash

check_root() {
  if [ "$EUID" -ne 0 ]; then
    printf %b\\n "Please run the script as root."
    exit 1
  fi
}

printf %b\\n "+--------------------------------------------+"
clear_screen() {
  printf '\e[2J\e[H'
}

source_variables() {
  # Default working directory of the script.
  ## Requirements: Cloning the entire repository.
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

  # Create a file with shared variables between the scripts
  printf %b\\n "#!/usr/bin/env bash" >"$my_wgl_folder"/shared_vars.sh
}

create_needed_dirs() {
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
}

ask_to_proceed() {
  read -n 1 -s -r -p "
Review the above. 
Press any key to continue 
Press r/R to try again
Press e/E to exit
" your_choice
}

generate_server_config() {

  clear_screen
  # Determine the public IP of the host.
  check_pub_ip=$(curl -s https://checkip.amazonaws.com)

  printf %b\\n "This script will take you through the steps needed to deploy a new server
and configure some clients."

  if [ -f "$check_for_full_clone" ]; then
    printf %b\\n "\n First, let's check if wireguard is installed..."

    ############## Determine OS Type ##############
    # see /doc/functions.sh for more info
    ###############################################
    determine_os
    check_wg_installation
    ############### FINISHED CHECKING OS AND OFFER TO INSTALL WIREGUARD ###############
  fi

  # Private address could be any address within RFC 1918,
  # usually the first useable address in a /24 range.
  # This however is completely up to you.
  printf %b\\n ""
  colour_print "${BW}" "Step 1) ${IW}Please specify the private address of the WireGuard server."
  read -r -p "Address: " server_private_range

  clear_screen

  # This would be a UDP port the WireGuard server would listen on.
  printf %b\\n ""
  printf %b\\n "--------------------------------------------+"
  colour_print "${BW}" "Server private address = ${BR}$server_private_range"
  printf %b\\n "+--------------------------------------------+"
  printf %b\\n ""
  colour_print "${BW}" "Step 2) ${IW}Please specify listen port of the server."
  printf %b\\n ""
  read -r -p "Listen port: " server_listen_port

  clear_screen

  # Public IP address of the server hosting the WireGuard server
  printf %b\\n ""
  printf %b\\n "+--------------------------------------------+"
  colour_print "${BW}" "Server private address = ${BR}$server_private_range"
  colour_print "${BW}" "Server listen port = ${BR}$server_listen_port"
  printf %b\\n "+--------------------------------------------+"
  printf %b\\n ""
  colour_print "${BW}" "Step 3) ${IW}The public IP address of this machine is $check_pub_ip."
  colour_print "${BW}" "Is this the address you would like to use?"
  printf %b\\n ""
  colour_print "${BW}" "1 = yes, 2 = no"
  read -r -p "Choice: " public_address

  printf %b\\n "+--------------------------------------------+"

  if [ "$public_address" = 1 ]; then
    server_public_address="$check_pub_ip"
  elif [ "$public_address" = 2 ]; then
    printf %b\\n ""
    colour_print "${IW}" "Please specify the public address of the server."
    read -r -p "Public IP: " server_public_address
    printf %b\\n "+--------------------------------------------+"
  fi

  clear_screen

  # Internet facing iface of the server hosting the WireGuard server
  printf %b\\n ""
  printf %b\\n "+--------------------------------------------+"
  colour_print "${BW}" "Server private address = ${BR}$server_private_range"
  colour_print "${BW}" "Server listen port = ${BR}$server_listen_port"
  colour_print "${BW}" "Server public address = ${BR}$server_public_address"
  printf %b\\n "+--------------------------------------------+"
  printf %b\\n ""
  colour_print "${BW}" "Step 4) ${IW}Please also provide the internet facing interface of the server."
  colour_print "${BW}" "Example: ${BR}eth0"

  if [ "$distro" != "" ] && [ "$distro" != "freebsd" ]; then
    printf %b\\n ""
    printf %b\\n "Available interfaces are:"
    printf %b\\n "+--------------------+"
    printf %b\\n "$(ip -br a | awk '{print $1}')"
    printf %b\\n "+--------------------+"
  else
    printf %b\\n ""
    printf %b\\n "Available interfaces are:"
    printf %b\\n "+--------------------+"
    printf %b\\n "$(ifconfig -l)"
    printf %b\\n "+--------------------+"
  fi

  read -r -p "Interface: " local_interface

  clear_screen

  printf %b\\n ""
  printf %b\\n "--------------------------------------------+"
  colour_print "${BW}" "Server private address = ${BR}$server_private_range"
  colour_print "${BW}" "Server listen port = ${BR}$server_listen_port"
  colour_print "${BW}" "Server public address = ${BR}$server_public_address"
  colour_print "${BW}" "WAN interface = ${BR}$local_interface"
  printf %b\\n "+--------------------------------------------+"
  printf %b\\n ""

  ask_to_proceed

  case "$your_choice" in
    [Rr]*)
      sudo bash "$my_wgl_folder"/Scripts/deploy_new_server.sh
      ;;
    [Ee]*)
      exit
      ;;
    *)
      clear_screen
      ;;
  esac

  printf %b\\n ""
  printf %b\\n "+--------------------------------------------+"
  colour_print "${BW}" "Server private address = ${BR}$server_private_range"
  colour_print "${BW}" "Server listen port = ${BR}$server_listen_port"
  colour_print "${BW}" "Server public address = ${BR}$server_public_address"
  colour_print "${BW}" "WAN interface = ${BR}$local_interface"
  printf %b\\n "+--------------------------------------------+"

  # This would be the private and public keys of the server.
  # If you are using this script, chances are those have not yet been generated yet.

  printf %b\\n ""
  colour_print "${IW}" "Do you need to generate server keys?"
  printf %b\\n "(If you have not yet configured the server, the probably yes)."
  printf %b\\n ""
  colour_print "${BW}" "1 = yes, 2 = no"
  printf %b\\n ""

  read -r -p "Choice: " generate_server_key
  printf %b\\n "+--------------------------------------------+"

  if [ "$generate_server_key" = 1 ]; then

    wg genkey | tee "$my_wgl_folder"/keys/ServerPrivatekey \
      | wg pubkey >"$my_wgl_folder"/keys/ServerPublickey

    chmod 600 "$my_wgl_folder"/keys/ServerPrivatekey \
      && chmod 600 "$my_wgl_folder"/keys/ServerPublickey

  # The else statement assumes the user already has server keys,
  # hence the option to generate them was not chosen.
  # For the script to generate a server config, the user is asked
  # to provide public/private key pair for the server.

  else
    printf %b\\n ""
    colour_print "${IW}" "Specify server private key."
    printf %b\\n ""

    read -r -p "Server private key: " server_private_key
    printf %b\\n "$server_private_key" >"$my_wgl_folder"/keys/ServerPrivatekey

    printf %b\\n "+--------------------------------------------+"

    printf %b\\n ""
    colour_print "${IW}" "Specify server public key."
    printf %b\\n ""

    read -r -p "Server public key: " server_public_key
    printf %b\\n "$server_public_key" >"$my_wgl_folder"/keys/ServerPublickey

    chmod 600 "$my_wgl_folder"/keys/ServerPrivatekey \
      && chmod 600 "$my_wgl_folder"/keys/ServerPrivatekey

    printf %b\\n "+--------------------------------------------+"

  fi

  sever_private_key_output=$(cat "$my_wgl_folder"/keys/ServerPrivatekey)
  sever_public_key_output=$(cat "$my_wgl_folder"/keys/ServerPublickey)

  printf %b\\n ""
  colour_print "${IW}" "Specify wireguard server interface name"
  colour_print "${IW}" "(will be the same as config name, without .conf)"
  printf %b\\n ""

  read -r -p "WireGuard Interface: " wg_serv_iface

  clear_screen

  printf %b\\n ""
  printf %b\\n "+--------------------------------------------+"
  colour_print "${BW}" "Server private address = ${BR}$server_private_range"
  colour_print "${BW}" "Server listen port = ${BR}$server_listen_port"
  colour_print "${BW}" "Server public address = ${BR}$server_public_address"
  colour_print "${BW}" "WAN interface = ${BR}$local_interface"
  colour_print "${BW}" "WireGuard interface = ${BR}$wg_serv_iface"
  printf %b\\n "+--------------------------------------------+"
  printf %b\\n ""

  {
    printf %b\\n "server_private_range=$server_private_range"
    printf %b\\n "server_listen_port=$server_listen_port"
    printf %b\\n "server_public_address=$server_public_address"
    printf %b\\n "local_interface=$local_interface"
    printf %b\\n "wg_serv_iface=$wg_serv_iface"
  } >>"$my_wgl_folder"/shared_vars.sh

  printf %b\\n ""
  printf %b\\n "Generating server config file...."

  sleep 2

  if [ "$distro" != "" ] && [ "$distro" = "freebsd" ]; then
    # We wont use iptables in server config on FreeBSD.
    # Everythig will be handled by IPFW.
    new_server_config=$(printf %b\\n "
[Interface]
Address = $server_private_range/32
SaveConfig = true
ListenPort = $server_listen_port
PrivateKey = $sever_private_key_output
  ")

  else

    new_server_config=$(printf %b\\n "
[Interface]
Address = $server_private_range/32
SaveConfig = true
PostUp = iptables -A FORWARD -i $wg_serv_iface -j ACCEPT; iptables -t nat -A POSTROUTING -o $local_interface -j MASQUERADE; ip6tables -A FORWARD -i $wg_serv_iface -j ACCEPT; ip6tables -t nat -A POSTROUTING -o $local_interface -j MASQUERADE
PostDown = iptables -D FORWARD -i $wg_serv_iface -j ACCEPT; iptables -t nat -D POSTROUTING -o $local_interface -j MASQUERADE; ip6tables -D FORWARD -i $wg_serv_iface -j ACCEPT; ip6tables -t nat -D POSTROUTING -o $local_interface -j MASQUERADE
ListenPort = $server_listen_port
PrivateKey = $sever_private_key_output
  ")

  fi

  printf %b\\n "$new_server_config" >"$my_wgl_folder"/"$wg_serv_iface".conf
  chmod 600 "$my_wgl_folder"/"$wg_serv_iface".conf

  printf %b\\n "Server config has been written to a file $my_wgl_folder/$wg_serv_iface.conf"
  printf %b\\n "+--------------------------------------------+"

  sleep 2

  printf %b\\n ""
  colour_print "${IW}" "Save config to /etc/wireguard/?"
  printf %b\\n ""
  colour_print "${IW}" "NOTE: ${UW}Choosing to save the config under the same file-name as"
  colour_print "${IW}" "an existing config will ${BR}overrite it."
  printf %b\\n ""
  printf %b\\n "This script will check if a config file with the same name already"
  printf %b\\n "exists. It will back the existing config up before overriting it."
  printf %b\\n "+--------------------------------------------+"
  colour_print "${IW}" "Save config: ${BW}1 = yes, 2 = no"
  printf %b\\n ""

  check_for_existing_config="/etc/wireguard/$wg_serv_iface.conf"

  read -r -p "Choice: " save_server_config

  # The if statement checks whether a config with the same filename already exists.
  # If it does, the falue will always be less than zero, hence it needs to be backed up.
  if [ "$save_server_config" = 1 ] && [ -f "$check_for_existing_config" ]; then
    printf %b\\n ""
    printf %b\\n "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
    printf %b\\n "Found existing config file with the same name. "
    printf %b\\n "Backing up to /etc/wireguard/$wg_serv_iface.conf.bak"
    printf %b\\n "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"

    sleep 2
    mv /etc/wireguard/"$wg_serv_iface".conf /etc/wireguard/"$wg_serv_iface".conf.bak
    sleep 1
    printf %b\\n "$new_server_config" >/etc/wireguard/"$wg_serv_iface".conf

    clear_screen

    printf %b\\n ""
    printf %b\\n "Congrats! Server config is ready and saved to"
    printf %b\\n "/etc/wireguard/$wg_serv_iface.conf... The config is shown below."

  elif [ "$save_server_config" = 1 ] && [ ! -f "$check_for_existing_config" ]; then
    # Make /etc/wireguard if it does not exist yet
    # Example is FreeBSD - /etc/wireguard is not automatically created
    # after installing WG.
    mkdir -p /etc/wireguard
    printf %b\\n "$new_server_config" >/etc/wireguard/"$wg_serv_iface".conf

    clear_screen

    printf %b\\n ""
    printf %b\\n "Congrats! Server config is ready and saved to"
    printf %b\\n "/etc/wireguard/$wg_serv_iface.conf... The config is shown below."

  elif [ "$save_server_config" = 2 ]; then
    clear_screen
    printf %b\\n ""
    printf %b\\n "Understood! Server config copy is located in:"
    printf %b\\n "$my_wgl_folder/$wg_serv_iface.conf."
    printf %b\\n "The config is shown below."
  fi

  printf %b\\n ""
  printf %b\\n ""
  colour_print "${IY}" "$new_server_config" \
    | sed -E 's/PrivateKey = .*/PrivateKey = Hidden/g'
  printf %b\\n ""
  printf %b\\n "+--------------------------------------------+"
}

generate_client_configs() {
  printf %b\\n ""
  colour_print "${IW}" "Configure clients?"
  colour_print "${BW}" "1=yes, 2=no"

  read -r -p "Choice: " client_config_answer
  printf %b\\n "+--------------------------------------------+"

  if [ "$client_config_answer" = 1 ]; then
    clear_screen
    printf %b\\n ""
    colour_print "${IW}" "How many clients would you like to configure?"
    printf %b\\n ""
    read -r -p "Number of clients: " number_of_clients

    printf %b\\n "+--------------------------------------------+"

    printf %b\\n ""
    colour_print "${IW}" "Specify the DNS server your clients will use."
    printf %b\\n ""
    # This would usually be a public DNS server, for example 1.1.1.1,
    # 8.8.8.8, etc.
    read -r -p "DNS server: " client_dns
    clear_screen
    printf %b\\n ""
    printf %b\\n "Next steps will ask to provide"
    printf %b\\n "private address and a name for each client, one at a time."
    printf %b\\n ""
    printf %b\\n "+--------------------------------------------+"

    # Private address would be within the RFC 1918 range of the server.
    # For example if the server IP is 10.10.10.1/24, the first client
    # would usually have an IP of 10.10.10.2; though this can be any
    # address as long as it's within the range specified for the server.
    for i in $(seq 1 "$number_of_clients"); do
      printf %b\\n ""
      colour_print "${IW}" "Private address of client # $i (do NOT include /32):"
      printf %b\\n ""
      read -r -p "Client $i IP: " client_private_address_["$i"]
      # Client name can be anything, mainly to easily identify the device
      # to be used. Some exampmles are:
      # Tom_iPhone
      # Wendy_laptop

      printf %b\\n "+--------------------------------------------+"
      printf %b\\n ""
      colour_print "${IW}" "Provide the name of the client # $i"
      colour_print "${IW}" "If left blank, name will be client_$i"
      printf %b\\n ""
      read -r -p "Client $i name: " client_name_["$i"]

      if [ "${client_name_["$i"]}" == "" ]; then
        client_name_["$i"]="client_$i"
      fi

      printf %b\\n "+--------------------------------------------+"

      wg genkey | tee "$my_wgl_folder"/keys/"${client_name_["$i"]}"Privatekey \
        | wg pubkey >"$my_wgl_folder"/keys/"${client_name_["$i"]}"Publickey

      chmod 600 "$my_wgl_folder"/keys/"${client_name_["$i"]}"Privatekey
      chmod 600 "$my_wgl_folder"/keys/"${client_name_["$i"]}"Publickey

      client_private_key_["$i"]="$(cat "$my_wgl_folder"/keys/"${client_name_["$i"]}"Privatekey)"
      client_public_key_["$i"]="$(cat "$my_wgl_folder"/keys/"${client_name_["$i"]}"Publickey)"

      {
        printf %b\\n "[Interface]"
        printf %b\\n "Address = ${client_private_address_["$i"]}"
        printf %b\\n "PrivateKey = ${client_private_key_["$i"]}"
        printf %b\\n "DNS = $client_dns"
        printf %b\\n ""
        printf %b\\n "[Peer]"
        printf %b\\n "PublicKey = $sever_public_key_output"
        printf %b\\n "Endpoint = $server_public_address:$server_listen_port"
        printf %b\\n "AllowedIPs = 0.0.0.0/0"
        printf %b\\n "PersistentKeepalive = 21"
      } >"$my_wgl_folder"/client_configs/"${client_name_["$i"]}".conf

      clear_screen
    done
    printf %b\\n ""
    printf %b\\n "Awesome!"
    printf %b\\n "Client config files were saved to:"
    colour_print "${IW}" "$my_wgl_folder/client_configs/"
  else
    printf %b\\n "+--------------------------------------------+"
    colour_print "${IW}" "Before ending this script,"
    colour_print "${IW}" "would you like to setup firewall rules for the new server? (recommended)"
    colour_print "${BW}" "1 = yes, 2 = no"
    printf %b\\n ""

    read -r -p "Choice: " iptables_setup
    if [ "$iptables_setup" = 1 ]; then
      sudo bash "$my_wgl_folder"/Scripts/setup_iptables.sh
    else
      printf %b\\n "Sounds good. Ending the scritp..."
      exit
    fi
  fi
  printf %b\\n ""
  colour_print "${IW}" "If you've got qrencode installed, the script can generate"
  colour_print "${IW}" "QR codes forthe client configs."
  printf %b\\n ""
  printf %b\\n ""
  colour_print "${IW}" "Would you like to have QR codes generated?"
  printf %b\\n ""
  colour_print "${IW}" "1= yes, 2 = no"

  read -r -p "Choice: " generate_qr_code

  if [ "$generate_qr_code" = 1 ]; then
    for q in $(seq 1 "$number_of_clients"); do
      colour_print "${BR}" "${client_name_[$q]}"
      printf %b\\n ""
      qrencode -t ansiutf8 <"$my_wgl_folder"/client_configs/"${client_name_["$q"]}".conf
      printf %b\\n "+--------------------------------------------+"
    done
  elif [ "$generate_qr_code" = 2 ]; then
    printf %b\\n ""
    printf %b\\n "Alright.. Moving on!"
    printf %b\\n "+--------------------------------------------+"
  else
    printf %b\\n "Sorry, wrong choice! Moving on with the script."
  fi

  colour_print "${IW}" "Would you like to add client info to the server config now?"
  printf %b\\n ""
  colour_print "${BW}" "1 = yes, 2 = no"
  read -r -p "Choice: " configure_server_with_clients

  # If you chose to add client info to the server config AND to save the server config
  # to /etc/wireguard/, then the script will add the clients to that config
  if [ "$configure_server_with_clients" = 1 ]; then
    for a in $(seq 1 "$number_of_clients"); do
      {
        printf %b\\n ""
        printf %b\\n "[Peer]"
        printf %b\\n "PublicKey = ${client_public_key_["$a"]}"
        printf %b\\n "AllowedIPs = ${client_private_address_["$a"]}/32"
        printf %b\\n ""
      } >>/etc/wireguard/"$wg_serv_iface".conf
    done
  elif [ "$configure_server_with_clients" = 2 ]; then
    printf %b\\n ""
    printf %b\\n "Alright,"
    printf %b\\n "add the following to a server config file to setup clients."
    printf %b\\n ""
    printf %b\\n "-----------------"
    printf %b\\n ""
    for d in $(seq 1 "$number_of_clients"); do
      printf %b\\n ""
      colour_print "${IY}" "[Peer]"
      colour_print "${IY}" "PublicKey = ${client_public_key_["$d"]}"
      colour_print "${IY}" "AllowedIPs = ${client_private_address_["$d"]}/32"
      printf %b\\n ""
    done
  fi

  printf %b\\n "-----------------"
}

enable_wireguard_iface() {
  # This assumes the WireGuard is already installed on the server.
  # The script checks is there is config in /etc/wireguard/, if there is one,
  # the value of the grep will be greater than or equal to 1, means it can be used
  # to bring up the WireGuard tunnel interface.
  colour_print "${IW}" "Almost done!"
  colour_print "${IW}" "Would you like to:"
  colour_print "${IW}" "  * Bring WireGuard interface up"
  colour_print "${IW}" "  * Enable the service on boot?"
  printf %b\\n ""
  colour_print "${BW}" "1 = yes, 2 = no"
  printf %b\\n ""

  read -r -p "Choice: " enable_on_boot
  clear_screen
  if [ "$enable_on_boot" = 1 ]; then
    # If current OS is FreeBSD - we wont use systemd as we would've for supported linux distros.
    freebsd_os=$(uname -a | awk '{print $1}' | grep -i -c FreeBSD)
    if [ "$freebsd_os" -gt 0 ]; then
      printf %b\\n ""
      colour_print "${IY}" "chown -v root:root /etc/wireguard/$wg_serv_iface.conf"
      colour_print "${IY}" "chmod -v 600 /etc/wireguard/$wg_serv_iface.conf"
      colour_print "${IY}" "sysrc wireguard_enable=\"YES\""
      colour_print "${IY}" "sysrc wireguard_interfaces=\"$wg_serv_iface\""
      colour_print "${IY}" "service wireguard start"
      printf %b\\n ""

      ask_to_proceed

      case "$your_choice" in
        [Rr]*)
          sudo bash "$my_wgl_folder"/Scripts/deploy_new_server.sh
          ;;
        [Ee]*)
          exit
          ;;
        *)
          chown -v root:root /etc/wireguard/"$wg_serv_iface".conf
          chmod -v 600 /etc/wireguard/"$wg_serv_iface".conf
          sysrc wireguard_enable="YES"
          sysrc wireguard_interfaces="$wg_serv_iface"
          service wireguard start
          ;;
      esac

    else
      printf %b\\n ""
      colour_print "${IY}" "chown -v root:root /etc/wireguard/$wg_serv_iface.conf"
      colour_print "${IY}" "chmod -v 600 /etc/wireguard/$wg_serv_iface.conf"
      colour_print "${IY}" "wg-quick up $wg_serv_iface"
      colour_print "${IY}" "systemctl enable wg-quick@$wg_serv_iface.service"
      printf %b\\n ""

      ask_to_proceed

      case "$your_choice" in
        [Rr]*)
          sudo bash "$my_wgl_folder"/Scripts/deploy_new_server.sh
          ;;
        [Ee]*)
          exit
          ;;
        *)
          chown -v root:root /etc/wireguard/"$wg_serv_iface".conf
          chmod -v 600 /etc/wireguard/"$wg_serv_iface".conf
          wg-quick up "$wg_serv_iface"
          systemctl enable wg-quick@"$wg_serv_iface".service
          ;;
      esac
    fi
  elif [ "$enable_on_boot" = 2 ]; then
    printf %b\\n ""
    colour_print "${IW}" "To manually enable the service and bring tunnel interface up,"
    colour_print "${IW}" "use the following commands"
    printf %b\\n ""
    if [ "$freebsd_os" = 0 ]; then
      printf %b\\n ""
      colour_print "${IY}" "chown -v root:root /etc/wireguard/$wg_serv_iface.conf"
      colour_print "${IY}" "chmod -v 600 /etc/wireguard/$wg_serv_iface.conf"
      colour_print "${IY}" "wg-quick up $wg_serv_iface"
      colour_print "${IY}" "systemctl enable wg-quick@$wg_serv_iface.service"
    else
      printf %b\\n ""
      colour_print "${IY}" "chown -v root:root /etc/wireguard/$wg_serv_iface.conf"
      colour_print "${IY}" "chmod -v 600 /etc/wireguard/$wg_serv_iface.conf"
      colour_print "${IY}" "sysrc wireguard_enable=\"YES\""
      colour_print "${IY}" "sysrc wireguard_interfaces=$wg_serv_iface"
      colour_print "${IY}" "service wireguard start"
    fi
  fi
}

setup_firewall() {
  printf %b\\n ""
  colour_print "${IW}" "Before ending this script,"
  colour_print "${IW}" "would you like to setup firewall rules for the new server? (recommended)"
  printf %b\\n ""
  colour_print "${BW}" "1 = yes, 2 = no"

  read -r -p "Choice: " iptables_setup
  if [ "$iptables_setup" = 1 ]; then
    sudo bash "$my_wgl_folder"/Scripts/setup_iptables.sh
  else
    printf %b\\n "Sounds good. Ending the script..."
  fi
  exit
}

main() {
  check_root
  source_variables
  create_needed_dirs
  generate_server_config
  generate_client_configs
  enable_wireguard_iface
  setup_firewall
}

main
