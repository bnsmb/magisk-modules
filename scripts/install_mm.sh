# no shebang because the location for the shell on the PC and the phone are different

# Simple script to install one or more Magisk modules on a phone running the Android OS with installed Magisk
#
# The script can run either on the phone or on a PC with an adb connection to a phone
#
#h#
#h# Usage:
#h#
#h# install_mm.sh [options_for_adb -- ] [--keep] [--force] [--reboot] [--dry-run] [magisk_module1|dir1 ... magisk_module#|dir#]
#h#
#h# Parameter:
#h#
#h#   options_for_adb - options for the adb command; this parameter is only used if running on a PC
#h#
#h#      --keep    - do not delete the ZIP file with the Magisk Module (this parameter is only used if the script is running on a PC)
#h#      --reboot  - reboot the phone after installing all Magisk Modules
#h#      --force   - reboot the phone even if not all Magisk Modules could be installed
#h#      --dry-run - only print the commands to install the Magisk module
#h#
#h# Use the parameter "-h -v" to print the detailed usage help
#h#     
#H# “options_for_adb” are the options for the ‘adb’ command. 
#H# If the parameter for the adb options is missing, the script uses the adb options stored in the environment variable ADB_OPTIONS.
#H# If the environment variable ADB_OPTIONS is empty and there are no script parameters for adb options, adb is executed without options.
#H# The parameter “options_for_adb” overwrites the value of the environment variable ADB_OPTIONS
#H# Use the prefix “+” for “options_for_adb” to add the options to the adb options defined in the environment variable ADB_OPTIONS.
#H# The parameter “--” is mandatory if adb options are specified in the parameter.
#H# The options for adb are optional; the script does not check the options for adb. 
#H# The specification of “options_for_adb” is not permitted if the script is executed in a shell on the phone.
#H# 
#H# "magisk_module#" is the name of a zip file with a Magisk Module to install; "dir#" is a directory tree with files with Magisk Mdodules.
#H# If "dir#" is used, the script installs all files with the extension .zip from that directory tree.
#H#
#H# The number of zip files or directories is only limited by the maxium parameter supported by the used shell.
#H#
#H# When running on the PC, the zip files are copied into the directory /sdcard/Download on the phone; to change that directory, set the environment variable TARGET_DIR before executing the script. 
#H# 
#H# The script deletes the zip file on the phone after successfully installing a Magisk Module when running on a PC; use the parameter "--keep" to keep the zip file on the phone.
#H#
#H# Set the environment variable PREFIX to the prefix for the commands to install the Magisk Modules. Example: The parameter "--dry-run" sets the variable PREFIX to "echo" to only print the commmands
#H#
#H# To use adb via WLAN enable adb via WiFi on the phone, start the adb for WLAN on the PC, example:
#H# 
#H#   adb -e -L tcp:localhost:5237 connect 192.168.1.148:6666
#H# 
#H# and then use a command like this to install Magisk Modules using the script:
#H# 
#H#   ./install_mm.sh -e -L tcp:localhost:5237 -- /data/Downloads/my_magisk_module.zip
#H# 
#H#
# 
# Prerequisites
#   Magisk must be installed and active on the phone
#   The Magisk Modules to install must exist on the machine on which this script is running
#   A shell on the phone or a connection via adb command to the phone is required
#   root access is required (either direct or via "su -")
#
#
# History
#   30.08.2024 v1.0.0 /bs
#     initial release
#
#   21.09.2024 v1.1.0 /bs
#     installing Modules on the phone did not work anymore -- fixed
#     corrected the comments and messages (replace "apk" with "Magisk Module", etc)
#     the default value for KEEP_FILE was true and therefor the script did not delete the temporary zip files on the phone -- fixed
#     added the parameter --dry-run
#
#   29.10.2024 v1.2.0 /bs
#     the script now uses /data/local/tmp or /sdcard/Download for temporary files if /tmp does not exist
#
#   19.04.2025 v1.2.1 /bs
#     the script now deletes the temporary test files /sdcard/Download/xxx.$$ 
#
# read the script version from the script source code
#
SCRIPT_VERSION="$( grep -E "^#.*/bs" $0 | tail -1 | awk '{ print $3 }' )"

SCRIPT_NAME="${0##*/}"


# constants
#
__TRUE=0
__FALSE=1

