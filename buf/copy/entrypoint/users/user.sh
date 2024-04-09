#!/bin/sh

script_path=$(dirname $(readlink -f "$0"))

lib="$script_path/../lib/system.sh"
configLib="$script_path/../lib/config.sh $1"
duplicate_user=NO
config_file=$1
command=$2
user_name=$3
shift
shift
shift

local_root=$($configLib configParam local_root)
guest_username=$($configLib configParam guest_username)
user_config_dir=$($configLib  configParam user_config_dir)

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

_addAsGuest(){
    local user_name=$guest_username;
    _addLocal NONE
}

_addLocal(){
    local pass=$1
    local opt_uid ls_dir owner_id
    if [[ -z "$($lib userIdByName $user_name)" ]]
    then
        if [[ -d "$local_root" ]]
        then
            owner_id=$($lib ownerIdDir "$local_root")
            if [[ -z "$($lib userNameById $owner_id)" ]]
            then
                opt_uid="-u $owner_id"
            fi
        fi
        
        adduser -s /sbin/nologin -h /var/lib/ftp -g $user_name -G ftp $opt_uid -D $user_name
        if [[ "$pass" != "NONE" ]]
        then
            passwd $user_name -d $pass
        fi

    else
        echo "User named already exists!"
        addgroup $user_name ftp 
        echo "The user is added only to the ftp group."
        pass=""
    fi 
    echo $pass
}

_addVirtual(){
    local pass=$1
    local opt_pass=
    if [[ ! -z "$pass" ]]
    then
        opt_pass="-p ${pass}"
    fi
    local buf="$($script_path/../vusers/vuser.sh -c add -u ${user_name} $opt_pass)"
    pass=$(echo "$buf"|grep "Password"|cut -d ":" -f 2|xargs)
    echo $pass
}

_add(){
    local pass=$1
    if [[ "$($configLib isVirtualUser)" == "YES" ]]
    then
        _addAsGuest &> /dev/null
        _addVirtual $pass
    else    
        _addLocal $pass
        if [[ "$duplicate_user" == "YES" ]]
        then
           _addVirtual $pass 
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
        $script_path/../createFromTpl.sh -t "$user_config_dir/template" -o "$user_config_dir" -i 2
    fi
}

_addUserDir(){
    local user_dir="$local_root"
    if [[ ! -z "$local_root" && ! -d "${local_root}"  ]]
    then
       mkdir -p $local_root
       chown $user_name:ftp $local_root
    fi
}

setUserConfig(){
    local config=$@
    config=$(echo -e "${config}")
    config=$(echo "$config"|$script_path/../lib/tplToStr.sh)
    if [[ ! -z "$user_config_dir" ]]
    then
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

update(){
    local pass=$1
    if [[ "$($configLib isVirtualUser)" == "YES" ]]
    then
        $script_path/../vusers/vuser update $user_name $pass
    else
        passwd $user_name -d $pass
    fi
}

delete(){
    if [[ "$($configLib isVirtualUser)" == "YES" ]]
    then
        $script_path/../vusers/vuser delete $user_name
    else
        deluser $user_name
    fi     
}

show(){
    local id
    if [[ "$($configLib isVirtualUser)" == "YES" ]]
    then
        $script_path/../vusers/vuser show $user_name
    else
        id=$($lib userIdByName $user_name)
        if [[ ! -z "$id" ]]
        then
            cat <<EOF
User : $user_name
  ID : $id 
EOF
        else 
            echo "User is missing."
        fi
    fi
}

convertLocalToGuestUsers(){
    # - Enumerate all FTP local users, and exclude passwords. list all local FTP users and exclude passwords. 
    # Thus, vsftpd has access to directories as through guest users.
    # - check user config and check local_root and if not set guest_username parameter
    #     then For the users config files, assign the parameter 'guest_username=$user_name' 
}
convertGuestToLocalUsers(){
    
}
init(){
    local pass=$1
    local root=$2
    local guest=$3
    if [[ ! -z "$root" ]]
    then
        root=$(echo "$root"|$script_path/../lib/tplToStr.sh)
        if [[ ! -z "$guest" ]]
        then
            guest=$(echo "$guest"|$script_path/../lib/tplToStr.sh)
        fi
        setUserDirConfig root guest
    fi
    _initUserSettings 
    _add $pass
    _addUserDir
}

if [[ "$command" == "buildTpl" || \
    "$command" == "setUserConfig" || \
    "$command" == "unsetUserConfig" || \
    "$command" == "setUserDirConfig" || \
    "$command" == "configParam" || \
    "$command" == "init" || \
    "$command" == "update" || \
    "$command" == "delete" || \
    "$command" == "show"  ]]
then
   $command $@
elif [[ -z $command ]]
then
_help
else 
    echo "Warn: bad '$command' command"
    _help
fi



