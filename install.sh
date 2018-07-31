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
        
	groupadd docker
	gpasswd -a "$TARGET_USER" docker

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
	echo "deb [arch=amd64] https://packages.microsoft.com/repos/vscode stable main" > /etc/apt/sources.list.d/vscode.list
	echo "deb [arch=amd64] http://download.virtualbox.org/virtualbox/debian stretch contrib" > /etc/apt/sources.list.d/virtualbox.list

	curl -sSL https://dl.google.com/linux/linux_signing_key.pub | apt-key add -
	curl -sSL https://www.virtualbox.org/download/oracle_vbox_2016.asc | apt-key add -
	curl -sSL https://www.virtualbox.org/download/oracle_vbox.asc | apt-key add -
	curl -sSL https://packages.microsoft.com/keys/microsoft.asc | apt-key add -
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
		linux-headers-amd64 \
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
	modprobe -r iwlwifi
	modprobe iwlwifi
}

install_golang() {
	export GO_VERSION
	GO_VERSION=$(curl -sSL "https://golang.org/VERSION?m=text")
	export GO_SRC=/usr/local/go

	if [[ -d "$GO_SRC" ]]; then
		sudo rm -rf "$GO_SRC"
		sudo rm -rf "$GOPATH"
	fi

	GO_VERSION=${GO_VERSION#go}
	
	# subshell
	(
	kernel=$(uname -s | tr '[:upper:]' '[:lower:]')
	curl -sSL "https://storage.googleapis.com/golang/go${GO_VERSION}.${kernel}-amd64.tar.gz" | tar -v -C /tmp -xz
	local user="$USER"
	sudo mv /tmp/go /usr/local
	CGO_ENABLED=0 go install -a -installsuffix cgo std
	)
}

install_debs() {
	packages=( releases.hashicorp.com/vagrant/2.1.2/vagrant_2.1.2_x86_64.deb ) 	
	for package in "${packages[@]}"; do
		owner=$(dirname "$package")
		deb=$(basename "$package")
	
		curl https://"${owner}"/"${deb}" -o /tmp/"${deb}"

		dpkg -i /tmp/"${deb}"
	done

}

install() {
	apt update || true
	apt -y upgrade

	apt install -y \
		alsa-utils \
		apparmor \
		bridge-utils \
		code \
		gcc \
		google-chrome-stable \
		htop \
		make \
		neovim \
		tree \
		tmux \
		unzip \
		virtualbox-5.2 \
		zip \
		zsh \
		--no-install-recommends

	apt autoremove
	apt autoclean
	apt clean
}

install_docker() {
	curl https://get.docker.com -sSf | sh
}

install_docker_toolkit() {
	binaries=( machine/releases/download/v0.15.0/docker-machine-Linux-x86_64 compose/releases/download/1.22.0/docker-compose-Linux-x86_64 ) 	
	for binary in "${binaries[@]}"; do
		version=$(dirname "$binary")
		bin=$(basename "$binary")
	
		curl -L https://github.com/docker/"${version}"/"${bin}" > /tmp/"${bin}"
		chmod +x /tmp/"${bin}"
		cp /tmp/"${bin}" /usr/local/bin/"${bin/-Linux-x86_64/}"
	done
}

reminder() {
	local C_GREEN='\033[0;32m'
	
	echo -e "${C_GREEN}"
	echo -e "Don't forget:"
	echo -e " nvidia		- run the installer nvidia/${NVIDIA_RUN}"
	echo -e "${C_RESET}"
}

main() {
	check_is_sudo
	setup_sudo
	sources
	firmware
	install
	install_docker
	install_docker_toolkit
	install_debs
	prepare_nvidia
	install_golang
	reminder
}

main "$@"