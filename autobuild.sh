#!/bin/bash
#
#	AutoBuild 
#
#	Automated build
#

#
#	usage 
#	Display autobuild script usage
#
usage() { 
	echo "Usage: autobuild.sh: [-c] [-d] [-s] LIBSCRIPT BINPATH LIBPATH INTPATH"
}

#
#	errorHandler 
#	Handle build errors
#
errorHandler() {
	echo "*******************************************************"
	echo "*** ${OPERATION} FAILED -- Please check the error messages ***"
	echo "*******************************************************"
	exit 1
}

#
#	relativeToAbsolute 
#	Convert an input path to an absolute one
#
relativeToAbsolute() {
	if [[ "$1" = /* ]]; then echo "$1"; fi
	
	echo "${PWD}/$1"
}

#
#	pathDir
#	return the directory part of the path
#
pathDir() {
	local PATH="${1%/*}/"
	
	# windows special case
	if [ "$PATH" = "$1/" ]; then PATH="${0%\\*}\\"; fi
	
	echo "$PATH"
}

#
#	detectOS
#	return the system running, the os name and the architecture
#
detectOS() {
	MACHINE_TYPE="$(uname -m)"
	if [ ! "${MACHINE_TYPE}" = "x86_64" ]; then
		MACHINE_TYPE="x86"
	fi

	if [[ "$OSTYPE" == "linux-gnu" ]]; then
		echo "LINUX Linux${MACHINE_TYPE}"
	elif [[ "$OSTYPE" == "darwin"* ]]; then
		echo "MACOS MacOS ${MACHINE_TYPE}"
	elif [[ "$OSTYPE" == "cygwin" ]]; then
		echo "CYGWIN WINDOWS ${MACHINE_TYPE}"
	elif [[ "$OSTYPE" == "msys" ]]; then
		echo "MSYS WINDOWS ${MACHINE_TYPE}"
	elif [[ "$OSTYPE" == "win32" ]]; then
		echo "WIN32 WINDOWS ${MACHINE_TYPE}"
	elif [[ "$OSTYPE" == "freebsd"* ]]; then
		echo "FREEBSD FreeBSD ${MACHINE_TYPE}"
	else
		echo "UNKNOWN"
	fi
}

#
#	autoBuild 
#	main Function
#
autoBuild() {
	#
	# autobuild switches
	#
	
	export DEBUG=""
	export STATIC=""
	export CLEAN=""
	
	
	#
	# Check inputs
	#
	local OPTIND=1
	while getopts ":cds" opt; do
	  case $opt in
		c)
		  CLEAN=1
		  ;;
		d)
		  DEBUG=1
		  ;;
		s)
		  STATIC=1
		  ;;
		*)
		  usage
		  exit 1
		  ;;
	  esac
	done
	shift $((OPTIND - 1))
	
	if [ $# -lt 4 ]; then
		echo "Wrong number of arguments."
		usage
		exit 1
	fi
	
	#
	# autobuild parameters
	#
	
	export SCRIPT=$(relativeToAbsolute $1)
	export BINPATH=$(relativeToAbsolute $2)
	export LIBPATH=$(relativeToAbsolute $3)
	export INTPATH=$(relativeToAbsolute $4)
	
	export ABPATH=$(pathDir $0)
	export SCPATH=$(pathDir $SCRIPT)
	export PLATFORM=($(detectOS))
	
	export BUILDFAILED=""
	local OPERATION=""
	if [ $CLEAN ]; then
		OPERATION="Clean"
	else
		OPERATION="Build"
		
		#ensure that output folder have been created
		mkdir -p "$BINPATH"
		mkdir -p "$LIBPATH"
		mkdir -p "$INTPATH"
	fi
	
	#
	# load build tool
	#
	. ${ABPATH}contrib_build.sh
	
	autobuildReset
	
	echo
	echo "*******************************"
	echo "*** ${OPERATION} Operation Started ***"
	echo "*******************************"
	echo

	# build
	. $SCRIPT
	if [ $BUILDFAILED ]; then false; fi

	echo
	echo "*********************************"
	echo "*** ${OPERATION} Operation Completed ***"
	echo "*********************************"
	echo
}

#
# set error handling
#
set -o pipefail  # trace ERR through pipes
set -o errtrace  # trace ERR through 'time command' and other functions
set -o nounset   ## set -u : exit the script if you try to use an uninitialised variable
set -o errexit   ## set -e : exit the script if any statement returns a non-true return value

trap errorHandler ERR

autoBuild $@
