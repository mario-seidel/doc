#!/bin/bash
set -e

###
# doc - Docker Operation Control
###

VERSION=0.11

DOCKER_COMPOSE_FILE="docker-compose.yml"
DOC_DOCKERFILE_PROD="./dockerfiles/Dockerfile-prod"
DOC_DOCKERFILE_FOLDER="./dockerfiles"
DOC_VHOST_CONFIG_FOLDER="./config"
DOC_SETTINGS="./config/settings.sh"
SOURCE_DIR="./sources"
NGINX_CONTAINER="nginx"
ENVIRONMENT=
IS_DEFAULT_ENVIRONMENT=0
DOCKER_COMPOSE_CMD=$(which docker-compose)

showhelp() {
	out ""
	out "doc $VERSION"
	out "========================================"
	out "Commands:"
	out "build [environment] \t\t\t - building an image with given environment. default is local if none given."
	out "tag \t\t\t\t\t - build and tag an image"
	out "up [environment] \t\t\t - run docker-compose with given environment. default is local if none given."
	out "down \t\t\t\t\t - stop all containers an remove them"
	out "stop [environment] \t\t\t - stop container with given environment. default is local if none given."
	out "status \t\t\t\t\t - shows status informations about current web container"
	out "in \t\t\t\t\t - start bash in given service (second argument, default is web) for given environment (first argument, default is local)"
	out "ps \t\t\t\t\t - show process list of all containers"
	out "exec [environment] [service] COMMAND \t - executes a COMMAND in a container service with user privileges. default environment is local"
	out "suexec [environment] [service] COMMAND \t - executes a COMMAND in a container service with root privileges. default environment is local"
	out "deploy \t\t\t\t\t - build, tag and deploy to remote repo"
	out "initproject [projectname] [git url] [environment] \t - initialize a new project. default environment is local. When no repo should be checked out, just pass -n as git url"
	out "logs [environment] [nginx|web] \t\t - show log output of all or specific container [web, typo3-db, nginx] with given environment."
	out "reinit [projectname] \t\t\t - rewrite all Docker- and docker-composer files from templates"
	out "self-update \t\t\t\t - run self update and pull latest version"
	out ""
}

### Docker Commands
dockerdeploy() {
    IMAGE_NAME="$1"
	CUR_VERSION=$(get_current_version $IMAGE_NAME)

	if [ -z "$CUR_VERSION" ]; then
		errout "either current version or image could not be determined"
		exit 1;
	fi

	info "Deploying image $IMAGE_NAME with version $CUR_VERSION to $DOC_REPO...\n"

	#push image to remote docker repo
	docker -D -l=debug push "$DOC_REPO/$IMAGE_NAME"
}

get_current_version() {
	if [ "$1" == '' ]; then
		errout "missing image name"
		exit 1;
	fi
	echo  $(sed -n "s|.*image:\s*\($DOC_REPO/\)\?$1:\(.*\)$|\2|p" "$DOCKER_COMPOSE_FILE")
}

buildandtag() {
	IMAGE_NAME=$1
	CUR_VERSION=$2

	if [ -z "$2" ]; then
		CUR_VERSION=$(get_current_version $IMAGE_NAME)
	fi

	if [ -z "$CUR_VERSION" ]; then
		errout "current version could not be determined fo $IMAGE_NAME"
		exit 1;
	fi

	info "current version is $CUR_VERSION"

	NEW_VERSION=$(increment_version $CUR_VERSION)
	NEW_IMAGE_NAME="$DOC_REPO/$IMAGE_NAME:$NEW_VERSION"

	#name and build image in SOURCE_DIR and tag builded image
	#use no cache, we want all to be fresh when deploying
	docker build -t $NEW_IMAGE_NAME -f "$DOC_DOCKERFILE_PROD" --no-cache . >&2 &&
#	docker tag "$NEW_IMAGE_NAME" "$DOC_REPO/$NEW_IMAGE_NAME" >&2

	if [ $? -eq 0 ]; then
		sed -i "s|\(.*image:\s*$DOC_REPO/$IMAGE_NAME:\)$CUR_VERSION|\1$NEW_VERSION|g" "$DOCKER_COMPOSE_FILE"
		info "new version build: $(get_current_version $IMAGE_NAME)"
	else
		exit 1;
	fi
}

