#!/bin/bash

xai_version="$(cat config/version 2>/dev/null)"

xai_dir="$xai_dir"


username=


trigger=


order=


language=


platform=


xai_arch=


xai_os_name=


xai_os_version=


xai_possible_answers=false


xai_api=false


xai_json=false

xai_ip="$(/sbin/ifconfig | sed -En 's/127.0.0.1//;s/.*inet (ad[d]?r:)?(([0-9]*\.){3}[0-9]*).*/\2/p')"

xai_is_paused=false


xai_sig_pause=$(kill -l SIGUSR1)


xai_sig_listen=$(kill -l SIGUSR2)


x_xai_updated=false


xai_check_dependencies () {
    local missings=()
    for package in "${dependencies[@]}"; do
        xai_is_installed "$package" || missings+=($package)
    done
    if [ ${#missings[@]} -gt 0 ]; then
        xai_warning "You must install missing dependencies before going further"
        for missing in "${missings[@]}"; do
            echo "$missing: Not found"
        done
        xai_yesno "Attempt to automatically install the above packages?" || exit 1
        xai_update # split xai_update and xai_install to make overall XAÏ installation faster
        xai_install ${missings[@]} || exit 1
    fi

    if [[ "$platform" == "linux" ]]; then
        if ! groups "$(whoami)" | grep -qw audio; then
            xai_warning "Your user should be part of audio group to list audio devices"
            xai_yesno "Would you like to add audio group to user $USER?" || exit 1
            sudo usermod -a -G audio $USER # add audio group to user
            xai_warning "Please logout and login for new group permissions to take effect, then restart XAÏ"
            exit
        fi
    fi
}


xai_repeat_last_command () {
    eval "$xai_last_command"
}

xai_json_separator=""

# $1 - key
# $2 - value
xai_print_json () {
    message=${2//\"/\\\\\"} # escape double quotes
    message=${message//[$'\t']/    } # replace tabs with spaces
    message=${message//%/%%} # escape percentage chars for printf
    printf "$xai_json_separator{\"$1\":\"${message}\"}"
    xai_json_separator=","
}

xai_get_commands () {
    grep -v "^#" XAÏ-commands
    while read; do
        cat plugins_enabled/$REPLY/${language:0:2}/commands 2>/dev/null
    done <plugins_order.txt
}

xai_display_commands () {
    xai_info "User defined commands:"
    xai_debug "$(grep -v "^#" XAÏ-commands | cut -d '=' -f 1 | pr -3 -l1 -t)"
    while read plugin_name; do
        xai_info "Commands from plugin $plugin_name:"
        xai_debug "$(cat plugins_enabled/$plugin_name/${language:0:2}/commands 2>/dev/null | cut -d '=' -f 1 | pr -3 -l1 -t)"
    done <plugins_order.txt
}

xai_add_timestamps () {
    while IFS= read -r line; do
        echo "$(date) $line"
    done
}

say () {
    #set -- "${1:-$(</dev/stdin)}" "${@:2}" # read commands if $1 is empty... #195
    local phrases="$1"
    phrases="$(echo -e "$phrases" | sed $'s/\xC2\xA0/ /g')" #574 remove non-breakable spaces
    #phrase="${phrase/\*/}" #TODO * char causes issues with google & OSX say TTS, looks like no longer with below icon
    xai_hook "start_speaking" "$phrases" #533
    while read -r phrase; do #591 can be multiline
        if $xai_json; then
            xai_print_json "answer" "$phrase" #564
        else
            echo -e "$_pink$trigger$_reset: $phrase"
        fi
        $quiet && break #602
        if $xai_api; then # if using API, put in queue
            if xai_is_started; then
                echo "$phrase" >> $xai_say_queue # put in queue (read by say.sh)
            else
                xai_error "ERROR: XAÏ is not running"
                xai_success "HELP: Start XAÏ using XAÏ -b"
            fi
        else # if using XAÏ, speak synchronously
            $tts_engine'_TTS' "$phrase"
        fi
    done <<< "$phrases"
    xai_hook "stop_speaking"
}

xai_curl () {
    local curl_command="curl --silent --fail --show-error $@"
    $verbose && xai_debug "DEBUG: $curl_command"
    response=$($curl_command 2>&1)
    local return_code=$?
    if [ $return_code -ne 0 ]; then
        xai_error "ERROR: $response"
    else
        $verbose && xai_debug "DEBUG: $response"
    fi
    return $return_code
}


xai_spinner () {
	while kill -0 $1 2>/dev/null; do
		for i in \| / - \\; do
			printf '%c\b' $i
			sleep .1
		done
	done
    wait $1 2>/dev/null
    return $?
}

xai_read_dom () {
    local IFS=\>
    read -d \< ENTITY CONTENT
}

update_alsa () {
    echo "Updating ~/.asoundrc..."
    cat<<EOM > ~/.asoundrc
pcm.!default {
  type asym
   playback.pcm {
     type plug
     slave.pcm "$1"
   }
   capture.pcm {
     type plug
     slave.pcm "$2"
   }
}
EOM
    echo "Reloading Alsa..."
    sudo /etc/init.d/alsa-utils restart
}


xai_sanitize () {
    local string="$1"
    local replace_spaces_with="$2"


    [[ -n "$replace_spaces_with" ]] && string=${string// /$replace_spaces_with}


    echo $string \
        | tr '[:upper:]' '[:lower:]' \
        | iconv -f utf-8 -t ascii//TRANSLIT \
        | sed "s/[^-a-zA-Z0-9 $replace_spaces_with]//g"
}

_reset="\033[0m"
_red="\033[91m"
_orange="\033[93m"
_green="\033[92m"
_gray="\033[2m"
_blue="\033[94m"
_cyan="\033[96m"
_pink="\033[95m"


# $1 - message to display
# $2 - message type (error/warning/success/debug)
# $3 - color to use
xai_message() {
    if $xai_json; then
        xai_print_json "$2" "$1"
    else
        echo -e "$3$1$_reset"
    fi
}

xai_error() { xai_message "$1" "error" "$_red" 1>&2 ;}

xai_warning() { xai_message "$1" "warning" "$_orange" ;}

xai_success() { xai_message "$1" "success" "$_green" ;}

xai_info() { xai_message "$1" "info" "$_blue" ;}

xai_debug() { xai_message "$1" "debug" "$_gray" ;}


xai_press_enter_to_continue () {
    xai_debug "Press [Enter] to continue"
    read
}

xai_start_in_background () {
    nohup XAÏ -$($verbose && echo v)n 2>&1 | xai_add_timestamps >> XAÏ.log &
    cat <<EOM
XAÏ has been launched in background
To view XAÏ output:
XAÏ and select "View output"
To check if XAÏ is running:
pgrep -laf XAÏ.sh
To stop XAÏ:
XAÏ and select "Stop XAÏ"
You can now close this terminal
EOM
}

xai_is_started () {
    [ -e $lockfile ] && kill -0 `cat $lockfile` 2>/dev/null
}

xai_kill_XAÏ () {
    if [ -e $lockfile ]; then
        local pid=$(cat $lockfile) # process id of XAÏ
        if kill -0 $pid 2>/dev/null; then
            kill -TERM $pid #607
            echo "XAÏ has been terminated"
            return 0
        fi
    fi
    echo "XAÏ is not running"
    return 1
}

xai_hook () {
    #$xai_api && return # don't trigger hooks from API #XAÏ-api/issues/11
    local hook="$1"
    shift
    source hooks/$hook "$@" 2>/dev/null # user hook
    shopt -s nullglob
    for f in plugins_enabled/*/hooks/$hook; do source $f "$@"; done # plugins hooks
    shopt -u nullglob
}

xai_pause_resume () {
    if $xai_is_paused; then
        xai_is_paused=false
        xai_debug "resuming..."
    else
        xai_is_paused=true
        xai_debug "pausing..."
    fi
}

# Public: Exit properly XAÏ
# $1 - Return code
#
# Returns nothing
xai_exit () {
    local return_code=${1:-0}

    # If using json formatting, terminate table
    $xai_json && echo "]"

    # reset font color (sometimes needed)
    $xai_api || echo -e $_reset

    # Trigger program exit hook if not from api call
    $xai_api || xai_hook "program_exit" $return_code

    # termine child processes (ex: HTTP Server from XAÏ API Plugin)
    local xai_child_pids="$(jobs -p)"
    if [ -n "$xai_child_pids" ]; then
        kill $(jobs -p) 2>/dev/null
    fi

    exit $return_code
}

xai_check_updates () {
    local initial_path="$(pwd)"
    local repo_path="${1:-.}" # . default value if $1 is empty (current dir)
    local force=${2:-false} # false default value if $2 is empty
    cd "$repo_path"
    local repo_name="$(basename $(pwd))"
    local is_XAÏ="$([ "$repo_name" == "XAÏ" ] && echo "true" || echo "false")"
    local branch="$( $is_XAÏ && echo "$xai_branch" || echo "master")"
    printf "Checking updates for $repo_name..."
	read < <( git fetch origin -q & echo $! ) # suppress bash job control output
    xai_spinner $REPLY
	case $(git rev-list HEAD...origin/$branch --count || echo e) in
		"e") xai_error "Error";;
		"0") xai_success "Up-to-date";;
		*)	 xai_warning "New version available"
             changes=$(git fetch -q 2>&1 && git log HEAD..origin/$branch --oneline --format="- %s (%ar)" | head -5)
             if $force || dialog_yesno "A new version of $repo_name is available, recent changes:\n$changes\n\nWould you like to update?" true >/dev/null; then
				 # display recent commits in non-interactive mode
                 $force && echo -e "Recent changes:\n$changes"

                 #git reset --hard HEAD >/dev/null # don't override local changes (config.sh)

                 local xai_config_changed=false
                 if $is_XAÏ; then
                     # inform XAÏ is updated to ask for restart
                     xai_XAÏ_updated=true
                 elif [ 1 -eq $(git diff --name-only ..origin/master config.sh | wc -l) ]; then
                     # save user configuration if config.sh file changed on repo (only for plugins)
                     xai_config_changed=true
                     mv config.sh config.sh.old # save user config
                 fi

                 # pull changes from repo
                 printf "Updating $repo_name..."
                 read < <( git pull -q & echo $! ) # suppress bash job control output
                 xai_spinner $REPLY
                 [ -f update.sh ] && source update.sh # source new updated file from git
            	 xai_success "Done"

                 # if config changed, merge with user configuration and open in editor
                 if $xai_config_changed; then
                     sed -i.old -e 's/^/#/' config.sh.old # comment out old config file
                     echo -e "\n#Your previous config below (to copy from)" >> config.sh
                     cat config.sh.old >> config.sh # and append to new config file (for reference)
                     rm -f *.old # remove temp files
                     if $force; then
                         xai_warning "Config file has changed, reset your variables"
                     else
                         dialog_msg "Config file has changed, reset your variables"
                         editor "config.sh"
                     fi
                 fi
			 fi
			 ;;
	esac
    cd "$initial_path"
}

xai_plugins_check_updates () {
    shopt -s nullglob
    for plugin_dir in plugins_installed/*; do
        xai_check_updates "$plugin_dir" "$1"
    done
    shopt -u nullglob
}


xai_plugins_order_rebuild () {

    cat plugins_order.txt <( ls plugins_enabled ) 2>/dev/null | awk '!x[$0]++' > /tmp/plugins_order.tmp

    grep -xf <( ls plugins_enabled ) /tmp/plugins_order.tmp > plugins_order.txt
}

xai_ga_send_hit () {
    local tid="UA-29589045-1"
    if [ -f config/uuid ]; then
        local cid=$(cat config/uuid)
    else
        [[ $OSTYPE = darwin* ]] && local cid=$(uuidgen) || local cid=$(cat /proc/sys/kernel/random/uuid)
        echo "$cid" > config/uuid
    fi
    local data="v=1"
    data+="&t=pageview"
    data+="&tid=$tid"
    data+="&cid=$cid"
    data+="&dp=%2FXAÏ.sh"
    data+="&ds=app" # data source
    data+="&ul=$language" # user language
    data+="&an=XAÏ" # application name
    data+="&av=$xai_version" # application version
    curl -s -o /dev/null --data "$data" "http://www.google-analytics.com/collect"
}

xai_yesno () {
    while true; do
        read -n 1 -p "$1 [Y/n] "
        echo # new line
        [[ $REPLY =~ [Yy] ]] && return 0
        [[ $REPLY =~ [Nn] ]] && return 1
    done
}

# $1 - current step number
# $2 - total number of steps
#
# Usage (usually in a loop)
#
#   $> xai_progressbar 5 10
#   [████████████████████                    ] 50%
#   $> xai_progressbar 10 10
#   [████████████████████████████████████████] 100%
xai_progressbar () {
    let _progress="(${1}*100/${2}*100)/100" # quotes to prevent globbing
	let _done="(${_progress}*4)/10" # quotes to prevent globbing
	let _left=40-$_done
	_done=$(printf "%${_done}s")
	_left=$(printf "%${_left}s")
    printf "\r${_done// /█}$_gray${_left// /█}$_reset ${_progress}%%"
}

xai_build () {
    echo "Running tests..."
        roundup test/*.sh || exit 1
    printf "Updating version file..."
        date +"%y.%m.%d" > version.txt
        xai_success "Done"
    printf "Generating documentation..."
        utils/tomdoc.sh --markdown --access Public utils/utils.sh utils/utils_linux.sh > docs/api-reference-public.md
        utils/tomdoc.sh --markdown utils/utils.sh utils/utils_linux.sh > docs/api-reference-internal.md
        xai_success "Done"
    printf "Opening GitHub Desktop..."
        open -a "GitHub Desktop" D:/XRAY/projet git/xray-ai-project
        xai_success "Done"
}
