#!/bin/bash
# assumes root login and requires pre-existing SSH key
#

# This script will: 1) fix locale, 2) update system and install dependencies, 3) create a service user to run the node
# 4) create a sudo user, 5) set SSHd to use keys only, to not accept root login (only accepts the new sudo user) and set other security restrictions
# 6) configure UFW, 7) download wallet and place execs in /usr/local/bin, 8) create a complete wallet .conf
# 9) create logrotate rules for debug.log, 10) create a systemd service to run the node, 11) disable root login and 12) reboot to apply changes and start the node

# Setup parameters // change default values - accounts and key - before running the script
new_NOlogin="nologin"
new_sudoer="sudoer"
wallet_genkey="---" # Needs to be a valid key, otherwise the node won't even run
# Get the latest download link from https://github.com/Lindacoin/Linda/releases
installer_url="https://something.tar.gz"
# Setting locale for en_US.UTF-8, but it should work with your prefered locale too.
# Depending on your location, you may need to add/modify locales here to avoid errors,
# ex. "en_GB.UTF-8 de_DE.UTF-8"
locs="en_US.UTF-8"

# !!! NO NEED FOR MORE EDITS BEYOND THIS POINT

# Check for existing SSH key
if grep -P "ssh-rsa AAAA[0-9A-Za-z+\/]+[=]{0,3} [^@]+@?[^@]+$" ~/.ssh/authorized_keys; then
  printf "\e[93mSSH key detected. Script will proceed.\n"
  read -n1 -rsp "$(printf 'Press any key to continue or Ctrl+C to exit...\e[0m')"
  echo
else
  printf "\e[93mSSH key NOT detected. Script will terminate.\n"
  printf "You can run SSH-key-setup.sh in your local machine to create and upload a SSH key to the server\n"
  printf "and after run this script remotely again.\e[0m"
  echo
  exit 1
fi

# Other checks
if [ "${wallet_genkey}" = "---" ]; then
  printf "\nPlease set your masternode genkey from the cold wallet and run again.\n"
  exit 1
elif [ "${new_NOlogin}" = "nologin" ]; then
  printf "\nPlease set your own username for the service account (no login) and run again.\n"
  exit 1
elif [ "${new_sudoer}" = "sudoer" ]; then
  printf "\nPlease set your own username with sudo access and run again.\n"
  exit 1
elif [ "${installer_url}" = "https://something.tar.gz" ]; then
  printf "\nPlease set the URL for the current wallet version and run again.\n"
  exit 1
fi

# Fix locale.
locale-gen ${locs}
# During the next command interactive choices, it should be enough to OK everything
#dpkg-reconfigure locales

# Update system & install packages
printf "\n\e[93mUpgrading Ubuntu...\e[0m\n"
apt update && apt -y upgrade
#apt install -y unzip
echo
read -n1 -rsp "$(printf '\e[93mPress any key to continue or Ctrl+C to exit...\e[0m\n')"
echo

# Create service account
useradd -r -m -s /usr/sbin/nologin -c "masternode service user" ${new_NOlogin}

# Create login account with sudo permission
adduser ${new_sudoer}
usermod -aG sudo ${new_sudoer}

# Move SSH key to new user
mv ~/.ssh /home/${new_sudoer}/
chown -R ${new_sudoer}:${new_sudoer} /home/${new_sudoer}/.ssh/
chmod -R 700 /home/${new_sudoer}/.ssh/

# Edit sshd_config
printf "\n\e[93m/etc/ssh/sshd_config edits:\e[0m\n"
sed -i -r -e "s/^#?PermitRootLogin yes/PermitRootLogin no/w /dev/stdout" \
-e "s/^#?PasswordAuthentication yes/PasswordAuthentication no/w /dev/stdout" \
-e "s/^#?ChallengeResponseAuthentication yes/ChallengeResponseAuthentication no/w /dev/stdout" \
-e "s/^HostKey \/etc\/ssh\/ssh_host_dsa_key/#HostKey \/etc\/ssh\/ssh_host_dsa_key/w /dev/stdout" \
-e "s/^HostKey \/etc\/ssh\/ssh_host_ecdsa_key/#HostKey \/etc\/ssh\/ssh_host_ecdsa_key/w /dev/stdout" \
-e "s/^X11Forwarding yes/X11Forwarding no/w /dev/stdout" \
-e "s/^#?(AuthorizedKeysFile.*)/\1/w /dev/stdout" /etc/ssh/sshd_config
echo -e "
# Specify MACs, Ciphers, and Kex algos
KexAlgorithms curve25519-sha256@libssh.org,diffie-hellman-group-exchange-sha256
Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr,aes192-ctr,aes128-ctr
MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,hmac-ripemd160-etm@openssh.com,umac-128-etm@openssh.com,hmac-sha2-512,hmac-sha2-256,hmac-ripemd160,umac-128@openssh.com

