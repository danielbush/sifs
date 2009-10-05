# Copyright 2009 Daniel Bush
#
# This file is part of SIFS (simple include-file system).
# SIFS is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
# 
# You are free to use or modify SIFS as you please.



# See docs/reference.txt for official descriptions.


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
  SIFS_HISTFILE: 
                $SIFS_HISTFILE         
                - Stores recent sif files loaded interactively in
                  your shell.  You can access these via the 'j'
                  command.
  SIFS_ROOT_DIR:
                $SIFS_ROOT_DIR
                - top level SIFS_DIR.  Usually corresponds to entires
                  in SIFS_CONF .
  LOCAL_SIFS_ROOT
                $LOCAL_SIFS_ROOT
                - If set, is the location for searching for local sif files.
                  See il,el,cl commands.
  LOCAL_SIF     $LOCAL_SIF
                - If set, the location of last loaded local sif file.
                  Type 'il' to load/reload it.
  ======================================================================

  $(sifs.doc)
EOF
}

#------------------------------------------------------------------------
# INIT of SIFS
#
# Gets called at the bottom...

sifs.init() {
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
  if test ! -d "$SIFS_HOME" -o ! -e "$SIFS_CONF"; then
    echo "Either SIFS_HOME or SIFS_CONF is not set, SIFS can't continue."
    echo "Set SIFS_HOME to where you installed sifs;"
    echo "Set SIFS_CONF to the location of your sifs.conf file."
    return 1
  fi
  if test -z "$EDITOR"; then
    echo "Warning: please set EDITOR for proper functionality (in ~/.bashrc etc)."
  fi

  export OLD_HOME=$HOME
  # TODO: Set bash history and similar to use OLD_HOME settings ? -- DBush 25-Mar-09

  export SIFS_HISTFILE=$OLD_HOME/.sifs_history

  if test -z "$SIFS_DIR"; then
    sifs.cd.root $(head -n 1 $SIFS_CONF) 
  fi
  #if test -z "$SIFS_DIR"; then d; return $?; fi
  if test -z "$SIFS_DIR"; then 
    cat <<-EOF 
    'c' can't continue.  SIFS_DIR is not set
    and there doesn't seem to be an entry in your
    SIFS_CONF file ($SIFS_CONF).
EOF
    return 1;
  fi
}

#------------------------------------------------------------------------
# CHANGING ROOT SIFS DIR (AS LISTED IN SIFS_CONF)
#
# Should get called once during sifs.init
# or when we change sifs repo via SIFS_CONF.
# cf sifs.cd().

sifs.cd.root() {
  export SIFS_DIR=$1
  export SIFS_ROOT_DIR=$1
}

sifs.cd() {
  export SIFS_DIR=$1
}

d() {

  if test -n "$1"; then
    sifs.cd $1
  else

  # Interactive mode...

  echo "Select a sif repository (sets SIFS_DIR)"
  echo "Type q to quit"
  tmpfile=/tmp/sifs.$$
  cat $SIFS_CONF | grep -v ' *#'  >$tmpfile
  select d in $(cat $tmpfile); do
    if test "$REPLY" = "q"; then
      break
    fi
    sifs.cd.root $d
    break
  done

  fi

  c
}


#------------------------------------------------------------------------
# CHANING SIFS FILES

i() {
 echo $SIFS_INCLUDE
 . $SIFS_INCLUDE
}

sif() {
  local i
  if test -z "$1"; then
    echo "sif: needs name of sif file." >&2
    return 1
  fi

  test -f $1.sif && c $1.sif && echo $1.sif && return 0
  test -f $1 && c $1 && echo $1 && return 0
  test -f $SIFS_DIR/$1.sif && c $SIFS_DIR/$1.sif && echo $SIFS_DIR/$1.sif && return 0
  test -f $SIFS_DIR/$1 && c $SIFS_DIR/$1 && echo $SIFS_DIR/$1 && return 0

  echo "Type 'q' to quit"
  select i in $(sifs.find $1); do
    test -n "$i" && c $i.sif && sifs.histfile $i.sif
    # TODO: c <name> should probably call sifs.histfile.
    return 0
  done

  return 1

}

sifs.find() {
  # Show the full directory path in case sif files have the same
  # file name.
  #find -L $SIFS_ROOT_DIR -iname      "*$1*.sif" -type f | grep '\.sif$' | sed -e 's/\.sif$//'
  find -L $SIFS_ROOT_DIR -iwholename "*$1*.sif" -type f | grep '\.sif$' | sed -e 's/\.sif$//'
}


