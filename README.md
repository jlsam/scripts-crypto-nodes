# scripts-crypto-nodes
Collection of Bash scripts for quick deployment and update of cryptocurrency (master)nodes in Ubuntu.

These scripts will help you quickly configure a new remote server (most commonly a VPS) and run wallet nodes to work as masternodes. Testing was done on Ubuntu 16.04 LTS.

Modifications to /etc/ssh/sshd_config will change your server's fingerprint after the initial reboot.
You will probably get a warning message, but you can follow the command to remove the previous fingerprint (copy/paste):<br>
`ssh-keygen -f "/home/<user>/.ssh/known_hosts" -R <server IP>`<br>
After that, reconnect and accept the new fingerprint.
  
These scripts will always work on a baseline of Key-based SSH authentication. No passwords for server authentication. You are of course free to edit the scripts to work with passwords for authentication, but you'll have a hard time finding anyone giving advice on how that's a good idea. If you don't know how Key-based SSH authentication works, you can start by reading this: https://help.ubuntu.com/community/SSH/OpenSSH/Keys. If you want to connect from Windows, Putty is your friend, try searching 'how to use putty ssh' for example.

Current version will perform the following major steps:
1. Update the system and install additional necessary software
2. Create a new system account to run the node
3. Create a new sudo account to manage the VPS
4. Disable root login
5. Configure SSHd to use Key-based authentication only, disallow root login, plus other security-minded settings
6. Configure UFW firewall
7. Download wallet, create files and edit values as needed
8. Perform any other necessary configuartion steps
9. Prepare a systemd service to run the wallet node automatically at startup
10. Reboot the server to apply changes and test if systemd is starting your node during startup, as intended

This is still work in progress, other coins will be added in time and also scripts for other tasks.<br>
Comments and suggestions are appreciated!

If this work helped you in any way, saved you time or showed you something you didn't know, consider leaving a tip.<br>
LTC or ETH is appreciated, but also any of the coins these scripts are for.

LTC: LSE7ezK7Qoszjgz9Ew25xmxazBzEsSL4Qt<br>
ETH: 0xc7Ef788B776734Ff3694c1Be8465110Babf61a6a<br>
Polis: PJyr4NgoPrWLuKsSV7gVZBNmDKGbK4PJbC<br>