# List of users allowed to login using SSH
AllowUsers ${new_sudoer}
" | tee -a /etc/ssh/sshd_config
systemctl daemon-reload
read -n1 -rsp "$(printf '\e[93mPress any key to continue or Ctrl+C to exit...\e[0m\n')"
echo

# Setup UFW
ufw disable
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh/tcp
ufw limit ssh/tcp
ufw allow 33820/tcp # some coin nodes may need tcp and udp, in that case remove /tcp
ufw logging on
ufw --force enable
ufw status
read -n1 -rsp "$(printf '\e[93mPress any key to continue or Ctrl+C to exit...\e[0m')"
echo

# Setup Linda Masternode
#  Download and install node wallet
installer_file="$(basename ${installer_url})"
wget ${installer_url}
tar -xvf ${installer_file}
cp -v Lindad /usr/local/bin
rm -v ${installer_file}
rm -v Lindad
echo

# Bootstrap
#wget XXX
#unzip -d /home/$new_NOlogin/.Linda/ LindaBootstrap.zip #full path is created?
chown -R $new_NOlogin:$new_NOlogin /home/$new_NOlogin/.Linda/

#  Setup Linda.conf
random_user="$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 16)"
random_pass="$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 26)"
ext_IP_addr="$(dig +short myip.opendns.com @resolver1.opendns.com)"
echo
mkdir -pv /etc/Linda
printf "\n\e[93m .conf settings:\e[0m\n"
echo -e "rpcuser=${random_user}
rpcpassword=${random_pass}
rpcallowip=127.0.0.1
listen=1
server=1
daemon=1
masternode=1
logtimestamps=1
maxconnections=256
masternodeaddr=${ext_IP_addr}:33820
masternodeprivkey=${wallet_genkey}

addnode=seed1.linda-wallet.com
addnode=seed2.linda-wallet.com
addnode=seed3.linda-wallet.com
addnode=seed4.linda-wallet.com
addnode=seed5.linda-wallet.com
" | tee /etc/Linda/Linda.conf

read -n1 -rsp "$(printf '\e[93mPress any key to continue or Ctrl+C to exit...\e[0m')"
echo

#  Setup logrotate
#  Break debug.log into weekly files, compress and keep at most 5 older log files
printf "\n\e[93mCreating logrotate rules...\e[0m\n"
echo -e "/home/${new_NOlogin}/.Linda/debug.log {
        rotate 5
        copytruncate
        weekly
        missingok
        notifempty
        compress
        delaycompress
}" | tee /etc/logrotate.d/Linda-debug

# Setup systemd service file
# https://github.com/bitcoin/bitcoin/blob/master/contrib/init/bitcoind.service
printf "\n\e[93mCreating systemd service file...\e[0m\n"
echo -e "[Unit]
Description=Linda Masternode
After=network.target

[Service]
User=${new_NOlogin}
Group=${new_NOlogin}

# Creates /run/Lindad owned by ${new_NOlogin}
RuntimeDirectory=Lindad

Type=forking
ExecStart=/usr/local/bin/Lindad -pid=/run/Lindad/Linda.pid -conf=/etc/Linda/Linda.conf
ExecStop=/usr/local/bin/Lindad -conf=/etc/Linda/Linda.conf stop
PIDFile=/run/Lindad/Linda.pid

Restart=on-failure
RestartSec=20
TimeoutStopSec=60s
TimeoutStartSec=15s
StartLimitInterval=120s
StartLimitBurst=5

# Hardening measures
#  Provide a private /tmp and /var/tmp.
PrivateTmp=true
#  Mount /usr, /boot/ and /etc read-only for the process.
ProtectSystem=full
#  Disallow the process and all of its children to gain
#  new privileges through execve().
NoNewPrivileges=true
#  Use a new /dev namespace only populated with API pseudo devices
#  such as /dev/null, /dev/zero and /dev/random.
PrivateDevices=true
#  Deny the creation of writable and executable memory mappings.
MemoryDenyWriteExecute=true

[Install]
WantedBy=multi-user.target
" | tee /etc/systemd/system/lindad.service
systemctl enable lindad.service
read -n1 -rsp "$(printf '\e[93mPress any key to continue or Ctrl+C to exit...\e[0m\n')"
echo

# Disable root login
printf "\n\e[93mDisabling root login:\e[0m\n"
passwd -l root

# Reboot
printf "\n\e[93mScript completed.\n"
read -n1 -rsp "$(printf 'Press any key to reboot or Ctrl+C to exit...\e[0m\n')"
reboot
