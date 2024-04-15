#!/bin/sh
script_path=$(dirname $(readlink -f "$0"))
#rc-service syslog start
source "$script_path/source_before.sh"
source "$script_path/instructions.sh"
log_file=
config_file="/etc/vsftpd/vsftpd.conf"
force=0
if [[ ! -z "$VSFTPD_CONFIG" ]]
then
   config_file="/etc/vsftpd/collection/env.conf" 
fi

while getopts "c:u:fh" options; do
    case "${options}" in
        h)
        echo "[-c Path] - Set path config file."
        echo "[-u /users/list/file] - Users list file. format file - user_name [password] [/local_root [guest_username]]\\n. Empty password -\"\" " 
        echo "[-f] - init force"
        return 0
        ;;
        c)
        config_file="${OPTARG}"
        ;;
        u)
        USERS_LIST="$(cat ${OPTARG})"
        rm "${OPTARG}"
        ;;
        f)
        force=1
        ;;
    esac
done

userLib="$script_path/users/user.sh -c $config_file"

configLib="$script_path/lib/config.sh $config_file"

lib="$script_path/lib/system.sh"
VSFTPD_CONFIG="$(echo -e "$VSFTPD_CONFIG")"

init_users(){
    if [[ -z "$USERS_LIST" ]]
    then
        return;
    fi
    echo "INIT USERS"
    local user_config_dir="$($configLib configParam user_config_dir)"
    local config_dir
    if [[ -z "$user_config_dir" ]]
    then
        config_dir=$(dirname $config_file)
        user_config_dir=$config_dir/users
        echo "# Added by program" >> $config_file
        echo "user_config_dir=$user_config_dir" >> $config_file
    fi
    $userLib buildTpl
    $userLib initUsersList "" "${USERS_LIST}"
}

init_config(){
    echo "INIT CONFIG"
    local dir_config_file=$(dirname "${config_file}")
    $script_path/lib/createFromTpl.sh  -i 2 -t $dir_config_file/template -o $dir_config_file
    # adding users list files
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
        init_users
        echo "$config_file">/entrypoint/init
    fi
}

tail_pid_vsftpd (){
    local pid=$(ps -o pid,ppid,comm|grep -E '\s*[0-9]\s+1+\s+vsftpd'|xargs|cut -d ' ' -f 1)
    echo "Displaying file logs '/var/log/vsftpd.log'"
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
    local user_config_dir=$($configLib configParam user_config_dir)

    cat << EOF
CONFIG FILE
-------------------------
${config_file}
-------------------------
$(cat "${config_file}")
-------------------------

-------------------------
FTP SETTINGS
-------------------------
· Config file : $config_file
· Guest user : $guest_username
· Guest user ID : $($lib userIdByName $guest_username)
· Default directory : $($configLib  configParam local_root)
· Is virtual users : $($configLib isVirtualUser)  
-------------------------

EOF
    if [[ ! -z "$USERS_LIST" ]]
    then
        local pass
        local user
        local config_user_file
        cat <<EOF
-------------------------
FTP Users settings
-------------------------
EOF
    echo -e "$USERS_LIST"|while read -r command
    do
        user=$(echo $command|awk '{print $1}')
        # deprecated
        pass=$($userLib show $user|grep 'Password hash'|cut -d ':' -f 2|xargs)
        if [[ ! -z "$user_config_dir" ]]
        then
            config_user_file=$user_config_dir/$user
            if [[ ! -e "$config_user_file" ]]
            then
                config_user_file=
            fi
        fi
        cat <<EOF
-------------------------
· User: $user 
· Config file: $config_user_file
· User ID : $( if [ "$($configLib isVirtualUser)"="NO" ]; then $lib userIdByName $user; fi)
· User password hash : $pass
· User directory : $(export USER=$user;$userLib configParam $user  local_root|envsubst "\$USER";unset USER)
· Guest user : $($userLib configParam $user guest_username)
· Guest user ID : $($lib userIdByName $($userLib configParam $user guest_username))
-------------------------
EOF
        done
    fi
    echo -e "\nTo add or remove user, use the command 'ftpuser help'\n"
}

init
init_log

source "$script_path/source_after.sh"

vsftpd "$config_file" && info && unset USERS_LIST  && tail_pid_vsftpd

