#!/usr/bin/env bash

#   __          _______   _      _
#   \ \        / / ____| | |    (_)
#    \ \  /\  / / |  __  | |     _  __ _  __ _ ___  ___
#     \ \/  \/ /| | |_ | | |    | |/ _` |/ _` / __|/ _ \
#      \  /\  / | |__| | | |____| | (_| | (_| \__ \  __/
#       \/  \/   \_____| |______|_|\__, |\__,_|___/\___|
#                                   __/ |
#                                  |___/
# This is a simple bash script to aid in configuring WireGuard tunnels and clients.
# Q: Hasn't this been done bedofe?
# A: Probably.
# Q: Why another WG configuration script?
# A: Why not?
# Q: ....Ligase???
# A: In biochemistry, a ligase is an enzyme that can catalyze the joining of two large molecules by forming a new chemical bond -
# - https://en.wikipedia.org/wiki/Ligase (May 19th, 2019)


my_working_dir=$(pwd)

source "$my_working_dir"/doc/colours.sh

logo=$(cat "$my_working_dir"/doc/ascii-logo)

echo -e "${BPurple}$logo${Color_Off}"

echo -e "${BWhite}Welcome to WG Ligase${Color_Off}.

The script will guide you through the installaton process, allowing to choose a starting point.

The idea is for this script to be equally suitable for new deployments, as well as for configuring a live deployment"

echo -e "
Let's begin. Please select from one of the following options:
-----------------------------------

${BWhite}1 = I would like to configure a new server and clients from scratch.${Color_Off}

-----------------------------------

${BWhite}2 = I just need to generate some client configs and add those to an existing server.${Color_Off}

-----------------------------------

${BWhite}3 = I just need commands to configure IPTABLEs.${Color_Off}

----------------------------------"

read -r scope_of_script

if [[ $scope_of_script == 1 ]]; then
  sudo bash "$my_working_dir"/Scripts/deploy_new_server.sh
elif [[ $scope_of_script == 2 ]]; then
  sudo bash "$my_working_dir"/Scripts/client_config.sh
elif [[ $scope_of_script == 3 ]]; then
  sudo bash "$my_working_dir"/Scripts/setup_iptables.sh
else
  echo "Sorry, wrong choise. Rerun the script and try again"
fi
