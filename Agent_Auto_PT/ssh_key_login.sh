#!/bin/bash

###################################
## auther:liuguanghui
## date:20181116
## work:Set up ssh key login
###################################

T_key_ip=`ifconfig eth0|awk '/inet addr/{print $2}'|awk -F : '{print $2}'`
R_key_ip=$1
key_yes_or_no=$2

#ssh_key_dir="$Agent_Auto_PT_home_dir/ssh_key"

\cp ./ssh_key/{id_rsa.pub,id_rsa} /root/.ssh/

\cp /root/.ssh/{id_rsa.pub,authorized_keys}

cmd1="sed -i '/\bRSAAuthentication\b/s/.*/RSAAuthentication yes/' /etc/ssh/sshd_config"
cmd2="sed -i '/\bPubkeyAuthentication\b/s/.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config"
cmd3="sed -i '/\bStrictHostKeyChecking\b/s/.*/StrictHostKeyChecking no/' /etc/ssh/ssh_config"
cmd4="sed -i '/\bAuthorizedKeysFile\b/s/.*/AuthorizedKeysFile .ssh\/authorized_keys/' /etc/ssh/sshd_config"
cmd5="sed -i '/\bRSAAuthentication\b/s/.*/#RSAAuthentication no/' /etc/ssh/sshd_config"
cmd6="sed -i '/\bPubkeyAuthentication\b/s/.*/#PubkeyAuthentication no/' /etc/ssh/sshd_config"
cmd7="sed -i '/\bStrictHostKeyChecking\b/s/.*/#   StrictHostKeyChecking ask/' /etc/ssh/ssh_config"
cmd8="rm -rf /root/.ssh/{authorized_keys,id_rsa}"
cmd9="service sshd restart"

if [[ $2 == y ]];then
	ssh root@$R_key_ip "mkdir -p /root/.ssh"
	scp /root/.ssh/{authorized_keys,id_rsa}  root@$R_key_ip:/root/.ssh/
	ssh root@$R_key_ip "$cmd1;$cmd2;$cmd3;$cmd4;$cmd9"
elif [[ $2 == n ]];then
	ssh root@$R_key_ip "$cmd5;$cmd6;$cmd7;$cmd9"
else
	echo "Please pass in parameters correctly."
	exit
fi
