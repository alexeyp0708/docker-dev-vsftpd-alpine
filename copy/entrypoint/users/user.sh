#!/bin/sh

script_path=$(dirname $(readlink -f "$0"))

config_file=
duplicate_user=NO
while getopts "c:d" options; do
        case "${options}" in
        c)
        config_file="${OPTARG}"
        ;;
        d)
        duplicate_user=YES
        ;;
        esac
done
shift $((OPTIND - 1))

if [[ -z "$config_file" ]]
then
    echo "($0) Warn: Configuration file needs to be set. [-c /path/file]">&2
    return 1
fi
if [[ ! -e "$config_file" ]]
    then
    echo "($0) Warn: Config '$config_file' file missing.">&2
    return 1
fi
lib="$script_path/../lib/system.sh"
configLib="$script_path/../lib/config.sh $config_file"

command=$1
user_name=$(echo $2|tr -d '"')
shift
shift
if [[ -z "$DEFAULT_ACCESS" ]]
then
    DEFAULT_ACCESS=700
fi
local_root=$($configLib configParam local_root)
guest_username=$($configLib configParam guest_username)
user_config_dir=$($configLib configParam user_config_dir)

_initUserSettings(){
    local configUserLib="$script_path/../lib/config.sh $user_config_dir/$user_name"
    local local_user_root guest_user_username
    if [[ ! -z "$user_config_dir" && -e "$user_config_dir/$user_name" ]]
    then
        local_user_root=$($configUserLib configParam local_root)
        if [[ ! -z "$local_user_root" ]]
        then
           local_root=$local_user_root 
        fi
        guest_user_username=$($configUserLib configParam guest_username)
        if [[ ! -z "$guest_user_username" ]]
        then
           guest_username=$guest_user_username 
        fi
    fi
    if [[ ! -z "$(echo \"$local_root\"|grep \$USER)" ]]
    then
        export USER=$user_name
        local_root="$(echo $local_root|envsubst '\$USER')"
        unset USER
    fi
}

_addShareUserGuest(){
    local user_name=$($configLib configParam guest_username);
    if [[ -z "$($lib userIdByName $user_name)" ]]
    then
        local local_root=$($configLib configParam local_root);
        if [[ ! -z "$(echo \"$local_root\"|grep \$USER)" ]]
        then
            local_root=
        fi
        echo "- Init guest user - '$user_name'"
        _addLocal NONE
    fi
}

_addUserGuest(){
    local user_name=$guest_username;
    echo "- Init guest user - '$user_name'"
    _addLocal NONE
}

_addLocal(){
    local pass=$1
    local opt_uid opt_home ls_dir owner_id
    local init_dir=NO
    local passwd_chroot_enable=$($configLib configParam passwd_chroot_enable)
    if [[ -z "$($lib userIdByName $user_name)" ]]
    then
        #opt_home="-H"
        opt_home="-h /var/lib/ftp/$user_name"
        mkdir -p  "/var/lib/ftp/$user_name"
        if [[ ! -z "$local_root"  ]]
        then
            if [[ -d "$local_root" ]]
            then
                owner_id=$($lib ownerIdDir "$local_root")
                if [[ -z "$($lib userNameById $owner_id)" ]]
                then
                    opt_uid="-u $owner_id"
                fi
            else 
                mkdir -m $DEFAULT_ACCESS -p $local_root
                init_dir=YES
            fi
            if [[ "$passwd_chroot_enable" == "YES" ]]
            then
                opt_home="-h $local_root"
            fi
        fi
        echo "- Creating local user - '$user_name'"
        adduser -s /sbin/nologin -g $user_name -G ftp $opt_uid $opt_home -D $user_name
        if [[ "$pass" != "NONE" ]]
        then
            echo "- Creating password '$pass' for '$user_name'"
            #passwd $user_name -d $pass
            echo "$user:$pass"|chpasswd
        fi
        
        if [[ "$init_dir" == "YES" ]]
        then
            chown $user_name:ftp $local_root
        fi
    else
        echo "- User name '$user_name' already exists!"
        addgroup $user_name ftp 
        echo "- The user is added only to the ftp group."
        if [[ ! -z "$local_root" ]]
        then
            if [[ ! -d "$local_root" ]]
            then
                echo "- Crating directory '$local_root' for '$user_name'"
                mkdir -m $DEFAULT_ACCESS -p "$local_root"
                chown $user_name:ftp "$local_root"
            fi
        fi
    fi 
}

_addVirtual(){
    local pass=$1
    local opt_pass=
    if [[ ! -z "$pass" ]]
    then
        opt_pass="-p ${pass}"
    fi
    echo "- Creating virtual user - '$user_name'"
    $script_path/../vusers/vuser.sh -c add -u ${user_name} $opt_pass
}

_add(){
    local pass=$1
    if [[ "$($configLib isVirtualUser)" == "YES" ]]
    then
        _addUserGuest
        #&> /dev/null
        _addVirtual $pass
    else    
        _addLocal $pass
        if [[ "$duplicate_user" == "YES" ]]
        then
            echo "- Init dublicate local user to virtual user"
           _addVirtual $pass 
        fi
    fi
}

