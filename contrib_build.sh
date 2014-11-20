#!/bin/bash
#
#	contrib-build 
#
#	build a contrib
#

#
#	setupBuild 
#	setup informations needed for the build
#

export COMPILER=""
export LINKER=""
export LINKERDEFOPTS=""

#
#	autobuildReset 
#	reset Build options
#
autobuildReset() {
	CUSTOMBUILD=""
	PROJNAME=""
	FOLDER=""
	LABELNAME=""
	COMPILEOPTS=""
	PREPROCDEF=""
	PCH=""
	PCHSRC=""
	SRCS=""
	LIBOPTS=""
	DLLOPTS=""
	PREBUILDEVENT=""
	BUILDEVENT=""
	POSTBUILDEVENT=""
	CLEANEVENT=""
}

#
#	autobuildCustomSetup 
#	Setup information for custom build
#
autobuildCustomSetup() {
	if [ -z "$VISUALSTUDIOVERSION" ]; then
		echo "You are running this bash script using MSYS but visual studio is missing."
		echo "You must open a \"Visual Studio .NET Command Prompt\" to run this script."
		return 1
	fi
	
	#set the compiler and linker
	COMPILER="cl"
	if [ $STATIC ]; then
		LINKER="lib"
		LINKERDEFOPTS=" /nologo /nodefaultlib"
	else
		LINKER="link"
		LINKERDEFOPTS=" /nologo /DLL"
	fi
}

#
#	autobuildFixAutoPathing
#	Fix an issue with MSYS
#
autobuildFixAutoPathing() {
	PREPROCDEF=" ${PREPROCDEF}"
	COMPILEOPTS=" ${COMPILEOPTS}"
}

#
#	autobuildCustomMSVC 
#	Custom build using msvc
#
autobuildCustomMSVC() {
	if [ ! $COMPILER ]; then autobuildCustomSetup; fi
	
	(
		#pre-build event
		eval $PREBUILDEVENT

		#build event
		eval ${BUILDEVENT}
		
		#post-build event
		eval $POSTBUILDEVENT
	)
}

#
#	autobuildBuild 
#	build function
#
autobuildBuild() {
	if [ $BUILDFAILED ]; then return 0; fi
	
	export LIBNAME="${PROJNAME}.lib"
	export DLLNAME="${PROJNAME}.dll"

	if [ ! $CLEAN ]; then
		if [ $STATIC ] && [ -f "${LIBPATH}${LIBNAME}" ]; then
			echo "Nothing to do for ${LABELNAME}"
		elif [ $STATIC ] && [ -f "${LIBPATH}${LIBNAME}" ] && [ -f "${BINPATH}${DLLNAME}" ]; then
			echo "Nothing to do for ${LABELNAME}"
		else
			if [ "$PLATFORM" = "MSYS" ]; then
				autobuildCustomMSVC
			else
				echo "No compiler tool available for current platform. Aborting..."
				exit 1
			fi
		fi
	else
		eval $CLEANEVENT
	fi
	
	autobuildReset
}

#
#	autobuildPreBuildEvent
#	Events to execute before building
#
autobuildPreBuildEvent()
{
	echo "=== Building ${LABELNAME} ==="
	echo ""
	
	# create intermediate directory
	INTPATH="${INTPATH}${PROJNAME}/"
	mkdir -p "$INTPATH"
	
	autobuildFixAutoPathing
	
	cd ${SCPATH}${FOLDER}
}

#
#	autobuildPostBuildEvent
#	Events to execute after building
#
autobuildPostBuildEvent()
{
	echo ""
	echo "=== Successfully built ${LABELNAME} for ${PLATFORM[1]}/${PLATFORM[2]} ==="
}

#
#	autobuildPostBuildEvent
#	Events to execute after building
#
autobuildCleandEvent()
{
	echo -n "Cleaning ${LABELNAME}... "
	rm -r -f "${INTPATH}${PROJNAME}"
	rm -f "${LIBPATH}${LIBNAME}"
	rm -f "${BINPATH}${DLLNAME}"
	echo "Done"
}

#
#	autobuildDefault 
#	default building switches
#
autobuildCustomBuild() {
	if [ $BUILDFAILED ]; then return 0; fi

	if [ ! $CLEAN ]; then
		COMPILEOPTS="$COMPILEOPTS /fp:precise"
		if [ $DEBUG ]; then
			if [ $STATIC ]; then
				COMPILEOPTS="$COMPILEOPTS /MTd"
			else
				COMPILEOPTS="$COMPILEOPTS /MDd"
			fi
		
			PREPROCDEF="$PREPROCDEF /D _DEBUG /D DEBUG"
		else
			if [ $STATIC ]; then
				COMPILEOPTS="$COMPILEOPTS /MT"
			else
				COMPILEOPTS="$COMPILEOPTS /MD"
			fi
			
			PREPROCDEF="$PREPROCDEF /D NDEBUG"
			LIBOPTS="$LIBOPTS /LTCG"
		fi
		if [ ! $PREBUILDEVENT ]; then PREBUILDEVENT="autobuildPreBuildEvent"; fi
		if [ ! $BUILDEVENT ]; then BUILDEVENT="cmd.exe \/c \"${ABPATH}custom_build.bat\""; fi
		if [ ! $POSTBUILDEVENT ]; then POSTBUILDEVENT="autobuildPostBuildEvent"; fi
	else
		if [ ! $CLEANEVENT ]; then CLEANEVENT="autobuildCleandEvent"; fi
	fi
	
	CUSTOMBUILD=1

	autobuildBuild
}