checkIfComposeFilesExistByEnvironment() {
	if [ ! -f "docker-compose.$1.yml" ]; then
		errout "configuration file docker-compose.$1.yml not found in current dir"
	fi
	if [ ! -f $DOCKER_COMPOSE_FILE ]; then
		errout "configuration file docker-compose.yml not found in current dir"
	fi
}

initEnvironment() {
	ENVIRONMENT=$1

	if [ -z "$ENVIRONMENT" ]; then
		ENVIRONMENT="local"
		IS_DEFAULT_ENVIRONMENT=1
	fi
}

dockerbuild() {
	initEnvironment "$1"
	if [ "$IS_DEFAULT_ENVIRONMENT" -eq 0 ]; then
		shift;
	fi
	checkIfComposeFilesExistByEnvironment "$ENVIRONMENT"
	docker-compose -p "${DOC_PROJECT_NAME}_$ENVIRONMENT" -f $DOCKER_COMPOSE_FILE -f "docker-compose.$ENVIRONMENT.yml" build --force-rm $@
}

dockerup() {
	initEnvironment "$1"
	if [ "$IS_DEFAULT_ENVIRONMENT" -eq 0 ]; then
		shift;
	fi
	checkIfComposeFilesExistByEnvironment "$ENVIRONMENT"
	docker-compose -p "${DOC_PROJECT_NAME}_$ENVIRONMENT" -f "$DOCKER_COMPOSE_FILE" -f "docker-compose.$ENVIRONMENT.yml" up -d $@
}

dockerdown() {
    	out "Stopping and remove all containers"
    	docker-compose down $@
}

dockerstop() {
	initEnvironment "$1"
	if [ "$IS_DEFAULT_ENVIRONMENT" -eq 0 ]; then
		shift;
	fi
	checkIfComposeFilesExistByEnvironment "$ENVIRONMENT"
	out "Stopping container for docker-compose.$ENVIRONMENT.yml"
    	docker-compose -p "${DOC_PROJECT_NAME}_$ENVIRONMENT" -f "$DOCKER_COMPOSE_FILE" -f "docker-compose.$ENVIRONMENT.yml" stop $@
}

##
# docker-compose ps with current environment
##
dockerps() {
	initEnvironment "$1"
	if [ "$IS_DEFAULT_ENVIRONMENT" -eq 0 ]; then
		shift;
	fi
	checkIfComposeFilesExistByEnvironment "$ENVIRONMENT"
	docker-compose -f "$DOCKER_COMPOSE_FILE" -f "docker-compose.$ENVIRONMENT.yml" ps $@
}

dockerip() {
	CONTAINER_ID="$1"
	echo $(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' ${CONTAINER_ID})
}

conteinerstatus() {
	CONTAINER_ID="$1"
	echo $(docker inspect -f '{{ .State.Status}}' ${CONTAINER_ID})
}

containerports() {
	CONTAINER_ID="$1"
	echo $(docker port ${CONTAINER_ID})
}

dockerlogs() {
	initEnvironment "$1"
	if [ "$IS_DEFAULT_ENVIRONMENT" -eq 0 ]; then
		shift;
	fi
	checkIfComposeFilesExistByEnvironment "$ENVIRONMENT"
	docker-compose -p "${DOC_PROJECT_NAME}_$ENVIRONMENT" -f "$DOCKER_COMPOSE_FILE" -f "docker-compose.$ENVIRONMENT.yml" logs -f $@
}

##
# shows status information about a container
##
dockerstatus() {
	source "$DOC_SETTINGS"
	initsettings ${DOC_PROJECT_NAME}
	LOCAL_CONTAINER="${DOC_PROJECT_NAME}_web_local"
	WEB_IP=$(dockerip ${LOCAL_CONTAINER})
	STATE=$(conteinerstatus ${LOCAL_CONTAINER})
	info "container: $LOCAL_CONTAINER"
	info "status: $STATE"
	info "IP: $WEB_IP"
	info "ports: $(containerports ${LOCAL_CONTAINER})"
	info "URL: http://$DOC_PROJECT_NAME.$DOC_LOCAL_DOMAIN"
}

dockerin() {
	initEnvironment "$1"
	if [ "$IS_DEFAULT_ENVIRONMENT" -eq 0 ]; then
		shift;
	fi

	SERVICE=$1
	if [ -z "$SERVICE" ]; then
		SERVICE="web"
	fi

	checkIfComposeFilesExistByEnvironment "$ENVIRONMENT"
	docker-compose -p "${DOC_PROJECT_NAME}_$ENVIRONMENT" -f "$DOCKER_COMPOSE_FILE" -f "docker-compose.$ENVIRONMENT.yml" exec --user "$HOST_USER" $SERVICE bash
}

##
# Execute a command in the container with user privileges, if -u flag is given. Else
# the command is executed with root privileges.
# Optinal an environment and a service could be specified.
# If 2 arguments are given, the first is the service and the second is the command.
# If 3 arguments are given, the order is ENV SERVICE COMMAND.
#
# examples:
# 	doc exec ps
# 	doc exec 'ps aux'
# 	doc exec webpack 'npm update'
# 	doc exec prod db 'mysqldump -u root -p root > dump.sql'
##
dockerexec() {
	local withUserPriv=0

	if [ -n "$1" ] && [ "$1" == "-u" ]; then
		withUserPriv=1
		shift
	fi

	case "$#" in
		3)
			initEnvironment "$1"
			shift
			SERVICE=$1
			shift
			;;
		2)
			initEnvironment
			SERVICE=$1
			shift
			;;
		1)
			initEnvironment
			SERVICE="web"
			;;
		*)
			info "usage: doc exec COMMAND"
			errout "need at lease one command but at most 3 arguments"
	esac

	info "exec '$@' in service '$SERVICE' in project '${DOC_PROJECT_NAME}_$ENVIRONMENT'"

	checkIfComposeFilesExistByEnvironment "$ENVIRONMENT"

	#execute command with or without user privileges
	if (( withUserPriv == 1 )); then
		dockerComposeExec exec --user "$HOST_USER" "$SERVICE" $@
	else
		dockerComposeExec exec "$SERVICE" $@

	fi
}

