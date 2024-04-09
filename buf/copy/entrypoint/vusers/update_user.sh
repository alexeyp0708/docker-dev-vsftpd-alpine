#!/bin/sh
user="$1"
password="$2"
if [[ -z "$password" ]]
then
    password=$(cat /dev/urandom | tr -dc A-Z-a-z-0-9 |head -n 10 -c 16)
fi
sqlite3 "${FTP_VUSER_DB}" "UPDATE accounts SET user_password = '$password' WHERE user_name = '$user';"