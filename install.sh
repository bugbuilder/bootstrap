#!/bin/bash

set -e
set -o pipefail

export DEBIAN_FRONTEND=noninteractive

C_RESET='\033[0m'
NVIDIA_RUN=NVIDIA-Linux-x86_64-390.77.run

get_user() {
	if [ -z "${TARGET_USER-}" ]; then
		mapfile -t options < <(find /home/* -maxdepth 0 -printf "%f\\n" -type d)
		# if there is only one option just use that user
		if [ "${#options[@]}" -eq "1" ]; then
			readonly TARGET_USER="${options[0]}"
			echo "Using user account: ${TARGET_USER}"
			return
		fi

		# iterate through the user options and print them
		PS3='Which user account should be used? '

		select opt in "${options[@]}"; do
			readonly TARGET_USER=$opt
			break
		done
	fi
}

check_is_sudo() {
	local C_RED='\033[0;31m'
	if [ "$EUID" -ne 0 ]; then
		echo -e "${C_RED}Please run as root.${C_RESET}"
		exit
	fi
}

setup_sudo() { 
	get_user

	gpasswd -a "$TARGET_USER" sudo
	gpasswd -a "$TARGET_USER" systemd-journal
	gpasswd -a "$TARGET_USER" systemd-network

	{ \
		echo -e "${TARGET_USER} ALL=(ALL) NOPASSWD:ALL"; \
		echo -e "${TARGET_USER} ALL=NOPASSWD: /sbin/ifconfig, /sbin/ifup, /sbin/ifdown, /sbin/ifquery"; \
	} >> /etc/sudoers

}

sources() {
	sources_dep

	cat <<-EOF > /etc/apt/sources.list
	deb http://httpredir.debian.org/debian stretch main contrib non-free
	deb-src http://httpredir.debian.org/debian/ stretch main contrib non-free
	
	deb http://httpredir.debian.org/debian/ stretch-updates main contrib non-free
	deb-src http://httpredir.debian.org/debian/ stretch-updates main contrib non-free
	
	deb http://security.debian.org/ stretch/updates main contrib non-free
	deb-src http://security.debian.org/ stretch/updates main contrib non-free
	EOF
       
	echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" > /etc/apt/sources.list.d/google-chrome.list

	curl https://dl.google.com/linux/linux_signing_key.pub | apt-key add -
}


sources_dep() {

	mkdir -p /etc/apt/apt.conf.d
	echo 'Acquire::Languages "none";' > /etc/apt/apt.conf.d/99translations	
   
	apt update || true
	apt install -y \
		apt-transport-https \
		ca-certificates \
		curl \
		dirmngr \
		gnupg2 \
		lsb-release \
		--no-install-recommends
}

prepare_nvidia() {
	dpkg --add-architecture i386
	apt update || true
	apt install -y \
		build-essential \
		gcc-multilib \
		libstdc++6:i386 \
		libgcc1:i386 \
		libncurses5:i386 \
		linux-headers-amd64 \
		rpm \
		zlib1g:i386 \
		--no-install-recommends

	mkdir -p nvidia

	curl https://us.download.nvidia.com/XFree86/Linux-x86_64/390.77/"${NVIDIA_RUN}" -o nvidia/"${NVIDIA_RUN}"
	chmod +x nvidia/"${NVIDIA_RUN}"
}

firmware() {
	apt update || true
	apt install -y \
		firmware-iwlwifi \
		firmware-realtek \
		--no-install-recommends
}

install() {
	apt update || true
	apt -y upgrade

	apt install -y \
		alsa-utils \
		apparmor \
		bridge-utils \
		gcc \
		google-chrome-stable \
		htop \
		make \
		neovim \
		tree \
		tmux \
		unzip \
		zip \
		zsh \
		--no-install-recommends

	apt autoremove
	apt autoclean
	apt clean
}

reminder() {
	local C_GREEN='\033[0;32m'
	
	echo -e "${C_GREEN}"
	echo -e "Don't forget:"
	echo -e " nvidia		- run the installer nvidia/${NVIDIA_RUN}"
	echo -e " iwlwif		- modprobe -r iwlwifi; modprobe iwlwifi "
	echo -e "${C_RESET}"
}

main() {
	check_is_sudo
	setup_sudo
	sources
	firmware
	install
	prepare_nvidia
	setup_sudo
	reminder
}

main "$@"

