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
  SIFS_GO:      $SIFS_GO         
                - File that records actions performed using sifs.go.
                  Note: you usually wrap it with a go() function.
  SIFS_SILFILE: 
                $SIFS_SILFILE
                - A file that records which sil files you have included into your
                  current shell.
           
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

  # sil files are specific to a given bash shell...
  # This init function may get called several times
  # during it.

  if ! test "$SIFS_SILFILE" = "/tmp/$$.sifs_silfile"; then
    SIFS_SILFILE=/tmp/$$.sifs_silfile
    cat /dev/null >$SIFS_SILFILE
  fi
  export SIFS_SILFILE
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

  # File is completely specified:
  test -f $1 && echo $1|grep -q '^/' && c $1 && echo $1 && return 0
  test -f $SIFS_DIR/$1.sif && c $SIFS_DIR/$1.sif && echo $SIFS_DIR/$1.sif && return 0

  #test -f $1.sif && c $1.sif && echo $1.sif && return 0
  #test -f $1 && c $1 && echo $1 && return 0
  #test -f $SIFS_DIR/$1.sif && c $SIFS_DIR/$1.sif && echo $SIFS_DIR/$1.sif && return 0
  #test -f $SIFS_DIR/$1 && c $SIFS_DIR/$1 && echo $SIFS_DIR/$1 && return 0

  echo "Type 'q' to quit"
  select i in $(sifs.find $1); do
    test -n "$i" && c $i.sif && sifs.histfile.track $i.sif
    # TODO: c <name> should probably call sifs.histfile.track.
    return 0
  done

  echo "sif: couldn't load requested sif file: $1." >&2
  return 1

}

sifs.find() {
  # Show the full directory path in case sif files have the same
  # file name.
  local pattern=$1
  test -z "$pattern" && pattern='.'
  find -L $SIFS_ROOT_DIR -iname "*.sif" -type f | grep -i $pattern | grep '\.sif$' | sed -e 's/\.sif$//'
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
      r --soft  # Reset.
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
        if pushd $SIFS_DIR/$1 >/dev/null 2>&1 ; then
          popd >/dev/null
          export SIFS_DIR=$SIFS_DIR/$1
          SIFS_rechoose="yes"
          return 0
        else
          c $SIFS_DIR/$1.sif
          return 0
        fi
      elif test -f $1.sif; then
        c $SIFS_DIR/$1.sif
        SIFS_rechoose="no"
        sifs.histfile.track "$SIFS_DIR/$1.sif" 
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

# Source a sil file.
# Use sil files for general routines, global variables shared between several
# sif files etc.
# Sil files are usually namespaced or written in a way that they 
# don't clash with the current sif file you are using.
# For instance, you would probably not define a go() function unless
# you intend not to use it in your sif files that use the sil file.
#
# Try to keep your sil file names unique.  This way you can say
#    sil <name>
# instead of
#    sil </path/to/name.sil>
# sil <name> will return the first sil found if more than one.


sil() {
  local file
  if test -z "$1"; then
    sil.show
    return 0
    #echo "sil: needs name of sil file." >&2
    #return 1
  fi

  # For SIF_SILFILE/sil.show which specifies exact filepath:
  if test -f $1; then
    echo $1
    . $1
    return 0
  fi

  file=$(sil.find $1|head -n 1)

  if test -n "$file"; then
    echo $file.sil
    if ! grep -q $file.sil $SIFS_SILFILE; then
      echo $file.sil >>$SIFS_SILFILE
    fi
    . $file.sil
    return 0
  fi

  echo "Couldn't find sil file ($1)."
  return 1

}

sil.find() {
  local pattern=$1
  test -z "$pattern" && pattern='.'
  (find -L $SIFS_ROOT_DIR -iname "*.sil" -type f | grep '\.sil$' | egrep -i "^$1|\b$1" | sed -e 's/\.sil$//'
  find -L $SIFS_ROOT_DIR -iname "*.sil" -type f | grep '\.sil$' | grep -i "$1" | sed -e 's/\.sil$//')|uniq
    # What I'm trying to do here is to make the search result
    # as relevant as possible by search for sil files with
    # /<pattern> first, then <pattern>; ie when your <pattern> is
    # small, you are more likely to type it completely.
    #
    # To make more efficient we could call 'find' once to a file
    # and grep this file.  There is some underlying buffering going
    # on anyway.
}
sil.find.all() {
  local pattern=$1
  test -z "$pattern" && pattern='.'
  find -L $SIFS_ROOT_DIR -iname "*.sil" -type f | grep '\.sil$' | grep -i $1 | sed -e 's/\.sil$//'
}

sil.show() {
  local i
  echo "Select a file to reload it into your shell or "
  echo "'q' to quit"
  select i in $(cat $SIFS_SILFILE); do
    case $REPLY in q*) break;; esac
    sil $i
    break
  done
}

sil.edit() {
  local i
  echo "'q' to quit"
  if test -n "$1"; then
    file=$(sil.find $1|head -n 1)
    test -z "$file" && echo "Can't find sil file." && return 1
    $EDITOR $file.sil
  else
    select i in $(sil.find.all); do
      case $REPLY in q*) break;; esac
      $EDITOR $i.sil
    done
  fi
}

