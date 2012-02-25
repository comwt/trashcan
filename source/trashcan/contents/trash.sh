################################################################################
#
# Copyright (C) 2001, 2002
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

################################################################################
#- Program Name: trash.sh
################################################################################
#- Purpose:  This program has three purposes:
#
#            1) Keep track of removed files.
#            2) Allow a file to be restored for up to number of 
#               days specified by user (except for core dumps and
#               dead.letter files which are automatically removed).
#            3) Daily flushes out files in trash.list older 
#               than user specified number of days old.
################################################################################
#- Version:  Trash Can 2.3
#-------------------------------------------------------------------------------

#- Trash Directory
#-------------------
TD=$2

TC="${TD}/can"                    #-- Trash Can Directory

#- trash.list contains the following columns:
#  rowid|removedate|originalname|storedname|path|date (julian)|file type|
#---------------------------------------------------------------------------
TL="${TD}/trash.list"             #-- Trash List
TLR="${TD}/trash.list.2"          #-- Trash List Replacement (temporary)
TCON="${TD}/trash.conf"           #-- Trash CONfiguration file
TCON2="${TD}/trash.conf.2"        #-- Trash CONfiguration temp replacement file
TEMPLIST="${TD}/temp.list"        #-- Temporay List file (for print)
OD=${PWD}                         #-- Original Directory

SHL=`env | grep SHELL | awk -F/ '{print \$NF}'`    #-- Get SHELL
case "${SHL}" in
  bash)  NCR1="-n"; NCR2="";;     #-- (NCR) No Carriage Return
   ksh)  NCR1=""; NCR2="\c";;
     *)  NCR1=""; NCR2="";;
esac

JULIAN=`date +%j`                 #-- Current Day of Year (Julian Date)
MO=`date +%m`                     #-- Current Month
DAY=`date +%d`                    #-- Current Day
YR=`date | awk '{print $6}'`      #-- Current Year
DATE="${MO}/${DAY}/${YR}"         #-- Current Date

#- Get trash.conf info
#------------------------
LASTPURGE=`awk "\\$1 ~ /LastPurge/ {print \\$3}" ${TCON}`
CURRENT=`awk "\\$1 ~ /Current/ {print \\$3}" ${TCON}`
LASTYEAR=`awk "\\$1 ~ /LastYear/ {print \\$3}" ${TCON}`
KEEPDAYS=`awk "\\$1 ~ /KeepDays/ {print \\$3}" ${TCON}`
MAXTRASHCAP=`awk "\\$1 ~ /MaxTrashCap/ {print \\$3}" ${TCON}`
MAXTRASHWARN=`awk "\\$1 ~ /MaxTrashWarn/ {print \\$3}" ${TCON}`
MTWARNFLAG=0                      #-- Max Trash Warning Flag

OLASTYEAR=${LASTYEAR}             #-- Original 'LASTYEAR'

OPT=$1                            #-- Option (-rm=rm; -rest=restore)

#- Allows for re-use of code in '-rest)' section of case statement
#  for permanent deletion of a single file rather than restore
#-------------------------------------------------------------------
if [[ $3 == "-d" ]]; then
  OF=$4                           #-- Original File name
else
  OF=$3
fi

NF=""                             #-- New File name

