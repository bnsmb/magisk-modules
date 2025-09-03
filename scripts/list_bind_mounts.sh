# no shebang necessary - without it the script can be used on Android and Linux
#!/system/bin/sh

# list_bind_mounts.sh - list bind mounts
#
# Usage: 
#
# list_bind_mounts.sh [file1...[file#]]
#
# Without a parameter the script checks all mounts for bind mounts.
#
# Returncodes
#
# Returncode          Meaning
#    0                 all files checked are bind mounted
#    1                 one or more files checked are not bind mounted
#    2                 one or more unexpected errors occured
#
# All info and error messages are written to STDERR
#
# The script works in the Android OS and also in Linux
#
# History
#
#  29.07.2024 v1.0.0 /bs
#   initial release
#
#  01.08.2024 v1.1.0 /bs
#   use /sdcard/Download for temporary files if /tmp is not available
#
#  15.06.2025 v1.2.0 /bs
#   the script now resolves symbolic links
#
#  14.07.2025 v1.3.0 /bs
#   the code to detect symbolic links only worked for absoulte filenames -- fixed
#   the script now ignores bind mount with source = target 
#   the name of the temporary file used is now list_bind_mounts.sh.tmp
#

__TRUE=0
__FALSE=1

THISRC=${__TRUE}


TMPFILE_NAME="${0##*/}.tmp"

if [ -d /tmp ] ; then
  TMPFILE="/tmp/${TMPFILE_NAME}"
else  
  TMPFILE="/sdcard/Download/${TMPFILE_NAME}"
fi

if [ "$1"x = "-h"x -o "$1"x = "-h"x ] ; then
  echo "Usage: $0 [file1...[file#]] "
  exit 1
fi

function cleanup {

  LogInfo "cleanup running"
  trap "" 0   
  [ -r "${TMPFILE}" ] && \rm -f "${TMPFILE}"

  exit
}

trap "cleanup"  0

function LogMsg {
  echo "$@"
}

function LogInfo {
  [[ ${VERBOSE} = ${__TRUE} ]] && echo "$@" >&2
}

# ---------------------------------------------------------------------
# aliase
#
alias LogInfoVar='f() { [[ ${__FUNCTION} = "" ]] && __FUNCTION=main ; [[ ${VERBOSE} != 0 ]] && return; varname="$1"; eval "echo \"INFO: in $__FUNCTION:  $varname ist \${$varname}\" >&2"; unset -f f; } ;  f'


# get the list of current bind mounts 
#
MOUNTINFO="$( cat /proc/self/mountinfo  | grep -E -v " 0:| / "   | awk '$4 != "/" && $4 != $5  {printf("%s %s %s ####\n",$3, $4,$5)}'  )"
NO_OF_MOUNTS_TO_CHECK=$( echo "${MOUNTINFO}" | wc -l )

