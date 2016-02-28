#!/bin/bash

#load settings
source "$DOC_SETTINGS"

DOC_TYPO3_VERSION=${2:-7.6}
DOC_DOCKERFILE_TYPO3="./dockerfiles/Dockerfile-typo3"

docker inspect "$DOC_USERNAME"/typo3base:"$DOC_TYPO3_VERSION" &> /dev/null

if [ $? -ne 0 ]; then
	echo "-> start building TYPO3 $DOC_TYPO3_VERSION"
	docker build \
	    --build-arg user_id=$(id -u) \
	    --build-arg group_id=$(id -g) \
	    --build-arg typo3_version=$DOC_TYPO3_VERSION \
	    -f "$DOC_DOCKERFILE_TYPO3" \
	    -t "$DOC_REPO/$DOC_USERNAME/typo3base:$DOC_TYPO3_VERSION" .
fi

echo "-> copy composer.json from config/composer.json"
cp config/composer.json sources/composer.json