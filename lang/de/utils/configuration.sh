#!/bin/bash
# Configuration
configure () {
    local variables=('google_speech_api_key'
                   'bing_speech_api_key'
                   'check_updates'
                   'command_stt'
                   'conversation_mode'
                   'dictionary'
                   'gain'
                   'google_speech_api_key'
                   'xai_branch'
                   'xai_bt_device_mac'
                   'xai_bt_device_name'
                   'xai_timeout'
                   'xai_use_bluetooth'
                   'language'
                   'language_model'
                   'trigger_mode'
                   'min_noise_duration_to_start'
                   'min_noise_perc_to_start'
                   'min_silence_duration_to_stop'
                   'min_silence_level_to_stop'
                   'osx_say_voice'
                   'phrase_failed'
                   'phrase_misunderstood'
                   'phrase_triggered'
                   'phrase_welcome'
                   'play_hw'
                   'pocketsphinxlog'
                   'rec_hw'
                   'recorder'
                   'send_usage_stats'
                   'separator'
                   'show_commands'
                   'snowboy_checkticks'
                   'snowboy_sensitivity'
                   'snowboy_token'
                   'tempo'
                   'trigger'
                   'trigger_stt'
                   'trigger_mode'
                   'tts_engine'
                   'username'
                   #'voxygen_voice'
                   'wit_server_access_token')
    local hooks=(  'entering_cmd'
                   'exiting_cmd'
                   'program_startup'
                   'program_exit'
                   'start_listening'
                   'stop_listening'
                   'start_speaking'
                   'stop_speaking'
                   'listening_timeout')
     case "$1" in
       google_speech_api_key)   eval "$1=\"$(dialog_input "Google Speech API KEY \nNicht frei, siehe https://cloud.google.com/speech/docs/getting-started" "${!1}" true)\"";;
       bing_speech_api_key)   eval "$1=\"$(dialog_input "Bing Speech API Key\nWie man eine bekommt: NICHT VERFÜGBAR" "${!1}" true)\"";;
       check_updates)         options=('Immer' 'Tagtäglich' 'Wöchentlich' 'Niemanden')
                              case "$(dialog_select "Updates beim Start von xaï prüfen\nEmpfohlen: Täglich" options[@] "Täglich")" in
                                  Always) check_updates=0;;
                                  Daily)  check_updates=1;;
                                  Weekly) check_updates=7;;
                                  Never)  check_updates=false;;
                              esac;;