initproject() {
	DOC_PROJECT_NAME=$1
	GIT_REPO=$2
	initsettings "$DOC_PROJECT_NAME"

	if [ -z "$DOC_PROJECT_NAME" ]; then
		errout "no project name given"
		exit 1
	fi
	
	if [ -z "$DOC_USERNAME" ]; then
		errout "please set a username or company name in DOC_USERNAME"
		exit 1
	fi
	
	info "init project \"$DOC_FULL_NAME\""
	initConfigurationFiles

	#initialize all deps before start building
	if [ -f "scripts/init.sh" ]; then
	    info "run init.sh"
	    scripts/init.sh ${GIT_REPO}

	    if [ $? -ne 0 ]; then
	        echo "run init.sh failed: $?"
	        exit;
	    fi
	fi

	info "start building project"
	dockerup $3 &&
		info "===========\n$DOC_FULL_NAME was built successfully\n\n"

	if [ -n ${NGINX_CONTAINER} ]; then
		NGINX_IP=$(dockerip "$NGINX_CONTAINER")
		out "please add $NGINX_IP to your /etc/hosts or run this:"
		out "echo -e \"$NGINX_IP\\\t${DOC_PROJECT_NAME}.${DOC_LOCAL_DOMAIN}\" | sudo tee -a /etc/hosts"
	else
		WEB_IP=$(dockerip "${DOC_PROJECT_NAME}_web_local")
		out "please add IP $WEB_IP to your /etc/hosts or run this:"
		out "echo -e \"$WEB_IP\\\t${DOC_PROJECT_NAME}.${DOC_LOCAL_DOMAIN}\" | sudo tee -a/etc/hosts"
	fi
}

