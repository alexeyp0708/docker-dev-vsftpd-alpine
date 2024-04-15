#!/bin/sh
user="$1"
response=$(sqlite3 "${FTP_VUSER_DB}" "SELECT * FROM accounts WHERE user_name='$user' LIMIT 1")
if [[ -z "$response" ]]
then
    echo "User '$user' is missing." 1>&2
    return 1;
fi
password=$(echo \"$response\"|cut -d '|' -f 2)
cat <<EOF
Type : virtual
ID :
Name : ${user}
Password hash : ${password}
EOF