# for debugging
#
#PREFIX="echo"
#PREFIX=""

# environment variables used
#
TARGET_DIR="${TARGET_DIR:=/sdcard/Download}"



if [ "${TMPDIR}"x = ""x ] ; then
  if [ -d /tmp ] ; then
    TMPDIR="/tmp"
  elif [ -d /data/local/tmp ] ; then
    TMPDIR="/data/local/tmp"
  elif [ -d /sdcard/Download ] ; then
    TMPDIR="/sdcard/Download"
  else
    die 9 "No temporary directory found - set the environment variable TMPDIR and try again"
  fi
fi

TMPFILE="${TMPDIR}/${0##*/}.tmp"


typeset THISRC=${__TRUE}

# default values for the parameter 
#
KEEP_FILE=${__FALSE}
REBOOT_PHONE=${__FALSE}
FORCE=${__FALSE}

# arrary for the modules to install
#
typeset -a MODULE_TO_INSTALL

# check if we're running on a phone
#
CUR_PHONE_MODEL="$(  getprop ro.product.odm.model 2>/dev/null )"
CUR_PHONE_SERIAL="$( getprop ro.serialno 2>/dev/null )"

if [ "${CUR_PHONE_SERIAL}"x != ""x ] ; then
  SCRIPT_IS_RUNNING_ON_A_PHONE=${__TRUE}
else
  SCRIPT_IS_RUNNING_ON_A_PHONE=${__FALSE}
fi

# ----------------------------------------------------------------------
# trap handler for deleting temporary files
#
function cleanup {
  LogInfo "cleanup running"
  if [ "${TMPFILE}"x != ""x ] ; then
    if [ -r "${TMPFILE}" ] ; then
      \rm -r "${TMPFILE}"
    fi
  fi
}

trap "cleanup"  0

# ----------------------------------------------------------------------
# functions to write messages
#

function LogMsg {
  echo "$@"
}

function LogInfo {
  [[ ${VERBOSE} == ${__TRUE} ]] && LogMsg "INFO: $@" >&2
}

function LogError {
  LogMsg "ERROR: $@" >&2
}

function LogWarning {
  LogMsg "WARNING: $@"
}

