#!/bin/sh

#
# run.sh
#
# (C) Copyright IBM Corp. 2003, 2009
#
# THIS FILE IS PROVIDED UNDER THE TERMS OF THE ECLIPSE PUBLIC LICENSE
# ("AGREEMENT"). ANY USE, REPRODUCTION OR DISTRIBUTION OF THIS FILE
# CONSTITUTES RECIPIENTS ACCEPTANCE OF THE AGREEMENT.
#
# You can obtain a current copy of the Eclipse Public License from
# http://www.opensource.org/licenses/eclipse-1.0.php
#
# Author:       Heidi Neumann <heidineu@de.ibm.com>
# Contributors: Gareth Bestor <bestorga@us.ibm.com> 
#
# Description:
# This shell script acts as entry point to the certain test types the
# test suite supports (interface, consistence and maybe more in the 
# future).
#


#******************************************************************************#
#                 Please edit to fit your local parameters                     #

TEST_DIR=`pwd`;
SYSTEM_PATH=$TEST_DIR/system/linux;
export PATH=$PATH:$SYSTEM_PATH;

# First run the createFiles script, if it exists 
cd $SYSTEM_PATH;
if [[ -a ./createKeyFiles.sh ]]; then
  ./createKeyFiles.sh
fi
cd -;

#******************************************************************************#

CLASSNAME=$1
shift
USERID=
PASSWORD=
NAMESPACE="/root/cimv2"
HOSTNAME="localhost"
PORT=
PROTOCOL="http"
VERBOSE=

while [ "$#" -gt 0 ]
do
  COMMAND=$1
  shift

  # specify the user
  if [[ -n "$COMMAND" && "$COMMAND" == "-u" ]]; then
      if [[ -n "$1" ]]; then 
	  USERID=$1;
      else
	  echo "run.sh : Please specify a UserID after -u"; 
	  exit 1;
      fi

  # specify the user's password
  elif [[ -n "$COMMAND" && "$COMMAND" == "-p" ]]; then
      if [[ -z "$1" ]]; then 
	  echo "run.sh : Please specify a password for UserID $USERID after -p"; exit 1;
      else 
	  PASSWORD=$1;
      fi

  # specify the hostname
  elif [[ -n "$COMMAND" && "$COMMAND" == "-host" ]]; then
      HOSTNAME=$1;

  # specify the port
  elif [[ -n "$COMMAND" && "$COMMAND" == "-port" ]]; then
      PORT=$1;

  # specify the namespace
  elif [[ -n "$COMMAND" && "$COMMAND" == "-n" ]]; then
      NAMESPACE=$1;

  elif [[ -n "$COMMAND" && "$COMMAND" == "-verbose" ]]; then
      VERBOSE="yes";

  fi
done

if [ -n "$SBLIM_TESTSUITE_PROTOCOL" ]; then
    if [ $SBLIM_TESTSUITE_PROTOCOL = "https" ]; then
	export PROTOCOL="-noverify $SBLIM_TESTSUITE_PROTOCOL";
	if [ -z "$PORT" ]; then
	    export PORT=5989
	fi
    else
	export PROTOCOL=$SBLIM_TESTSUITE_PROTOCOL;
    fi
fi

if [ -z "$PORT" ]; then
    export PORT=5988
fi

if [[ -n $USERID && -z $PASSWORD ]]; then
    echo "run.sh : Please specify a password for UserID $USERID : option -p"; 
    exit 1;
elif  [[ -n $USERID && -n $PASSWORD ]]; then
    export SBLIM_TESTSUITE_ACCESS="$USERID:$PASSWORD@";
fi

if [[ -n $HOSTNAME ]]; then
    export SBLIM_TESTSUITE_HOSTNAME="$HOSTNAME";
fi

if [[ -n "$PORT" ]]; then
    export SBLIM_TESTSUITE_PORT="$PORT";
fi

if [[ -n $NAMESPACE ]]; then
    export SBLIM_TESTSUITE_NAMESPACE="$NAMESPACE";
fi

if [[ -n $VERBOSE ]]; then
    export SBLIM_TESTSUITE_VERBOSE=1;
fi



#******************************************************************************#
#
# exit, if CIMOM is not running
#

RC=
WBEMCLI_ENV=`env | grep WBEMCLI_IND | sed -e s/WBEMCLI_IND=//`;

if [[ -n $WBEMCLI_ENV ]]; then
    WBEMCLI_ALIAS=`head -1 $WBEMCLI_ENV | sed -e s/.*:' '//`
    echo "check if CIMOM is running - wbemgc $WBEMCLI_ALIAS$NAMESPACE:cim_managedelement";
    RC=`wbemgc $WBEMCLI_ALIAS$NAMESPACE:cim_managedelement 2>&1`;
else
    if [[ -n $SBLIM_TESTSUITE_ACCESS ]]; then
	echo "check if CIMOM is running - wbemgc $PROTOCOL://"$SBLIM_TESTSUITE_ACCESS$HOSTNAME":"$PORT$NAMESPACE":cim_managedelement";
	RC=`wbemgc $PROTOCOL://"$SBLIM_TESTSUITE_ACCESS$HOSTNAME":"$PORT$NAMESPACE":cim_managedelement 2>&1`;
    else
	echo "check if CIMOM is running - wbemgc $PROTOCOL://$HOSTNAME":"$PORT$NAMESPACE:cim_managedelement";
	RC=`wbemgc $PROTOCOL://$HOSTNAME":"$PORT$NAMESPACE:cim_managedelement 2>&1`;
    fi
fi

if [[ -n $RC ]]; then
    echo $RC | grep 'Exception' >/dev/null \
	&& echo 'CIMOM NOT RUNNING ?' && exit 1;
    echo "OK";
    echo ;
fi


#******************************************************************************#
#                           start interface test                               #

perl interface.pl -className $CLASSNAME -v \
    || export SBLIM_TESTSUITE_RUN=-1;

#******************************************************************************#


#******************************************************************************#
#                          start consistency test                              #

perl consistence.pl -className $CLASSNAME -path $SYSTEM_PATH -v \
    || export SBLIM_TESTSUITE_RUN=-1;

#******************************************************************************#


#******************************************************************************#
#                          start specification test                            #

#******************************************************************************#
