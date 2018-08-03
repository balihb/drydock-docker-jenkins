#!/bin/bash

set -ueE

function error() {
    echo -e "\e[41m$1\e[0m"
}

function on_error() {
    local err=$?
    set +o xtrace
    local code="${1:-1}"
    local err_cmd="${BASH_COMMAND}"
    echo
    error " 0: ${BASH_SOURCE[0]}:${BASH_LINENO[0]}"
    if [ ${#FUNCNAME[@]} -gt 2 ]
    then
        for ((i=1;i<${#FUNCNAME[@]}-1;i++))
        do
            error " $i: ${BASH_SOURCE[$i+1]}:${BASH_LINENO[$i]} ${FUNCNAME[$i]}"
        done
    fi
    echo
    error "Error in ${BASH_SOURCE[1]}:${BASH_LINENO[0]}. '${err_cmd}'"
    trap - EXIT
    command exit "${code}"
}

trap 'on_error' ERR

trap 'on_exit' EXIT

function on_exit () {
    local err=$?
    if [ $err -eq 0 ];then
        echo
        echo -e "\e[32mOK\e[0m"
        command exit $err
    else
        on_error $err
    fi
}
