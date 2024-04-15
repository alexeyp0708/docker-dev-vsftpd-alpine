# Alpine+vsftpd+pam_sqlite3.so

## Description

The task  of the project is an FTP server for Backend developers.  
Designed to synchronize scripts in volumes to which other Docker containers are connected.
In this case, FTP does not change the directory rights and works with it as is.

## Definitions
 
- Local user is a user that is created in the operating system and on whose behalf works with the user’s working directory.
- guest user is a local user account on behalf of which virtual users with the specified directory work.
- Virtual user - these are users of the FTP service only, who have access to FTP through the PAM service.
- Working directory - Directory to which the user has access via FTP


## Peculiarities 

1. Configuration files are formed through templates, thanks to which you can embed variable values ​​into the config file.

2. If the user's working directory exists, then the local user will be created with the ID of the directory owner (if it does not exist in the system).
Thus, the local user will have parallel access to the data as the owner.
Concept: one working directory - one user.

3. If the working directory of the virtual user was previously created in the volume by another container (for example, a web service),
then the guest user will be created with the ID of the directory owner (if it does not exist in the system).
Thus, virtual users through a guest user will have parallel access to data as the owner.
Concept: one working directory - one guest user - many virtual users.

4. Each working directory must have its own owner. If different working directories have the same owner, then they can only be accessed through a guest user to which different virtual users are attached.

## Fast start

Create vlan network db_net
(settings are individual and depend on your host machine)
```
docker network create -d ipvlan \
    --subnet=172.19.32.4/20 \
    --gateway=172.19.32.1 \
    -o ipvlan_mode=l2 \
    -o parent=eth0 db_net
```
 run the command
```
docker run  --rm -it --name ftp_test \
-e USERS_LIST="test" \
-e HOSTNAME="ftp_test" \
-e VSFTPD_CONFIG="background=YES" \
--network db_net --ip 172.19.32.4  \
 --mount type=volume,src=ftp_test,dst=/mnt/data \
 ftp_image -c /etc/vsftpd/collection/basic.conf
```
 Remove the `-e HOSTNAME="ftp_test"` options from CLI command.
Then the container data  will be created each time in a new directory.

Delete the ftp_test volume every time you want to create a new data stack.
`docker volume rm ftp_test`

Connect your FTP client (172.19.32.4:21 ->passive mode->user:test) 
Alpine

Warning: Filezilla may not work in passive mode with vsftpd.

###  Learning by example

1.  Create a list of users you want to use.  It is assumed that through each user you will communicate with the volume (or directory) of another container.

File `USERS_LIST.env`
```
user1
user2
user3 ""  /mnt/data/${HOSTNAME}/ftp_users/user3 guest_user3
user4 "" /mnt/data/${HOSTNAME}/ftp_users/user4 guest_user4
```
It is recommended to assign a new local user for each existing working directory.
When creating virtual users, it is recommended to assign a new guest user for each existing working directory.

For basic settings, use the file in the container `/etc/vsftpd/collection/basic.conf`. 
The file does not actually exist, but every time a container is created, it is generated from the template `/etc/vsftpd/collection/template/basic.conf.tpl`,
where the variables `${VAR}` are replaced with values.

### Using local users

Create an additional settings file `VSFTPD_CONFIG.env`.  
Its contents through the VSFTPD_CONFIG environment variable are integrated into the config file /etc/vsftpd/collection/basic.conf

```
## If background=YES, then the ability to display information on the display will be implemented.   
background=YES
local_root=/mnt/data/${HOSTNAME}/ftp
```

Start the container
```
docker run --rm -it --name ftp_test \
-e VSFTPD_CONFIG="$(cat VSFTPD_CONFIG.env)" \
-e HOSTNAME="test_host" \
-e USERS_LIST="$(cat USERS_LIST.env)" \
--network db_net --ip 172.19.32.4 \
--mount type=volume,src=ftp_test,dst=/mnt/data \
ftp_image -c /etc/vsftpd/collection/basic.conf
```

Note:
Alternative way  is transfer the file  `USERS_LIST.env`  in the container via  copied  or mounted.
And specify the path to the file when starting the container
`run ... ftp_image -c /etc/vsftpd/collection/basic.conf -u /USERS_LIST.env` ,