initsettings() {
	if [ ! -f "$DOC_SETTINGS" ]; then
		touch "$DOC_SETTINGS"
	fi
	source "$DOC_SETTINGS"

	DOC_PROJECT_NAME="$1"

	if [ -z "$DOC_USERNAME" ]; then
		while [ -z "$DOC_USERNAME" ]; do
			ask "user / company name? [DOC_USERNAME]"
			read DOC_USERNAME
		done

		ask "docker regestry server (repo.domain.de:5000)? [DOC_REPO]"
		read DOC_REPO

		if [ -n "$DOC_REPO" ]; then
			DOC_USERNAME="$DOC_REPO\$DOC_USERNAME"
		fi
		echo "DOC_USERNAME=\"$DOC_USERNAME\"" >> "$DOC_SETTINGS"
	fi

	if [ -z "$DOC_PROJECT_NAME" ] || [ -z "$DOC_FULL_NAME" ]; then
		while [ -z "$DOC_PROJECT_NAME" ]; do
			ask "project name? [DOC_PROJECT_NAME]"
			read DOC_PROJECT_NAME
		done
		echo "DOC_PROJECT_NAME=\"$DOC_PROJECT_NAME\"" >> "$DOC_SETTINGS"
		DOC_FULL_NAME="$DOC_USERNAME/$DOC_PROJECT_NAME"
		echo "DOC_FULL_NAME=\"$DOC_FULL_NAME\"" >> "$DOC_SETTINGS"
	fi

	if [ -z "$DOC_GITHUB_OAUTH" ]; then
		while [ -z "$DOC_GITHUB_OAUTH" ]; do
			ask "github oauth token? [DOC_GITHUB_OAUTH]"
			read DOC_GITHUB_OAUTH
		done
		echo "DOC_GITHUB_OAUTH=\"$DOC_GITHUB_OAUTH\"" >> "$DOC_SETTINGS"
	fi

	if [ -z "$DOC_SSH_KEY_FILE" ]; then
		while [ -z "$DOC_SSH_KEY_FILE" ]; do
			ask "path to ssh key file? [DOC_SSH_KEY_FILE]"
			read DOC_SSH_KEY_FILE
		done
		echo "DOC_SSH_KEY_FILE=\"$DOC_SSH_KEY_FILE\"" >> "$DOC_SETTINGS"
	fi

	if [ -z "$HOST_USER" ]; then
		while [ -z "$HOST_USER" ]; do
			ask "username for shared source dir (aka your username)? [HOST_USER]"
			read HOST_USER
		done
		HOST_USERID=$(id -u ${HOST_USER})
		if [ ${HOST_USERID} -le 0  ]; then
			errout "user $HOST_USER does not exists"
		fi
		echo "HOST_USER=\"$HOST_USER\"" >> "$DOC_SETTINGS"
		echo "HOST_USERID=$HOST_USERID" >> "$DOC_SETTINGS"
	fi

	if [ -z "$HOST_GROUP" ]; then
		while [ -z "$HOST_GROUP" ]; do
			ask "usergroup for shared source dir (aka your usergroup)? [HOST_GROUP]"
			read HOST_GROUP
		done
		HOST_GROUPID=$(id -g ${HOST_USER})
		if [ ${HOST_GROUPID} -le 0 ]; then
			errout "user $HOST_GROUP does not exists"
		fi
		echo "HOST_GROUP=\"$HOST_GROUP\"" >> "$DOC_SETTINGS"
		echo "HOST_GROUPID=$HOST_GROUPID" >> "$DOC_SETTINGS"
	fi

	if [ -z "$DOC_LOCAL_DOMAIN" ]; then
		while [ -z "$DOC_LOCAL_DOMAIN" ]; do
			ask "local TLD without dot (default is 'local') ? [DOC_LOCAL_DOMAIN]"
			read DOC_LOCAL_DOMAIN
			DOC_LOCAL_DOMAIN=${DOC_LOCAL_DOMAIN:-local}
		done
		echo "DOC_LOCAL_DOMAIN=\"$DOC_LOCAL_DOMAIN\"" >> "$DOC_SETTINGS"
	fi

	source "$DOC_SETTINGS"
	export DOC_SETTINGS
}

replaceMarkerInFiles() {
	for file in $1; do
		if [ -w "$file" ]; then
			sed -i "s|###projectname###|$DOC_PROJECT_NAME|g" "$file"
			sed -i "s|###username###|$DOC_USERNAME|g" "$file"
			sed -i "s|###repohost###|$DOC_REPO|g" "$file"
			sed -i "s|###github_oauth###|$DOC_GITHUB_OAUTH|g" "$file"
			sed -i "s|###ssh_key_file###|$DOC_SSH_KEY_FILE|g" "$file"
			sed -i "s|###ssh_auth_sock###|$SSH_AUTH_SOCK|g" "$file"
			sed -i "s|###hostuser###|$HOST_USER|g" "$file"
			sed -i "s|###hostuserid###|$HOST_USERID|g" "$file"
			sed -i "s|###hostgroup###|$HOST_GROUP|g" "$file"
			sed -i "s|###hostgroupid###|$HOST_GROUPID|g" "$file"
			sed -i "s|###local_domain###|$DOC_LOCAL_DOMAIN|g" "$file"
		else
			errout "file ${file} does not exist or is not writable"
		fi
	done
}

