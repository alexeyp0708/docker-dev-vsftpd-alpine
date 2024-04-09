#---------------------------------
# BASIC USER CONFIG
#---------------------------------

background=NO
listen=YES
anonymous_enable=NO
local_enable=YES
#guest_enable=YES
write_enable=YES
user_sub_token=$USER
local_root=${LOCAL_ROOT}
chroot_local_user=YES
allow_writeable_chroot=YES
hide_ids=YES
pasv_enable=YES
pasv_address=${PASV_ADDRESS}
pasv_min_port=21100
pasv_max_port=21110
pasv_addr_resolve=NO
seccomp_sandbox=NO
xferlog_enable=YES
xferlog_file=/var/log/vsftpd.log
xferlog_std_format=NO
#dual_log_enable=YES
log_ftp_protocol=YES
file_open_mode=0666
pasv_promiscuous=NO
port_promiscuous=NO
guest_username=ftp-data
user_config_dir=/etc/vsftpd/collection/users

${VSFTPD_CONFIG}

#---------------------------------
# END BASIC USER CONFIG
#---------------------------------