Entrypoint will create:
- User `user1`.  If the /mnt/data/test_host/ftp directory exists, it will create a user `user1` with the ID of the directory owner  (if he does not exist).
- User `user2`.  Will have limited rights to the /mnt/data/test_host/ftp .
- User`user3` and  `/etc/vsftpd/collection/users/user3` config file . If the `/mnt/data/test_host/ftp_users/user3` directory exists, it will create a user `user1` with the ID of the directory owner (if he does not exist).
- User`user4` and  `/etc/vsftpd/collection/users/user4`config file. ЕIf the `/mnt/data/test_host/ftp_users/user4` directory exists, it will create a user `user4`  with the ID of the directory owner (if he does not exist).
directory, since its owner will be `user3`
- Will create the directory `/mnt/data/test_host/ftp` if it does not exist and assign it as owner `user1`Access rights  -740.
- Creates directory `/mnt/data/test_host/ftp_users/user3` if it does not exist and assigns it as owner `user4` Access rights  -740.
- Creates directory directory `/mnt/data/test_host/ftp_users/user4` if it does not exist and assign it as owner `user4` Access rights  -740.



Disable the firewall on the client

For a Windows client, to disable the firewall, enter the command:
`netsh advfirewall firewall add rule name="FTP" dir=in action=allow profile=any localip=any remoteip=localsubnet remoteport=20,21 protocol=tcp`

This needs to be done so that the ftp client can connect in active mode.

For the connection, use the container IP.

Connect to the ftp server using user accounts.  
Conduct various experiments with deleting and adding data.

### Using virtual users

Virtual users are needed when more than one user needs to be connected to one volume/directory. 
Or when there are different directories, but they have the same owner.

Change the advanced settings file  `VSFTPD_CONFIG.env`
```
background=YES
local_root=/mnt/data/${HOSTNAME}/ftp
guest_enable=YES
pam_service_name=vsftpd_virtual
virtual_use_local_privs=YES
```
Start the container
```
docker run --rm -it  --name ftp_test \
-e VSFTPD_CONFIG="$(cat VSFTPD_CONFIG.env)" \
-e HOSTNAME="test_host" \ 
-e USERS_LIST="$(cat USERS_LIST.env)" \
--network db_net --ip 172.19.32.4 \
--mount type=volume,src=ftp_test,dst=/mnt/data \
ftp_image -c /etc/vsftpd/collection/basic.conf
```

The entrypoint will created:
-virtual user `user1`.  Will be bind with the local user `ftp-data` and have access to the directory `/mnt/data/test_host/ftp`  
- local user `ftp-data`. If the `/mnt/data/test_host/ftp`  directory exists, it will create a user `ftp-data` with the ID of the directory owner (if  he does not exist).
- virtual user `user2` .Will be bind with the local user `ftp-data` and have access to the directory `/mnt/data/test_host/ftp`
- virtual user `user3` and `/etc/vsftpd/collection/users/user3` config file . Virtual user will be bind with the local user `guest_user3` and have access to the directory `/mnt/data/test_host/ftp_users/user3`.
- local user `guest_user3`. If the `/mnt/data/test_host/ftp_users/user3 ` directory exists, it will create a user `guest_user3` with the ID of the directory owner (if he does not exist).
- virtual user`user4` and `/etc/vsftpd/collection/users/user4` config file. Virtual user will be bind with the local user  `guest_user4` and have access to the directory `/mnt/data/test_host/ftp_users/user4`.
-  local user  `guest_user4`.  If the `/mnt/data/test_host/ftp_users/user4` directory exists, it will create a user `guest_user4` with the ID of the directory owner (if he does not exist).
- Will create the directory `/mnt/data/test_host/ftp` if it does not exist and assign it as owner `ftp-data`
- Will create the directory `/mnt/data/test_host/ftp_users/user3` if it does not exist and assign it as owner `guest_user3`
- Will create the directory `/mnt/data/test_host/ftp_users/user4` if it does not exist and assign it as owner `guest_user4`

Connect to the ftp server using user accounts.  
Make sure that you have access to the same user directories.  
Conduct various experiments with deleting and adding data.


## Warn

- Filezila for Windows in passive mode cannot obtain a list of directories (LIST => 425 Failed to establish connection.)

## Enviroment

- `USERS_LIST` - Optional. Blank default value. Format value `user_name [password] [/work/directory] [guest_user]\n ...`

