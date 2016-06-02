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
    echo "Usage:"
    echo "  install-workflow.sh [-hvd] [--] FILE [FILE...]"
    echo "  install-workflow.sh --update-plist"
    echo
    echo "Options:"
    echo "  -h --help       Displays this help"
    echo "  -v --verbose    Shows more verbose information"
    echo "  -d --debug      Shows debug information"
    echo "  --update-plist  Update ./info.plist from the installed workflow"
    [[ $1 != verbose ]] && return
    echo
    echo "When invoked with a list of files, the workflow is installed using those files"
    echo "and ./info.plist (and optionally ./icon.png)."
    echo
    echo "When invoked with --update-plist, the installed workflow is located and the"
    echo "info.plist is copied back into the development directory."
}

verbose=
debug=
while (( $# > 0 )); do
    case "$1" in
        -[^-]?*)
            flag=${1:0:2}
            rest=${1:2}
            shift
            set -- "$flag" -"$rest" "$@"
            continue
            ;;
        -h|--help)
            usage verbose
            exit
            ;;
        -v|--verbose)
            verbose=yes
            ;;
        -d|--debug)
            debug=yes
            verbose=yes
            ;;
        --update-plist)
            update_plist=yes
            ;;
        --)
            shift
            break
            ;;
        -*)
            echo "error: unknown flag $1" >&2
            usage >&2
            exit 2
            ;;
        *)
            break
            ;;
    esac
    shift
done

if [[ -n $update_plist ]]; then
    if (( $# > 0 )); then
        echo "error: unexpected parameter $1" >&2
        usage >&2
        exit 2
    fi
else
    if (( $# == 0 )); then
        usage >&2
        exit 2
    fi
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

syncfolder=$(defaults read com.runningwithcrayons.Alfred-Preferences-3 syncfolder)
syncfolder=${syncfolder/#~\//"$HOME"/}
prefs=${syncfolder%/}/Alfred.alfredpreferences

if [[ ! -d "$prefs" ]]; then
    echo "error: Preferences path '$prefs' does not exist or is not a folder" >&2
    exit 1
fi

dest=
for workflow in "$prefs"/workflows/user.workflow.*; do
    [[ $debug = yes ]] && echo "debug: checking $workflow"

    workflowid=$(getBundleID "$workflow"/info.plist)
    if [[ "$bundleid" = "$workflowid" ]]; then
        [[ $debug = yes ]] && echo "debug: found match"
        dest=$workflow
        break
    fi
done
if [[ -z $dest ]]; then
    if [[ -n $update_plist ]]; then
        echo "error: No existing installed workflow found" >&2
        exit 1
    fi
    [[ $verbose = yes ]] && echo "No existing installed workflow found; installing new workflow"
    dest=$prefs/workflows/user.workflow.$(uuidgen)
    mkdir "$dest"
fi
dest_pretty=${dest//"$HOME"\//\~/}

if [[ -n $update_plist ]]; then
    # copy the info.plist from the installed workflow to the local folder
    plist_path=$dest/info.plist
    if [[ ! -f "$plist_path" ]]; then
        plist_path=$dest/Info.plist
        if [[ ! -f "$plist_path" ]]; then
            echo "error: can't find info.plist in $dest_pretty" >&2
            exit 1
        fi
    fi
    echo "Copying info.plist from $dest_pretty"
    cp "$plist_path" ./info.plist
    exit
fi

echo "Installing to $dest_pretty"
install_queue=(info.plist)
if [[ -f icon.png ]]; then
    install_queue+=(icon.png)
fi
install_queue+=("$@")
[[ $debug = yes ]] && echo "debug: install queue: [${install_queue[*]}]"

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
[[ $debug = yes ]] && echo "debug: delete queue: [${to_delete[*]}]"

[[ -d "$dest" ]] || mkdir "$dest"
for f in "${install_queue[@]}"; do
    [[ $verbose = yes ]] && echo "Copying $f"
    # shellcheck disable=SC2046
    cp -a $([[ $debug = yes ]] && echo "-v") "${f%/}" "$dest"
done

for f in "${to_delete[@]}"; do
    [[ $verbose = yes ]] && echo "Deleting $f"
    # shellcheck disable=SC2046
    rm -rf $([[ $debug = yes ]] && echo "-v") "$f"
done
