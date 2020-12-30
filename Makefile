
CONTAINER_BUILDER=podman
CONTAINER_VERSION=latest
CONTAINER_FULL_NAME="docker.io/shadow53/taskd"
CERTS_DEST=/tmp/certs

.PHONY: all
all: ${CONTAINER_BUILDER}

${CONTAINER_BUILDER}-deps: docker/Dockerfile docker/init.sh

.PHONY: ${CONTAINER_BUILDER}
${CONTAINER_BUILDER}: ${CONTAINER_BUILDER}-deps
ifeq (, $(shell which ${CONTAINER_BUILDER}))
	@echo "ensure ${CONTAINER_BUILDER} is installed, then run this again"
	@exit 1
else    
	@echo "Generating image"
	$(eval CONTAINER_ID := $(shell ${CONTAINER_BUILDER} build docker | tail -1))
	@echo "Built image with id ${CONTAINER_ID}. Tagging as ${CONTAINER_VERSION}."
	${CONTAINER_BUILDER} tag ${CONTAINER_ID} ${CONTAINER_FULL_NAME}:${CONTAINER_VERSION}
	@echo "Logging in to docker"
	${CONTAINER_BUILDER} login docker.io
	@echo "Uploading to docker"
	${CONTAINER_BUILDER} push ${CONTAINER_FULL_NAME}:${CONTAINER_VERSION}
endif