- `FTP_VUSER_DB` - Default `/mnt/data/\${HOSTNAME}/DB/virtual_users.db`. Path to the sqlite database file where virtual users are stored. If it does not exist, it will be created.  
- `VSFTPD_CONFIG` - An additional set of settings for the vsftpd.config file. Settings are implemented into the config file by specifying ${VSFTPD_CONFIG} in the template file.
- `HOST_GATEWAY` - Default -empty. If empty,  then will accept container gateway.  
- `DEFAULT_ACCESS` -  Default 700. Permissions with which directories are created for users. See chmod command

# Volumes

- `/mnt/data` - Декларативный объем. Не смонтирован.

## Adding configuration

### Adding additional settings in config file

The VSFTPD_CONFIG environment variable may contain additional settings for the config file.
It is recommended to load data from your settings file into VSFTPD_CONFIG - `-e VSFTPD_CONFIG="$(cat VSFTPD_CONFIG.env)"`
or
`-e VSFTPD_CONFIG="$(echo -e ' first_line_command=value \n second_line_command=value')"`
or 
`-e VSFTPD_CONFIG="first_line_command=value \n second_line_command=value"`

When running the command format `docer run ... image_vsftpd` - the default config file `/etс/vsftpd/vsftpd.conf` will be used .
 
When running the command format `docer run ... -e VSFTPD_CONFIG="$(cat VSFTPD_CONFIG.env)" image_vsftpd`, then it will be used  
config file `/etс/vsftpd/collection/env.conf` which has no parameters and into which the environment variable `VSFTPD_CONFIG` is integrated.

When you run a command in the format `docer run ... -e VSFTPD_CONFIG="$(cat VSFTPD_CONFIG.env)" image_vsftpd -c /etс/vsftpd/collection/basic.conf` then  will be used the config file `/etс/vsftpd/collection/basic.conf` into which the environment variable `VSFTPD_CONFIG` is integrated

### Loading a list of users.

If the list of users was mounted or copied into a container, then you can indicate it using the command
`docker run ... ftp_image -u /USERS_LIST.env` 
The file will be deleted as soon as the script reads it.

You can also specify a list of users in a enveroment  variable
`docker run -e USERS_LIST="user1 pass /local/root1 guest_user1\nuser1 pass /local/root1 guest_user1"`

User stirng format for users list:
 `user_name [password] [local_root] [guest_username]`
Where:
`user_name` - username to create an account
`password` - user password.   ""- empty password if you need to pass the following parameters.
`local_root` - user's working directory.  "" - empty value if you need to pass the following parameters
`guest_username` - guest user, on whose behalf the virtual user will use the working directory (for virtual users)

Each new line is a new user.

From the list, users whose parameters have not previously been declared for other users are initialized first.

### How to create configuration file templates

A config file template is a file where instead of values
​​you can specify environment variables using the `${ENV_VAR}` style.
Templates are converted into config files with environment variables set.
Thanks to this approach, you can implement your own environment variables that will be used in config files.

If you run the command `docker run ... image_vsftpd -c /dir/my_config.conf` then in `/dir/template` directory will search for templates with `.tpl` extension. 
Before running the daemon,   `/dir/template/my_config.conf.tpl` file will be converted to `/dir/my_config.conf` file.
It is recommended to create templates instead of config files.
By set the `${VSFTPD_CONFIG}` variable at the end of the template,
you can expand the file with additional settings set in the `${VSFTPD_CONFIG}` variable.

When generating templates, directory nesting is also taken into account. 
Therefore, you can create config file  templates in a subdirectory for users .

Warn - All config files and templates must be Unix format. (UTF8)+(LF)

## Running

- `docker run -e VSFTPD_CONFIG="$(cat ${VSFTPD_CONFIG.conf})" -e USERS_LIST="user1\nuser2" ... ftp_image`  
- `docker run ... --rm ftp_image -h` -  Description run options  
- `docker run ... ftp_image -c /mnt/data/config/ftp/my.conf` - Set your own configuration file. 
-  `docker run ... ftp_image -u /mnt/data/config/ftp/USERS_LIST.env` - Users list for ctreating accounts. - File removing after initialization.
If there is a `/mnt/data/config/ftp/template` directory with a `my.conf.tpl` template in the config file directory, 
then the template will be converted into a `/mnt/data/config/ftp/my.conf`. 
All environment variables in the template will be replaced.

