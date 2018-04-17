#!/bin/bash
flags='bc:ihjklmnp:qrs:uvwx:z'

EOF
}

headline="NOUVEAU: Réactualisation par défaut de pause dans Settings > Audio"


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
source utils/store.sh
source utils/audio.sh
source utils/configure.sh


if [ "$EUID" -eq 0 ]; then
    echo "ERREUR: XAÏ ne peut pas être lancé en mode root !" 1>&2
    exit 1
fi                                                                                           