c() {
  local i;

  # If we want to run 'c' from a script.
  # First arg should be an aboslute path to a sif file
  # including the .sif extension.
  #
  # For cron, don't bother with this; just source
  # the sif file directly.  Use this facility here
  # to initialise a 'screen' session.

  if test -n "$1"; then
    if test -f "$1"; then
      # TODO: use 'd' and 'c.include' here...
      export SIFS_DIR=$(dirname $1)
      export SIFS_INCLUDE=$1
      . $1
      return 0
    else
      return 1
    fi
  fi

  # Go into interactive mode...

  while true; do
  pushd $SIFS_DIR >/dev/null  # SIFS_DIR may change.

  echo
  echo "Using $SIFS_DIR"
  echo
  echo "Type 'quit' to quit; '..' to go up a level"
  SIFS_rechoose=no
  i= ; j=
  select i in $(sifs.ls|sort); do
    test -n "$i" && c.include $i && break
    case "$REPLY" in
    quit) break ;;
    "..") c.include $REPLY; break ;; 
    "") ;; # To avoid running sifs.glob below.
    *) 
      select j in $(sifs.glob $REPLY); do
        test -n "$j" && c.include $j && break 2
        echo "Try again..."
        SIFS_rechoose=yes
        break 2
      done
    ;;
    esac
  done # select
  case "$SIFS_rechoose" in 
    yes) SIFS_rechoose=no ;; 
    *) break;; 
  esac

  popd >/dev/null
  done # while
  popd >/dev/null 2>&1  # Failsafe.

}

c.include() {
  local i;
    if test -n "$1"; then
      if test "$1" = ".."; then
        sifs.up
        SIFS_rechoose="yes"
        return 0
      elif test -d "$1" -o -h "$1"; then
        export SIFS_DIR=$SIFS_DIR/$1
        SIFS_rechoose="yes"
        return 0
      elif test -f $1.sif; then
        r --soft  # Reset.
        export SIFS_INCLUDE=$SIFS_DIR/$1.sif
        . $1.sif
        sifs.push $SIFS_INCLUDE
        SIFS_rechoose="no"
        sifs.histfile "$SIFS_DIR/$1" 
        return 0
      fi
    else
      return 1
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

#------------------------------------------------------------------------
# SIL - simple include libraries

# Source a sif file without updating SIF_* variables.

sil() {
  if test -z "$1"; then
    echo "sil: needs name of sil file." >&2
    return 1
  fi

  test -f $1.sif && . $1.sif && return 0
  test -f $1 && . $1 && return 0
  test -f $SIFS_DIR/$1.sif && . $SIFS_DIR/$1.sif && return 0
  test -f $SIFS_DIR/$1 && . $SIFS_DIR/$1 && return 0
  return 1

}

#------------------------------------------------------------------------
# CHANGING LOCAL SIFS FILES

# Source a local sif file.

cl() {
  local i;
  if test ! -d "$LOCAL_SIFS_ROOT"; then
    echo "Using current directory for LOCAL_SIFS_ROOT"
    LOCAL_SIFS_ROOT=$(pwd)
  fi

  test -n "$1" && . $1 && LOCAL_SIF="$1" && return 0

  echo "Using local root: $LOCAL_SIFS_ROOT"
  echo "q to quit"
  echo "afterwards: 'i' to load original sif; 'il' to reload local sif"
  pushd $LOCAL_SIFS_ROOT >/dev/null
  select i in $(find . -type f -name "*.sif" ); do
    case "$REPLY" in 
    q) break ;;
    esac
    . $i
    LOCAL_SIF=$LOCAL_SIFS_ROOT/$i
    break
  done
  popd >/dev/null
}


# Reload local sif file.

il() {
  test -z "$LOCAL_SIF" && 
    echo "LOCAL_SIF not set." && return 1
  test ! -e "$LOCAL_SIF" && 
    echo "LOCAL_SIF ($LOCAL_SIF) doesn't exist." && return 1
  echo "Reloading local sif file: $LOCAL_SIF"
  cl $LOCAL_SIF
}

el() {
  test -z "$LOCAL_SIF" && 
    echo "LOCAL_SIF not set." && return 1
  test ! -e "$LOCAL_SIF" && 
    echo "LOCAL_SIF ($LOCAL_SIF) doesn't exist." && return 1
  $EDITOR $LOCAL_SIF
}


#------------------------------------------------------------------------
# BOOKMARK FUNCTIONS

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

