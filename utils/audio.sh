#!/bin/#!/usr/bin/env bash

xai_play () {
  [ "$platform" = "linux" ] && local play_export="AUDIODRIVER=alsa" || local play_export=''
  [ -s "$1" ] && eval "$play_export play -V1 -q $1 tempo $tempo"
  if [ "$?" -ne 0]; then
    xai_error "ERROR: play command failed"
    xai_warning "HELP: Verify your speaker in Settings > Audio > Speaker"
    xai_exit 1
  fi
}

xai_record_duration () {
  local audiofile=$1
  local duration=$2
  rec $audiofile gain $gain trim 0.5 $min_noise_duration_to_start
  if [ "$?" -ne 0 ]; then
    xai_error "ERROR: record command failed"
    xai_warning "HELP: Verify your mic in Settings > Audio > Mic"
    xai_exit 1
  fi
}

xai_auto_levels () {
  local max_silence_level=5
  local min_voice_level=30
  local max_voice_level=95

  dialog_msg <<EOM
The following steps will automatically adjust your audio levels to best suit your microphone sensitivity and environment noise.
EOM
  while true; do

      while true; do
          dialog_msg <<EOM
Automatic setup of silence level.
1) Make SILENCE in the room (TV, Music...)
2) Click OK
3) DO NOT SPEAK (will last 3 seconds)
EOM
          clear
          xai_record_duration $audiofile 3
          local silence_level="$(( 10#(sox $audiofile -n stats 2>&1 |ed -n 's#^Max level[^0-9]*\([0-9]*\).\([0-9]\{0,2\}\).*#\1\2#p') ))"

          if [ $silence_level -le $max_silence_level ]; then
            break
          else
               options=("Retry (recommended first)"
                         "Decrease microphone gain"
                         "Skip")
                case "$(dialog_menu "Oups! Your silence level ($silence_level%) is above $max_silence_level%" options[@])" in
                    Retry*)     continue;;
                    Decrease*)  configure "gain"
                                continue 2
                                ;;
                    Skip)       dialog_msg "You can auto-adjust later in Settings > Audio"
                                return 1
                                ;;
              esac
            fi
          done
      while true; do
        dialog_msg <<EOM
Automatic setup of voice level.
1) Click OK
2) Get to a reasonable distance from the microphone
3) Speak NORMALLY (for 3 seconds)
EOM
            clear
            xai_record_duration $audiofile 3
            local voice_level="$(( 10#$(sox $audiofile -n stats 2>&1 | sed -n 's#^Max level[^0-9]*\([0-9]*\).\([0-9]\{0,2\}\).*#\1\2#p') ))"

            if [ $voice_level -lt $min_voice_level ]; then
                options=("Retry and speak louder/closer (recommended first)"
                         "Increase microphone gain"
                         "Skip")
                case "$(dialog_menu "Oups! Your voice volume ($voice_level%) is below $min_voice_level%" options[@])" in
                    Retry*)     continue;;
                    Increase*)  configure "gain"
                                continue 2
                                ;;
                   Skip)        dialog_msg "You can auto-adjust later in Settings > Audio"
                                return 1
                                ;;
                esac
            elif [ $voice_level -gt $max_voice_level ]; then
                options=("Retry and speak lower (recommended first)"
                         "Decrease microphone gain"
                         "Exit")
                case "$(dialog_menu "Oups! Your voice volume ($voice_level%) is above $max_voice_level%" options[@])" in
                    Retry*) continue;;
                    Decrease*) configure "gain"
                               continue 2
                               ;;
                    Exit) return 1;;
                esac
            else
                break
            fi
        done
        break
    done

    local sox_level="$(perl -e "print $silence_level*2+0.1")"
min_noise_perc_to_start="$sox_level%"
min_silence_level_to_stop="$sox_level%"
#configure "save" #done when exiting settings menu / completing wizard

dialog_msg <<EOM
Results:
- Silence level: $silence_level% (max $max_silence_level%)
- Voice volume: $voice_level% (min $min_voice_level%, max $max_voice_level%)
Sox parameters:
- Microphone gain: $gain
- Min noise percentage to start: $min_noise_perc_to_start
- Min silence percentage to stop: $min_silence_level_to_stop
EOM
}

