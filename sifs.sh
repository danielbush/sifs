# Copyright 2009 Daniel Bush
#
# This file is part of SIFS (simple include-file system).
# SIFS is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
# 
# You are free to use or modify SIFS as you please.

if ! test -n "$BASH"; then
  echo "Not starting SIFS - you need a bash shell."
  return 1
fi
if test -n "$SIFS_HOME"; then
  . $SIFS_HOME/edit.sif
else
  echo "SIFS_HOME is not set, SIFS can't continue."
  return 1
fi
if test -z "$EDITOR"; then
  echo "Warning: please set EDITOR for proper functionality."
fi

hh() {
less <<-EOF
       _  __      
   ___(_)/ _|___  
  / __| | |_/ __| 
  \__ \ |  _\__ \ 
  |___/_|_| |___/ 
               
  Help page for SIFS system (hh)

  RESERVED variables:

  OLD_HOME:     $OLD_HOME          
                - Original home directory before SIFS was loaded.
  SIFS_INCLUDE: $SIFS_INCLUDE      
                - Current include file.
  SIFS_DIR:     $SIFS_DIR         
                - Current location for finding .sif files.
  SIFS_HOME:    $SIFS_HOME         
                - Location of the SIFS system
                  eg SIFS_HOME=/home/danb/sifs  or /etc/sifs

  Variables managed by the current include file:
  HOME:         $HOME


  Locations:

  SIFS_HOME/sifs.sh   - The main sifs file which should be loaded into your system at login
  SIFS_HOME/sifs.conf - Store locations of sif files
                        eg /home/user/sifs
                        Containing:
                         - /home/user/sifs/project1.sif
                         - etc
                        eg /etc/sifs

  Functions (RESERVED names)
  hh           Output this help message.
  i            Re-source the current include file and print its location
  d            Select a sifs location by setting SIFS_DIR. 'c' will run this
               automatically if SIFS_DIR is not set.
  c            Source an include file from SIFS_DIR
  c [name]     Run 'c' with name of sif file (should be absolute path with .sif included).
  e            Edit the current included file.
  r            Reset sifs and your shell; basically set HOME to OLD_HOME (your original HOME).
  rc           shortcut for running 'r' then 'c'; use this to change to a sif file in a different
               sif repo to your current one.
  sifs.go      cd to SIFS_HOME 
  sifs.dir     cd to SIFS_DIR  (if you want to delete a file etc)

EOF
}



export OLD_HOME=$HOME
# TODO: Set bash history and similar to use OLD_HOME settings ? -- DBush 25-Mar-09


i() {
 echo $SIFS_INCLUDE
 . $SIFS_INCLUDE
}

d() {
  echo "Select a sif repository (sets SIFS_DIR)"
  echo "Type q to quit"
  tmpfile=/tmp/sifs.$$
  cat $SIFS_HOME/sifs.conf | grep -v ' *#'  >$tmpfile
  select d in $(cat $tmpfile); do
    if test "$REPLY" = "q"; then
      break
    fi
    export SIFS_DIR=$d
    break
  done
}

sifs.dir() {
  cd $SIFS_DIR
}
sifs.go() {
  cd $SIFS_HOME
}

c() {

  # If we want to run 'c' from a script.
  # First arg should be an aboslute path to a sif file
  # including the .sif extension.
  #
  # For cron, don't bother with this; just source
  # the sif file directly.  Use this facility here
  # to initialise a 'screen' session.

  if test -n "$1"; then
    if test -f "$1"; then
      export SIFS_DIR=$(dirname $1)
      export SIFS_INCLUDE=$1
      . $1
      return 0
    else
      return 1
    fi
  fi

  # Go into interactive mode...

  if test -z "$SIFS_DIR"; then d; fi
  if test -z "$SIFS_DIR"; then return 1; fi

  pushd $SIFS_DIR >/dev/null
  echo
  echo "Using $SIFS_DIR"
  echo
  echo "Type q to quit"
  select i in $(ls|grep '\.sif$'|sed -e 's/\.sif$//'); do
    if test "$REPLY" = "q"; then
      break
    fi
    r --soft  # Reset.
    export SIFS_INCLUDE=$SIFS_DIR/$i.sif
    . $i.sif
    break
  done
  popd >/dev/null
}

e() {
  $EDITOR $SIFS_INCLUDE
}

r() {
  if test -n $OLD_HOME; then
    export HOME=$OLD_HOME
  fi
  # We don't want help message to show.
  # People will assume the old include is still
  # active.
  unset h
  test "$1" != "--soft" && unset SIFS_DIR
  test "$1" != "--soft" && unset SIFS_INCLUDE
  . $SIFS_HOME/sifs.sh
}

rc() {
  r;c
}
