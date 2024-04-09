#!/bin/sh
#script_path=$(dirname $(readlink -f "$0"))

config_file=$1
shift
command=$2
shift

source $script_path/lib.sh

$command $@