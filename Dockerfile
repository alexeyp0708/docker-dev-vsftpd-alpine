FROM alpine:latest


ENV FTP_VUSER_DB=/mnt/data/\${HOSTNAME}/DB/virtual_users.db
ENV USERS_LIST=

ENV VSFTPD_CONFIG=
ENV PASV_ADDRESS=
ENV DEFAULT_ACCESS=700

RUN <<EOF
apk update 
apk upgrade
apk add openrc vsftpd gettext coreutils sqlite openssl
EOF

RUN <<EOF
#apk add syslog-ng busybox-openrc
##rc-update add syslog boot
#rc-status
#touch /run/openrc/softlevel
EOF

RUN <<EOF
apk add  --repository="https://dl-cdn.alpinelinux.org/alpine/edge/testing" pam_sqlite3 
    
cat <<EOF2 > /etc/pam_sqlite3.conf
database = /etc/users.db
table = accounts
user_column = user_name
pwd_column = user_password
pwd_type_column = password_type
pw_type=md5
expired_column = acc_expired
newtok_column = acc_new_pwreq
debug
EOF2

EOF

#RUN adduser -u ${USER_ID} ftp && addgroup -g ${GROUP_ID} ftp
COPY ./copy /

RUN <<EOF
cat <<EOF2 >/entrypoint/instructions.sh
FTP_VUSER_DB="\$(echo \$FTP_VUSER_DB|/entrypoint/lib/tplToStr.sh)"

cat <<EOF3 > /etc/pam.d/vsftpd_virtual
#%PAM-1.0
auth	required	pam_sqlite3.so	database=\${FTP_VUSER_DB} 
account	required	pam_sqlite3.so	database=\${FTP_VUSER_DB}
password    required    pam_sqlite3.so database=\${FTP_VUSER_DB}
session	required	pam_loginuid.so
EOF3
if [[ ! -e "\${FTP_VUSER_DB}" ]]
then
    mkdir -p \$(dirname "\${FTP_VUSER_DB}")
    sqlite3 "\${FTP_VUSER_DB}" "CREATE TABLE accounts (user_name TEXT PRIMARY KEY, user_password TEXT NOT NULL, password_type INTEGER DEFAULT 4, acc_expired TEXT DEFAULT \"0\", acc_new_pwreq TEXT DEFAULT \"0\");"
    chown :ftp "\${FTP_VUSER_DB}"
    chmod 640 "\${FTP_VUSER_DB}"
fi
if [[ -z "${PASV_ADDRESS}" ]]
then
    PASV_ADDRESS=$(/sbin/ip route|awk '/default/ { print $3 }')
fi
EOF2

chown -R root:root "/entrypoint/"
chmod -R 755 "/entrypoint/"
ln -s /entrypoint/adm/ftpuser.sh /usr/bin/ftpuser
EOF

#VOLUME "/mnt/data"
ENTRYPOINT ["/entrypoint/run.sh"]