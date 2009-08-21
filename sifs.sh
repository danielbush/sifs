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
  . $SIFS_HOME/edit.sif
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

  OLD_HOME:     $OLD_HOME          
                - Original HOME directory before SIFS was loaded.
                  Only useful if you change HOME in your sif file.
  SIFS_INCLUDE: $SIFS_INCLUDE      
                - Current sif file (sourced into your current shell).
  SIFS_CONF:    $SIFS_CONF         
                - Location of your sifs.conf file.
  SIFS_DIR:     $SIFS_DIR         
                - Current location for finding .sif files.
  SIFS_HOME:    $SIFS_HOME         
                - Location of the SIFS system
                  eg SIFS_HOME=/home/danb/sifs  or /etc/sifs

  Variables managed by the current include file:
  HOME:         $HOME


  Locations:

  SIFS_HOME/sifs.sh   - The main sifs file which should be loaded into your system at login
  SIFS_CONF           - Store locations of sif files
                        eg /home/user/sifs.conf
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
  sif [name]   Tries to intelligently load a sif file into the current
               shell (either interactive or batch mode).
               If you've already selected a SIFS_DIR, then you can
               invoke a name of a sif file within SIFS_DIR simply as
                 sif [name] 
               where file is [name].sif .
               However, 'sif' will look for all variants:
                 [name].sif
                 [name]  # Assumes the user has suffixed with .sif.
                 SIFS_DIR/[name].sif
                 SIFS_DIR/[name]
  c [name]     At the moment, this is the raw routine called by 'sif'.
               [name] has to be absolute and include the .sif suffix.
  e            Edit the current included file.
  r            Reset sifs and your shell; basically set HOME to OLD_HOME (your original HOME).
  rc           shortcut for running 'r' then 'c'; use this to change to a sif
               file in a different sif repo to your current one.

  The following g/m functions are to help you jump about from one location to another.
  m <char>     store current directory in a variable \$STASH_<char>
  m -          clear (unset) all \$STASH_<char>
  g            view all STASH variables
  g <char>     cd to \$STASH_<char>
  gg           Go to STASH_LAST; STASH_LAST is set to your current location by 'g <char>' command
               prior to moving you.
  If you've enabled dot_commands (default) and bash supports 
  command_not_found_handle(), then you will also have the following shortcuts:
  .<char>      same as: g <char>
  ,<char>      same as: m <char>

  sifs.help       General help and intro
  sifs.edit.help  Help file for sifs editing eg creating new sif files etc.

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
      select j in $(sifs.glob $REPLY); do
        c.include $j
        break
      done
      break
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
