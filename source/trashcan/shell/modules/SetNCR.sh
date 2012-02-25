################################################################################
#
#    File: SetNCR.sh (module for trash_install & trash_uninstall)
#
# Purpose: Set the variables TC_NCR1 and TC_NCR2
#
################################################################################
#
# Copyright (C) 2001-2003
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
  echo "DEBUG: SetNCR.sh"
fi

M_SHELL=`env | grep SHELL | awk -F/ '{print \$NF}'`   #-- Get SHELL
case "${M_SHELL}" in
  bash)  TC_NCR1="-n"; TC_NCR2="";;     #-- (TC_NCR) Trashcan No Carriage Return
  ksh )  TC_NCR1=""; TC_NCR2="\c";;
  *   )  TC_NCR1=""; TC_NCR2="";;
esac

export TC_NCR1 TC_NCR2

if [[ $TRASHCAN_DEBUG_FLAG -eq 1 ]]; then
  echo "DEBUG: SetNCR.sh - Finished"
fi
