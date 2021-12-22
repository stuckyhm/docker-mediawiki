#!/bin/bash
#set -x

function getLastGithubTag {
	JSON=$(curl -s https://api.github.com/repos/${1}/${2}/tags | jq '.[0]')

	VALUE=$(echo ${JSON} | jq '.name' | sed -e 's/"//g')

	[[ "${VALUE}" = "" ]] && echo "No version tag ${1}/${2} for found." && exit 1

	echo ${VALUE}
}

function getLastDockerImageTag {
	VALUE=$(wget -q https://registry.hub.docker.com/v1/repositories/${1}/tags -O - | \
		sed -e 's/[][]//g' -e 's/"//g' -e 's/ //g' | \
		tr '}' '\n' | \
		awk -F: '{print $3}' | \
		grep ${2} | \
		sort | \
		tail -n 1)

	[[ "${VALUE}" = "" ]] && echo "No version tag for '${1}:${2}*' found." && exit 1

	echo ${VALUE}
}

function replaceInDockerfileIfChanged {
	KEY=${1}
	VALUE_NEW=${2}
	VALUE_OLD=$(grep -E "^${KEY}" Dockerfile | sed -e "s/^\(${1}\)//g")
	LINE=$(grep -n -E "^${KEY}" Dockerfile | cut -d ":" -f 1)

	if [[ "${VALUE_NEW}" = "${VALUE_OLD}" ]]; then
		echo "No changes line ${LINE}: '${KEY}' value '${VALUE_OLD}'."
		return 1
	else
		sed -i '' -e "s/^\(${KEY}\).*/\1${VALUE_NEW}/g" Dockerfile
		echo "Replacing at line ${LINE}: '${KEY}' value '${VALUE_OLD}' with '${VALUE_NEW}'."
		return 0
	fi
}

function replaceTag {
	TAG=$(echo ${1} | tr -d '[:space:]')
	git tag -d "${TAG}"
	git push origin :refs/tags/"${TAG}"
	git tag -af "${TAG}" -m "${2}"
}

function dockerBuildAndPush {
	export DOCKER_REPO=$1
	chmod a+x ./hooks/build
	./hooks/build

	export IMAGE_NAME=${DOCKER_REPO}:latest
	docker push ${IMAGE_NAME}

	chmod a+x ./hooks/post_push
	./hooks/post_push
}

function gitCommitAndPush {
	git add Dockerfile
	git commit -m "${COMMIT_TEXT}"

	git push

	BASE_TAG=$(echo ${DOCKER_IMAGE_TAG} | cut -d "-" -f 2)
	replaceTag "v${APPLICATION_VERSION_MAJOR}" "${COMMIT_TEXT}"
	replaceTag "v${APPLICATION_VERSION_MAJOR}-${BASE_TAG}" "${COMMIT_TEXT}"
	replaceTag "v${APPLICATION_VERSION_MAJOR}.${APPLICATION_VERSION_MINOR}" "${COMMIT_TEXT}"
	replaceTag "v${APPLICATION_VERSION_MAJOR}.${APPLICATION_VERSION_MINOR}-${BASE_TAG}" "${COMMIT_TEXT}"
	replaceTag "v${APPLICATION_VERSION_MAJOR}.${APPLICATION_VERSION_MINOR}.${APPLICATION_VERSION_PATCH}" "${COMMIT_TEXT}"
	replaceTag "v${APPLICATION_VERSION_MAJOR}.${APPLICATION_VERSION_MINOR}.${APPLICATION_VERSION_PATCH}-${BASE_TAG}" "${COMMIT_TEXT}"

	git push --tags
}

function updateDockerfileBaseImage {
	DOCKER_IMAGE_TAG=$(getLastDockerImageTag ${1} ${2})

	replaceInDockerfileIfChanged "ARG BASE_IMAGE_TAG=" "${DOCKER_IMAGE_TAG}"
	if [[ ${?} -eq 0 ]]; then
		COMMIT_TEXT="${COMMIT_TEXT}Update base image to '${1}:${DOCKER_IMAGE_TAG}'."$'\n'
		BUILD=1
	fi
}

function updateApplicationVersion {
	GITHUB_TAG_NAME=$(getLastGithubTag ${1} ${2})

	APPLICATION_KEY=${3:-APPLICATION}

	replaceInDockerfileIfChanged "ARG ${APPLICATION_KEY}_VERSION=" "${GITHUB_TAG_NAME}"
	if [[ ${?} -eq 0 ]]; then
		COMMIT_TEXT="${COMMIT_TEXT}Update ${2} to '${GITHUB_TAG_NAME}'."$'\n'
		BUILD=1
	fi

	APPLICATION_VERSION_MAJOR=$(echo ${GITHUB_TAG_NAME} | cut -d "." -f 1)
	replaceInDockerfileIfChanged "ARG ${APPLICATION_KEY}_VERSION_MAJOR=" ${APPLICATION_VERSION_MAJOR}

	APPLICATION_VERSION_MINOR=$(echo ${GITHUB_TAG_NAME} | cut -d "." -f 2)
	replaceInDockerfileIfChanged "ARG ${APPLICATION_KEY}_VERSION_MINOR=" ${APPLICATION_VERSION_MINOR}

	APPLICATION_VERSION_PATCH=$(echo ${GITHUB_TAG_NAME} | cut -d "." -f 3)
	replaceInDockerfileIfChanged "ARG ${APPLICATION_KEY}_VERSION_PATCH=" ${APPLICATION_VERSION_PATCH}
}


updateDockerfileBaseImage ubuntu bionic-
updateApplicationVersion wikimedia mediawiki MEDIAWIKI

echo ${COMMIT_TEXT}

if [[ ${BUILD} -eq 1 ]] || [[ ${FORCE_BUILD} -eq 1 ]]; then
	gitCommitAndPush
	dockerBuildAndPush stucky/mediawiki
fi
