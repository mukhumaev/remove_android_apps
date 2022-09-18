#!/usr/bin/env sh

TOTAL_COUNT=0
REMOVED_COUNT=0

print_info(){
cat << EOF

one of the parameters is required:
 -a, --adb    ADB mode. This device  using like server
              It's mean remove APPS on another device

 -s, --self   SELF mode. Only for Android Devices
              It's mean remove APPS on THIS device



optional parameters:
 -f, --file   File with a list of programs
              It removes programs from the list
              Need use together with ADB or SELF mode

 -h, --help   Print this info

EOF
  exit 0
}

uninstall(){
    TOTAL_COUNT=$((TOTAL_COUNT+1))
    $COMMAND uninstall -k --user 0 $1 | grep -ioq 'Failure' && echo "[-]  $1" && return 1
    echo "[+]  $1"
    REMOVED_COUNT=$((REMOVED_COUNT+1))
}

check_file(){
    [ -z "$1" ] && echo "ERROR. Not found filename" && return 1
    [ ! -f "$1" ] && echo "ERROR. File not found" && return 1
    [ ! -s "$1" ] && echo "ERROR. File '$1' have not data" && return 1
    return 0
}

check_depends(){

    [ "$1" = "-q" ] && QUIET=true && shift

    [ -z "$1" ] && echo "Send parametes inside ${FUNCNAME}" && return 1

    DEPENDS_NOT_FOUND=""

    for i in $@; do
        [[ $(which "$i" 2>/dev/null) ]] || DEPENDS_NOT_FOUND="$DEPENDS_NOT_FOUND $i"
    done

    [ -z "$DEPENDS_NOT_FOUND" ] && return 0

    [ "${QUIET}" = "true" ] && return 1
    echo -e "Error. Not founded depends list:\n$DEPENDS_NOT_FOUND" && return 1
}

is_wsl(){
   uname -a | grep -qo WSL
}

wsl_adb_install(){
    BASHRC="$HOME/.BASHRC"
    ADB_DIR="$HOME/.adb"
    FILENAME=/tmp/windows-adb.zip
    if is_wsl; then
        check_depends "wget  unzip" || return 1
        echo "Installing adb.exe inside WSL..."

        wget -q -O $FILENAME https://dl.google.com/android/repository/platform-tools-latest-windows.zip
        rm -rf $ADB_DIR
         unzip -qq -o $FILENAME -d $HOME/
        mv -u $HOME/platform-tools $ADB_DIR
        rm -rf $FILENAME

        if ! grep -q 'adb.exe' $BASHRC; then
            echo >> $BASHRC
            echo '#  use ADB.EXE inside WSL' >> $BASHRC
            echo 'if [ "$(uname -a | grep -o WSL)" = "WSL" ]; then' >> $BASHRC
            echo '    export PATH="$PATH:$HOME/.adb"' >> $BASHRC
            echo "    alias adb='$ADB_DIR/adb.exe'" >> $BASHRC
            echo "    alias fastboot='$ADB_DIR/fastboot.exe'" >> $BASHRC
            echo 'fi' >> $BASHRC
        fi

        echo "adb.exe installation in WSL successful"
    fi
}

default_list_remove() {
  # Google Gboard
  uninstall   uninstall com.google.android.inputmethod.latin

  # wellbeing
  uninstall com.google.android.apps.wellbeing

  # Google lens
  uninstall com.google.ar.lens

  # Android Auto
  uninstall com.google.android.projection.gearhead

  # YouTube
  uninstall com.google.android.youtube

  # YouTube Music
  uninstall com.google.android.apps.youtube.music

  # Google Maps
  uninstall com.google.android.apps.maps

  # Google podcasts
  uninstall com.google.android.apps.podcasts

  # Google Chrome
  uninstall com.android.chrome

  # Google Search Box
  uninstall com.google.android.googlequicksearchbox

  # Google assistant
  uninstall com.google.android.apps.googleassistant

  # Google Play Music
  uninstall com.google.android.music

  # Google Play Books
  uninstall com.google.android.apps.books

  # Google Keep
  uninstall com.google.android.keep

  # Google News
  uninstall com.google.android.apps.magazines

  # Google Disk
  uninstall com.google.android.apps.docs

  # Google Talkback
  uninstall com.google.android.marvin.talkback

  # Google Play Service for AR
  uninstall com.google.ar.core

  # Google Docs
  uninstall com.google.android.apps.docs

	 # Google Photos
  uninstall com.google.android.apps.photos

	 # Google Duo
  uninstall com.google.android.apps.tachyon

	 # Google One
  uninstall com.google.android.apps.subscriptions.red

	 # Google Play Movies & TV
  uninstall com.google.android.videos

	 # Feedback app
  uninstall com.google.android.feedback
}

main(){

    [ $(id -u) -ne 0 ] && echo "Need root priveleges. Run  under su" && exit 0

    [ -z "$1" ] && print_info

    while [ -n "$1" ]; do
        case "$1" in
        -f|--file)
            shift
            check_file $1 && FILE=$1 || return 1
            shift
            [ -z "$1" ] && [ -z "$COMMAND" ] && print_info && exit 1
        ;;

        -a|--adb)
            shift
            is_wsl && wsl_adb_install && ADB="adb.exe" || ADB="adb"
            check_depends "$ADB" || return 1
            COMMAND="$ADB shell pm"

            # stop adb if it was running
            $ADB kill-server &> /dev/null

            if [ "$($ADB devices | wc -l)" = "2" ]; then
                echo "ADB devices not found!"
                $ADB kill-server &> /dev/null
                exit 0
            fi
        ;;

        -s|--self)
            shift
            COMMAND="pm"

            if ! check_depends -q 'pm'; then
                echo "Script can't be run  under SELF mode on this device"
                echo "This device IS NOT android"
                exit 0
            fi
        ;;

        *)
            print_info
            exit 0
        ;;
        esac
    done

    if [ -z "$FILE" ]; then
        echo "Using DEFAULT list"
        echo
        sleep 3
        default_list_remove
    else
        for package in $(grep -v "^#" $FILE); do
             uninstall "$package"
        done
    fi
    echo "------------------------------------------"
    echo "Removed $REMOVED_COUNT of $TOTAL_COUNT apps"
    echo
}

main $*
