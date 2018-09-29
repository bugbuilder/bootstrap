
http(){
    docker run -t --rm \
        --net=host \
        --log-driver none \
        jess/httpie "$@"
}

terraform(){
    docker run -it --rm \
        -v "${HOME}:${HOME}:ro" \
		-v "$(pwd):/usr/src/repo" \
		-v /tmp:/tmp \
		--workdir /usr/src/repo \
		--log-driver none \
        --user "${UID}:${GID}" \
		hashicorp/terraform:0.11.8 "$@"
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


kustomize(){
    docker run -it --rm \
        -v "${HOME}:${HOME}:ro" \
		-v "$(pwd):/usr/src/repo" \
		-v /tmp:/tmp \
		--workdir /usr/src/repo \
		--log-driver none \
        --user "${UID}:${GID}" \
		bennu/kustomize:v1.0.8 "$@"
}

hugo(){
    docker run -it --rm \
        -v "${HOME}:${HOME}:ro" \
		-v "$(pwd):/usr/src/repo" \
		-v /tmp:/tmp \
        -p 1313:1313 \
		--workdir /usr/src/repo \
		--log-driver none \
        --user "${UID}:${GID}" \
		bennu/hugo:0.49 "$@"
}

