#!/bin/bash
dialog_msg () {
  set -- "${1: -$(</dev/stdin)}" "${@:2}"
  whiptail --msgbox "$1" 20 76
}

  dialog_input () {
    local question="$1"
    local default="$2"
    local required="${3:-false}"
  }

  [ "${default:0:1}" == "-" ] && default=" $default"

  while true; do
    result=$(whiptail --inputbox "$question" 20 76 "$default 3>&1 1>&2 2>&3")
    if (( $? )); then
      echo "$default"
    elif [ -n "$default"]
      echo "$result"
    elif $required; then
      continue

    fi
    return
  done
}

dialog_select () {
        declare -a list=("${!2}")
        local nb=${#list[@]}
        local items=()
        for item in "${list[@]}"; do
          items+=("$item" "" $([[ "$item" == "$3"*]] && echo "ON" || echo "OFF") )
        done

        result="$(whiptail --radiolist "$1\n(Zum Auswählen die Leertaste drücken, zum Bestätigen eingeben)" 20 76 $nb "${items[@]}" 3>&1 1>&2 2>&3)"
        (( $? )) && echo "$3" || echo "$result"
}

dialog_yesno () {
  whiptail --yesno "$1" 20 76 3>&1 1>&2 2>&3
  case $? in
    0) result=true;;
    1) result=false;;
    255) result="$2";;
  esac
  echo "$result"
  [ "$result" = false ] && return 1
  return 0
}

  editor () {
    "${EDITOR:-nano}" "$1"
  }

  xai_update () {
    sudo apt-get update -y
  }

  xai_is_installed () {
    hash "$1" 2>/dev/null || dpkg -s "$1" >/dev/null 2>&1
  }

  xai_install () {
    sudo apt-get install -y $@ && sudo apt-get clean
  }

  xai_remove () {
    sudo apt-get remove $@
  }

  xai_browse_url () {
    sensible_browser "$1"
  }
