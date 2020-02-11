#!/usr/bin/env bash

check_root() {
  if [ "$EUID" -ne 0 ]; then
    printf %b\\n "Please run the script as root."
    exit 1
  fi
}

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

  ## List number of files in /etc/wireguard/
  check_existing_config=$(ls -1 /etc/wireguard/ | wc -l)
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

##################### Pre-checks finished #########################

create_client_configs() {
  clear_screen

  printf %b\\n "This script will help in easily generating client config for WireGuard."

  printf %b\\n "\nAre you running the script on the same machine as the server is hosted on?\n
${BW}1 = yes, 2 = no${Off}"

  read -r -p "Choice: " running_on_server

  if [ "$running_on_server" = 1 ] && [ "$check_existing_config" -gt 0 ]; then

    clear_screen

    for file in /etc/wireguard/*.conf; do

      wg_priv_key=$(grep "PrivateKey" "$file" | awk '{print $3}')

      printf %b\\n "${IW}Is your server config file: ${BR}$file ?\n
\n${BW}1 = yes, 2 = no${Off}"

      read -r -p "Choice: " correct_server_conf

      if [ "$correct_server_conf" = 1 ]; then

        wg pubkey < <(printf %b\\n "$wg_priv_key") >"$my_wgl_folder"/keys/ServerPublickey

        sever_public_key_output=$(cat "$my_wgl_folder"/keys/ServerPublickey)

        server_listen_port=$(grep "ListenPort" "$file" | awk '{print $3}')

        clear_screen

        printf %b\\n "\n+--------------------------------------------+
${BW}Server config file = ${BR}$file${Off}
${BW}Server public key = ${BR}$my_wgl_folder/keys/ServerPublickey${Off}
${BW}Server listen port = ${BR}$server_listen_port${Off}
+--------------------------------------------+
\nThe public IP address of this machine is $check_pub_ip. 
Is this the address you would like to use?
\n1 = yes, 2 = no"
        read -r -p "Choice: " public_address

        printf %s\\n "+--------------------------------------------+"

        if [ "$public_address" = 1 ]; then
          server_public_address="$check_pub_ip"
        elif [ "$public_address" = 2 ]; then
          printf %b\\n "\Please specify the public address of the server."
          read -r -p "Public IP: " server_public_address
          printf %s\\n "+--------------------------------------------+"
        fi

        clear_screen
        break
      fi
    done

  elif [ "$running_on_server" = 2 ] || [ "$check_existing_config" = 0 ]; then

    clear_screen

    printf %b\\n "\nWhat is the server's public key?\n"

    read -r sever_public_key_output

    printf %b\\n "\nWhat is the server listen port and public IP address?\n"

    read -r -p "Public IP: " server_public_address
    read -r -p "Listen Port: " server_listen_port
  fi

  clear_screen

  printf %b\\n "\n+--------------------------------------------+
${BW}Server config file = ${BR}$file${Off}
${BW}Server public key = ${BR}$my_wgl_folder/keys/ServerPublickey${Off}
${BW}Server listen port = ${BR}$server_listen_port${Off}
${BW}Server oubic address = ${BR}$server_public_address${Off}
+--------------------------------------------+"

  printf %b\\n "\nHow many clients would you like to configure?\n"
  read -r -p "Number of clients: " number_of_clients

  clear_screen

  printf %b\\n "\n+--------------------------------------------+
${BW}Server config file = ${BR}$file${Off}
${BW}Server public key = ${BR}$my_wgl_folder/keys/ServerPublickey${Off}
${BW}Server listen port = ${BR}$server_listen_port${Off}
${BW}Server pubic address = ${BR}$server_public_address${Off}
${BW}Number of clients = ${BR}$number_of_clients${Off}
+--------------------------------------------+"

  printf %b\\n "\nSpecify the DNS server your clients will use.\n"
  read -r -p "Client DNS: " client_dns

  clear_screen

  printf %b\\n "\n+--------------------------------------------+
${BW}Server config file = ${BR}$file${Off}
${BW}Server public key = ${BR}$my_wgl_folder/keys/ServerPublickey${Off}
${BW}Server listen port = ${BR}$server_listen_port${Off}
${BW}Server pubic address = ${BR}$server_public_address${Off}
${BW}Number of clients = ${BR}$number_of_clients${Off}
${BW}Client DNS = ${BR}$client_dns${Off}
+--------------------------------------------+"

  printf %b\\n "\nNext steps will ask to provide private address and a name for each client, one at a time.\n"
  for i in $(seq 1 "$number_of_clients"); do
    printf %b\\n "\nPrivate address of a client (do NOT include /32):\n"
    read -r -p "Client private address: " client_private_address_["$i"]
    printf %b\\n "\nProvide the name of the client\n"

    read -r -p "Client name: " client_name_["$i"]

    wg genkey | tee "$my_wgl_folder"/keys/"${client_name_["$i"]}"Privatekey | wg pubkey >"$my_wgl_folder"/keys/"${client_name_["$i"]}"Publickey

    chmod 600 "$my_wgl_folder"/keys/"${client_name_["$i"]}"Privatekey
    chmod 600 "$my_wgl_folder"/keys/"${client_name_["$i"]}"Publickey

    client_private_key_["$i"]="$(cat "$my_wgl_folder"/keys/"${client_name_["$i"]}"Privatekey)"
    client_public_key_["$i"]="$(cat "$my_wgl_folder"/keys/"${client_name_["$i"]}"Publickey)"

    printf %b\\n "\n[Interface]
Address = ${client_private_address_["$i"]}
PrivateKey = ${client_private_key_["$i"]}
DNS = $client_dns
\n[Peer]
PublicKey = $sever_public_key_output
Endpoint = $server_public_address:$server_listen_port
AllowedIPs = 0.0.0.0/0
PersistentKeepalive = 21" >"$my_wgl_folder"/client_configs/"${client_name_["$i"]}".conf

    clear_screen

    printf %b\\n "\n+--------------------------------------------+
${BW}Server config file = ${BR}$file${Off}
${BW}Server public key = ${BR}$my_wgl_folder/keys/ServerPublickey${Off}
${BW}Server listen port = ${BR}$server_listen_port${Off}
${BW}Server pubic address = ${BR}$server_public_address${Off}
${BW}Number of clients = ${BR}$number_of_clients${Off}
${BW}Client DNS = ${BR}$client_dns${Off}"
    for z in $(seq 1 "$number_of_clients"); do
      printf %b\\n "${BW}Client $z:${BR}
  ${client_private_address_["$z"]}
  ${client_name_["$z"]}"
    done
    printf %b\\n "\n+--------------------------------------------+"
  done
  printf %b\\n "\nAwesome!\nClient config files were saved to $my_wgl_folder/client_configs/"

}

add_clients_to_server() {
  printf %b\\n "\nWould you link to add client info to the server config now?\n
1 = yes, 2 = no"
  read -r -p "Choice: " configure_server_with_clients

  ## If client info is to be added to server config, then:
  if [ "$configure_server_with_clients" = 1 ]; then
    clear_screen
    ## List currently active WG interfaces
    running_wg_iface=$(wg | grep "interface" | awk '{print $2}')

    ## If there is at least one file, ask if this is the server config file
    if [ "$check_existing_config" -gt 0 ]; then

      ## Similarly, if there is more than one config files, then let the user choose
      for file in /etc/wireguard/*.conf; do
        printf %b\\n "Is your server config file: $file ?\n
${BW}1 = yes, 2 = no${Off}"

        read -r -p "Choice: " correct_server_conf
        ## Once we've found the correct config then...
        if [ "$correct_server_conf" = 1 ]; then
          ## ... we check if there are any active WG interfaces
          ## In case there are, warn the user it will have to be disabled
          ## to add the client info.
          if [ "$running_wg_iface" != "" ]; then
            printf %b\\n "\n Detected a running Wireguard instance: $running_wg_iface\n
WireGuard interface has to be disabled before changing the config.\n
Would you like the script to disable the interface before adding the clients to the config?\n
${BW}1 = yes, 2 = no${Off}\n"

            read -r -p "Choice: " disable_wg
            ## If the user agreed, disable the interface and get the 'OK' to proceed
            if [ "$disable_wg" = 1 ]; then
              wg-quick down "$running_wg_iface"
              clear_screen
              printf %b\\n "The interface has been disabled. Ready to proceed?"

              ask_to_proceed

              case "$your_choice" in
                [Rr]*)
                  sudo bash "$my_wgl_folder"/Scripts/client_config.sh
                  ;;
                [Ee]*)
                  exit
                  ;;
                *)
                  clear_screen
                  for c in $(seq 1 "$number_of_clients"); do
                    printf %b\\n "
[Peer]
PublicKey = ${client_public_key_["$c"]}
AllowedIPs = ${client_private_address_["$c"]}/32
  " | tee -a "$file" >/dev/null
                  done
                  ;;
              esac

            ## If the user does not wish to disable the interface,
            ## explain what need to be done to add more clients to the server
            elif [ "$disable_wg" = 2 ]; then
              clear_screen
              printf %b\\n "
  Alright...\n
  In order to add the client info to the server, you'll need to:\n
  1) De-activate the server interface
  2) Manually add the following to the server config
    2.1) It wil also be saved in $my_wgl_folder/client_configs/add_this_to_server.txt

  -----------------
  "
              for d in $(seq 1 "$number_of_clients"); do
                printf %b\\n "
[Peer]
PublicKey = ${client_public_key_["$d"]}
AllowedIPs = ${client_private_address_["$d"]}/32 
" >>"$my_wgl_folder"/client_configs/add_this_to_server.txt
              done

            fi
            ## If there are no running WG interfaces, keep going
          elif [ "$running_wg_iface" = "" ]; then
            clear_screen

            printf %b\\n "There appear to be no active Wireguard instances..Ready to proceed?"

            ask_to_proceed

            case "$your_choice" in
              [Rr]*)
                sudo bash "$my_wgl_folder"/Scripts/client_config.sh
                ;;
              [Ee]*)
                exit
                ;;
              *)
                clear_screen
                for c in $(seq 1 "$number_of_clients"); do
                  printf %b\\n "
[Peer]
PublicKey = ${client_public_key_["$c"]}
AllowedIPs = ${client_private_address_["$c"]}/32
  " | tee -a "$file" >/dev/null
                done
                ;;
            esac
          fi
        fi
      done
      ## If no existing configs were found, alert the user
      ## and explain how to add the client info to the configs
    elif [ "$check_existing_config" = 0 ]; then
      clear_screen
      printf %b\\n "No existing Wireguard server configs were found in /etc/wireguard\n
In order to add the client info to the server, you'll need to:\n
  1) De-activate the server interface
  2) Manually add the following to the server config
    2.1) It wil also be saved in $my_wgl_folder/client_configs/add_this_to_server.txt
  -----------------
  "
      for d in $(seq 1 "$number_of_clients"); do
        printf %b\\n "
[Peer]
PublicKey = ${client_public_key_["$d"]}
AllowedIPs = ${client_private_address_["$d"]}/32
" >>"$my_wgl_folder"/client_configs/add_this_to_server.txt
      done
    fi

    ## Finally, if the user chose not to add the client info to the server
    ## show what to add to the server later
  elif [ "$configure_server_with_clients" = 2 ]; then
    clear_screen
    printf %b\\n "\nIn order to add the client info to the server, you'll need to:\n
  1) De-activate the server interface
  2) Manually add the following to the server config
    2.1) It wil also be saved in $my_wgl_folder/client_configs/add_this_to_server.txt
  -----------------
  "
    for d in $(seq 1 "$number_of_clients"); do
      printf %b\\n "
[Peer]
PublicKey = ${client_public_key_["$d"]}
AllowedIPs = ${client_private_address_["$d"]}/32
" >>"$my_wgl_folder"/client_configs/add_this_to_server.txt
    done
  fi
}

offer_qr_codes() {
  printf %b\\n "\n${IW}If you've got qrencode installed, the script can generate QR codes for
the client configs.\n\n Would you like to have QR codes generated?
\n1= yes, 2 = no${Off}"

  read -r -p "Choice: " generate_qr_code

  if [ "$generate_qr_code" = 1 ]; then
    for q in $(seq 1 "$number_of_clients"); do
      printf %b\\n "${BR}${client_name_[$q]}${Off}\n"
      qrencode -t ansiutf8 <"$my_wgl_folder"/client_configs/"${client_name_["$q"]}".conf
      printf %s\\n "+--------------------------------------------+"
    done
  elif [ "$generate_qr_code" = 2 ]; then
    printf %b\\n "\nAlright..The script is done!\n+--------------------------------------------+"
  else
    printf %b\\n "Sorry, wrong choice!"
  fi
}

main() {
  check_root
  source_variables
  create_needed_dirs
  create_client_configs
  add_clients_to_server
  offer_qr_codes
}

main