sil.add() {
  echo -n "Create $SIFS_DIR/$1.sil? [y] "
  read resp
  case "$resp" in y*|Y*|"");; *)return 1;; esac
  touch $SIFS_DIR/$1.sil

  echo -n "Do you want to edit? [y] "
  read resp
  case "$resp" in y*|Y*|"");; *)return 1;; esac
  $EDITOR $SIFS_DIR/$1.sil
}

#------------------------------------------------------------------------
# CHANGING LOCAL SIFS FILES

# Source a local sif file.

cl() {
  local i;
  echo "*** Type cl.info to view description of local sif files that set SIF_DESC."
  #if test ! -d "$LOCAL_SIFS_ROOT"; then
    #echo "Using current directory for LOCAL_SIFS_ROOT"
    #LOCAL_SIFS_ROOT=$(pwd)
  #fi
  LOCAL_SIFS_ROOT=$(pwd)

  test -n "$1" && . $1 && LOCAL_SIF="$1" && return 0

  echo "Using local root: $LOCAL_SIFS_ROOT"
  echo "q to quit"
  echo "afterwards: 'i' to load original sif; 'il' to reload local sif"
  pushd $LOCAL_SIFS_ROOT >/dev/null
  select i in $(find . -type f -name "*.sif" ); do
    case "$REPLY" in 
    q) break ;;
    esac
    LOCAL_SIF=$LOCAL_SIFS_ROOT/$i
      # LOCAL_SIF should be available to $i
    . $i
    break
  done
  popd >/dev/null
}

cl.info() {
  local i
  for i in $(find . -type f -name "*.sif"); do
        echo "$(basename $i): "
        grep '^SIF_DESC=' $i | sed -e 's/^SIF_DESC=//'
        echo
  done
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
  [a-z0-9A-Z]*) eval STASH_$1="'$(pwd)'";;
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
       if test -n "$_stash"; then 
         STASH_LAST=$(pwd); 
         echo $_stash; 
         cd "$_stash"; 
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

sifs.dir() {
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
# Sifs history file

sifs.histfile.track() {
  touch $SIFS_HISTFILE
  if test -e "$1"; then
    grep -v "^${1}$" $SIFS_HISTFILE >$SIFS_HISTFILE.tmp
    mv $SIFS_HISTFILE.tmp $SIFS_HISTFILE
    echo $1 >> $SIFS_HISTFILE
  fi
}

sifs.histfile.clear() {
  cat /dev/null >$SIFS_HISTFILE
}

sifs.histfile.edit() {
  $EDITOR $SIFS_HISTFILE
}

j() {
  local i n;
  n=$1
  test -z "$1" && n=15
  echo "Type 'q' to quit"
  select i in $(tac $SIFS_HISTFILE|head -n $n); do
    test -n "$i" && sif $i && sifs.histfile.track $i
    break
  done
}

#------------------------------------------------------------------------
# Sifs.go helper functions
#
# Helper function for use in your sif files.

SIFS_GO=/tmp/$$.sifs.go.histfile
_SIFS_GO_EXCLUDE="/\."
SIFS_WENT=
  # Record where sifs.go took us.

# Find directory or file matching first several characters
# in a given location.

# sifs.go <search-path> <pattern> <exclude-pattern>

sifs.go(){
  local exclude_pattern
  SIFS_WENT=
  test -z "$2" && cd "$1" && sifs.go.track $1 && return

  # If you pass in full path as 2nd arg...
  test -d $2 && cd $2 && sifs.go.track $2 && return

  test -n "$3" && exclude_pattern=$3 || exclude_pattern=$SIFS_GO_EXCLUDE
  test -z "$exclude_pattern" && exclude_pattern=$_SIFS_GO_EXCLUDE

  echo 'q to quit'
  select i in $(find $1 -iname "*$2*"|egrep -v $exclude_pattern ); do
    case "$REPLY" in q|Q) break;; esac
    test -d $i && cd $i && sifs.go.track $i && return
    break
  done
}

# Record entry made by sifs.go.

sifs.go.track(){
  touch $SIFS_GO
  if test -e "$1"; then
    SIFS_WENT=$1
      # Record where we went to.
    grep -v "^${1}$" $SIFS_GO >$SIFS_GO.tmp
    mv $SIFS_GO.tmp $SIFS_GO
    echo $1 >> $SIFS_GO
  fi
}

# Allow user to select from sifs.go history.

sifs.go.select(){
  touch $SIFS_GO
  select i in $(tac $SIFS_GO); do
    test -d $i -o -f $i && sifs.go.track $i
    test -d $i && cd $i && return
    test -f $i && $EDITOR $i && return
    break
  done
}

gohist(){
  sifs.go.select
}



#------------------------------------------------------------------------
# Sifs.utils.* - helpful utilities
#
#

sifs.utils.add-to-path() {
  export OLDPATH=$PATH
  if ! echo $PATH | grep -q "$1"; then
    export PATH=$1:$PATH
  fi
}

sifs.utils.prepend-to-var() {
  var=$1; val=$2
  eval "export OLD$var=\$var"
  eval "if ! echo \$$var | grep -q \"\$val\"; then export $var=\$val:\$$var; fi"
}

# Use only if you've run add-to-path and want to unset it
# within a current interactive session.

sifs.utils.reset-path() {
  test -n "$OLDPATH" && export PATH=$OLDPATH && return 0
}


#------------------------------------------------------------------------

sifs.init
