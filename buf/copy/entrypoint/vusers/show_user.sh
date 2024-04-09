#!/bin/sh
user="$1"
response=$(sqlite3 "${FTP_VUSER_DB}" "SELECT * FROM accounts WHERE user_name='$user'")
if [[ -z "$response" ]]
then
    echo "User '$user' is missing."
    return 0;
fi
password="$(echo \"$response\"|cut -d '|' -f 2)"
cat <<EOF
---------------------------    
Name: ${user}
Password: ${password}
---------------------------
EOF