## Aditional config files

   - `/etс/vsftpd/collection/basic.conf` - Generated from template`/etс/vsftpd/collection/template/basic.conf.tpl`. 
Settings for passive and active modes and local users.
 If you add the following settings `-e VSFTPD_CONFIG="$(echo -e ' guest_enable=YES \n pam_service_name=vsftpd_virtual \n virtual_use_local_privs=YES')"` then you will enable virtual users, which will be stored in the sqlite3 database.


### Virtual users

To work with virtual users, the PAM authorization service is used through the module  [pam_sqlite.so](https://github.com/HormyAJP/pam_sqlite3)  where a sqlite3 database is used to store users.
Pack  [pam_sqlite.so for Alpine](https://pkgs.alpinelinux.org/package/edge/testing/x86/pam_sqlite3) located in [testing](https://wiki.alpinelinux.org/wiki/Repositories#Testing) repository. 
As a result, this image is at risk of being unable to be installed if the `pam_sqlite.so` package is removed from the Alpine repositories.

User registration occurs in the sqlite3 default database -`/mnt/data/\${HOSTNAME}/DB/virtual_users.db` -vatiable ${FTP_VUSER_DB}
Table layout as described in https://github.com/HormyAJP/pam_sqlite3
You can add or remove users using sql queries sqlite3.


## Image extension 

To extend the parent script's entrypoint behavior use the following template
```
RUN <<EOF
cat <<EOF2 >>/entrypoint/source_before.sh
# your scripts
EOF2

cat <<EOF2 >>/entrypoint/source_after.sh
# your scripts
EOF2

EOF
```

## Settings vsftpd
https://security.appspot.com/vsftpd/vsftpd_conf.html
https://linux.die.net/man/5/vsftpd.conf

The entrypoint script in the configuration file defines some parameters:

is a virtual user
```
pam_service_name=vsftpd_virtual
virtual_use_local_privs=YES
```

Default local directory (Required)
```
local_root=/data/ftp
```

Default guest user  (Required for virtual users)
```
guest_username=ftp
```

Directory users configs 
```
user_config_dir=/data/config/users
```

If set to YES, then the path specified in the local_root parameter will be set as the home directory in the system (in /etc/passwd file) for the local user.
In this case, the directory's permissions may change.
```
passwd_chroot_enable=NO
```


local directory in user config 
```
local_root=/data/ftp/users
```

 guest user  in user config 
 ```
guest_username=ftp_user1
```



## Logs
Set value "YES" for "background" parameter in config file for to display logs on the screen when the container running.

And set parametrs for logs
```
xferlog_enable=YES
xferlog_file=/var/log/vsftpd.log
xferlog_std_format=NO
```
-------------------

##  Client settings

### Active mode
If vsftpd is in active mode and the client device produces the following logs:
```
FTP response: Client "{IP}", "200 PORT command successful. Consider using PASV.
FTP command: Client "{IP}", "LIST"
FTP response: Client "{IP}", "425 Failed to establish connection."
```
This is due to the fact that on the client side the firewall settings are set to block incoming connections.
To check this, try disabling the firewall on your computer.

Firewall settings must meet the following specifications
```
Rule: incoming
Action: allow
Local IP: any
Remote IP: localhost|IP|gateway|subnetwork(based on your protection conditions)
Remote port: 20,21
Protocol: TCP
```

For windows
Run as administrator:
`netsh advfirewall firewall add rule name="FTP" dir=in action=allow profile=any localip=any remoteip=localsubnet remoteport=20,21 protocol=tcp`

For details, see `netsh advfirewall firewall add rule /?`
or
https://learn.microsoft.com/ru-ru/windows/security/operating-system-security/network-security/windows-firewall/configure-with-command-line?tabs=powershell

Configure manually for Windows.

```
Control Panel -> Windows Defender Firewall ->Additional parameters ->Incoming connection rules ->Create rule -> For ports -> protocol TCP + all local ports -> allow connects -> Rule for all profiles (checks all profiles) -> Name - FTP ->save

Change FTP rule 
Protocols and Ports tab -> Remote port 20,21
Area tab -> Remote addresses -> Otional(IP/local network/interface ...)
```
(You can offer other instructions on how to set up different clients.)







