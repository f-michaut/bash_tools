#!/usr/bin/env bash

# Print the name of the function calling me
get_caller_name () {
  if [[ -n $BASH_VERSION ]]; then
    printf "%s\n" "${FUNCNAME[2]}"
  else  # zsh
    # Use offset:length as array indexing may start at 1 or 0
    # shellcheck disable=SC2154
    printf "%s\n" "${funcstack[@]:2:1}"
  fi
}

json_error() {
    echo "$(get_caller_name): ERROR: $*" >&2
}

json_warn() {
    echo "$(get_caller_name): WARNING: $*" >&2
}

json_make_string() {
    echo "\"$*\""
}

# exemple: json=$(json_make_object key1 "$(json_make_string some string)" "key 2" `json_make_string some_string` nb 2)
# or also: json=$(json_make_object key1 "`json_make_string some string`" "key 2" `json_make_string some_string` nb 2)
# returns: {"key1": "some string", "key 2": "some_string", "nb": 2}
json_make_object() {
    local RES=""
    local SEP=""
    local is_key=1

    if [[ "$#" -lt 2 || $(($# % 2)) -ne 0 ]];
    then
        json_error "Require an even number or arguments to create key/value pairs"
        return 1
    fi
    for arg in "$@"
    do
        if [[ "$SEP" == ": " ]];
        then
            is_key=0
        else
            arg=$(json_make_string "$arg")
            is_key=1
        fi

        RES="${RES}${SEP}${arg}"
        if [[ "$is_key" -eq 1 ]];
        then
            SEP=": "
        else
            SEP=", "
        fi
    done
    echo "{${RES}}"
}

json_make_string_array() {
    local ARGS=()

    for arg in "$@"
    do
        ARGS+=("$(json_make_string "$arg")")
    done
    json_make_array "${ARGS[@]}"
}

json_make_array() {
    local RES=""
    local SEP=""

    for arg in "$@"
    do
        RES="${RES}${SEP}${arg}"
        SEP=", "
    done
    echo "[$RES]"
}

json_map_object() {
    local array=()
    local ARGS=("$@")

    read -r -a line
    array=()
    if [[ "${#ARGS[@]}" -ne "${#line[@]}" ]]
    then
        json_warn "Line doesn't have the same number of elements than key list"
    fi
    for i in "${!ARGS[@]}"
    do
        array+=("${ARGS[$i]}")
        array+=("${line[$i]}")
    done
    json_make_object "${array[@]}"
}

json_map_string() {
    local ARGS=("$@")
    local ALL

    [[ $# -ge 1 && ( "$1" == "-a" || "$1" ==  "--all" ) ]]
    ALL=$?
    while read -r -a line
    do
        for i in "${!line[@]}"
        do
            if [[ "$ALL" -eq 0 || " ${ARGS[*]} " =~ " ${i} " ]]; then
                echo -n "$(json_make_string "${line[$i]}") "
            else
                echo -n "${line[$i]} "
            fi
        done
        echo # \n
    done
}

json_map_object_array() {
    local res=()

    while read -r line
    do
        res+=("$(echo "$line" | json_map_object "$@")")
    done
    json_make_array "${res[@]}"
}
