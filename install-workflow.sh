#!/bin/bash

# This script is expected to be run from within the directory that contains the info.plist.
# Every argument is a path that is copied into the final workflow, along with info.plist.
# Arguments may be directories, which are copied as directories into the result.
#
# Note: at least one file to copy must be given, because a workflow that is comprised solely
# of info.plist/icon.png does not need an install script, and so it is assumed to be an
# error.

set -e
shopt -s nullglob

function usage() {
    echo "usage: install-workflow.sh [-hv] FILE [FILE...]"
}

verbose=no
while (( $# > 0 )); do
    case "$1" in
        -h|--help)
            usage
            exit
            ;;
        -v|--verbose)
            verbose=yes
            ;;
        --)
            shift
            break
            ;;
        -*)
            usage >&2
            exit 2
            ;;
        *)
            break
            ;;
    esac
    shift
done

if (( $# == 0 )); then
    usage >&2
    exit 2
fi

function getBundleID() {
    local path=$1
    if [[ ! -f "$path" ]]; then
        echo "no such file: $path" >&2
        return 1
    fi

    /usr/libexec/PlistBuddy -c 'Print :bundleid' "$path"
}

bundleid=$(getBundleID info.plist)

syncfolder=$(defaults read com.runningwithcrayons.Alfred-Preferences syncfolder)
syncfolder=${syncfolder/#~\//"$HOME"/}
prefs=${syncfolder%/}/Alfred.alfredpreferences

if [[ ! -d "$prefs" ]]; then
    echo "error: Preferences path '$prefs' does not exist or is not a folder" >&2
    exit 1
fi

dest=
for workflow in "$prefs"/workflows/user.workflow.*; do
    [[ $verbose = yes ]] && echo "debug: checking $workflow"

    workflowid=$(getBundleID "$workflow"/info.plist)
    if [[ "$bundleid" = "$workflowid" ]]; then
        [[ $verbose = yes ]] && echo "debug: found match"
        dest=$workflow
        break
    fi
done
if [[ -z "$dest" ]]; then
    [[ $verbose = yes ]] && echo "no match found; installing new workflow"
    dest=$prefs/workflows/user.workflow.$(uuidgen)
    mkdir "$dest"
fi

echo "Installing to $dest..."
install_queue=(info.plist)
if [[ -f icon.png ]]; then
    install_queue+=(icon.png)
fi
install_queue+=("$@")
[[ $verbose = yes ]] && echo "install queue: [${install_queue[@]}]"

declare -a to_delete
for f in "$dest"/{*,.[!.]*,.??*}; do
    for g in "${install_queue[@]}"; do
        if [[ "$(basename "$g")" = "$(basename "$f")" ]]; then
            # found a match
            continue 2
        fi
    done
    # no match
    to_delete+=("$f")
done
[[ $verbose = yes ]] && echo "delete queue: [${to_delete[@]}]"

echo TODO