#------------------------------------------------------------------------
# sifs.* commands

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

# We need -L or else find will not look for sif files in symlinked
# directories.

sifs.ls() {
  find -L $SIFS_DIR -mindepth 1 -maxdepth 1 -type l -printf '%f\n';
  find -L $SIFS_DIR -mindepth 1 -maxdepth 1 -type d -printf '%f\n';
  find -L $SIFS_DIR -mindepth 1 -maxdepth 1 -type f -name "*.sif" -printf '%f\n'|sed -e 's/\.sif$//';
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
  find -L $SIFS_DIR -mindepth 1 -maxdepth 1 -type l -printf '%f\n'|grep -i $1;
  find -L $SIFS_DIR -mindepth 1 -maxdepth 1 -type d -printf '%f\n'|grep -i $1;
  find -L $SIFS_DIR -mindepth 1 -maxdepth 1 -type f -printf '%f\n' | grep '\.sif$'|sed -e 's/\.sif$//'|grep -i $1;
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

sifs.doc() {
  less $SIFS_HOME/docs/reference.txt
}

#------------------------------------------------------------------------
# SIFS History Tracking
#
# Record sif file that the user selects when using 'c'.
# Up to 9: SIFS1 ... SIFS9
# This is an interactive feature.
# Use full path to sif file in case a different SIFS_DIR
# was used (see 'c' for this).

j() {
  echo "Type 'q' to quit"
  select i in \
    $SIFS1 $SIFS2 $SIFS3 \
    $SIFS4 $SIFS5 $SIFS6 \
    $SIFS7 $SIFS8 $SIFS9
  do
    # 'c <name>' doesn't call sifs.push; only 'c' does.
    test -n "$i" && c $i && sifs.push $i && break
    break
  done
}

# Move SIFS1 to SIFS2, SIFS2 to ... , ... SIFS9 to nowhere .

sifs.push() {
  test -z "$1" && echo "Usage: sifs.push <sif-file>" && return 1
  sifs.push.pack $1
  for i in 9 8 7 6 5 4 3 2 1; do
    case "$i" in 1) continue;; esac
    # i => SIFS[i] ; j => SIFS[i-1]
    let j=$i-1; eval "SIFSj=\$SIFS$j"
    if test -n "$SIFSj"; then
      eval "SIFS$i=\$SIFS$j"
    fi
    eval "SIFS$j="
  done
  SIFS1=$1
}

# Remove any blank SIFS$i and renumber from 1.
# Remove $1 if it is in the list.

sifs.push.pack() {
  let j=1
  for i in 1 2 3 4 5 6 7 8 9; do
    eval "SIFSi=\$SIFS$i"
    if test -n "$SIFSi" -a "$SIFSi" != "$1" ; then 
      eval "local SIFStmp$j=\$SIFS$i"
      let j+=1
    fi
  done
  for i in 1 2 3 4 5 6 7 8 9; do
    eval "local SIFStmpi=\$SIFStmp$i"
    eval "SIFS$i=\$SIFStmpi"
  done
}

#------------------------------------------------------------------------
# Sifs history file

sifs.histfile() {
  case "$1" in
  "");;
  *)
    echo $1 >> $SIFS_HISTFILE
    sifs.histfile.truncate
  ;;
  esac
}

sifs.histfile.clear() {
  cat /dev/null >$SIFS_HISTFILE
}

sifs.histfile.edit() {
  $EDITOR $SIFS_HISTFILE
}

# The hist file is ordered oldest (top) to most recent (bottom).
# Weed out duplicate entries, retaining the most recent.
# Restrict final size to 20 entries.

sifs.histfile.truncate() {
  local line
  cat /dev/null >$SIFS_HISTFILE.reverse
  tac $SIFS_HISTFILE | while read line; do
    if ! grep -q "$line" $SIFS_HISTFILE.reverse; then
      echo $line >>$SIFS_HISTFILE.reverse
    fi
  done
  tac $SIFS_HISTFILE.reverse | tail -n 40  >$SIFS_HISTFILE
  test -f $SIFS_HISTFILE.reverse && rm $SIFS_HISTFILE.reverse
}

# Rewrite j().
# Not sure what to do with the old j().
# -- DB, Sun Oct  4 17:14:45 EST 2009

j() {
  echo "Type 'q' to quit"
  local i;
  select i in $(tac $SIFS_HISTFILE); do
    test -n "$i" && sif $i && sifs.histfile $i
    break
  done
}


sifs.init
