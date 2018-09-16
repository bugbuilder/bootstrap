
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