# ----------------------------------------------------------------------
# die
#
# function: print a message and end the script
#
# usage: die [script_exit_code] [message]
#
# the parameter "message" is optional; the script will add a leading "ERROR: "
# to the message if the script_exit_code is not zero
#
# returns: n/a
#
function die  {
  typeset THISRC=$1
  [ $# -ne 0 ] && shift
  typeset THISMSG="$*"

  if [ "${THISMSG}"x != ""x ] ; then
    if [ ${THISRC} -gt 1 ] ; then
      LogError "${THISMSG} (RC=${THISRC})" >&2
    else
      LogMsg "${THISMSG}"
    fi
  fi

  exit ${THISRC}
}


# ----------------------------------------------------------------------
# check for the usage parameter
#  
if [ "$1"x = "-h"x -o "$1"x = "--help"x  -o $# -eq 0 ] ; then

  echo "${SCRIPT_NAME} ${SCRIPT_VERSION} "

  grep "^#h#" $0 | cut -c4-
 
  if [[ " $* " == *\ --verbose\ * || " $* " == *\ -v\ * ]] ; then
    grep "^#H#" $0 | cut -c4-
  fi
  echo "Environment variables used:"
  echo
  for CUR_VAR in TARGET_DIR ADB_OPTIONS TMPDIR PREFIX  ; do
    eval "CUR_VALUE=\"\$${CUR_VAR}\""
    echo "${CUR_VAR} = ${CUR_VALUE}"
  done
  echo
  die 1
fi

# ----------------------------------------------------------------------

LogMsg "${SCRIPT_NAME} ${SCRIPT_VERSION} started on $( date )"

# default : Android Version unknown
#
ANDROID_VERSION=0
 
if [ ${SCRIPT_IS_RUNNING_ON_A_PHONE} = ${__TRUE} ] ; then
  LogMsg "Running on a phone"

  ADB_COMMAND=""
  ADB_SHELL_COMMAND=""

  if [[ $* == *\ --\ * ]] ; then
    CUR_PARAMETER="$*"
    
    die 6 "ERROR: adb parameter \"${CUR_PARAMETER% -- *}\" are not supported if running on a phone"
  fi

  ANDROID_VERSION="$( getprop ro.build.version.release )"

else
  LogMsg "Running on a PC"
  ADB="$( which adb 2>/dev/null )"
  if [ "${ADB}"x = ""x ] ; then
    die 5 "adb executable not found"
  fi

# get the parameter for adb if any 
#
  if [[ $* == *\ --\ * ]] ; then

    OLD_ADB_OPTIONS="${ADB_OPTIONS}"
    ADB_OPTIONS=""

    while [ $# -ne 0 ] ; do
      CUR_PARAMETER="$1"
      shift
      [ "${CUR_PARAMETER}"x = "--"x ] && break
      [ "${CUR_PARAMETER}"x = "+"x ] && CUR_PARAMETER="${OLD_ADB_OPTIONS}"
      
      ADB_OPTIONS="${ADB_OPTIONS} ${CUR_PARAMETER}"
    done
  fi

  if [ "${ADB_OPTIONS}"x != ""x ] ; then
    LogMsg "Using adb with the options \"${ADB_OPTIONS}\" to install the packages "
  else
    LogMsg "Using adb to install the packages"
  fi    
  
  ADB_COMMAND="${ADB} ${ADB_OPTIONS}  "
  ADB_SHELL_COMMAND="${ADB_COMMAND} shell "

  ANDROID_VERSION="$( ${ADB_SHELL_COMMAND} getprop ro.build.version.release )"
  
  CUR_OUTPUT="$( ${PREFIX} ${ADB_SHELL_COMMAND} uname -a 2>&1 )"
  if [ $? -ne 0 ] ; then
    LogMsg "${CUR_OUTPUT}"
    LogMsg ""
    die 100 "Can not connect to the phone via adb"
  fi

  CUR_ID="$( ${ADB_SHELL_COMMAND} touch ${TARGET_DIR}/xxx.$$  )"
  if [ $? != 0 ] ; then
     die 107  "Can not write to the directory \"${TARGET_DIR}\" "
  else     
    CUR_OUTPUT="$( ${ADB_SHELL_COMMAND} rm ${TARGET_DIR}/xxx.$$  )"
  fi

  CUR_PHONE_MODEL="$( ${ADB_SHELL_COMMAND} getprop ro.product.odm.model 2>/dev/null )"
  CUR_PHONE_SERIAL="$( ${ADB_SHELL_COMMAND} getprop ro.serialno 2>/dev/null )"
fi

# ----------------------------------------------------------------------
# check if we do have root access on the phone
#

SU_PREFIX=""

CUR_ID="$( ${ADB_SHELL_COMMAND} id -un )"
if [ "${CUR_ID}"x = "root"x ] ; then
  LogMsg "root access without any prefix works"
else
  CUR_ID="$( ${ADB_SHELL_COMMAND} su - -c id -un )"
  if [ "${CUR_ID}"x = "root"x ] ; then
    SU_PREFIX="su - -c "
    LogMsg "Using the prefix \"${SU_PREFIX}\" for root access"
  else
    die 105 " root access to the phone does not work"
  fi
fi

# ----------------------------------------------------------------------
#
# init the global variables
#   
MAGISK_MODULES_INSTALLED=""
NO_OF_MAGISK_MODULES_INSTALLED=0

MAGISK_MODULES_NOT_INSTALLED=""
NO_OF_MAGISK_MODULES_NOT_INSTALLED=0

MAGISK_MODULES_NOT_FOUND=""
NO_OF_MAGISK_MODULES_NOT_FOUND=0

# ----------------------------------------------------------------------
# process the parameter
#
MAGISK_MODULES_TO_INSTALL=""

ERRORS_FOUND=${__FALSE}

while [ $# -ne 0 ] ; do

  CUR_PARAMETER="$1"
  shift

  case ${CUR_PARAMETER} in

    --dry-run | --dryrun )
      PREFIX="echo"
      ;;

    ++dry-run | ++dryrun )
      PREFIX=""
      ;;

    --force | force )
      FORCE=${__TRUE}
      ;;

    ++force )
      FORCE=${__FALSE}
      ;;

    --keep | keep )
      KEEP_FILE=${__TRUE}
      ;;

    ++keep )
      KEEP_FILE=${__FALSE}
      ;;

    --reboot | reboot )      
      REBOOT_PHONE=${__TRUE}
     ;;
    
    ++reboot )
      REBOOT_PHONE=${__FALSE}
      ;;

    --* | ++* | -* )
      LogError "Unknown parameter found: \"${CUR_PARAMETER}\""
      ERRORS_FOUND=${__TRUE}
      ;;

    * )  
      if [ -d "${CUR_PARAMETER}"  ] ; then
        LogMsg "Directory found in the parameter: Installing all zip files found in the directory \"${CUR_PARAMETER}\" "
        MAGISK_MODULES_TO_INSTALL="${MAGISK_MODULES_TO_INSTALL} $( find ${CUR_PARAMETER} -name "*.zip"  )"
      else
        MAGISK_MODULES_TO_INSTALL="${MAGISK_MODULES_TO_INSTALL} 