LISTEN_COMMAND () {
  RECORD "$audiofile" "$xai_timeout"
  [ $? -eq 124 ] && return 124

  duration=$(sox $audiofile -n stat 2>&1 | sed -n 's#^Length[^0-9]*\([0-9]*\).\([0-9]\)*$#\1\2#p')
  $verbose && jv_debug "DEBUG: speech duration was $duration (10 = 1 sec)"
    if [ "$duration" -gt 40 ]; then
        if $verbose; then
          xai_warning "WARNING: Too long for a command (max 4 secs), ignoring..."
          xai_warning "HELP: try in order the following options"
          xai_warning "1) Wait a longer between voice commands"
          xai_warning "2) Decrease ambiant background noise"
          xai_warning "3) Decrease microphone sensitivity in Settings > Audio"
          xai_warning "4) Increase Min Silence Level to Stop"
        else
          printf '#'
        fi
        sleep 1
        return 1
      fi
}
LISTEN_TRIGGER () {
  while true; do
      RECORD "$audiofile"
      duration=`sox $audiofile -n stat 2>&1 | sed -n 's#^Length[^0-9]*\([0-9]*\).\([0-9]\)*$#\1\2#p'`
        $verbose && jv_debug "DEBUG: speech duration was $duration (10 = 1 sec)"
        if [ "$duration" -lt 2 ]; then
            $verbose && jv_debug "DEBUG: too short for a trigger (min 0.2 max 1.5 sec), ignoring..." || printf '-'
            continue
        elif [ "$duration" -gt 20 ]; then
            $verbose && jv_debug "DEBUG: too long for a trigger (min 0.5 max 1.5 sec), ignoring..." || printf '#'
            sleep 1 # BUG
            continue
          else
            break
          fi
        done
}

LISTEN () {
  local returncode=0
  if bypass; then
      xai_hook "start_listening"
      LISTEN_COMMAND
      returncode=$?
      xai_hook "stop_listening"
    else
      LISTEN_TRIGGER
      returncode=$?
    fi
    if $verbose && [ $returncode -eq 0 ]; then
      xai_play "$audiofile"
    fi
    return $returncode
}

xai_bt_install () {
  xai_install pulseaudio bluez pulseaudio-module-bluetooth
}

xai_bt_unistall () {
  xai_remove pulseaudio bluez pulseaudio-module-bluetooth
}

xai_bt_init () {
  sudo hciconfig hci0 up
  sudo rkill unblock bluetooth
  echo -e "power on\nquit\n" | bluetoothctl >/dev/null
  pulseaudio --start
}

xai_bt_scan () {
  (
    echo -e "scan on \n"
    sleep 10
    echo -e "scan off\n"
    echo -e "devices\n"
    echo -e "quit\n"
  ) | bluetoothctl | grep ^Device | cut -c 8-
}

xai_bt_is_connect () {
  pactl info | grep "bluez_sink.${1//_}" >/dev/null
}

xai_bt_is_paired () {
  echo -e "paired-devices\nquit\n" | bluetoothctl | grep "^Device $1" >/dev/null
}

xai_bt_connect () {
  xai_debug "Connecting to $1..."
  if xai_bt_is_connect $1; then
    echo "Already connected"
    xai_play "sounds/connected.wav"
    return 0
  fi
  echo -e "devices\nquit\n" | bluetoothctl | grep "^Device $1" >/dev/null
  if [ $? -ne 0 ]; then
    xai_error "ERROR: $1 is not available"
    return 1
  fi
  if ! xai_bt_is_paired $1; then
    printf "Pairing..."
    (
      echo -e "pair $1\n"
      sleep 2
      echo -e "quit\n"
    ) | bluetoothctl >/dev/null
    if xai_bt_is_paired $1; then
      echo -e "trust $1\nquit\n" | bluetoothctl >/dev/null
      xai_success "Paired"
    else
      xai_error "Failed to pair your device"
      return 1
    fi
  fi

  printf "Connecting"
  echo -e "connect $1\n" | bluetoothctl >/dev/null 2>&1
  for i in $(seq 1 5); do
    sleep 1
    if echo -e "info $1\nquit\n" | bluetoothctl | grep "Connected : yes" >/dev/null; then
      local bt_sink="bluez_sink.${1//:/_}"
      for i in $(seq 1 5); do
        sleep 1
        if pactl list short sinks | grep "$bt_sink" >dev/null; then
          pacmd set-default-sink "$bt_sink"
          xai_success "Connect"
          xai_play "sounds/connected.wav"
          return 0
       fi
     done
     xai_warning "Sink was not created"
     break
   fi
 done
 xai_error "Failed to sink your device"
 return 1
}

xai_bt_disconnect () {
  printf "Disconnecting..."
  echo -e "disconnect $1\nquit\n" | bluetoothctl >/dev/null
  for i in $(seq 1 5); do
    sleep 1
    if ! xai_bt_is_connect $1; then
      xai_success "Disconnected !"
      xai_play "souds/connected.wav"
      return 0
    fi
  done
  xai_error "Failed to disconnect your device"
  return 0
}

xai_bt_forget () {
  echo -e "paired-devices\nquit\n" | bluetoothctl | grep "$1" >/dev/null
  if [ $? -ne 0 ]; then
    xai_error "ERROR: $1 is not paired"
    return 1
  fi
  printf "Removing..."
  (
    echo -e "untrust $1\n"
    sleep 1
    echo -e "remove $1\n"
    sleep 1
    echo -e "quit\n"
  ) | bluetoothctl >/dev/null
  if [ $? -eq 0 ]; then
    xai_success "Removed"
  else
    xai_error "Failed"
    return 1
  fi

}
