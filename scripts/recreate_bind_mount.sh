#!/bin/sh
# 
# recreate_bind_mount.sh - recreate bind mounts for files from Magisk Modules
#
#h#
#h# Usage: recreate_bind_mount.sh [/data/adb/<modulename>/system/<filename>] [...]
#h#
#h# The module path can be omitted for the 2nd parameter and the following
#h# If the file to be remounted is only provided by one Magisk module, the module path can also be omitted for the first parameter 
#h#
#h# Without parameter the script reads the list of files from STDIN.
#e#
#e# examples:
#e# 
#e# recreate_bind_mount.sh  /data/adb/modules/clang19/system/usr/clang19/bin/as
#e# 
#e# recreate_bind_mount.sh  /data/adb/modules/clang19/system/usr/clang19/bin/as /system/usr/clang19/bin/clang
#e# 
#
# History
#   06.11.2024 1.0.0 /bs
#    initial release
#

__TRUE=0
__FALSE=1


# for testing
#PREFIX="echo"

CUR_USER="$( id -un )"

[ "${CUR_USER}"x != "root"x ] && PREFIX="su - -c " || PREFIX=""

if [ "$1"x = "-h"x -o "$1"x = "--help"x   ] ; then
  grep -E "^#h#|^#e#" $0 | cut -c4- | sed "s#recreate_bind_mount.sh#$0#g"
  exit 1
fi

CUR_MODULE_PATH=""


if [ $# -eq 0 ] ; then

# check for a redirected STDIN
#
  STDIN="$( ls -l -l /proc/$$/fd/0 )"

  STDIN="$( echo $STDIN | awk '{ print $NF}' )"

  if [ "${STDIN}"x != "/dev/pts/0"x ] ; then
    if [[ "${STDIN}" != /* ]] ; then
      echo "Reading the files to process from STDIN ..."
    else
      echo "Reading the files to process from the file \"$STDIN\" ..."
    fi
    PARAMETER=""
    while read FILE ; do
      PARAMETER="${PARAMETER} ${FILE}"
    done
    set -- ${PARAMETER}
  fi
fi

while [ $# -ne 0 ] ; do
   
   CUR_FILE="$1"
   shift

   echo ""
   
   ERRORS_FOUND=${__FALSE}

   if [[ ${CUR_FILE} == /data/adb/modules/* ]] ; then
     CUR_MODULE_PATH="${CUR_FILE%/system*}"
     echo
     echo "Using the module directory \"${CUR_MODULE_PATH}\" "
     echo 
     
     SOURCE_FILE="${CUR_FILE}"
   else     
     if [ "${CUR_MODULE_PATH}"x = ""x ] ; then

       SOURCE_FILE="$( ${PREFIX} ls /data/adb/modules/*/"${CUR_FILE}" 2>/dev/null )"
       
       [ $? -eq 0 ]  && NO_OF_SOURCE_FILES="$( echo "${SOURCE_FILE}" | wc -l )" || NO_OF_SOURCE_FILES=0

       if [ ${NO_OF_SOURCE_FILES} = 1 ] ; then
         CUR_MODULE_PATH="${SOURCE_FILE%/system*}"
         echo
         echo "Using the module directory \"${CUR_MODULE_PATH}\" "
         echo          
       else
         if [ ${NO_OF_SOURCE_FILES} -gt 1 ] ; then
           echo "ERROR: There are multiple Magisk Modules providing the file \"${CUR_FILE}\" :"
           echo 
           echo "${SOURCE_FILE}"
           echo 
         fi
         SOURCE_FILE=""
       fi

       if [ "${SOURCE_FILE}"x = ""x ] ; then
         echo "ERROR: The first parameter must be a complete path of the file in the Magisk Module"
         grep -E "^#e#" $0 | cut -c4- | sed "s#recreate_bind_mount.sh#$0#g"
         exit 5
       fi
     fi

     [[ ${CUR_FILE} != /* ]] && CUR_FILE="/${CUR_FILE}"

     SOURCE_FILE="${CUR_MODULE_PATH}${CUR_FILE}"
   fi
   TARGET_FILE="/system${CUR_FILE#*system}"
      
   if ! ${PREFIX} test -r "${TARGET_FILE}"  ; then
     echo "ERROR: The file \"${TARGET_FILE}\" does not exist "
     ERRORS_FOUND=${__TRUE}
   fi

   if ! ${PREFIX} test -r "${SOURCE_FILE}" ; then
     echo "ERROR: The file \"${SOURCE_FILE}\" does not exist "
     ERRORS_FOUND=${__TRUE}
   fi
   
   if [ ${ERRORS_FOUND} = ${__FALSE} ] ; then
     echo "Recreating the bind mount ${TARGET_FILE} -> ${SOURCE_FILE} ..."

     ( set -x ; ${PREFIX} umount "${TARGET_FILE}" && ${PREFIX} mount -o bind "${SOURCE_FILE}" "${TARGET_FILE}" )
    if [ $? -ne 0 ] ; then
      echo "ERROR: recreating the bind mount ${TARGET_FILE} -> ${SOURCE_FILE} "
    else
      echo "OK;  succesfully recreated the bind mount ${TARGET_FILE} -> ${SOURCE_FILE}"
    fi
  fi
done
echo

