#!/bin/bash
#set -x

function getLastGithubTag {
	JSON=$(curl -s https://api.github.com/repos/${1}/${2}/tags | jq '.[0]')

	MEDIAWIKI_TAG_NAME=$(echo ${JSON} | jq '.name' | sed -e 's/"//g')
	MEDIAWIKI_VERSION=$(echo ${MEDIAWIKI_TAG_NAME} | cut -d "." -f 1,2)
	MEDIAWIKI_PATCH=$(echo ${MEDIAWIKI_TAG_NAME} | cut -d "." -f 3)

	[[ "${MEDIAWIKI_TAG_NAME}" = "" ]] && echo "No mediawiki version tag found." && exit 1
}

function getLastDockerImage {
	BASE_TAG=$(wget -q https://registry.hub.docker.com/v1/repositories/${1}/tags -O - | sed -e 's/[][]//g' -e 's/"//g' -e 's/ //g' | tr '}' '\n' | awk -F: '{print $3}' | grep ${2} | sort | tail -n 1)

	[[ "${BASE_TAG}" = "" ]] && echo "No ubuntu version tag found." && exit 1
}

function replaceInDockerfile {
	KEY=${1}
	VALUE_NEW=${2}
	VALUE_OLD=$(grep -E "^${KEY}" Dockerfile | sed -e "s/^\(${1}\)//g")
	LINE=$(grep -n -E "^${KEY}" Dockerfile | cut -d ":" -f 1)

	[[ "${VALUE_NEW}" = "${VALUE_OLD}" ]] && CHANGE=0 && return

	sed -i '' -e "s/^\(${KEY}\).*/\1${VALUE_NEW}/g" Dockerfile
	echo "Replacing at line ${LINE}: '${KEY}' value '${VALUE_OLD}' with '${VALUE_NEW}'."

	CHANGE=1
}

function replateTag {
	TAG=$(echo ${1} | tr -d '[:space:]')
	git tag -d "${TAG}"
	git push origin :refs/tags/"${TAG}"
	git tag -af "${TAG}" -m "${2}"
}

while getopts "ct" opt; do
  case $opt in
    c)
      COMMIT=1
      ;;
    t)
      TAGGING=1
      ;;
  esac
done

getLastGithubTag wikimedia mediawiki
getLastDockerImage ubuntu bionic-

replaceInDockerfile "ARG BASE_TAG=" "${BASE_TAG}"
BASE_CHANGE=${CHANGE}
replaceInDockerfile "ARG MEDIAWIKI_VERSION=" "${MEDIAWIKI_VERSION}"
VERSION_CHANGE=${CHANGE}
replaceInDockerfile "ARG MEDIAWIKI_PATCH=" "${MEDIAWIKI_PATCH}"
PATCH_CHANGE=${CHANGE}

BASE_VERSION=$(echo ${BASE_TAG} | cut -d "-" -f 2)

if [[ ${BASE_CHANGE} -eq 1 ]]; then
	TEXT="base image to ubuntu:${BASE_TAG}"
fi
if [[ ${VERSION_CHANGE} -eq 1 ]] || [[ ${PATCH_CHANGE} -eq 1 ]]; then
	[[ "${TEXT}" != "" ]] && TEXT="${TEXT} and "
	TEXT="${TEXT}mediawiki to ${MEDIAWIKI_VERSION}.${MEDIAWIKI_PATCH}"
fi
TEXT="Update ${TEXT}."

echo ${TEXT}

if [[ ${GIT} -eq 1 ]]; then
	git add Dockerfile
	git commit -m "${TEXT}"

	git push
fi

if [[ ${TAGGING} -eq 1 ]]; then
	replateTag "v${MEDIAWIKI_VERSION}.${MEDIAWIKI_PATCH}" "${TEXT}"
	replateTag "v${MEDIAWIKI_VERSION}.${MEDIAWIKI_PATCH}-${BASE_VERSION}" "${TEXT}"

	git push --tags
fi
