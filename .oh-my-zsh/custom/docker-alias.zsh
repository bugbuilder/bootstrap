export DOCKER_REPO_PREFIX=jess

http(){
    docker run -t --rm \
        -v /var/run/docker.sock:/var/run/docker.sock \
		--log-driver none \
		${DOCKER_REPO_PREFIX}/httpie "$@"
}