_addUserDirConfig(){
    local local_root=$(echo $1|tr -d '"')
    local guest_username=$(echo $2|tr -d '"')
    local userConf="$script_path/../lib/config.sh $user_config_dir/$user_name"  
    if [[ ! -z "$user_config_dir" ]]
    then
        mkdir -p $user_config_dir
        if [[ ! -e "$user_config_dir/$user_name" ]]
        then
            echo "- Creating user config -'$user_config_dir/$user_name'" 
            touch $user_config_dir/$user_name
        fi
        
        if [[ ! -z "$local_root" && -z "$($userConf configParam local_root)" ]]
        then
            echo "local_root=$local_root" >> $user_config_dir/$user_name
            echo "- Added for '$user_name' parameter 'local_root=$local_root'" 
        fi
        if [[ ! -z "$guest_username" && -z "$($userConf configParam guest_username)" ]]
        then
            echo "guest_username=$guest_username" >> $user_config_dir/$user_name
            echo "- Added for '$user_name' parameter 'guest_username=$guest_username'"
        fi
    fi
}

_help(){
   cat <<EOF
[buildTpl user_name] - Assembly of templates '${user_config_dir}/\$USER/template/\$USER.tpl' for the users.  
    See 'user_config_dir params' in '$config_file'.

[setUserConfig user_name "param1=value\n param2=value\n ....."] - creates/extends configuration for the user in '${user_config_dir}/\$USER' file.

[unsetUserConfig user_name] - '${user_config_dir}/\$USER' configuration file will be renamed '${user_config_dir}/\$USER'.unset{No.}'

[setUserDirConfig user_name [/user/directory [guest_username]]] - Sets the local_root and guest_username parameters 
for the user in '${user_config_dir}/\$USER'
    - /user/directory - set local_root params in config.
    - guest_username - set guest_username params in config.

[configParam user_name param] - Prompts for a user parameter. If absent, returned the global parameter.

[init user_name [user_pass] [/user/directory [guest_username]]] - Initializes a new user.
    If the user's working directory exists, then the user (or guest user) will be assigned the ID of the owner 
    of the working directory (if there is no such owner). If the directory does not exist, it will be created.
    [user_pass] - User password
    [/user/directory [guest_username]] - see setUserDirConfig command.

[update user_name new_pass] - update user password. 
    If password === NONE, then a password for the local user will not be set. Access will be denied.

[delete user_name] - delete user

[show user_name] - show user data

Options:
-c /config/file - Main 'vsftpd' configuration file with which еthis script will work.
[-d] - Duplicate   local user as virtual user. For command init|update|delete|show.  Valid if local user mode is enabled
    This is necessary if you decide to change local users to virtual users without changing the password. 
EOF
}

buildTpl(){
    if [[ ! -z "${user_config_dir}" && -d "$user_config_dir/template" ]]
    then
        echo "-Create config files from templates in '$user_config_dir/template'"
        $script_path/../lib/createFromTpl.sh -t "$user_config_dir/template" -o "$user_config_dir" -i 2
    fi
}

setUserConfig(){
    local config=$@
    config=$(echo -e "${config}")
    config=$(echo "$config"|$script_path/../lib/tplToStr.sh)
    if [[ ! -z "$user_config_dir" ]]
    then
        mkdir -p $user_config_dir
        echo "$config">>"$user_config_dir/$user_name"
    fi
}

unsetUserConfig(){
    if [[ ! -z "$user_config_dir" ]]
    then
        rm "$user_config_dir/$user_name"
    fi
    local $file_name="$user_config_dir/${user_name}"
    local a=1
    local $unset_file_name=$file_name.unset$a
    while [[ -e "$unset_file_name" ]]
    do
        ((a++))
        unset_file_name="$file_name.unset$a"
        
    done;
    mv "$user_config_dir/$user_name" "$unset_file_name" 
}

setUserDirConfig(){
    local local_root=$1
    local guest_username=$2
    
    if [[ ! -z "$user_config_dir" ]]
    then
        mkdir -p $user_config_dir
        echo "local_root=$local_root" >> $user_config_dir/$user_name
        if [[ ! -z "$guest_username" ]]
        then
            echo "guest_username=$guest_username" >> $user_config_dir/$user_name
        fi
    fi
}

configParam(){
    local param=$1
    local configUserLib="$script_path/../lib/config.sh $user_config_dir/$user_name"
    local value
    if [[ ! -z "$user_config_dir" && -e "$user_config_dir/$user_name" ]]
    then
        value="$($configUserLib configParam $param)"
    fi
    if [[ -z "$value" ]]
    then
       value="$($configLib configParam $param)"
    fi
    echo "$value"
}

