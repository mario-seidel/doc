#!/bin/bash
set -e

###
# doc - Do Op Cheating
###

VERSION=0.12

DOCKER_COMPOSE_FILE="docker-compose.yml"
DOCKER_COMPOSE_CRED_FILE="docker-compose.credentials.yml"
DOC_DOCKERFILE_PROD="./dockerfiles/Dockerfile-prod"
DOC_DOCKERFILE_FOLDER="./dockerfiles"
DOC_VHOST_CONFIG_FOLDER="./config"
DOC_SETTINGS_FILE=$([ -f ./settings.sh ] && echo "./settings.sh" 2>/dev/null || true)
DOC_SETTINGS=${DOC_SETTINGS_FILE:-./config/settings.sh}
SOURCE_DIR="./sources"
NGINX_CONTAINER="nginx"
ENVIRONMENT=
IS_DEFAULT_ENVIRONMENT=0
DOCKER_COMPOSE_CMD=$(which docker-compose)
DOC_ALLOWED_ENV="local test alpha beta prod"

### check winpty usage ()
WINPTY_CMD=$(which winpty 2>/dev/null || true)
### set globaly if DOC_USE_WINPTY is set
if [ -n "${DOC_USE_WINPTY+set}" ]; then
	if [ "$WINPTY_CMD" ]; then
		DOCKER_COMPOSE_CMD="$WINPTY_CMD $DOCKER_COMPOSE_CMD"
	fi
fi

showhelp() {
	out ""
	out "doc $VERSION"
	out "================================================================================"
	out "Commands:"
	out "  cmd [environment] [docker-compose-options] [COMMAND] [ARGS...]"
	out "        executes a docker-compose command"
	out "        including the -p argument with the enviroment,"
	out "        and the -f argument with all the docker-compose.yml files."
	out "        Example: 'doc cmd prod logs web | grep ERR'"
	out "  do [environment] [docker-compose-options] [COMMAND] [ARGS...]"
	out "        currently only an alias for 'doc cmd'"
	out "  build [environment]"
	out "        building an image with given environment."
	out "        default is local if none given."
	out "  tag"
	out "        build and tag an image"
	out "  up [environment]"
	out "        run docker-compose with given environment."
	out "        default is local if none given."
	out "  down"
	out "        stop all containers an remove them"
	out "  stop [environment]"
	out "        stop container with given environment."
	out "        default is local if none given."
	out "  restart [environment] [service]"
	out "        stop container and start all or one container service."
	out "  status"
	out "        shows status informations about current web container"
	out "  in"
	out "        start bash in given service (second argument, default is web)"
	out "        for given environment (first argument, default is local)"
	out "  ps"
	out "        show process list of all containers"
	out "  exec [environment] [service] COMMAND"
	out "        executes a COMMAND in a container service with user privileges"
	out "  suexec [environment] [service] COMMAND"
	out "        executes a COMMAND in a container service with root privileges"
	out "  deploy"
	out "        build, tag and deploy to remote repo"
	out "  init [projectname] [git url] [environment]"
	out "        initialize a new project. When no repo should be checked out, just pass -n as git url"
	out "  logs [environment] [nginx|web]"
	out "        show log output of all or specific container [web, typo3-db, nginx] with given environment."
	out "  reinit [projectname]"
	out "        rewrite all Docker- and docker-composer files from templates"
	out "  self-update"
	out "        run self update and pull latest version"
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

	### push image to remote docker repo
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

	### name and build image in SOURCE_DIR and tag builded image
	### use no cache, we want all to be fresh when deploying
	docker build -t $NEW_IMAGE_NAME -f "$DOC_DOCKERFILE_PROD" --no-cache . >&2 &&
	#docker tag "$NEW_IMAGE_NAME" "$DOC_REPO/$NEW_IMAGE_NAME" >&2

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
	if [ ! -f ${DOCKER_COMPOSE_FILE} ]; then
		errout "configuration file docker-compose.yml not found in current dir"
	fi
	if [ ! -f ${DOCKER_COMPOSE_CRED_FILE} ]; then
		warnout "configuration file ${DOCKER_COMPOSE_CRED_FILE} not found in current dir"
	fi
}

initEnvironment() {
	for allowedEnv in ${DOC_ALLOWED_ENV}; do
		if [ "$1" == ${allowedEnv} ]; then
			ENVIRONMENT=$1
			break
		fi
	done

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
	dockerComposeCmd build --force-rm $@
}

dockerup() {
	initEnvironment "$1"
	if [ "$IS_DEFAULT_ENVIRONMENT" -eq 0 ]; then
		shift;
	fi
	checkIfComposeFilesExistByEnvironment "$ENVIRONMENT"

	dockerComposeCmd up -d $@
}

dockerdown() {
	initEnvironment "$1"
	if [ "$IS_DEFAULT_ENVIRONMENT" -eq 0 ]; then
		shift;
	fi
	checkIfComposeFilesExistByEnvironment "$ENVIRONMENT"

	out "Stopping and remove all containers for $ENVIRONMENT"
	dockerComposeCmd down $@
}

