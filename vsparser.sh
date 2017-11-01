#!/bin/bash

#
#	vsparser
#
#	parses visual studio file
#

declare -A ABPARAMMATCH=(
	["MinimalRebuild"]="/Gm- /Gm"
	["Optimization"]="/Od /O1 /O2"
	["BasicRuntimeChecks"]="/RTC1"
	["PrecompiledHeaderOutputFile"]=" "
	["RuntimeLibrary"]=" "
	["WarningLevel"]="/W0 /W1 /W2 /W3 /W4 /Wall"
	["DebugInformationFormat"]="/Z7 /Zi /ZI"
	["CompileAs"]="/TC /TP"
	["BufferSecurityCheck"]="/GS- /GS"
	["EnableEnhancedInstructionSet"]="/arch:IA32 /arch:SSE /arch:SSE2 /arch:AVX /arch:AVX2"
	["OmitDefaultLibName"]=" "
	["InlineFunctionExpansion"]=" "
)

declare -A ABVALTOIDX=(
	["false"]=0
	["disabled"]=0
	["default"]=0
	["enablefastchecks"]=0
	["true"]=1
	["level0"]=0
	["level1"]=1
	["level2"]=2
	["level3"]=3
	["level4"]=4
	["programdatabase"]=1
	["streamingsimdextensions"]=1
	["streamingsimdextensions2"]=2
	["advancedvectorextensions"]=3
	["advancedvectorextensions2"]=4
)

declare -A ABDefaultCompilerOptions=(
	["/WX"]="/WX-"
	["/W"]="/W1"
	["/EH"]="/EHsc"
)
if [ $ABDEBUG == 1 ]; then
	ABDefaultCompilerOptions["/Oy"]="/Oy-"
	ABDefaultCompilerOptions["/O"]="/Od"
	ABDefaultCompilerOptions["/GS"]="/GS"
	ABDefaultCompilerOptions["/Gm"]="/Gm"
	ABDefaultCompilerOptions["/Z"]="/Zi"
else
	ABDefaultCompilerOptions["/O"]="/O2"
	ABDefaultCompilerOptions["/GS"]="/GS-"
	ABDefaultCompilerOptions["/Gm"]="/Gm-"
fi

local ABConfigSrch=""
[ $ABDEBUG == 1 ] && ABConfigSrch="debug" || ABConfigSrch="release"
[ "$ABARCH" == "x86" ] && ABConfigSrch="$ABConfigSrch|win32" || ABConfigSrch="$ABConfigSrch|x64"

