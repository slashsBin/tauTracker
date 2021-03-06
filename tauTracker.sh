#!/bin/bash

#
# τacker
# 
# Simple TimeTracking
#
# Tested on Debian Wheezy 7 and Bash 4.2.x, but should work with Bash 4.0+
#

appName="τracker(TauTracker)"
appVersion="0.1"

# App Options
action="track"
tag=`basename $0`
verbose=0
declare -A flows

# App Info
function appInfo
{
	echo "$appName v$appVersion"
	echo
}

# App Usage
function appUsage
{
	cat <<-USAGE
		Usage:
			`basename $0` <action> --tag MyTask --file ~/myRoll.log -vv

		Actions:
			track		Write Track Information to Log file[Default Action](Flag 2)
			parse		Read & Parse Track Information from Log file(Flag 4)

		Options:
			-t|--tag		Tracking Tag, Case-InSensitive[Default: ScriptName]
			-f|--flow		Coma-Separated List of Tracking Time-Flows, Case-InSensitive[Default: ScriptName~ScriptName]
			-F|--file		Tracker Log File[Default: ./tauTracker.log]
			

			-v|--verbose		Be Verbose or Even more Verbose with -vv
			   --list-config	List Application Effective Configuration
			   --list-flows		List Available Time Flows
			-h|--help		Prints this Message & Exits
			-V|--version		Print Application Version Info

		NOTE: If Options or Arguments are used Multiple times, the Last One is Effective
	USAGE
}

# Default Config Options
# Options which begin with tauTracker are modifiable from outside
function declareDefaults
{
	# External
	tauTrackerLog="./tauTracker.log"
	tauTrackerFlows="${tag^^}~${tag^^}"

	# Internal
	trackDTFormat="%A %B %_d, %Y, %T %p"
}

# Load config files:
#     /etc/tauTracker/tauTracker.config
#     ~/.tauTracker.config
#     ./.tauTracker.config
function loadConfig
{
	[ $verbose -gt 0 ] && echo "Load Configuration file"

	local configFileName="tauTracker.config"
	local configFile="/etc/tauTracker/"$configFileName
	[ -r $configFile ] && . "$configFile"
	local configFile="~/."$configFileName
	[ -r $configFile ] && . "$configFile"
	local configFile="./."$configFileName
	[ -r $configFile ] && . "$configFile"
}

# Prepare the Tag
function prepareTag
{
	tag=${tag^^}
}

# List Config Options
function listConfig
{
	echo "List Config Options:"

	set | grep -E "^tauTracker"
	echo
}

# Track
function track
{
	echo "Tracking $tag"
	msg="[$tag][`date --rfc-3339=ns`]: "`date +"${trackDTFormat}"`
	[ $verbose -gt 0 ] && echo -e $msg
	echo $msg >> $tauTrackerLog
}

