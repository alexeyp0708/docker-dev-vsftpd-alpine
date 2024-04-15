background=NO
listen=YES
seccomp_sandbox=NO

anonymous_enable=NO
local_enable=YES
#guest_enable=YES
write_enable=YES
user_sub_token=$USER
local_root=/mnt/data/${HOSTNAME}/ftp
chroot_local_user=YES
allow_writeable_chroot=YES
hide_ids=YES

# passive mode 
pasv_enable=YES
pasv_addr_resolve=NO
pasv_address=${PASV_ADDRESS}
pasv_min_port=21100
pasv_max_port=21110


# active mode
port_enable=YES
connect_from_port_20=YES
ftp_data_port=20
connect_from_port_20=YES
listen_port=21

#ascii_download_enable=YES
#ascii_upload_enable=YES
#session_support=YES
setproctitle_enable=YES
idle_session_timeout=3600
data_connection_timeout=3600

xferlog_enable=YES
xferlog_file=/var/log/vsftpd.log
xferlog_std_format=NO
#dual_log_enable=YES
log_ftp_protocol=YES
file_open_mode=0666
pasv_promiscuous=NO
port_promiscuous=NO
guest_username=ftp-data
#user_config_dir=/etc/vsftpd/collection/users

${VSFTPD_CONFIG}

