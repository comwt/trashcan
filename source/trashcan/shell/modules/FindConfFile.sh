################################################################################
#
#    File: FindConfFile.sh (module for trash_install & trash_uninstall)
#
# Purpose: Find the trashcan valid trash.conf file for the current user.
#
################################################################################
#
# Copyright (C) 2001-2012
# by Justin Francis
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307 USA
#
################################################################################

if [[ $TRASHCAN_DEBUG_FLAG -eq 1 ]]; then
  echo "DEBUG: FindConfFile()"
fi

RET_VAL=0

CNT=`ls -d ${USER_TRASH_HOME}/.trash* 2>/dev/null | wc -l`

if [[ $TRASHCAN_DEBUG_FLAG -eq 1 ]]; then
  echo "  DEBUG: CNT = ${CNT}"
fi

NEXT_TRASHCAN_USER=0

if [[ ${CNT} -eq 0 ]]; then

  if [[ ${MULTIPLE_USERS} -eq 1 ]]; then
    NEXT_TRASHCAN_USER=1
  else
    RET_VAL=1
  fi

elif [[ ${CNT} -eq 1 ]]; then

  DTDIR=`ls -d $USER_TRASH_HOME/.trash*` #-- Delete Trash Directory

elif [[ ${CNT} -gt 1 ]]; then

  while :
    do

      echo "Trash Directories:"
      echo ""

      STEP=1

      for i in `ls -d ${USER_TRASH_HOME}/.trash*`
        do
          echo "  ${STEP})  ${i}"
          DTDIR_ARR[${STEP}]="${i}"
          (( STEP += 1 ))
        done
      echo "  ${STEP})  Exit (Not Shown)"
      echo ""
      echo $TC_NCR1 "Enter the trash directory number that you want to delete (1 - ${STEP}): $TC_NCR2"
      read ANSW
      echo ""

      #- If a non-digit character is entered the program will fail
      #  in the numeric comparison in the until loop.
      #--------------------------------------------------------------
      if [[ ${ANSW} != [[:digit:]] ]]; then
        if [[ ${ANSW} == [[:alpha:]] || ${ANSW} == [[:alnum:]] ]]; then
          ANSW=0
        fi
      fi

      #- If user chooses to EXIT.
      #--------------------------
      if [[ ${ANSW} -eq ${STEP} ]]; then
        exit 0;
      fi

      if [[ ${ANSW} -lt 1 || ${ANSW} -gt ${LC} ]]; then

        ANSW=0
        echo "Invalid Entry."
        sleep 1; clear; continue

      fi

      break

    done

  DTDIR=${DTDIR_ARR[${ANSW}]}

fi

if [[ ${NEXT_TRASHCAN_USER} -eq 0 ]]; then

  if [[ ${CNT} -gt 0 ]]; then

    #- find existing trash.conf file
    #--------------------------------
    TRASHCAN_CONF_FILE=`find ${DTDIR} -name "trash.conf" | grep -v ${HDIR}`

    if [[ $TRASHCAN_DEBUG_FLAG -eq 1 ]]; then
      echo "  DEBUG: TRASHCAN_CONF_FILE=${TRASHCAN_CONF_FILE}"
    fi

    if [[ ${TRASHCAN_CONF_FILE} == "" ]]; then
      echo "Trash Can does not appear to be installed."
      echo ""
      RET_VAL=1
    fi

    CNT=`awk '$1 ~ /^TrashDir/ || $1 ~ /^TrashBIN/ || $1 ~ /^ProFile/ {print $0} ' ${TRASHCAN_CONF_FILE} | wc -l`

    if [[ ${CNT} -eq 0 ]]; then

      echo ""
      echo "You are using an older version of Trash Can."
      echo ""
      echo "Please run ${HDIR}/trash_install, first."
      echo "This will install over your existing Trash Can installation"
      echo "thus allowing the un-install script to function properly."
      echo ""
      RET_VAL=1

    fi

    TDIR=${DTDIR}

  fi

fi

export NEXT_TRASHCAN_USER TRASHCAN_CONF_FILE TDIR

if [[ $TRASHCAN_DEBUG_FLAG -eq 1 ]]; then
  echo "DEBUG: FindConfFile() - Finished"
fi

return ${RET_VAL};
