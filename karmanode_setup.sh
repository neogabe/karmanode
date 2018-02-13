#!/bin/bash
VERSION=1.0.0
DATE=`date +%F_%H%M%S`
if (( $EUID != 0 )); then
    echo "Please run as root"
    exit
fi

function gather_user_info () {

	clear

	ERRORS=false

	echo "| OHMC Karmanode configuration utility - ${VERSION}"
	echo "| Tested on ubuntu 16.04.3"
	echo "|--------------------------------------------------"
	echo ""
	read -p "  Karmanode genkey: " KARMANODE_GENKEY
	read -p "  Karmanode outputs tx_hash: " KARMANODE_TX_HASH
	read -p "  Karmanode outputs idx: " KARMANODE_IDX
	read -p "  Karmanode user (Default ohmcoin): " KARMANODE_USER

	if [ -z "$KARMANODE_GENKEY" ]; then
		echo "=> Information provided on Karmanode genkey is not correct."
		ERRORS=true
	fi
	if [ -z "$KARMANODE_TX_HASH" ]; then
		echo "=> Information provided on Karmanode outputs tx_hash is not correct."
		ERRORS=true
	fi
	if [ -z "$KARMANODE_IDX" ]; then
		echo "=> Information provided on Karmanode outputs idx is not correct."
		ERRORS=true
	fi
	if [ -z "$KARMANODE_USER" ]; then
		echo "=> Using default: ohmcoin as Karmanode user."
		KARMANODE_USER=ohmcoin
	fi

	if [[ "$ERRORS" == "true" ]]; then
		echo "Please correct the above errors before continuing."
		exit
	fi
}

function check_info () {

	echo ""
	echo "Karmanode genkey: $KARMANODE_GENKEY"
	echo "Karmanode outputs tx_hash: $KARMANODE_TX_HASH"
	echo "Karmanode outputs idx: $KARMANODE_IDX"
	echo "Karmanode user: $KARMANODE_USER"

	read -p "Procced? [y/n]: " PROCCED
	if [ "$PROCCED" != "y" ]; then
		echo "Aborted."
		exit
	fi
}

function system_upgrade () {

	add-apt-repository ppa:bitcoin/bitcoin -y
	apt-get -y update
	apt-get -y upgrade
	apt-get -y install pkg-config
	apt-get -y install build-essential autoconf automake libtool libboost-all-dev libgmp-dev libssl-dev libcurl4-openssl-dev git
	apt-get -y install libdb4.8-dev libdb4.8++-dev

}

function user_creation () {

	useradd -m -U -s /bin/bash $KARMANODE_USER
	passwd $KARMANODE_USER
	echo "Granting sudo privileges..."
	adduser $KARMANODE_USER sudo

}

function modify_sshd_config () {

	cp /etc/ssh/sshd_config /etc/ssh/sshd_config_$DATE
	sed -re 's/^(\#)(PasswordAuthentication)([[:space:]]+)(.*)/\2\3\4/' -i /etc/ssh/sshd_config
	sed -re 's/^(\#?)(PasswordAuthentication)([[:space:]]+)yes/\2\3no/' -i /etc/ssh/sshd_config
	sed -re 's/^(\#)(UsePAM)([[:space:]]+)(.*)/\2\3\4/' -i /etc/ssh/sshd_config
	sed -re 's/^(\#?)(UsePAM)([[:space:]]+)yes/\2\3no/' -i /etc/ssh/sshd_config
	sed -re 's/^(\#)(PermitRootLogin)([[:space:]]+)(.*)/\2\3\4/' -i /etc/ssh/sshd_config
	sed -re 's/^(\#?)(PermitRootLogin)([[:space:]]+)(.*)/\2\3no/' -i /etc/ssh/sshd_config

}

function create_swap_space () {

	if [ ! -f /swapfile ]; then
    	fallocate -l 2G /swapfile
		chmod 600 /swapfile
		mkswap /swapfile
		swapon /swapfile
		echo -e "/swapfile none swap sw 0 0 \n" >> /etc/fstab
	else
		echo "Swapfile already exists: `ls -l /swapfile`"	
	fi

}

gather_user_info
check_info

echo "--- Running system upgrade..."
system_upgrade

echo "--- Creating user $KARMANODE_USER..."
user_creation

echo "--- Disabling remote root login..."
modify_sshd_config

echo "--- Creating swap partition..."
create_swap_space

echo "Installing ohmc daemon..."
su ohmcoin
cd
git clone https://github.com/theohmproject/ohmcoin.git 
cd ohmcoin 
chmod +x share/genbuild.sh 
chmod +x autogen.sh 
chmod 755 src/leveldb/build_detect_platform
#sudo ./autogen.sh 
#sudo ./configure
#sudo make
#sudo make install
echo "Installing blockchain snapshot..."