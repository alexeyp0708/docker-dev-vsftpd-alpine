#!/bin/sh
user="$1"
password="$2"
#if [[ -z "$password" ]]
#then
#    password=$(cat /dev/urandom | tr -dc A-Z-a-z-0-9 |head -n 10 -c 16)
#fi

#password="$(openssl passwd -6 "$password")"
password="$(mkpasswd "$password")"

is_exists="$(sqlite3 "${FTP_VUSER_DB}" "INSERT INTO accounts (user_name, user_password) VALUES ('$user','$password')" 2>&1)";
if [[ ! -z "$is_exists" ]]
then 
    echo "Warning:'$user' not added. User already exists." 1>&2
    return 1
fi
