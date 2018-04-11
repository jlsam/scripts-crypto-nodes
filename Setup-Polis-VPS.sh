#!/bin/bash
# assumes root login and requires pre-existing SSH key
# run script with dot/space (source): '. setup_polis.sh' or 'source setup_polis.sh' to preserve directory changes.

# This script will: 1) fix locale, 2) update system and install dependencies, 3) create a service user to run the node
# 4) create a sudo user, 5) set SSHd to use keys only, to not accept root login (only accepts the new sudo user) and set other security restrictions
# 6) configure UFW, 7) download wallet and place execs in /usr/local/bin, 8) create a complete wallet .conf
# 9) create a systemd service to run the node, 10) setup Sentinel, 11) disable root login and 12) reboot to apply changes and start the node

# Setup parameters // change default values - accounts and key - before running the script
new_NOlogin="nologin"
new_sudoer="sudoer"
wallet_genkey="---" # Needs to be a valid key, otherwise the node won't even run
installer_url="https://github.com/polispay/polis/releases/download/v1.2.2/poliscore-1.2.2-linux64.tar.gz"
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
if [ "$wallet_genkey" = "---" ]; then
  printf "\nPlease set your masternode genkey from the cold wallet and run again.\n"
  exit 1
elif [ "$new_NOlogin" = "nologin" ]; then
  printf "\nPlease set your own username for the service account (no login) and run again.\n"
  exit 1
elif [ "$new_sudoer" = "sudoer" ]; then
  printf "\nPlease set your own username with sudo access and run again.\n"
  exit 1
fi

# Fix locale. Particularly important for python Sentinel installation
locale-gen $locs
# During the next command interactive choices, it should be enough to OK everything
dpkg-reconfigure locales

# Update system & install packages
apt update && apt -y upgrade
apt install -y virtualenv python-pip
echo
read -n1 -rsp "$(printf '\e[93mPress any key to continue or Ctrl+C to exit...\e[0m\n')"
echo

# Create service account
useradd -r -m -s /usr/sbin/nologin -c "masternode service user" $new_NOlogin

# Create login account with sudo permission
adduser $new_sudoer
usermod -aG sudo $new_sudoer

# Move SSH key to new user
mv ~/.ssh /home/$new_sudoer/
chown -R $new_sudoer:$new_sudoer /home/$new_sudoer/.ssh/
chmod -R 700 /home/$new_sudoer/.ssh/

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
ufw allow 24126/tcp # some coin nodes may need tcp and udp, in that case remove /tcp
ufw logging on
ufw --force enable
ufw status
read -n1 -rsp "$(printf '\e[93mPress any key to continue or Ctrl+C to exit...\e[0m')"
echo

# Setup Polis Masternode
installer_file="$(basename $installer_url)"
random_user="$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 16)"
random_pass="$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c 26)"
ext_IP_addr="$(dig +short myip.opendns.com @resolver1.opendns.com)"

wget $installer_url
tar -xvf $installer_file
top_lvl_dir="$(tar -tzf $installer_file | sed -e 's@/.*@@' | uniq)"
cp -v $top_lvl_dir/bin/polis{d,-cli} /usr/local/bin
rm $installer_file
rm -R $top_lvl_dir
echo
mkdir -p /home/$new_NOlogin/.poliscore
echo -e "rpcuser=$random_user
rpcpassword=$random_pass
rpcallowip=127.0.0.1
listen=1
server=1
daemon=1
logtimestamps=1
maxconnections=256
externalip=$ext_IP_addr
masternodeprivkey=$wallet_genkey
masternode=1
connect=35.227.49.86:24126
connect=192.243.103.182:24126
connect=185.153.231.146:24126
connect=91.223.147.100:24126
connect=96.43.143.93:24126
connect=104.236.147.210:24126
connect=159.89.137.114:24126
connect=159.89.139.41:24126
connect=174.138.70.155:24126
connect=174.138.70.16:24126
connect=45.55.247.25:24126
" | tee /home/$new_NOlogin/.poliscore/polis.conf
chown -R $new_NOlogin:$new_NOlogin /home/$new_NOlogin/.poliscore/
read -n1 -rsp "$(printf '\e[93mPress any key to continue or Ctrl+C to exit...\e[0m')"
echo

# Setup systemd service file
echo -e "[Unit]
Description=Polis Masternode
After=network.target

[Service]
User=$new_NOlogin
Group=$new_NOlogin

Type=forking
PIDFile=/home/$new_NOlogin/.poliscore/polisd.pid

ExecStart=/usr/local/bin/polisd -pid=/home/$new_NOlogin/.poliscore/polisd.pid
ExecStop=/usr/local/bin/polis-cli stop

Restart=always
PrivateTmp=true
TimeoutStopSec=60s
TimeoutStartSec=2s
StartLimitInterval=120s
StartLimitBurst=5

[Install]
WantedBy=multi-user.target
" | tee /etc/systemd/system/polisd.service
systemctl enable polisd.service
read -n1 -rsp "$(printf '\e[93mPress any key to continue or Ctrl+C to exit...\e[0m\n')"
echo

# Setup Polis Sentinel
sudo -H -u $new_NOlogin sh <<EOF
cd /home/${new_NOlogin}/
git clone https://github.com/polispay/sentinel.git /home/${new_NOlogin}/sentinel
cd sentinel/
virtualenv ./venv
./venv/bin/pip install -r requirements.txt
echo "* * * * * cd /home/${new_NOlogin}/sentinel && ./venv/bin/python bin/sentinel.py >/dev/null 2>&1" >> tmpcron
crontab tmpcron
rm tmpcron
EOF

# Disable root login
printf "\n\e[93mDisabling root login:\e[0m\n"
passwd -l root

# Reboot
printf "\n\e[93mScript completed.\n"
read -n1 -rsp "$(printf 'Press any key to reboot or Ctrl+C to exit...\n')"
reboot
