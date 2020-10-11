
http(){
    docker run -t --rm \
        --net=host \
        --log-driver none \
        jess/httpie "$@"
}

aws(){
	docker run -it --rm \
        -v "${HOME}/.aws:/root/.aws" \
		--log-driver none \
		--name aws \
		jess/awscli "$@"
}

az(){
	docker run -it --rm \
		-v "${HOME}/.azure:/root/.azure" \
		--log-driver none \
		jess/azure-cli "$@"
}

vault() {
    local tag="1.1.1"

    if [ -z "$1" ]; then
        docker run --rm --name vault_client -it --cap-add IPC_LOCK vault:${tag} --help
        return 0
    fi

    docker inspect vault_server &>/dev/null

    if [ $? -eq 1 ]; then
        docker rm -f vault_server 2>/dev/null
        docker run --rm --name vault_server -dit --cap-add IPC_LOCK -e 'VAULT_DEV_ROOT_TOKEN_ID=bennu' vault:${tag}
	fi

    local token="$(docker logs vault_server | grep "Root Token:" | awk '{print $3}' | sed 's/\x1b\[[0-9;]*[mGKF]//g' | sed 's/\r//g' )"
    local addr=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' vault_server)

    docker run --rm --name vault_client -it --cap-add IPC_LOCK -eVAULT_TOKEN=${token} -eVAULT_ADDR=http://${addr}:8200 vault:${tag} "$@"
}

terraform(){
    docker run -it --rm \
        -e HOME=/root \
        -v "${HOME}:/root:ro" \
	-v "$(pwd):/usr/src/repo" \
	-v /tmp:/tmp \
	--workdir /usr/src/repo \
	--log-driver none \
        --user "${UID}:${GID}" \
	hashicorp/terraform:0.13.4 "$@"
}
