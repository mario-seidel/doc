#!/bin/bash

#load settings
source "$DOC_SETTINGS"

DOC_TYPO3_VERSION=${2:-7.6}
GIT_REPO=$1
DOC_DOCKERFILE_TYPO3="./dockerfiles/Dockerfile-typo3"

docker inspect "$DOC_USERNAME"/typo3base:"$DOC_TYPO3_VERSION" &> /dev/null

if [ $? -ne 0 ]; then
	echo "-> start building TYPO3 $DOC_TYPO3_VERSION"
	docker build \
	    --build-arg hostuser=${HOST_USER} \
	    --build-arg hostuserid=${HOST_USERID} \
	    --build-arg hostgroup=${HOST_GROUP} \
	    --build-arg hostgroupid=${HOST_GROUPID} \
	    --build-arg typo3_version=${DOC_TYPO3_VERSION} \
	    -f "$DOC_DOCKERFILE_TYPO3" \
	    -t "$DOC_USERNAME/typo3base:$DOC_TYPO3_VERSION" .
fi

if [ -z ${GIT_REPO} ]; then
	echo "-> copy composer.json from config/composer.json"
	cp config/composer.json sources/composer.json
else
	echo "-> init project from $GIT_REPO"
	rm -rf ./sources
	git checkout ${GIT_REPO} sources
fi
