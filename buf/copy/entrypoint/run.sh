#!/bin/sh
script_path=$(dirname $(readlink -f "$0"))
source "$script_path/child_before_instructions.sh"
source "$script_path/instructions.sh"
log_file=
config_file="/etc/vsftpd/vsftpd.conf"
force=0
if [[ ! -z "$VSFTPD_CONFIG" ]]
then
   config_file="/etc/vsftpd/collection/env.conf" 
fi

while getopts "c:fh" options; do
    case "${options}" in
        h)
        echo "[-c Path] - Set path config file."
        echo "[-l Path]- Set log file, and STDOUT in log file."
        echo "[-f] - init force"
        echo "[-L] - STDOUT in default log file."
        return 0
        ;;
        c)
        config_file="${OPTARG}"
        ;;
        f)
        force=1
        ;;
    esac
done

userLib="$script_path/users/user.sh $config_file"

configLib="$script_path/lib/config.sh $config_file"

lib="$script_path/lib/system.sh"

init_user(){
    if [[ -z "$FTP_USER" ]]
    then
        return;
    fi
    echo "INIT USER"
    local buf=$($userLib init $FTP_USER $FTP_PASS)
    FTP_PASS=$(echo $buf|tail -n 1)
}

init_config(){
    echo "INIT CONFIG"
    local dir_config_file=$(dirname "${config_file}")
    $script_path/lib/createFromTpl.sh  -i 2 -t $dir_config_file/template -o $dir_config_file
    $userLib buildTpl $FTP_USER 
}

init_log() {
    echo "INIT LOG"
    log_file="$($configLib configParam xferlog_file)"
    if [[ ! -z "${log_file}" ]]
    then
        mkdir -p $(dirname $log_file)
        touch $log_file
    fi
    log_file="/var/log/vsftpd.log"
    touch $log_file
}

init() {
    is_init=0
    if [[ -e "/entrypoint/init" ]]
    then
        is_init=1
        if [[ "$config_file" != "$(cat /entrypoint/init)" ]]
        then 
            is_init=0
        fi
    fi
    if [[ "$force" -eq "1" || "$is_init" -eq "0" ]]
    then
        echo "INIT"
        init_config
        init_user
        echo "${config_file}" > "/entrypoint/init"
    fi
}

tail_pid_vsftpd (){
    local pid=$(ps -o pid,ppid,comm|grep -E '\s*[0-9]\s+1+\s+vsftpd'|xargs|cut -d ' ' -f 1)
    tail --pid $pid -f /var/log/vsftpd.log
}

info(){ 
    if [[ "$($configLib configParam background)" != "YES" ]]
    then
        return 0
    fi
    local guest_username=$($configLib configParam guest_username)
    if [[ -z "$guest_username" ]]
    then
        guest_username="ftp"
    fi
    local config_user_file=$($configLib configParam user_config_dir)
    if [[ ! -z "config_user_file" ]]
    then
        config_user_file="$config_user_file/$FTP_USER"
        if [[ ! -e "$config_user_file" ]]
        then
            config_user_file=
        fi
    fi
    cat << EOF
-------------------------
${config_file}
-------------------------
$(cat "${config_file}")
-------------------------
-------------------------
FTP Settings
-------------------------
· Config file: $config_file
· Guest user: $guest_username
· Guest user ID: $($lib userIdByName $guest_username)
· Default directory: $($configLib  configParam local_root)
· Is virtual users: $($configLib isVirtualUser)  
-------------------------
FTP User settings
-------------------------
· Config file: $config_user_file
· User: $FTP_USER 
· User ID: $( if [ "$($configLib isVirtualUser)"="NO" ]; then $lib userIdByName $FTP_USER; fi)
· Password: $FTP_PASS
· User directory: $(export USER=$FTP_USER;$userLib configParam $FTP_USER  local_root|envsubst "\$USER";unset USER)
· User guest: $($userLib configParam $FTP_USER guest_username)
· User guest ID: $($lib userIdByName $($userLib configParam $FTP_USER guest_username))
-------------------------
EOF
#To add or remove virtual a user, use the command '/entrypoint/vusers.sh -h'

#To add or remove real a user, use the command 'adduser --help' and 'deluser --help'
tail_pid_vsftpd
}

init
init_log
info

source "$script_path/child_after_instructions.sh"


vsftpd "$config_file" && info

