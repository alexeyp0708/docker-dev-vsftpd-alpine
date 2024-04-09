#!/bin/sh
script_path=$(dirname $(readlink -f "$0"))

config=$(cat /entrypoint/init)

if [[ -z "$config" ]]
then 
    return
fi

userLib="$script_path/../users/user.sh $config" 

$userLib $@