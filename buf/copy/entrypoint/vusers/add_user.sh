#!/bin/sh
user="$1"
password="$2"
echo "'$password'"
#if [[ -z "$password" ]]
#then
#    password=$(cat /dev/urandom | tr -dc A-Z-a-z-0-9 |head -n 10 -c 16)
#fi

sqlite3 "${FTP_VUSER_DB}" "INSERT INTO accounts (user_name, user_password) VALUES ('$user','$password');"