function prepareFlows
{
	echo "Prepare Flows ..."

	__tauTrackerFlows=(${tauTrackerFlows//,/ })
	for fIndex in $(seq 0 $((${#__tauTrackerFlows[@]} - 1)))
	do
		__flow=${__tauTrackerFlows[$fIndex]}
		__fFrom=${__flow%%~*}
		__fFrom=${__fFrom^^}
		__fTo=${__flow##*~}
		__fTo=${__fTo^^}
		flows[$__fFrom]=$__fTo
	done
}

function listTimeFlows
{
	echo "TimeFlows are:"

	for flowKey in ${!flows[@]}
	do
		echo "TimeFlow From '$flowKey' To '${flows[$flowKey]}'"
	done
}

# Parse
function parse
{
	echo "Parsing ..."

	# Prepare Calculation Temp
	# Total amount of Parsing Item in Seconds
	declare -A __total
	# Previous Dates Temp
	declare -A __prev
	for flowKey in ${!flows[@]}
	do
		__prev[$flowKey]=""
		__total[$flowKey]=0
	done

	[ $verbose -gt 1 ] && listTimeFlows

	# Read & Parse Log File
	while read line
	do
		[ $verbose -gt 1 ] && echo "Parsing Log: $line"

		# Parse Log Line
		__pTag=${line:1}
		__pTag=${__pTag%%]*}
		__pDate=${line##*[}
		__pDate=${__pDate%%]*}

		# Locate Tag in Flows
		__locFound=0
		for __fK in ${!flows[@]}
		do
			__fV=${flows[$__fK]}
			if [[ $__fV == $__pTag ]]
			then
				# Locate Tag in FlowTo Tags
				__locFound=1
				break
			elif [[ $__fK == $__pTag ]]
			then
				# Locate Tag in FlowFrom Tags
				__locFound=2
				break
			fi
		done
		# UnMatched Flow
		if [[ $__locFound -eq 0 ]]
		then
				[ $verbose -gt 1 ] && echo "UnMatched Flow, Ignoring..." && echo
				continue
		fi

		# FlowTo Tags
		if [[ $__locFound -eq 1 ]] && [[ ! -z "${__prev[$__fK]}" ]]
		then
			[ $verbose -gt 1 ] && echo "Flow from $__fK To $__fV Ended @$__pDate"
			#if [[ -z "${__prev[$__fK]}" ]]
			#then
			#	[ $verbose -gt 1 ] && echo "Ignoring..."
			#else
				__t=$(( $(date -d"$__pDate" +%s) - $(date -d"${__prev[$__fK]}" +%s) ))
				[ $verbose -gt 1 ] && echo "Due:$__t Seconds"
				__total[$__fK]=$((${__total[$__fK]} + $__t))
				__prev[$__fK]=""
			#fi
		# FlowFrom Tags
		elif [[ $__locFound -eq 2 ]] || [[ -z "${__prev[$__fK]}" ]]
		then
			[[ ! -z "$__prev[$__fK]" ]] && [ $verbose -gt 1 ] && echo "OverWrite Previous Start Event:"
			[ $verbose -gt 1 ] && echo "Flow from $__fK To $__fV Started @$__pDate"
			__prev[$__fK]=$__pDate
		fi
		[ $verbose -gt 1 ] && echo
	done < $tauTrackerLog
	echo "Finished" && echo

	# Summary
	echo "Summary"
	for __sK in ${!flows[@]}
	do
		# Seconds
		__sS=${__total[$__sK]}
		# Minutes
		__sM=$(( $__sS / 60 ))
		# Hours
		__sH=$(( $__sM / 60 ))
		# Days
		__sD=$(( $__sH / 24 ))
		echo -e "Flow $__sK ~ ${flows[$__sK]}: \t$__sS Seconds | $__sM Minutes | $__sH Hours | $__sD Days"
	done

}

# Check to see if Log file is available, if not create it
function checkLogFile
{
	if [[ ! -z $tauTrackerLog ]] && [[ ! -f $tauTrackerLog ]]
	then
		`touch $tauTrackerLog`
	fi
	if [[ ! -e $tauTrackerLog ]]
	then
	    echo "Can NOT find/create Log File!"
	    exit 1
	fi
}

appInfo

declareDefaults
loadConfig

# Process App Options & Arguments
while [ $# -gt 0 ]
do
    case $1 in
	track)			action="track";;
	parse)			action="parse";;
	--list-config)	action="listConfig";;
	--list-flows)	action="listTimeFlows";;
	--tag|-t)		tag=$2
					[ -z $tag ] && echo "Tag Can NOT be Empty" && exit 1
					shift;;
	--flow|-f)		tauTrackerFlows=$2
					[ -z $tauTrackerFlows ] && echo "Time-Flows Can NOT be Empty" && exit 1
					shift;;
	--verbose|-v)	verbose=1;;
	-vv)			verbose=2;;
	--version|-V)	exit 0;;
	--file|-F)		tauTrackerLog=$2; shift;;
	--help|-h|*)	appUsage; exit;;
    esac
    shift
done

# Prepare App
prepareTag
prepareFlows

checkLogFile

# Do the Action
[ $verbose -gt 1 ] && echo "Performing Action: ${action^^}"
$action

exit 0


errors=0
total=''
tH=0
tM=0
prefixStart="STARTED"
prefixEnd="ENDED"

started=""
ended=""
while read line
do
started=${ended}
ended=${line}
if [ "${started}" = "" ] || [ "${ended}" = "" ]
then
    continue
fi

msg='Due: '
sPrefix=${started%%@*}
ePrefix=${ended%%@*}
if [ ${sPrefix} != ${prefixStart} ] || [ ${ePrefix} != ${prefixEnd} ]
then
    let "errors=${errors} + 1"
    continue
fi

if [ ${rollDetail} = on ]
then
    echo ${started}
    echo ${ended}
fi

s=${started##*@}
e=${ended##*@}
sD=$(date +%-d -d "${s}")
sH=$(date +%-H -d "${s}")
sM=$(date +%-M -d "${s}")
eD=$(date +%-d -d "${e}")
eH=$(date +%-H -d "${e}")
eM=$(date +%-M -d "${e}")
let "dH=${eH} - ${sH}"
let "dM=60 - ${sM} + ${eM}"
let "d_M=${dM} % 60"
let "dd_M=${dM} - ${d_M}"
let "dd_M=${dd_M} / 60"
let "dH=${dH} + ${dd_M} - 1"
let "dM=${d_M}"

let "tH=${tH} + ${dH}"
let "tM=${tM} + ${dM}"

dayOfWeek=$(date +%u -d "${s}")
let "dayOfWeek=${dayOfWeek} + 1"
let "dayOfWeek=${dayOfWeek} % 7"
dayOfWeekName=$(date +%A -d "${s}")
if [ ${rollDetail} = on ]
then
    echo "["${dayOfWeek}"] "${dayOfWeekName}
fi

msg=${msg}${dH}":"${dM}
if [ ${rollDetail} = on ]
then
    echo ${msg}
    echo
fi

done < "${logFile}"

let "t_M=${tM} % 60"
let "dt_M=${tM} - ${t_M}"
let "dt_M=${dt_M} / 60"
let "tH=${tH} + ${dt_M}"
let "tM=${t_M}"

total=${tH}":"${tM}

echo '+================+'
echo '| Errors: '${errors}
echo '|'
echo '| Total:  '${total}
echo '+================+'
echo
exit 0
