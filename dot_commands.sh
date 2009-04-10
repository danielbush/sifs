# Look for dot_commands which are of form 
#   .[A-z0-9]+
#   ..[A-z0-9]+
#   ..
# and convert to 
#   g [A-z0-9]+
#   m [A-z0-9]+
#   gg
#
# To use:
# 1) Set this to handle bash's ERR signal using 'trap'.
# 2) command_not_found_handle() should return 128
# for dot commands.  command_not_found_handle() 
# is a debian extension.

sifs.dot_commands() {
  if test $? = 128; then
    # Warning: BASH_COMMAND may be set to a command in
    # command_not_found_handle; case/if-expressions not included.
    cmd=$BASH_COMMAND  
    case $cmd in 
    ..)  gg ;;
    ..*) m $(echo $cmd|cut -c 3-) ;;
    .*)  g $(echo $cmd|cut -c 2-) ;;
    *);;
    esac
  fi
}
trap sifs.dot_commands ERR


# If someone types dot command (.<string>) then
# return 128 and allow bash's 'trap ERR'
# to handle it.
# Otherwise return standard 127.
#
# NOTES
# This handle is a debian extension.
# Don't run simple commands here as this will
# reset BASH_COMMAND.
# Also, changing dir here doesn't work anyway.
# -- DBush 10-Apr-09.

command_not_found_handle() {
  case "$1" in
  .*) return 128;;
  *)  return 127;;
  esac
}
