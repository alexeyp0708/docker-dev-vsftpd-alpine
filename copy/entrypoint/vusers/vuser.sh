#!/bin/sh
FTP_VUSER_DB="$(echo "${FTP_VUSER_DB}"|/entrypoint/lib/tplToStr.sh)"
script_path=$(dirname $(readlink -f "$0"))
user=
password=
command=
while getopts "c:u:p:h" options; do
    case "${options}" in
        h)
        echo "Enter the command $0 -c command -u \"user_name\" [-p \"password_user\"] [-d /path]"
        echo "'-c command' - Commands: 'add' - adding user, 'delete' - deleting user, 'update' - updating user, 'show' - Show user data."
        echo "'-u user_name' - User name to which the commands will be applied."
        echo "[-p user_password] - User password that will be written to the database."
        return 0
        ;;
        c)
        command="${OPTARG}"
        ;;
        u)
        user="${OPTARG}"
        ;;
        p)
        password="${OPTARG}"
        ;;      
    esac
done

if [[ -z "$user" ]]
then
    echo "($0) Warn: Option [-u 'user'] is required">&2
    return 1
fi

case "${command}" in
    "add")
        $script_path/add_user.sh $user $password
    ;;
    "delete")
        $script_path/delete_user.sh $user $password
    ;;
    "update")
        $script_path/update_user.sh $user $password
    ;;
    "show")
        $script_path/show_user.sh $user $password
    ;;
esac

