#!/bin/bash
flags='bc:ihjklmnp:qrs:uvwx:z'
xai_help () { cat <<EOF
    Usage: xai [-$flags]
    -b  run in background (no menu, continues after terminal is closed)
    -c  overrides conversation mode setting (true/false)
    -i  install and setup wizard
    -h  display this help
    -k  directly start in keyboard mode
    -l  directly listen for one command (ex: launch from physical button)
    -m  mute mode (overrides settings)
    -n  directly start xaï without menu
    -q  quit xai if running in background
    -r  uninstall
    -s  just say something and exit, ex: ${0##*/} -s 'hello world'
    -u  force update
    -v  troubleshooting mode
    -w  no colors in output
    -x  execute order, ex: ${0##*/} -x "switch on lights"
EOF
}

headline="NEW: Update default timeout in Settings > Audio"


xai_get_current_dir () {
    SOURCE="${BASH_SOURCE[0]}"
    while [ -h "$SOURCE" ]; do
      DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
      SOURCE="$(readlink "$SOURCE")"
      [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE"
    done
    echo "$( cd -P "$( dirname "$SOURCE" )" && pwd )"
}

xai_dir="$(xai_get_current_dir)"


cd "$xai_dir"

shopt -s nocasematch
source utils/utils.sh
source utils/audio.sh
source utils/configure.sh


# Check not ran as root

if [ "$EUID" -eq 0 ]; then
    echo "ERROR: Xaï cannot be used as root !" 1>&2
    exit 1
fi


# Check the platform if is compatible or no
dependencies=(awk curl iconv nano perl sed sox wget)
case "$OSTYPE" in
  linux*)       plateform="linux"
                xai_arch="$(uname -m)"
                xai_os_name="$(cat /etc/*release | grep ^ID= | cut - f2 -d=)"
                xai_os_version="$(cat /etc/*release | grep ^VERSION_ID= | cut -f2 -d= | tr -d '"')"
                dependencies+=(alsamixer aplay arecord whiptail libsox-fmt-mp3)
                xai_tmp="/dev/shm"
                ;;
        *)      xai_error "ERROR: $OSTYPE is not a supported platform"
                exit 1;;
esac
source utils/utils_$platform.sh

#Initiate files & directories
lockfile="$xai_tmp/xai.lock"
audiofile="$xai_tmp/xai_record.wav"
forder="$xai_tmp/xai_order"
xai_say_queue="$xai_tmp/xai_say"
rm -f $audiofile

# default flags
quiet=false
verbose=false
keyboard=false
just_say=false
just_listen=false
just_execute=false
no_menu=false
xai_start_in_background=false
while getopts ":$flags" o; do
  case "${o}" in
            b) xai_start_in_background=true;;

            c) conversation_mode_override=${OPTARG};;

            h) xai_help
              exit;;

            m) quiet=true;;

            n) no_menu=true;;

            q) xai_kill
              exit $?;;

            r) source uninstall.sh

            s) xai_just_say="${OPTARG}"
            if [ -z "$xai_say" ]; then
              xai_error "ERROR: Phrase cannot be empty"
              exit 1
            fi

            u) configure "load"
            xai_check_update "./" true
            touch config/last_update_check
            exit;;

            v) verbose=true;;

            w) unset _reset _red _orange _green _gray _blue _cyan _pink;;

            x) just_execute="${OPTARG}"
                if [ -z "$just_execute" ]; then
                  xai_error "ERROR: Order cannot be empty"
                  exit 1
                fi

            z) xai_build
            exit $?;;
        *)      echo -e "XAI : Invalid Option\n Please try 'xai -h' for more information."  1>&2
              exit 1;;
      esac
done

if $xai_start_in_background; then
  if xai_on; then
      xai_error "Xaï is already running"
      xai_warning "Please run the command 'xai -q' to stop it"
      exit 1
    fi
    xai_start_in_background
    exit
  fi

xai_check_dependencies
configure "load" || wizard
$xai_use_bluetooth && xai_bt_init
$send_usage_stats && ( xai_ga_send_hit & )

trigger_sanitized=$(xai_sanitize "$trigger")
[ -n "$conversation_mode_override" ] && conversation_mode=$conversation_mode_override

if ( [ "$play_hw" != "false" ] || [ "$rec_hw" != "false" ] ) && [ ! -f ~/.asoundrc ]; then
    update_alsa $play_hw $rec_hw  # retro compatibility
    dialog_msg<<EOM
XAÏ has created .asoundrc in your homefolder
YOU MUST REBOOT YOUR SYSTEM TO TAKE IT INTO ACCOUNT
EOM
      echo "You can reboot your system with the command : 'sudo reboot'"
      exit
fi