dockerstop() {
	initEnvironment "$1"
	if [ "$IS_DEFAULT_ENVIRONMENT" -eq 0 ]; then
		shift;
	fi
	checkIfComposeFilesExistByEnvironment "$ENVIRONMENT"
	dockerComposeCmd stop $@
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
	dockerComposeCmd ps $@
}

dockerip() {
	CONTAINER_ID="$1"
	echo $(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' ${CONTAINER_ID})
}

conteinerstatus() {
	CONTAINER_ID="$1"
	echo $(docker inspect -f '{{ .State.Status}}' ${CONTAINER_ID})
}

conteinername() {
	CONTAINER_ID="$1"
	echo $(docker inspect -f '{{ .Name}}' ${CONTAINER_ID})
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
	dockerComposeCmd logs -f $@
}

##
# shows status information about a container
##
dockerstatus() {
	DOC_SERVICE="${1:-web}"

	source "$DOC_SETTINGS"
	initsettings ${DOC_PROJECT_NAME}

	LOCAL_CONTAINER=$(dockerps local -q ${DOC_SERVICE})
	CONTAINER_NAME=$(conteinername ${LOCAL_CONTAINER})
	WEB_IP=$(dockerip ${LOCAL_CONTAINER})
	STATE=$(conteinerstatus ${LOCAL_CONTAINER})
	info "name: $CONTAINER_NAME"
	info "id: $LOCAL_CONTAINER"
	info "status: $STATE"
	info "IP: $WEB_IP"
	info "ports: $(containerports ${LOCAL_CONTAINER})"

	URL=$(docker inspect -f '{{range $index, $value := .Config.Env}}{{if eq (index (split $value "=") 0) "VIRTUAL_HOST" }}{{range $i, $part := (split $value "=")}}{{if gt $i 1}}{{print "="}}{{end}}{{if gt $i 0}}{{print $part}}{{end}}{{end}}{{end}}{{end}}' ${LOCAL_CONTAINER})
	info "URL: http://$URL"
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
	dockerComposeCmd exec --user "$HOST_USER" "$SERVICE" bash
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

	### execute command with or without user privileges
	if (( withUserPriv == 1 )); then
		dockerComposeCmd exec --user "$HOST_USER" "$SERVICE" $@
	else
		dockerComposeCmd exec "$SERVICE" $@
	fi
}

##
# executes a docker-compose command
# including the -p argument with the enviroment,
# and the -f argument with all the docker-compose.yml files.
# Example:
#     'doc cmd pause'
#     'doc cmd prod logs web | grep ERR'
##
dockercmd() {
	initEnvironment "$1"
	if [ "$IS_DEFAULT_ENVIRONMENT" -eq 0 ]; then
		shift;
	fi

	checkIfComposeFilesExistByEnvironment "$ENVIRONMENT"
	dockerComposeCmd $@
}

initproject() {
	### only for backward compatibility START
	if [ -z "$1" ]; then
		DOC_PROJECT_NAME=$1
		GIT_REPO=$2
	fi
	### only for backward compatibility START

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
	if [ -d "./template" ]; then
		info "copy template files"
		initConfigurationFiles
	fi

	### initialize all deps before start building
	if [ -f "scripts/init.sh" ]; then
		info "run init.sh"
		scripts/init.sh
		if [ $? -ne 0 ]; then
	        	echo "run scripts/init.sh failed: $?"
	        	exit;
	    	fi
	fi

	### initialize all deps before start building
	if [ -f "web/scripts/init.sh" ]; then
		info "run init.sh"
		web/scripts/init.sh

		if [ $? -ne 0 ]; then
	        	echo "run web/scripts/init.sh failed: $?"
	        	exit;
	    	fi
	fi

	initEnvironment "$3"

	info "start building project"
	dockerup $ENVIRONMENT &&
		info "===========\n$DOC_FULL_NAME was built successfully\n\n"

	if [ -n ${NGINX_CONTAINER} ]; then
		WEB_IP=$(dockerip "$NGINX_CONTAINER")
	else
		WEB_IP=$(dockerip "${DOC_PROJECT_NAME}_web_local")
	fi
	out "please add the ip '$WEB_IP' for your domain '$DOC_PROJECT_NAME.$DOC_LOCAL_DOMAIN' to your /etc/hosts or use dnsmasq."
}

initsettings() {
	if [ ! -f "$DOC_SETTINGS" ]; then
		touch "$DOC_SETTINGS"
	fi
	source "$DOC_SETTINGS"
	
	if [ ! -z "$1" ]; then
		DOC_PROJECT_NAME="$1"
	fi

	if [ -z "$DOC_USERNAME" ]; then
		while [ -z "$DOC_USERNAME" ]; do
			ask "user / company name? (dmk)"
			read DOC_USERNAME
		done

		ask "docker regestry server (repo.domain.de:5000)?"
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

	if [ -z "$HOST_USERID" ]; then
		while [ -z "$HOST_USERID" ]; do
			ask "your user id? ($(id -u))"
			read HOST_USERID
		done
		HOST_USER="docker"
		if [ ${HOST_USERID} -le 0  ]; then
			errout "user $HOST_USER does not exists"
		fi
		echo "HOST_USER=\"$HOST_USER\"" >> "$DOC_SETTINGS"
		echo "HOST_USERID=$HOST_USERID" >> "$DOC_SETTINGS"
	fi

	if [ -z "$HOST_GROUPID" ]; then
		while [ -z "$HOST_GROUPID" ]; do
			ask "your group id? ($(id -g))"
			read HOST_GROUPID
		done
		HOST_GROUP="docker"
		if [ ${HOST_GROUPID} -le 0 ]; then
			errout "user $HOST_GROUP does not exists"
		fi
		echo "HOST_GROUP=\"$HOST_GROUP\"" >> "$DOC_SETTINGS"
		echo "HOST_GROUPID=$HOST_GROUPID" >> "$DOC_SETTINGS"
	fi

	source "$DOC_SETTINGS"
	export DOC_SETTINGS
}

### deprecated, only for old template structure
replaceMarkerInFiles() {
	for file in $1; do
		if [ -w "$file" ]; then
			sed -i "s|###projectname###|$DOC_PROJECT_NAME|g" "$file"
			sed -i "s|###username###|$DOC_USERNAME|g" "$file"
			sed -i "s|###repohost###|$DOC_REPO|g" "$file"
			sed -i "s|###ssh_auth_sock###|$SSH_AUTH_SOCK|g" "$file"
			sed -i "s|###hostuser###|$HOST_USER|g" "$file"
			sed -i "s|###hostuserid###|$HOST_USERID|g" "$file"
			sed -i "s|###hostgroup###|$HOST_GROUP|g" "$file"
			sed -i "s|###hostgroupid###|$HOST_GROUPID|g" "$file"
		else
			errout "file ${file} does not exist or is not writable"
		fi
	done
}

### deprecated, only for old template structure
initConfigurationFiles() {
	cp ./template/docker-compose* .
	cp ./template/Dockerfile* dockerfiles/
	cp ./template/apache-vhost* ${DOC_VHOST_CONFIG_FOLDER}/

	### wir können im for loop nicht mit einmal mehrere Ordner mit Wildcard durchgehen
	replaceMarkerInFiles "./docker-compose*"
	replaceMarkerInFiles "$DOC_DOCKERFILE_FOLDER/Dockerfile*"
	replaceMarkerInFiles "$DOC_VHOST_CONFIG_FOLDER/apache-vhost*"
}

##
# Execute a docker compose command with the given environment, config files and credentials.
##
dockerComposeCmd() {
	DC_CMD="'$DOCKER_COMPOSE_CMD'"
	### check winpty usage. on newer windows docker versions the winpty is only needet for some commands like exec bash
	if [[ "$@" =~ (^exec.*bash$) ]] && [ "$WINPTY_CMD" ] && [ ! -n "${DOC_USE_WINPTY+set}" ] ; then
		DC_CMD="$WINPTY_CMD $DOCKER_COMPOSE_CMD"
	fi
	### build the command with enviroment and docker-compose.yml files
	DC_CMD="${DC_CMD} -p ${DOC_PROJECT_NAME}_${ENVIRONMENT} -f ${DOCKER_COMPOSE_FILE} -f docker-compose.${ENVIRONMENT}.yml"
	### add optionaly credential yml file
	if [ -f ${DOCKER_COMPOSE_CRED_FILE} ]; then
		DC_CMD="${DC_CMD} -f ${DOCKER_COMPOSE_CRED_FILE}"
	fi
	
	
	### optionaly print out the command, if the enviroment variable DOC_DEBUG_CMD="1" was set.
	if [ -n "${DOC_DEBUG_CMD+set}" ]; then
		echo
		echo "${DC_CMD}" $@
		echo
	fi
	
	### finaly execute the command
	eval "${DC_CMD}" $@
}


### Helper Methods
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
	"do") ;&
	"cmd") shift; dockercmd $@ ;;
	"build") out "building image"; shift; dockerbuild $@ ;;
	"tag") out "build and tag"; buildandtag $2 $(get_current_version $2) ;;
	"up") out "docker up"; dockerup "$2" ;;
	"down") out "docker down"; shift; dockerdown $@ ;;
	"stop") out "docker stop"; shift; dockerstop $@ ;;
	"status") out "container status:"; shift; dockerstatus $@ ;;
	"restart") out "docker restart"; shift; dockerstop $@ && dockerup $@ ;;
	"rebuild") out "docker rebuild"; shift; dockerdown --rmi all && dockerup --build ;;
	"status") out "container status:"; shift; dockerstatus ;;
	"ps") shift; dockerps $@ ;;
	"exec") shift; dockerexec -u "$@" ;;
	"suexec") shift; dockerexec "$@" ;;
	"in") shift; out "starting bash..."; dockerin $@ ;;
	"deploy") out "starting deployment"; dockerdeploy "$2" "$3" ;;
	"init") ;&
	"initproject") shift; initproject $@ ;;
	"logs") shift; dockerlogs $@ ;;
	"reinit") shift; out "reinit all Dockerfiles"; initsettings $@ && initConfigurationFiles ;;
	"self-update") self_update ;;
	*)   out "Unknown parameter"; showhelp; ;;
esac
