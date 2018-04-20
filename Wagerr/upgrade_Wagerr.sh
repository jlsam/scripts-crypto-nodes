#!/bin/bash
# This script will update the node to a new version you indicate.
# This script assumes the same naming and location choices made for the installer script;
# If you placed the executables in another directory or if you named the systemd service file differently, you'll have to modify this script accordingly.
# Run script with the URL to the new version to download as parameter, for example:
# ./update_node.sh https://github.com/wagerr/wagerr/releases/download/1.5.0/wagerr-1.5.0-x86_64-linux-gnu.tar.gz

# Account name running the node
# You must set this to show node status after restarting
daemon_user="---"

# Elevate user if necessary, to be able to copy files into /usr/local/bin
[ "$UID" -eq 0 ] || exec sudo bash "$0" "$@"

# Checks
if [ "${daemon_user}" = "---" ]; then
  printf "\n\e[93mPlease edit this script with the username of the (system?) account running the node and try again.\e[0m\n"
  exit 1
elif ! getent passwd ${daemon_user}; then
  printf "\n\e[93mThe account name you provided doesn't exist in this server.\e[0m\n"
  exit 1
fi
printf "\n\e[93mAccount ${daemon_user} exists in this server. Moving on.\e[0m\n"

# Download file and check if there were no errors
wget $1
if [[ $? -ne 0 ]]; then
  printf "\n\e[93mError downloading the file; see above. Fix the issue and try again.\e[0m\n"
  exit 1
fi

# Read extension and extract accordingly
installer_file="$(basename $1)"
if [[ ${installer_file} =~ \.zip$ ]]; then
  dpkg -s unzip &> /dev/null
  if [[ $? -eq 1 ]]; then
    apt install unzip
  fi
  unzip ${installer_file}
  top_lvl_dir="$(unzip -l ${installer_file} | sed -e 's@/.*@@' | uniq)"
else
  case ${installer_file} in
	*.tar.bz2) tar -xvjf ${installer_file} ;;
        *.tar.gz)  tar -xvzf ${installer_file} ;;
#        *.bz2)     bunzip2 ${installer_file}   ;;
#        *.gz)      gunzip ${installer_file}    ;;
        *.tar)     tar -xvf ${installer_file}  ;;
        *.tbz2)    tar -xvjf ${installer_file} ;;
        *.tgz)     tar -xvzf ${installer_file} ;;
      	*)         printf "\e[93mDon't know how to handle '$installer_file'...\e[0m\n" && exit 1 ;;
  esac
  top_lvl_dir="$(tar -tzf $installer_file | sed -e 's@/.*@@' | uniq)"
fi

# Copy new files over to /usr/local/bin
printf "\n\e[93mStopping wallet node service...\e[0m\n"
systemctl stop wagerrd.service
cp -v ${top_lvl_dir}/bin/wagerr{-cli,d} /usr/local/bin
# Delete installer and remove extracted dir if copy was successful
if [[ $? -eq "0" ]]; then
  rm -v ${installer_file}
  rm -Rv ${top_lvl_dir}
fi

# Restart wallet node
printf "\n\e[93mUpgrade completed.\n"
read -n1 -rsp "$(printf 'Press any key to restart the wallet node or Ctrl+C to exit...\e[0m\n')"
systemctl restart wagerrd.service
until sudo -H -u ${daemon_user} bash -c "wagerr-cli -conf=/etc/wagerr/wagerr.conf getinfo" &>/dev/null; do
  sleep 2
done

sudo -H -u ${daemon_user} bash -c "wagerr-cli -conf=/etc/wagerr/wagerr.conf getinfo"
sudo -H -u ${daemon_user} bash -c "wagerr-cli -conf=/etc/wagerr/wagerr.conf masternode status"