${CUR_PARAMETER}"
      fi
      ;;
  esac
done

if [ ${ERRORS_FOUND} -eq ${__TRUE} ] ; then
  die 15 "One or more invalid parameter found"
fi

# ----------------------------------------------------------------------


LogMsg "The Magisk Modules are installed on the phone model ${CUR_PHONE_MODEL} with the serial number ${CUR_PHONE_SERIAL} "

LogMsg "Installing these Magisk Modules "
LogMsg "${MAGISK_MODULES_TO_INSTALL}"
LogMsg ""

if [ "${PREFIX}"x != ""x ] ; then
  LogWarning "The value of the environment variable PREFIX is \"${PREFIX}\" "
fi
  
CUR_OUTPUT="$( ${PREFIX} ${ADB_SHELL_COMMAND} ${SU_PREFIX} magisk -v 2>&1 )"
if [ $? -ne 0 ] ; then
  LogMsg "${CUR_OUTPUT}"
  LogMsg ""
  die 104 " Magisk is either not installed or not running on the phone"
fi

# use a temporary file to handle whitespaces (I'm lazy ...)
#
echo  "${MAGISK_MODULES_TO_INSTALL}">"${TMPFILE}"
if [ $? -ne 0 ] ; then
  die 107 "Can not write to the temporary file \"${TMPFILE}\" "
fi
 
# create an array with the modules to install (because Module names may contain whitespaces)
#
i=0
while read CUR_MAGISK_MODULE ; do
  [ "${CUR_MAGISK_MODULE}"x = ""x ] && continue
  
  (( i = i + 1 ))
  MODULE_TO_INSTALL[$i]="${CUR_MAGISK_MODULE}"
done <"${TMPFILE}"

if [ $i = 0 ] ; then
  die 108  "No modules to install found"
fi

NO_OF_MODULES_TO_INSTALL=$i
i=0 

while [ $i -lt ${NO_OF_MODULES_TO_INSTALL} ] ; do
  ((i = i + 1 ))
  CUR_MAGISK_MODULE="${MODULE_TO_INSTALL[$i]}"
  
  LogMsg ""
  LogMsg "*** Processing the Magisk Module \"${CUR_MAGISK_MODULE}\" ..."
  
  if [ ! -r "${CUR_MAGISK_MODULE}" ] ; then
    LogError " The file \"${CUR_MAGISK_MODULE}\" does not exist or is not readable"

    MAGISK_MODULES_NOT_FOUND="${MAGISK_MODULES_NOT_FOUND} 
${CUR_MAGISK_MODULE}"
    (( NO_OF_MAGISK_MODULES_NOT_FOUND = NO_OF_MAGISK_MODULES_NOT_FOUND +1 ))

    continue
  fi

  LogMsg "Installing the Magisk Module \"${CUR_MAGISK_MODULE}\" ..."

  if [ ${SCRIPT_IS_RUNNING_ON_A_PHONE} = ${__TRUE} ] ; then
    ZIP_FILE="${CUR_MAGISK_MODULE}"
  else

    ZIP_FILE="${TARGET_DIR}/${CUR_MAGISK_MODULE##*/}"

