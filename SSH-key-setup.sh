#!/bin/bash
# Usage: run with one argument, the IP address of your server:
# Example: ./SSH-key-setup.sh 192.168.0.1

printf "\n\e[93mThis script will create a new RSA SSH key in your local machine and upload the corresponding public key to the remote server's root account.\n\n"
printf "You can then run the server setup script, which will pick up that key and configure SSH to use it only with the sudo account that will be created.\e[0m\n"

# Check if a valid IP address was submitted when starting the script 
# ideal ipregexp="^(?:(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(?:25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$"
ipregexp="^((25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.){3}(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$"
if ! [[ $1 =~ $ipregexp ]]; then
  printf "\n\e[93mError: you must provide a valid IP address as argument when running this script.\n"
  printf "Example: ./SSH-key-setup.sh 192.168.0.1\e[0m\n"
  exit 2
else
 printf "\n\e[93mPinging host... "
 ping -c 1 $1 2>/dev/null 1>/dev/null
 if ! [ $? -eq 0 ]; then
  printf "\e[93mError: IP address not pingable, exiting.\e[0m\n"
  exit 2
 fi
fi
printf "OK\n\n"

# Create the keys
read -p "Choose a name for the SSH key files: " ssh_file
printf "\e[0m"
ssh-keygen -t rsa -a 1000 -b 4096 -C "$USER@$HOSTNAME" -o -f ~/.ssh/$ssh_file
SSH_AUTH_SOCK=0 ssh-copy-id -i ~/.ssh/$ssh_file root@$1

if ! [ $? -eq 0 ]; then
 printf "\e[93mError uploading key to server.\n"
 printf "Key was probably created, but not uploaded.\n"
 printf "Check error message above for further details.\e[0m\n"
 exit 1
fi

printf "\e[93mKey creation and export complete. You can now run one of the node setup scripts.\n"
printf "Once the SSH key-only authentication rule is in place, you can login by specifying which key to use with the -i parameter:\e[0m\n"
printf "\e[34mssh <user>@${1} -i ~/.ssh/${ssh_file}\n"
exit 0

# Warning: if you get this error "Received disconnect from xxx.xxx.xxx.xxx: 2: Too many authentication failures"
# you probably have a lot of SSH keys in your system already and ssh-agent is throwing them all at the server
# as a temporary workaround, connect using "SSH_AUTH_SOCK=0 ssh <user>@$<IP> -i ~/.ssh/<key_file>"