case "${OPT}" in

  -rm  )  #--  Remove and log a file or files

        for i in $@
          do

            if [[ ${i} != "-rm" && ${i} != "${TD}" ]]; then

              #- Check trash can capacity before each file is removed.
              #---------------------------------------------------------
              KB=`du -k ${TC} 2>/dev/null | awk '{print $1}'`

              if [[ ${KB} -ge ${MAXTRASHCAP} ]]; then

                #- The trash can has exceeded it capacity.
                #  Notify USER of possible resolutions.
                #-------------------------------------------

                MTWARNFLAG=1

                echo "

      ####################################################################
      #                                                                  #
      #  NO FILES WERE REMOVED . . .                                     #
      #                                                                  #
      #  Your Trash Can has exceeded its maximum capacity!               #
      #  Please run one of the following commands:                       #
      #                                                                  #
      #      'empty'    - to remove everything from the trash can,       #
      #      'prm'      - to permantly remove files,                     #
      #      'trestore' - to choose files to restore,                    #
      #      'delete'   - to choose files to permanently remove, or      #
      #      'tmax'     - to increase trash can maximum capacity.        #
      #                                                                  #
      #  Or run the following command sequence:                          #
      #                                                                  #
      #    'tkeep; purge' - to decrease the number of days trash is kept #
      #                     and then to purge the old trash.             #
      #                                                                  #
      ####################################################################