ABParse() {
	local DEFFLAG=0
	local FILEFLAG=0
	local COMPILEFLAG=0
	local LIBFLAG=0
	local LINKFLAG=0
	local CUSTOMBUILDFLAG=0
	local CONFIG=""
	local CUSTOMCOMMAND=""
	local CUSTOMOUTPUT=""
	
	while IFS== read -r line ; do
		local tag=${line#*<}
		tag=${tag%%>*}
		
		local tagKey=${tag%% *}
		
		if [ $DEFFLAG -eq 1 ]; then
			if [ $COMPILEFLAG == 1 ]; then
				#parse all the build definitions
				local value=${line#*>}
				
				if [[ $line == *"PreprocessorDefinitions"* ]]; then
					value=${value%;\%*}
					ABPREPROCDEF="$ABPREPROCDEF /D ${value//;/ /D }"
				else
					local key=$tag
					local value=${line#*>}
					
					value=${value%<*}
					value=$(trim ${value//[$'\t\r\n']})
					
					if [ ${#value} == 0 ]; then
						if [ "${key: -1}" == "/" ]; then continue
						elif [ "$key" == "/ClCompile" ]; then
							COMPILEFLAG=0
						else
							echo "def: $key"
						fi
					elif [ "$key" == "AdditionalOptions" ]; then
						value=${value%\%*}
						ABCOMPILEOPTS="$ABCOMPILEOPTS $value"
					elif [ "$key" == "AdditionalIncludeDirectories" ]; then
						value=${value%;\%*}
						ABINCLUDEDIRS="$ABINCLUDEDIRS ${value//;/ }"
					elif [ "$key" == "AdditionalUsingDirectories" ]; then
						continue
					elif [ "$key" == "DisableSpecificWarnings" ]; then
						value=${value%;\%*}
						ABCOMPILEOPTS="$ABCOMPILEOPTS /wd${value//;/ /wd}"
					elif [ "$key" == "CompileAs" ] && [ "$value" == "Default" ]; then
						continue
					elif [ "$key" == "EnableEnhancedInstructionSet" ] && [ "$value" == "Not Set" ]; then
						continue
					else
						value=${value,,}
						if [ $COMPILEFLAG == 1 ] && [ ${ABPARAMMATCH[$key]+abc} ] && [ ${ABVALTOIDX[$value]+abc} ]; then
							local paramArray=${ABPARAMMATCH[$key]}
							read -r -a paramArray <<< ${paramArray}
							ABCOMPILEOPTS="$ABCOMPILEOPTS ${paramArray[${ABVALTOIDX[$value]}]}"
						else
							if [ $COMPILEFLAG == 0 ]; then echo "def: $key: ${value}"
							elif [ ! ${ABPARAMMATCH[$key]+abc} ]; then echo "Unknown option $key : $value"
							fi
						fi
					fi
				fi
			elif [[ $line == *"ItemDefinitionGroup"* ]]; then
				DEFFLAG=0
			elif [[ $line == *"ClCompile"* ]]; then
				if [[ $line == *"/ClCompile"* ]]; then
					COMPILEFLAG=0
				else COMPILEFLAG=1
				fi
			elif [ $ABSTATIC == 1 ] && [[ $line == *"Lib"* ]]; then
				LIBFLAG=1
			elif [ $ABSTATIC == 0 ] && [[ $line == *"Link"* ]]; then
				LINKFLAG=1
			fi
		elif [ $FILEFLAG -eq 1 ]; then
			#parse relevant files
			if [[ $line == *"ClCompile"* ]]; then
				local file=${line#*\"}
				ABSRCS="$ABSRCS ${file%\"*}"
			elif [[ $line == *"MASM"* ]]; then
				if [[ $line == *"/MASM"* ]]; then continue; fi
				local file=${line#*\"}
				ABASMSRCS="$ABASMSRCS ${file%\"*}"
			elif [[ $line == *"ExcludedFromBuild"* ]]; then continue
			elif [[ "$tagKey" == "CustomBuild" ]]; then
				FILEFLAG=0;
				CUSTOMBUILDFLAG=1;
			else
				FILEFLAG=0;
			fi
		elif [ $CUSTOMBUILDFLAG == 1 ]; then
			if [[ "$tagKey" == "/CustomBuild" ]]; then
				#fix paths
				for output in $CUSTOMOUTPUT; do
					local newPath="${ABINTPATH}$(basename $output)"
					CUSTOMCOMMAND=${CUSTOMCOMMAND/$output/$newPath}
				done
				ABCUSTOMCOMMAND="$ABCUSTOMCOMMAND && $CUSTOMCOMMAND"
			
				CUSTOMBUILDFLAG=0;
				FILEFLAG=1;
			elif [[ $line == *"$CONFIG"* ]]; then
				if [[ $line == *"Command"* ]]; then
					local value=${line#*>}
					CUSTOMCOMMAND="${value%<*}"
				elif [[ $line == *"Outputs"* ]]; then
					local value=${line#*>}
					value="${value%\%*}"
					CUSTOMOUTPUT="${value//;/ }"
				elif [[ $line == *"ExcludedFromBuild"* ]]; then
					CUSTOMCOMMAND=""
					CUSTOMOUTPUT=""
				fi
			fi
		elif [[ $line == *"ProjectConfiguration"* ]]; then
			if [[ $line == *"</ProjectConfiguration>"* ]]; then continue; fi
		
			#read the existing project configurations, pick the most appropriate
			local config=${line#*\"}
			config=${config%\"*}
			local comparison=${config,,}
				
			if [[ $comparison == *"$ABConfigSrch"* ]]; then
				if [[ ${CONFIG,,} == *"asm"* ]]; then continue; fi
			
				if [[ $comparison == *"lib"* ]]; then
					if [ $ABSTATIC == 1 ]; then
						CONFIG=$config
					fi
				elif [[ $comparison == *"dll"* ]]; then
					if [ $ABSTATIC == 0 ]; then
						CONFIG=$config
					fi
				else
					CONFIG=$config
				fi
			fi
		elif [[ $line == *"ItemDefinitionGroup"* ]]; then
			#check if this is the build options we are looking for
			
			if [[ $line == *"/ItemDefinitionGroup"* ]]; then
				continue
			elif [[ ! $line == *"Condition"* ]] || [[ $line == *"$CONFIG"* ]]; then
				DEFFLAG=1;
			fi
		elif [[ $line == *"ItemGroup"* ]]; then
			#this is the file definition group
			
			if [[ $line == *"/ItemGroup"* ]]; then continue; fi
			
			FILEFLAG=1;
		fi
	done < $1
	
	#finalize
	if [ -n "$ABCUSTOMCOMMAND" ]; then
		ABCUSTOMCOMMAND=${ABCUSTOMCOMMAND:3}
	fi
	
	#set default compile options
	for key in "${!ABDefaultCompilerOptions[@]}"; do
		if [[ ! "$ABCOMPILEOPTS" == *"$key"* ]]; then
			ABCOMPILEOPTS="$ABCOMPILEOPTS ${ABDefaultCompilerOptions[$key]}"
		fi
	done
}