_sortPrioritiesUsersList(){
    local commands="$1"
    local primary_commands secondary_commands
    local cpath cuser cguest
    while read -r command
    do
        cuser=$(echo $command|awk '{print $1}')
        if [[ -z "$cuser" ]]
        then
            continue
        fi
        cpath=$(echo $command|awk '{print $3}')
        cguser=$(echo $command|awk '{print $4}')

        if [[ -z "$cpath" ]]
        then
            cpath=$($userLib configParam $cuser local_root)
        fi
        
        if [[ -z "$cguser" ]]
        then
            cguser=$($userLib configParam $cuser guest_username)
        fi
        local check=NO
        local ownerDir
        if [[ -z "$($lib userIdByName $cuser)" && -z "$(echo "$primary_commands"|grep "'$cpath'")" ]]
        then
            check=YES
            if [[ -d "$cpath" ]]
            then
                ownerDir="$($lib ownerIdDir "$cpath")"
                if [[ ! -z "$($lib userNameById $ownerDir)" ]]
                then
                   check=NO 
                fi
            fi
            if [[ "$($configLib isVirtualUser)" == "YES" && ! -z "$(echo "$primary_commands"|grep "'$cguser'")" ]]
            then
                check=NO
            fi
        fi
        if [[ "$check" == "YES" ]]
        then
            primary_commands="$primary_commands\n$cuser '$cpath' '$cguser'"
        else
            secondary_commands="$secondary_commands\n$cuser '$cpath' '$cguser'"
        fi
    done < <(echo -e "$commands")
    echo -e "$primary_commands"|while read -r command
    do
        if [[ -z "$command" ]]
        then
            continue
        fi        
        find_user=$(echo $command|awk '{print $1}')
        echo "$commands"|grep "$find_user"
    done
    echo -e "$secondary_commands"|while read -r command
    do
        if [[ -z "$command" ]]
        then
            continue
        fi
        find_user=$(echo $command|awk '{print $1}')
        echo "$commands"|grep "^\s*$find_user"
    done
}

_formatUsersList(){
    local list="$(echo "$1"|$script_path/../lib/tplToStr.sh)"
    list="$(_sortPrioritiesUsersList "$list")"
    list="$list \n\"\""
    echo -e "$list"
}

update(){
    local pass=$1
    if [[ "$($configLib isVirtualUser)" == "YES" ]]
    then
        $script_path/../vusers/vuser.sh -c update -u $user_name -p $pass
    else
        passwd $user_name -d $pass
    fi
}

delete(){
    if [[ "$($configLib isVirtualUser)" == "YES" ]]
    then
        $script_path/../vusers/vuser.sh -c delete -u $user_name
    else
        deluser $user_name
    fi     
}

show(){
    local id
    if [[ "$($configLib isVirtualUser)" == "YES" ]]
    then
        $script_path/../vusers/vuser.sh -c show -u $user_name
    else
        id=$($lib userIdByName $user_name)
        if [[ ! -z "$id" ]]
        then
            pass=$($lib hashUserPass $user_name)
            cat <<EOF
Type : local
ID : $id 
User : $user_name
Password hash : $pass
EOF
        else 
            echo "User '$user_name' is missing." 1>&2
            return 1
        fi
    fi
}

convertLocalToGuestUsers(){
    # - Enumerate all FTP local users, and exclude passwords. list all local FTP users and exclude passwords. 
    # Thus, vsftpd has access to directories as through guest users.
    # - check user config and check local_root and if not set guest_username parameter
    #     then For the users config files, assign the parameter 'guest_username=$user_name' 
    echo none
}

convertGuestToLocalUsers(){
    # - check guest_username for core config file, Enumerate all config users files, check guest_username ,  and set guest_username as local user and set password if check guest_username in DB .
    echo none
}

initUsersList(){
    local list="$(_formatUsersList "$1")"

    echo -e "$list"|while read -r command
    do
        $0 -c $config_file init $command 
    done
}

init(){
    #local pass=$(echo $1|tr -d '"')
    local pass=${1%\"};pass=${pass#\"}
    local dir=$2
    local guest=$3
    if [[ ! -z "$dir" || ! -z "$guest" ]]
    then
        dir=$(echo "$dir"|$script_path/../lib/tplToStr.sh)
        if [[ ! -z "$guest" ]]
        then
            guest=$(echo "$guest"|$script_path/../lib/tplToStr.sh)
        fi
        _addUserDirConfig $dir $guest
    fi
    if [[ ! -z "$user_name" ]]
    then
        _initUserSettings 
        _add $pass
    elif [[ "$($configLib isVirtualUser)" == "YES" ]]
    then
        _addShareUserGuest
    fi
}

if [[ "$command" == "buildTpl" || \
    "$command" == "setUserConfig" || \
    "$command" == "unsetUserConfig" || \
    "$command" == "setUserDirConfig" || \
    "$command" == "configParam" || \
    "$command" == "init" || \
    "$command" == "update" || \
    "$command" == "delete" || \
    "$command" == "show" || \
    "$command" == "initUsersList" ]]
then
   $command "$@"
elif [[ -z $command ]]
then
_help
else 
    echo "Warn: bad '$command' command"
    _help
fi



