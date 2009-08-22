# Copyright 2009 Daniel Bush
#
# This file is part of SIFS (simple include-file system).
# SIFS is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
# 
# You are free to use or modify SIFS as you please.

# Include optional dot commands.
# Unset SIFS_DOT_COMMANDS or set to 'n' to stop.
# Dot commands  will overwrite command_not_found_handle.
# Because some people may not like this, 
# it is not included directly in this file.

case "$SIFS_DOT_COMMANDS" in 
y|Y) . $SIFS_HOME/dot_commands.sh ;;
esac


if ! test -n "$BASH"; then
  echo "Not starting SIFS - you need a bash shell."
  return 1
fi
if test -d "$SIFS_HOME" -a -e "$SIFS_CONF"; then
  echo "SIFS vars are set."
else
  echo "Either SIFS_HOME or SIFS_CONF is not set, SIFS can't continue."
  echo "Set SIFS_HOME to where you installed sifs;"
  echo "Set SIFS_CONF to the location of your sifs.conf file."
  return 1
fi
if test -z "$EDITOR"; then
  echo "Warning: please set EDITOR for proper functionality (in ~/.bashrc etc)."
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
  ======================================================================
  You should see values; if there are any BLANKS, your sifs
  system may not be working properly ;)

  HOME:         $HOME
  OLD_HOME:     $OLD_HOME          
                - Original HOME directory before SIFS was loaded.
                  Only useful if you change HOME in your sif file.
  SIFS_INCLUDE: $SIFS_INCLUDE      
                - Current sif file (sourced into your current shell).
  SIFS_CONF:    $SIFS_CONF         
                - Location of your sifs.conf file that stores one or more
                  SIFS_DIR's.
                - See SIFS_HOME/sifs.conf.example.
  SIFS_DIR:     $SIFS_DIR         
                - Current location for finding .sif files.
  SIFS_HOME:    $SIFS_HOME         
                - Location of the SIFS system software
                  eg SIFS_HOME=/home/danb/sifs.sys  or /etc/sifs.sys
                  or whatever you want to call it.
                  I often reserve 'sifs' by itself for a SIFS_DIR.
  ======================================================================

  $(cat $SIFS_HOME/docs/reference.txt)
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
  cat $SIFS_CONF | grep -v ' *#'  >$tmpfile
  select d in $(cat $tmpfile); do
    if test "$REPLY" = "q"; then
      break
    fi
    export SIFS_DIR=$d
    break
  done
}

sif() {
  if test -z "$1"; then
    echo "sif: needs name of sif file." >&2
    return 1
  fi

  test -f $1.sif && c $1.sif && return 0
  test -f $1 && c $1 && return 0
  test -f $SIFS_DIR/$1.sif && c $SIFS_DIR/$1.sif && return 0
  test -f $SIFS_DIR/$1 && c $SIFS_DIR/$1 && return 0
  return 1

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
  select i in $(sifs.ls|sort); do
    c.include $i
    case "$REPLY" in
    q) break ;;
    "") ;;
    *) 
      j=
      select j in $(sifs.glob $REPLY); do
        c.include $j
        break
      done
      # Only break if user typed a valid number.
      test -n "$j" && break
    ;;
    esac
  done
  popd >/dev/null
}

c.include() {
    if test -n "$1"; then
      if test -d "$1"; then
        export SIFS_DIR=$SIFS_DIR/$1
        c
        break
      elif test -f $1.sif; then
        r --soft  # Reset.
        export SIFS_INCLUDE=$SIFS_DIR/$1.sif
        . $1.sif
        break
      fi
    fi
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

m() {
  case "$1" in
  [a-z0-9A-Z]*) eval STASH_$1=$(pwd);;
  -) for i in $(set | grep '^STASH_' | sed -e 's/=.*$//'); do unset $i; done;;
  *) echo "Usage: m <char> where <char> might be a,b,c or 1,2,3 ... etc" 
     echo "If <char> is '-', settings will be cleared."
     return 1 ;;
  esac
}
g() {
  case "$1" in
  "") set | grep '^STASH_' | sed -e 's/^STASH_//;s/=/: /' ;;
  *) if echo "$1" | egrep -q '^[0-9a-zA-Z_]+$'; then
       eval "_stash=\"\$STASH_$1\""
       if test -n $_stash; then 
         STASH_LAST=$(pwd); 
         echo $_stash; 
         cd $_stash; 
       fi
     fi
  esac
}
gg() {
  if test -n "$STASH_LAST"; then
    _stash=$(pwd)
    echo $STASH_LAST
    cd $STASH_LAST
    STASH_LAST=$_stash
  fi
}

# sifs.* commands
#-----------------------------------------------------

sifs.conf() {
  $EDITOR $SIFS_CONF
}

sifs.edit() {
  $EDITOR $SIFS_HOME/sifs.sh
}

sifs.template() {
  if test -n "$1"; then

  if test -e "$1"; then
    echo "$1 already exists - delete or rename it."
    read tmp  # Pause here.
  else
    cat $SIFS_HOME/sifs.template >$1
    echo "Created $1"
    echo "Edit it? [y] "
    read resp
    case "$resp" in
    n|N|no|NO|No) ;;
    *) $EDITOR $1 ;;
    esac
  fi

  else
    less $SIFS_HOME/sifs.template
  fi

}

sifs.add() {
  if test -z "$SIFS_DIR"; then
    echo "SIFS_DIR not set."
    return 1
  fi
  sifs.template $SIFS_DIR/$1.sif
}

sifs.sys() {
  cd $SIFS_HOME
}

sifs.go() {
  test ! -d $SIFS_DIR && echo 'SIFS_DIR not set or not a directory.' && return 1
  cd $SIFS_DIR
}

sifs.ls() {
  find $SIFS_DIR -mindepth 1 -maxdepth 1 -type d -printf '%f\n';
  find $SIFS_DIR -mindepth 1 -maxdepth 1 -type f -name "*.sif" -printf '%f\n'|sed -e 's/\.sif$//';
}

sifs.mkdir() {
  if test -z "$1"; then
    echo "Usage: sifs.mkdir <dir_name>"
    return 1
  fi
  if test -z "$SIFS_DIR"; then
    echo "SIFS_DIR not set."
    return 1
  fi
  mkdir $SIFS_DIR/$1
}

# Probably should call it regex, not glob (!).
sifs.glob() {
  find $SIFS_DIR -mindepth 1 -maxdepth 1 -type d -printf '%f\n'|grep $1;
  find $SIFS_DIR -mindepth 1 -maxdepth 1 -type f -printf '%f\n' | grep '\.sif$'|sed -e 's/\.sif$//'|grep $1;
}

sifs.up() {
  export SIFS_DIR=$(dirname $SIFS_DIR)
}

sifs.help() {
  less $SIFS_HOME/docs/editing.txt
}

sifs.readme() {
  less $SIFS_HOME/README
}

sifs.quickstart() {
  less $SIFS_HOME/QUICKSTART
}
