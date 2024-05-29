#!/bin/sh
user=$1
sqlite3 "${FTP_VUSER_DB}" "DELETE FROM accounts WHERE user_name='$user';"