if [ $# -ne 0 ] ; then
  FILES_TO_CHECK="$*"
  NO_OF_FILES_TO_CHECK=$( echo "${FILES_TO_CHECK}" | tr "\t" " " | tr -s " " | tr " " "\n" | wc -l )

  IGNORE_NON_BIND_MOUNTS=${__FALSE}
  LOOP_MSG=""
else
  FILES_TO_CHECK=$( echo "${MOUNTINFO}" | awk '{ print $3 }' )
  NO_OF_FILES_TO_CHECK=$( echo "${FILES_TO_CHECK}" | wc -l )

  IGNORE_NON_BIND_MOUNTS=${__TRUE}

  echo "# ${NO_OF_MOUNTS_TO_CHECK} mounts to check found" >&2

  LOOP_MSG='printf "%s\r" "$i of ${NO_OF_FILES_TO_CHECK}"'
fi


i=0

BINDS_ALREADY_PROCESSED=" "

NO_OF_BIND_MOUNTS_FOUND=0
LogMsg "# Checking ${NO_OF_FILES_TO_CHECK} mount entries ..." >&2

for CUR_FILE in ${FILES_TO_CHECK} ; do
  let  i=i+1
  
  eval ${LOOP_MSG} >&2

  [[ ${BINDS_ALREADY_PROCESSED} == *\ ${CUR_FILE}\ * ]] && continue
  BINDS_ALREADY_PROCESSED="${BINDS_ALREADY_PROCESSED} ${CUR_FILE} "
  
  LogInfo
  LogInfo "Processing \"${CUR_FILE}\" ..."

  CUR_OUTPUT="$( readlink -f "${CUR_FILE}" )"
  if [ -L "${CUR_FILE}" ] ; then
    LogMsg "\"${CUR_FILE}\" is a symbolic link to ${CUR_OUTPUT} -- Now using the target for the symbolic link \"${CUR_OUTPUT}\" "
    CUR_FILE="${CUR_OUTPUT}"
  fi
    
  CUR_OUTPUT="$( echo "${MOUNTINFO}" | grep  -F " ${CUR_FILE} ####" )"
  if [ $? -eq 2 ] ; then
    LogInfo "# Error using \"${CUR_FILE}\" as parameter for grep:" 
    LogInfo "${CUR_OUTPUT}" 
    THISRC=2
    continue
  else
    LogInfo "Found this entry: \"${CUR_OUTPUT}\" "
  fi
   
  if [ "${CUR_OUTPUT}"x = ""x ] ; then
    if [ ${IGNORE_NON_BIND_MOUNTS} = ${__FALSE} ] ; then
      LogInfo "${CUR_FILE} is not bind mounted" 
      THISRC=1
    fi
    continue
  else
    NO_OF_MOUNTS=$( echo "${CUR_OUTPUT}"  | wc -l )
    
    echo "${CUR_OUTPUT}" >"${TMPFILE}"
    
    while read CUR_LINE ; do

      [[ ${VERBOSE} = ${__TRUE} ]] && set -x

      MAJOR_MINOR="$( echo "${CUR_LINE}" | cut -f1 -d " " )"
      MOUNT_SOURCE="$( echo "${CUR_LINE}" | cut -f2 -d " " )"
      MOUNT_TARGET="$( echo "${CUR_LINE}" | cut -f3 -d " " )"

      LogInfoVar MAJOR_MINOR
      LogInfoVar MOUNT_SOURCE
      LogInfoVar MOUNT_TARGET
      
      [[ ${VERBOSE} = ${__TRUE} ]] && set +x
    
      [ "${MOUNT_TARGET}"x = "/"x ] && MOUNT_TARGET=""
 
      eval MOUNT_SRC_ROOT_DEV="\$DEV_${MAJOR_MINOR%:*}_${MAJOR_MINOR#*:}"
      
      LogInfoVar MOUNT_SRC_ROOT_DEV
  
      if [ "${MOUNT_SRC_ROOT_DEV}"x = ""x ] ; then
        MOUNT_SRC_ROOT_DEV="$( mount | grep   "/dev/block/$( ls -ld /sys/dev/block/${MAJOR_MINOR} | awk -F/ '{ print $NF}'|  tail -1 | awk '{ print $NF}' )" | head -1 | awk '{ print $3}' )"

        eval DEV_${MAJOR_MINOR%:*}_${MAJOR_MINOR#*:}="\${MOUNT_SRC_ROOT_DEV}"
      fi

      LogInfoVar MOUNT_SRC_ROOT_DEV

      if [ "${MOUNT_TARGET}"x !=  "${MOUNT_SRC_ROOT_DEV}${MOUNT_SOURCE}"x  ] ; then
      
        LogInfo "MOUNT_SRC_ROOT_DEV is ${MOUNT_SRC_ROOT_DEV}" 

        let NO_OF_BIND_MOUNTS_FOUND=NO_OF_BIND_MOUNTS_FOUND+1
  
        LogMsg "$( printf "%-20s -> %-20s\n"  "${MOUNT_TARGET}" "${MOUNT_SRC_ROOT_DEV}${MOUNT_SOURCE}" )"        
      fi
      
    done <"${TMPFILE}"
  fi
done

if [ ${IGNORE_NON_BIND_MOUNTS} = ${__TRUE} ] ; then
  echo ""
  echo "# ${NO_OF_BIND_MOUNTS_FOUND} bind mount(s) found" 
  echo ""
fi

exit ${THISRC}