# use a temporary file with a unique name on the phone
#
    [ ${KEEP_FILE} != ${__TRUE} ] && ZIP_FILE="${ZIP_FILE}.$$"

    LogMsg "Copying the file \"${CUR_MAGISK_MODULE}\" to \"${ZIP_FILE}\" on the phone ..."

    ${PREFIX} ${ADB_COMMAND} push "${CUR_MAGISK_MODULE}" "${ZIP_FILE}" 
    if [ $? -ne 0 ] ; then
      LogError " Error copying the file \"${CUR_MAGISK_MODULE}\" to \"${ZIP_FILE}\" on the phone"

    MAGISK_MODULES_NOT_INSTALLED="${MAGISK_MODULES_NOT_INSTALLED} 
${CUR_MAGISK_MODULE}"
    (( NO_OF_MAGISK_MODULES_NOT_INSTALLED = NO_OF_MAGISK_MODULES_NOT_INSTALLED +1 ))

      continue
    fi  
  fi

  LogMsg "Installing the Magisk module file \"${ZIP_FILE}\" with Magisk ..."
  ${PREFIX} ${ADB_SHELL_COMMAND} ${SU_PREFIX} magisk --install-module "${ZIP_FILE}"  
  TEMPRC=$?
  
  if [ ${TEMPRC} -eq 0 ] ; then
    LogMsg "\"${CUR_MAGISK_MODULE}\" succcessfully installed"

    if [ ${SCRIPT_IS_RUNNING_ON_A_PHONE} != ${__TRUE} ] ; then
      if [ ${KEEP_FILE} != ${__TRUE} ] ; then
        LogMsg "Deleting the file \"${ZIP_FILE}\" on the phone ..."
        ${PREFIX} ${ADB_SHELL_COMMAND} ${SU_PREFIX} rm "${ZIP_FILE}" 
      fi
    fi

    MAGISK_MODULES_INSTALLED="${MAGISK_MODULES_INSTALLED} 
${CUR_MAGISK_MODULE}"
    (( NO_OF_MAGISK_MODULES_INSTALLED = NO_OF_MAGISK_MODULES_INSTALLED +1 ))
  else
    LogError " Error installing the Magisk Module  \"${CUR_MAGISK_MODULE}\" "

    MAGISK_MODULES_NOT_INSTALLED="${MAGISK_MODULES_NOT_INSTALLED} 
${CUR_MAGISK_MODULE}"
    (( NO_OF_MAGISK_MODULES_NOT_INSTALLED = NO_OF_MAGISK_MODULES_NOT_INSTALLED +1 ))

  fi
  
done

# ----------------------------------------------------------------------

LogMsg ""

LogMsg ""
LogMsg "Installation summary"
LogMsg "===================="

if [ ${NO_OF_MAGISK_MODULES_INSTALLED} != 0 ] ; then
  LogMsg ""
  LogMsg "${NO_OF_MAGISK_MODULES_INSTALLED} Magisk Module(s) successfully installed:"
  LogMsg "${MAGISK_MODULES_INSTALLED}"
  LogMsg ""
else
  LogWarning "No Magisk Module installed"  
fi

if [ ${NO_OF_MAGISK_MODULES_NOT_INSTALLED} != 0 ] ; then
  LogMsg ""
  LogMsg "${NO_OF_MAGISK_MODULES_NOT_INSTALLED} Magisk Module(s) not installed:"
  LogMsg "${MAGISK_MODULES_NOT_INSTALLED}"
  LogMsg ""

  THISRC=${__FALSE}
fi

if [ ${NO_OF_MAGISK_MODULES_NOT_FOUND} != 0 ] ; then
  LogMsg ""
  LogMsg "${NO_OF_MAGISK_MODULES_NOT_FOUND} Magisk Module(s) not found:"
  LogMsg "${MAGISK_MODULES_NOT_FOUND}"
  LogMsg ""

  THISRC=${__FALSE}      
fi

# ----------------------------------------------------------------------

if [ ${REBOOT_PHONE} = ${__TRUE} ] ; then
  if [[  ( ${NO_OF_MAGISK_MODULES_NOT_FOUND} != 0 || ${NO_OF_MAGISK_MODULES_NOT_INSTALLED} != 0 ) && ${FORCE} == ${__FALSE} ]] ; then    
    LogMsg "WARNING: reboot of the phone requested but the installation of one or more modules failed "
  else
    LogMsg "Rebooting the phone now ..."
    ${PREFIX} ${ADB_SHELL_COMMAND} reboot
  fi
fi

# ----------------------------------------------------------------------

die ${THISRC}

# ----------------------------------------------------------------------