"
                break;

              else

                OF=${i}               #-- Assign 'i' to Original File

                ################################################################
                #  FILE CHECK - (PWD is only correct if the file being
                #                removed is in the present working directory.
                #                This section is needed to make sure that the
                #                original file name and original directory
                #                are correct if the file is being removed from 
                #                a directory other than PWD.)
                #---------------------------------------------------------------
                NUMFLD=`echo ${OF} | awk -F"/" "{print NF}"`

                #- Get Original Path, if <> to $PWD
                #--------------------------------------
                if [[ ${NUMFLD} -gt 1 ]]; then

                  #- Set file name
                  #------------------------
                  DOF=${OF}      #-- Duplicate old file
                  OF=`echo ${DOF} | awk -F"/" "{print \\$${NUMFLD}}"`

                  FLD=1          #-- Current Field
                  OD=""          #-- Re-Initialize Old Directory

                  #- Decrement field count by 1 to eliminate file name
                  #----------------------------------------------------
                  (( NUMFLD -= 1 ))

                  #- Get the remainder of original directory
                  #-------------------------------------------
                  while [ ${FLD} -le ${NUMFLD} ]
                    do

                      CURR=`echo ${DOF} | awk -F"/" "{print \\$${FLD}}"`

                      OD="${OD}${CURR}"

                      #- Don't put a trailing slash if on last field
                      #-----------------------------------------------
                      if [[ ${FLD} -lt ${NUMFLD} ]]; then
                        OD="${OD}/"
                      fi

                      (( FLD += 1 ))

                    done

                  #- This fixes the problem if . or .. and so on are used in
                  #  the path for the file that needs to be removed, since
                  #  these are relative paths and not absolute.
                  #---------------------------------------------------------
                  cd ${OD} 2>/dev/null; OD=$PWD; cd - 1>/dev/null

                fi
                #---------------------------------------------------------------
                #  finished PWD check
                ################################################################

                VerifyRM() #-- Verify removal of Special File Types
                {
                  echo "Are you sure you want to remove this ${FTYPE}."
                  echo ${NCR1} "As of yet, ${FTYPE}s have not been tested for accurate restoration? (Y/N): ${NCR2}"
                  read ANSW

                  ANSW=`echo ${ANSW} | cut -c1`

                  if [[ ${ANSW} != "Y" && ${ANSW} != "y" ]]; then
                    echo "The ${FTYPE}, ${OF} has not been removed."
                    continue;
                  fi
                }

                FileType()
                {
                  case "${FTYPE}" in
                    l )  FTYPE="LINK  ";;
                    - )  FTYPE="FILE  ";;
                    d )  FTYPE="DIR   ";;
                    D )  FTYPE="DOOR  "; VerifyRM;;
                    b )  FTYPE="BLOCK "; VerifyRM;;
                    c )  FTYPE="CHAR  "; VerifyRM;;
                    p )  FTYPE="FIFO  "; VerifyRM;;
                    s )  FTYPE="SOCKET"; VerifyRM;;
                  esac
                }

                #- Check to see if file exists, if not, go to next file
                #------------------------------------------------------
                if [ -d ${OD}/${OF} ]; then
                  FTYPE="d"
                #elif [[ `ls ${OD}/${OF} | wc -l` -gt 0 ]]; then
                elif [[ -f "${OD}/${OF}" ]]; then
                  FTYPE=`ls -l ${OD}/${OF} | cut -c1`
                else
                  echo "File (${i}) does not exist."
                  continue;
                fi

                FileType                     #-- Function call

                #- First, permanently remove if 'core' or 'dead.letter'
                #------------------------------------------------------
                if [[ ${OF} == "core" || ${OF} == "dead.letter" ]]; then

                  `rm ${i}`

                  #- Check for success
                  #---------------------
                  if [ -f ${i} ]; then
                    echo "Could not remove '${i}'."
                  else
                    echo "'${i}' was permanently removed."
                  fi

                  continue;

                fi

                #- Make sure trash can directory exists, if not create.
                #------------------------------------------------------
                if [ ! -d ${TC} ]; then
                  mkdir ${TC}
                fi

                #- Assign unique ROWID and New File Name to Original File
                #  Uses the first available number (first column).
                #----------------------------------------------------------
                ROWID=0
                COUNT=0
                STEP=1

                until [[ ${ROWID} -gt 0 ]]
                  do
                    COUNT=`awk -F"|" "{if (\\$1 == ${STEP}) print \\$1}" ${TL} | wc -l`

                    if [[ ${COUNT} -eq 0 ]]; then
                      ROWID=${STEP}
                      break;
                    fi

                    (( STEP += 1 ))
                  done

                  NF="${OF}.${ROWID}"
                  
                  #---------------------------------
                  #- Tar & Zip the file to archive into Trash Can, then delete 
                  #  original file.  (only removes file if archive succeeds)
                  #-------------------------------------------------------------
                  mv -f ${i} ${TC}/${NF}
                  tar Pcf ${TC}/${NF}.tar ${TC}/${NF} 1>/dev/null 2>&1
                  gzip ${TC}/${NF}.tar && rm -rf ${TC}/${NF}

                  #- Log file to be moved
                  #-------------------------
                  echo "${ROWID}|${DATE}|${OF}|${NF}|${OD}|${JULIAN}|${FTYPE}|" >> ${TL}
              fi

            fi
                
          done

          ;;

  -prm )  #-- Permanently remove a file (bypass trash can)

          for i in $@
            do

              if [[ ${i} != "-prm" && ${i} != "${TD}" ]]; then

                rm -ri ${i}

              fi

            done

          ;;

  -rest)  #--------------------------------------------------------------
          #--  Restore a file to its original location, or
          #--  if 2nd parameter is "-d", then permanently delete file
          #--  (allows for re-use of code)
          #--------------------------------------------------------------

          LC=1                       #-- List Count
          CURR=1                     #-- Current array element

          clear

          > ${TEMPLIST}              #-- Clear if present

          #- If no file name is passed in then assign "**" to list all files
          #-------------------------------------------------------------------
          if [[ ${OF} == "" ]]; then
            OF="^.*"
          fi

          banner "Trash List" 2>/dev/null

          CNT=`ls -A ${TC} | wc -l`

          if [[ ${CNT} -eq 0 ]]; then
            echo "The trash can is empty."
            echo ""
            exit 0;
          fi

          echo "       Deleted     Type     Original Path"
          echo ""

          Length()
          {
            LENGTH=`echo ${LC} | awk '{print length}'`
            case "${LENGTH}" in
              1)  SPC="   ";;
              2)  SPC="  ";;
              3)  SPC=" ";;
              4)  SPC="";;
            esac
          }

          for i in `sort -k 3,3 -t"|" ${TL} | awk -F"|" "\\$4 ~ /${OF}/ {print \\$1}"`
            do

              #FileType  #-- Function call

              #- Assign STR the values of DATE, PATH/FILE NAME
              #-------------------------------------------------
              STR=`awk -F"|" "\\$1 == ${i} {print \\$2 \\"   \\"\\$7\\"  \\" \\$5 \"/\" \\$3}" ${TL}`
              Length  #-- Function call

              echo "${SPC}${LC}. ${STR}" >> ${TEMPLIST}
              ROW[${LC}]=${i}        #-- Assign Row Number to ROW array

              (( LC += 1 ))

            done
          
          Length  #-- Function call

          echo "${SPC}${LC}. EXIT (NOT SHOWN)" >> ${TEMPLIST}

          ANSW=0

          until [[ ${ANSW} -gt 0 && ${ANSW} -le ${LC} ]]
            do

              cat ${TEMPLIST} | more
              echo "" 

              if [[ $3 == "-d" ]]; then
                echo ${NCR1} "Select the file number to be permanently deleted: ${NCR2}"
                read ANSW
              else
                echo ${NCR1} "Select the file number to be restored: ${NCR2}"
                read ANSW
              fi

              #- If a non-digit character is intered the program will fail
              #  in the numeric comparison in the until loop.
              #--------------------------------------------------------------
              if [[ ${ANSW} != [[:digit:]] ]]; then
                if [[ ${ANSW} == [[:alpha:]] || ${ANSW} == [[:alnum:]] ]]; then
                  ANSW=0
                fi
              fi

              #- If user chooses to EXIT.
              #--------------------------
              if [[ ${ANSW} -eq ${LC} ]]; then
                if [[ $3 == "-d" ]]; then
                  echo "No files permanently deleted."
                else
                  echo "No files restored."
                fi
                echo ""
                rm -r ${TEMPLIST}
                exit 0;
              fi

              if [[ ${ANSW} -lt 1 || ${ANSW} -gt ${LC} ]]; then

                ANSW=0
                echo "Invalid Entry."
                sleep 2
                clear
                banner "Trash List" 2>/dev/null

                echo ""
                echo "       Deleted         Original Path"
                echo ""

              fi

            done

          echo ""

          #- Get ROWID
          #-------------------------------------------
          ROWID=${ROW[${ANSW}]}

          #- Get Directory PATH to put file in
          #-------------------------------------------
          DIR=`awk -F"|" "\\$1 == ${ROW[${ANSW}]} {print \\$5}" ${TL}`

          #- Get NEW FILE NAME
          #-------------------------------------------
          NF=`awk -F"|" "\\$1 == ${ROW[${ANSW}]} {print \\$4}" ${TL}`

          #- Get OLD FILE NAME
          #-------------------------------------------
          OF=`awk -F"|" "\\$1 == ${ROW[${ANSW}]} {print \\$3}" ${TL}`

          if [[ $3 != "-d" ]]; then

            #- See if file already exists in restore path
            #  Could have used -a option alone, but wasn't
            #  sure if linux supports the -a test.
            #----------------------------------------------
            if [[ -f ${DIR}/${OF} || -d ${DIR}/${OF} ]]; then

              echo ""
              echo ${NCR1} "File already exists.  Overwrite? (Y/N): ${NCR2}"
              read ANSW
 
              ANSW=`echo ${ANSW} | cut -c1`

              if [[ ${ANSW} != "Y" && ${ANSW} != "y" ]]; then

                echo ""
                echo "No files have been restored."
                echo ""
                rm -r ${TEMPLIST}
                exit 0;

              fi

            fi

          else  #-- Marked for deletion

            echo ${NCR1} "Permanently delete ${OF}? (Y/N): ${NCR2}"
            read ANSW

            ANSW=`echo ${ANSW} | cut -c1`

            if [[ ${ANSW} != "Y" && ${ANSW} != "y" ]]; then

              echo ""
              echo "No files have been permanently deleted."
              echo ""
              rm -r ${TEMPLIST}
              exit 0;

            fi

          fi

          if [[ $3 == "-d" ]]; then

            echo ""
            rm ${TC}/${NF}.tar.gz && echo "${OF} has been permanently deleted."; echo ""

          else

            #- Restore the file to its original position
            #---------------------------------------------
            gunzip ${TC}/${NF}.tar.gz
            tar -Pxf ${TC}/${NF}.tar

            mv -f ${TC}/${NF} ${DIR}/${OF} && rm -rf ${TC}/${NF}.tar

            #- Check success of move.
            #------------------------
            if [[ $? -eq 0 ]]; then
              echo "File was successfully restored."
              echo ""
            fi
            
          fi

          #- Delete Listing from trash.list
          #---------------------------------
          sed -e /^${ROWID}\|*\|*\|*\|*\|*\|/d ${TL} > ${TLR}
          mv -f ${TLR} ${TL}

          rm -r ${TEMPLIST}

          ;;

  -empty)  #-- Delete all contents of trash can

          echo ${NCR1} "\n\n\nDelete all trash? (Y/N): ${NCR2}"
          read ANSW

          if [[ ${ANSW} == "Y" || ${ANSW} == "y" ]]; then

            cd ${TC}

            QTY1a=`ls | wc -l`
            QTY1b=`ls -d .* | grep -v "^..$" | grep -v "^.$" | wc -l`

            let QTY1="$QTY1a + $QTY1b"

            if [[ ${QTY1} -gt 0 ]]; then
              if [[ ${QTY1a} -gt 0 ]]; then
                rm ${TC}/* 2>/dev/null
                if [[ $? -ne 0 ]]; then
                  echo "rm ${TC}/*  returned EXIT STATUS: $?"
                fi
              fi
              if [[ ${QTY1b} -gt 0 ]]; then
                rm ${TC}/.* 2>/dev/null
                if [[ $? -ne 0 && `ls -A | wc -l` -gt 0 ]]; then
                  echo "rm ${TC}/.* returned EXIT STATUS: $?"
                fi
              fi
              QTY2=`ls -A ${TC} | wc -l`
              if [[ ${QTY2} -eq 0 ]]; then
                > ${TL}
                echo "All trash has been permanently deleted."
              elif [[ ${QTY1} -ne ${QTY2} ]]; then
                > ${TL}
                echo "\n`expr ${QTY1} - ${QTY2}` out of `expr ${QTY1}` files were deleted."
                echo "\nBelow are the files that were left:"
                ls -A ${TC}
                echo "\nYou will have to manually delete the files from\n${TC}"
              else
                echo "No trash was deleted."
              fi
            else
              echo "The trash can is empty."
            fi

            cd - 1>/dev/null

          else
            echo "No trash has been deleted."
          fi

          echo ""

          ;;

  -list)  #--  List Contents of trash.list

          clear
          banner "Trash Info" 2>/dev/null
          echo ""
          echo "DISK USAGE:"
          KB=`du -k ${TC} 2>/dev/null | awk '{print $1}'`
          echo "  <= ${KB} Kilobytes"
          echo ""
          echo "OPTIONS:"
          echo "  empty    -Permanently remove all trash
  prm      -Permanently remove (bypass trash system)
  purge    -Permanently remove trash older than ${KEEPDAYS} days
  trestore -Restores file to its original location
  rm       -remove file(s)
  throw    -remove file(s)
  tkeep    -configure the number of days to keep trash
  tmax     -configure trash can capacity
  trash    -list trash disk usage,
            list trash options,
            list files in trash (date deleted, file name, original path)
  "

          echo ${NCR1} "Press '1' now to view the GPL License or 'enter' to continue: ${NCR2}"
          read TEST
          TEST="${TEST}"
          if [[ ${TEST} == "1" ]]; then
            clear
            cat ${TD}/License | more
            echo ""
            echo "^v^v^v^v^v^v^v^v^v^v^v^v^v^v^v^v^v^v^v^v^v^v^v^v^v^v^v^v^v^v^v^v^v^v^v^v^v^v^v^v"
            echo ""
            echo ""
          fi

          echo ""
          echo "TRASH CAN CONTENTS:"
          echo ""

          #- Check to see if Trash Can has any files
          #------------------------------------------
          CNT=`ls -A ${TC} | wc -l`
          if [[ ${CNT} -eq 0 ]]; then
            echo "The trash can is empty."
            echo ""
            exit 0;
          fi

          echo "  Deleted     Type    File Name"
          echo "  -------     ----    ---------"
          awk -F"|" "{print \"  \" \$2 \"  \" \$7 \"  \" \$3}" ${TL} | sort +2n -d -t\| | uniq | more
          echo ""

          ;;

  -purge  )  #--  Delete files older than trash.conf 'KeepDays' specified.

          #- Only purge old files if they haven't already been purged today
          #-----------------------------------------------------------------

          if [[ ${LASTPURGE} -eq ${JULIAN} ]]; then

            exit 0;

          else

            ####################################################################
            #          SET trash.conf variables 'Current' & 'LastYear'
            #-------------------------------------------------------------------

            #- Set current day in trash.conf
            #--------------------------------
            sed "s/Current = ${CURRENT}/Current = ${JULIAN}/" ${TCON} > ${TCON2}
            mv -f ${TCON2} ${TCON}

            LYR=${YR}                 #-- Last YeaR (set to current year)

            #- Decrement LYR by 1 for actual
            #--------------------------------
            (( LYR -= 1 ))

            #- Get comparison for leap year table (for last year)
            #----------------------------------------------------
            LYR=`echo "${LYR}" | cut -c3-4`

            MOD=${LYR}
            (( MOD %= 4 ))

            #- Check to see if Last year was a leap year
            #--------------------------------------------
            if [[ ${MOD} -eq 0 ]]; then
              LASTYEAR=366
            else
              LASTYEAR=365
            fi

            #- Set 'LastYear' in trash.conf
            #--------------------------------
            sed "s/LastYear = ${OLASTYEAR}/LastYear = ${LASTYEAR}/" ${TCON} > ${TCON2}
            mv -f ${TCON2} ${TCON}
            #-------------------------------------------------------------------
            #          Finished dynamically setting trash.conf variables
            ####################################################################

            #- Verify that user wants to purge files
            #---------------------------------------
            #echo ${NCR1} "Delete old trash? (Y/N): ${NCR2}"
            #read ANSW

            #if [[ ${ANSW} != "Y" && ${ANSW} != "y" ]]; then
            #  echo "No trash has been deleted."
            #  echo ""
            #  exit 0;
            #fi

            clear
            echo ""
            echo ${NCR1} "Determining which trash to purge ..... ${NCR2}"

            CNT=1                  #-- Used for array 'DELARR' element position.
            DELCNT=0               #-- Used to increment possition for files
                                   #   that need to be deleted.

            #- Create or Clear the file to contain file names to be deleted
            #-----------------------------------------------------------------
            F_DEL_LIST="${TD}/del.list"  #-- (File) Delete List
            > ${F_DEL_LIST}

            #-----------------------------------------------------------------
            #- First, check to see if old file date falls within current year
            #-----------------------------------------------------------------
            if [[ ${JULIAN} -gt ${KEEPDAYS} ]]; then

              OLD=${JULIAN}
              (( OLD -= ${KEEPDAYS} ))

              for i in `awk -F"|" "\\$6 < ${OLD} {print NR}" ${TL}`
                do

                  (( DELCNT += 1 ))

                  #- DELetion ARRay (holds ROWID in trash.list to be deleted)
                  #----------------------------------------------------------
                  DELARR[${CNT}]=`awk -F"|" "NR == ${i} {print \\$1}" ${TL}`

                  NF=`awk -F"|" "NR == ${i} {print \\$4}" ${TL}`
                  awk -F"|" "NR == ${i} {print \"  \" \$7 \"  \" \$3}" ${TL} >> ${F_DEL_LIST}
                  FILEDELARR_FOUR[${DELCNT}]="${NF}.tar.gz"

                  (( CNT += 1 ))

                done

            fi

            #- Check to see if any files are left over from last year
            #  and if they are older than KeepDays allows.  Delete.
            #  This occurs if today's date is <= "KeepDays".
            #-----------------------------------------------------------
            LYCNT=`awk -F"|" "\\$6 > ${JULIAN} {print NR}" ${TL} | wc -l`

            if [[ ${LYCNT} -gt 0 ]]; then

              #- Finds how many KeepDays are left to count back from LastYear
              #  Example:  If JULIAN = 07 and KEEPDAYS = 7; then KEEPDAYS = 0
              #            If LASTYEAR=365 then LASTYEAR = 365
              #        Anything <= 365 and > 07 will be deleted...
              #---------------------------------------------------------------
              (( KEEPDAYS -= ${JULIAN} ))

              (( LASTYEAR -= ${KEEPDAYS} ))

              OLD=${LASTYEAR}

              for i in `awk -F"|" "\\$6 <= ${OLD} && \\$6 > ${JULIAN} {print NR}" ${TL}`
                do

                  (( DELCNT += 1 ))

                  #- DELetion ARRay (holds ROWID in trash.list to be deleted)
                  #----------------------------------------------------------
                  DELARR[${CNT}]=`awk -F"|" "NR == ${i} {print \\$1}" ${TL}`
                  NF=`awk -F"|" "NR == ${i} {print \\$4}" ${TL}`
                  awk -F"|" "NR == ${i} {print \"  \" \$7 \"  \" \$3}" ${TL} >> ${F_DEL_LIST}
                  FILEDELARR_FOUR[${DELCNT}]="${NF}.tar.gz"

                  (( CNT += 1 ))

                done

            fi


            ###########################################################
            SetLastPurgeDay()
            #
            #  Purpose: Sets the 'LastPurge' line in trash.conf to
            #           today's julian date.
            #----------------------------------------------------------
            {
              sed "s/LastPurge = ${LASTPURGE}/LastPurge = ${JULIAN}/" ${TCON} > ${TCON2}
              mv -f ${TCON2} ${TCON}
            }
            ######----- END SUBFUNCTION - SetLastPurgeDay() -----######


            ###########################################################
            #  Added to notify USER of the files that will be deleted.
            #----------------------------------------------------------
            if [[ ${DELCNT} -gt 0 ]]; then
              echo ""
              echo ""
              echo "The following file(s) will be deleted:"
              cat ${F_DEL_LIST} | more
              echo ""
              echo ${NCR1} "Is this OK? (Y/N): ${NCR2}"
              read ANSW

              if [[ ${ANSW} != "Y" && ${ANSW} != "y" ]]; then
                echo ""
                echo "No trash has been deleted."
                echo ""
                exit 0;
              fi
            else
              echo ""
              echo ""
              echo "There are no files to delete today."
              echo ""
              SetLastPurgeDay  #-- Function Call
              exit 0;
            fi
            #
            #########################################################

            #- Remove the files now
            #-----------------------------------------------------------
            echo ""
            echo ${NCR1} "Purging old trash ..... ${NCR2}"

            for FILETODEL in ${FILEDELARR_FOUR[@]}
              do
                rm ${TC}/${FILETODEL}
              done

            #- Re-Initialize Counter
            #-----------------------------------------------------------
            CNT=1

            #- Delete Listings from trash.list (must be done after
            #  trash.list has been read, since altering the file
            #  while deletions are taking place above, affects line
            #  numbers for awk.
            #-----------------------------------------------------------
            while [[ ${CNT} -le ${#DELARR[@]} ]]
              do
                sed -e /^${DELARR[${CNT}]}\|*\|*\|*\|*\|*\|/d ${TL} > ${TLR}
                mv -f ${TLR} ${TL}
                (( CNT += 1 ))
              done

            #- Decrement CNT by 1 to show actual quantity of deletions
            #----------------------------------------------------------
            (( CNT -= 1 ))

            if [[ ${CNT} -eq 1 ]]; then
              GRAMMAR="file was"
            else
              GRAMMAR="files were"
            fi

            echo "Finished."
            echo ""
            echo "${CNT} ${GRAMMAR} permanently deleted."
            echo ""

            SetLastPurgeDay  #-- Function Call

          fi
 
          ;;

  -keep  )  #-- Configure number of days to keep trash

          clear
          banner Trash Config 2>/dev/null
          echo ""
          echo "Current Keep Days: ${KEEPDAYS}"
          echo ""
          echo ${NCR1} "Do you wish to change this? (Y/N): ${NCR2}"
          read ANSW
          echo ""

          if [[ ${ANSW} == "Y" || ${ANSW} == "y" ]]; then

            echo ${NCR1} "Enter New Keep Days: ${NCR2}"
            read NEWKEEP

            if [[ ${NEWKEEP} -ne ${KEEPDAYS} ]]; then

              sed "s/KeepDays = ${KEEPDAYS}/KeepDays = ${NEWKEEP}/" ${TCON} > ${TCON2}

              #- Re-set last purge day
              #-------------------------
              sed "s/LastPurge = ${LASTPURGE}/LastPurge = 0/" ${TCON2} > ${TCON}
              rm ${TCON2}

              echo ""
              echo "Keep Days changed to ${NEWKEEP}."

            else

              echo ""
              echo "No change made."

            fi

          else

            echo "No change made."

          fi

          echo ""

          ;;

  -tmax  )  #-- Configure max space (in kilobytes) to alot for trash can

          clear
          banner Trash Config 2>/dev/null
          echo ""
          echo "Current Maximum Kilobytes: ${MAXTRASHCAP}"
          echo ""
          echo ${NCR1} "Do you wish to change this? (Y/N): ${NCR2}"
          read ANSW
          echo ""

          if [[ ${ANSW} == "Y" || ${ANSW} == "y" ]]; then

            echo ${NCR1} "Enter New MAX Trash Can Size (in Kilobytes): ${NCR2}"
            read NEWMAX

            if [[ ${NEWMAX} -ne ${MAXTRASHCAP} ]]; then

              sed "s/MaxTrashCap = ${MAXTRASHCAP}/MaxTrashCap = ${NEWMAX}/" ${TCON} > ${TCON2}
              NEWWARN=`expr ${NEWMAX} / 4 \\* 3`
              sed "s/MaxTrashWarn = ${MAXTRASHWARN}/MaxTrashWarn = ${NEWWARN}/" ${TCON2} > ${TCON}
              rm ${TCON2}
              echo ""
              echo "Maximum Trash Can Size is now ${NEWMAX} kilobytes."

            else

              echo ""
              echo "No change made."

            fi

          else

            echo "No change made."

          fi

          echo ""

          ;;

esac

#- Each time this program is involked (for file removal), it will check
#  how full the trash can is.  It will then notify the user if they have
#  reached 75% of capacity (>= ${MAXTRASHWARN}).
#-----------------------------------------------------------------------
if [[ ${OPT} == "-rm" ]]; then

  if [[ ${MTWARNFLAG} -eq 0 ]]; then

    KB=`du -k ${TC} 2>/dev/null | awk '{print $1}'`

    if [[ ${KB} -ge ${MAXTRASHWARN} ]]; then
      echo ""
      echo "Your Trash Can has reached or exceeded 75% of its capacity."
      echo ""
      echo "Currently you are using ${KB} kilobytes"
      echo "   out of your possible ${MAXTRASHCAP} kilobyte (max capacity)."
      echo ""
      echo "Once your trash can reaches 100% capacity, a notification will"
      echo "display and you will be unable to temporarily remove files."
      echo ""
    fi

  fi

fi

exit 0;