initConfigurationFiles() {
	cp ./template/docker-compose* .
	cp ./template/Dockerfile* dockerfiles/
	cp ./template/apache-vhost* ${DOC_VHOST_CONFIG_FOLDER}/

	### wir können im for loop nicht mit einmal mehrere Ordner mit Wildcard durchgehen
	replaceMarkerInFiles "./docker-compose*"
	replaceMarkerInFiles "$DOC_DOCKERFILE_FOLDER/Dockerfile*"
	replaceMarkerInFiles "$DOC_VHOST_CONFIG_FOLDER/apache-vhost*"
}

### Helper Methods

##
# execute a docker compose command with the given environment and config files
##
dockerComposeExec() {
	eval "${DOCKER_COMPOSE_CMD} -p ${DOC_PROJECT_NAME}_${ENVIRONMENT} -f ${DOCKER_COMPOSE_FILE} \
		-f docker-compose.${ENVIRONMENT}.yml" $@
}

increment_version (){
	declare -a part=( ${1//\./ } )
	declare    new
	declare -i carry=1

	for (( CNTR=${#part[@]}-1; CNTR>=0; CNTR-=1 )); do
	len=${#part[CNTR]}
	new=$((part[CNTR]+carry))
	[ ${#new} -gt $len ] && carry=1 || carry=0
	[ $CNTR -gt 0 ] && part[CNTR]=${new: -len} || part[CNTR]=${new}
	done
	new="${part[*]}"
	echo -e "${new// /.}"
}

self_update() {
	DOC_DIR="`dirname $(realpath $(which doc))`/.."
	if [ -d ${DOC_DIR} ]; then
		info "updating doc..."
		cd ${DOC_DIR}
		git pull
		showhelp
		info "...done"
	else
		errout "could not find doc dir"
	fi
}

##
# parse yaml files to a list of variables
# example:
#	global:
#	  debug: yes
#	  verbose: no
#	  debugging:
#		detailed: no
#		header: "debugging started"
#
#	output:
#	   file: "yes"
#
# will output:
#	global_debug="yes"
#	global_verbose="no"
#	global_debugging_detailed="no"
#	global_debugging_header="debugging started"
#	output_file="yes"
##
function parse_yaml {
	local prefix=$2
	local s='[[:space:]]*' w='[a-zA-Z0-9_]*' fs=$(echo @|tr @ '\034')
	sed -ne "s|^\($s\):|\1|" \
		-e "s|^\($s\)\($w\)$s:$s[\"']\(.*\)[\"']$s\$|\1$fs\2$fs\3|p" \
		-e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p"  $1 |
	awk -F$fs '{
	  indent = length($1)/2;
	  vname[indent] = $2;
	  for (i in vname) {if (i > indent) {delete vname[i]}}
	  if (length($3) > 0) {
		 vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
		 printf("%s%s%s=\"%s\"\n", "'$prefix'",vn, $2, $3);
	  }
   }'
}

RED='\033[0;31m'
YELLOW='\033[1;33m'
ORANGE='\033[0;33m'
NC='\033[0m' # No Color
	
out() {
	echo -e "$@"
}

info() {
	out "${YELLOW}$@${NC}"
}

errout() {
	echo -e "${RED}[ERROR]: $@${NC}"
	exit 1;
}

warnout() {
	echo -e "${ORANGE}[WARNING]: $@${NC}"
}

ask() {
	echo -n -e "${YELLOW}$@${NC} "
}

if [ -f "$DOC_SETTINGS" ]; then
	source "$DOC_SETTINGS"
	export DOC_SETTINGS
fi

### Main
case "$1" in
	"build") out "building image"; shift; dockerbuild $@ ;;
	"tag") out "build and tag"; buildandtag $2 $(get_current_version $2) ;;
	"up") out "docker up"; dockerup "$2" ;;
	"down") out "docker down"; shift; dockerdown $@ ;;
	"stop") out "docker stop"; shift; dockerstop $@ ;;
	"status") out "container status:"; shift; dockerstatus ;;
	"ps") shift; dockerps $@ ;;
	"exec") shift; dockerexec -u "$@" ;;
	"suexec") shift; dockerexec "$@" ;;
	"in") shift; out "starting bash..."; dockerin $@ ;;
	"deploy") out "starting deployment"; dockerdeploy "$2" "$3" ;;
	"initproject") shift; initproject $@ ;;
	"logs") shift; dockerlogs $@ ;;
	"reinit") shift; out "reinit all Dockerfiles"; initsettings $@ && initConfigurationFiles ;;
	"self-update") self_update ;;
	*)   out "Unknown parameter"; showhelp; ;;
esac
