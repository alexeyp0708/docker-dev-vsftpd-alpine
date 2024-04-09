#!/bin/sh

config_file=$1
command=$2
shift
shift

configParam(){
    grep "^\s*$1" "${config_file}"|tail -n 1|cut -d= -f2|xargs
}

isVirtualUser(){
    local virtual_use_local_privs="$(configParam virtual_use_local_privs)"
    local pam_service_name="$(configParam pam_service_name)"
    if [[ ! -z "$pam_service_name" && "$virtual_use_local_privs" == "YES" ]]
    then
        echo YES
    else
        echo NO
    fi
}
$command $@