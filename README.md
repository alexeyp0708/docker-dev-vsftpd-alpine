## Description

Цель проекта - FTP сервер для Web разработчиков.
Предназначен для синхранизации скриптов в томах к которым подключены другие контейнеры.
В любых других случаях можно развернуть в качестве рабочего сервиса.
 
 Определения
 
- Локальный юзер - это юзер который создан в операционной системе и отлица которого работают с рабочей директорией юзера.
- Гостевой юзер - это локальный аккаунт юзера от лица которого работают виртуальные юзеры с указанной директорией.

Особенности :
1. Конфигурационные файлы формируются через шаблоны, благодоря которым можно внедрять в конфиг файл значения перемнных.

2. Если рабочая директория юзера существует, то локальный юзер будет создан с ID владельца директории (если он не существует в системе). 
Тем самым локальный юзер будет иметь паралельный доступ к данным как владелец.
Концепция: одна рабочая директория - один юзер.

3. Если рабочая директория виртуального юзера была ранее создана в томе другим контейнером (например веб сервис),
то гостевой юзер будет создан с ID владельца директории (если он не существует в системе). 
Тем самым виртуальные юзера через гостевой юзер будут иметь паралельный доступ к данным как владелец.
Концепция: одна рабочая директория - много юзеров.

## Warn

- Для работы с виртуальными юзерами используется сервис авторизации PAM через модуль [pam_sqlite.so](https://github.com/HormyAJP/pam_sqlite3) 
где для хранения юзеров используется БД sqlite3. 
Пакет [pam_sqlite.so для Alpine](https://pkgs.alpinelinux.org/package/edge/testing/x86/pam_sqlite3) находится в репозитории [testing](https://wiki.alpinelinux.org/wiki/Repositories#Testing), 
в результате чего данный образ подвержен рискам не возможности установки пакета `pam_sqlite.so` в будущем.

## Enviroment

- `FTP_USER` - Empty default.  User to connect.If the User is specified, it will be created. 
If there are no virtual user settings in the config file, it will ask for a password for the local user.   
- `FTP_PASS` - Empty default. User password to connect.  For a local user it does not matter. If the field is empty, a user with an empty password will be created.
For a virtual user a password will be generated if this field is empty. 
- `FTP_VUSER_DB` - Default `/mnt/data/\${HOSTNAME}/DB/virtual_users.db`. Path to the sqlite database file where virtual users are stored.
If it does not exist, it will be created.  
- `VSFTPD_CONFIG` - Default -empty. If empty,  then will accept the default settings. 
- `HOST_GATEWAY` - Default -empty. If empty,  then will accept container gateway.  

# Volumes

- `/mnt/data` - Declarative Volume. Not mounted.

## Adding configuration

Переменная среды VSFTPD_CONFIG может в себе содержать дополнительные настройки конфиг файла.
Рекомендуется в VSFTPD_CONFIG загружать данные из вашего файла настроек - `-e VSFTPD_CONFIG="$(cat VSFTPD_CONFIG.env)"`
Чтобы передать настройки в консоли, с возможностью перевода строк, используйте в качестве примера команду
`-e VSFTPD_CONFIG="$(echo -e ' first_line_command=value \n second_line_command=value')"`

При запуске команды `docer run ... image_vsftpd` - будет использоваться конфиг файл по умолчанию `/etс/vsftpd/vsftpd.conf`
При запуске команды `docer run ... -e VSFTPD_CONFIG="$(cat VSFTPD_CONFIG.env)" image_vsftpd` - будет использоваться пустой
конфиг файл `/etс/vsftpd/collection/env.conf` в который интегрируется переменная среды `VSFTPD_CONFIG`
При запуске команды `docer run ... -e VSFTPD_CONFIG="$(cat VSFTPD_CONFIG.env)" image_vsftpd -c /etс/vsftpd/collection/basic.conf` 
- будет использоваться конфиг файл`/etс/vsftpd/collection/basic.conf` в который интегрируется переменная среды `VSFTPD_CONFIG`


### how to create configuration file templates

A config file template is a file where instead of values
​​you can specify environment variables using the `${ENV_VAR}` style.
Templates are converted into config files with environment variables set.
Thanks to this approach, you can implement your own environment variables that will be used in config files.

If you run the command `docker run ... image_vsftpd -c /dir/my_config.conf` 
then in `/dir/template` directory will search for templates with `.tpl` extension. 
Before running the daemon, `/dir/template/my_config.conf.tpl` will be converted to `/dir/my_config.conf`.
It is recommended to create templates instead of config files.
By set the `${VSFTPD_CONFIG}` variable at the end of the template,
you can expand the file with additional settings set in the `${VSFTPD_CONFIG}` variable.


When generating templates, directory nesting is also taken into account. 
Therefore, you can create config file  templates in a subdirectory for Users .

Warn - All config files and templates must be Unix format. (UTF8)+(LF)

## Running

- `docker run -e VSFTPD_CONFIG="$(cat ${VSFTPD_CONFIG.conf})" ... ftp_image`  
- `docker run ... ftp_image -h` -  Description run options  
- `docker run ... ftp_image -c /mnt/data/config/ftp/my.conf` - Set your own configuration file. 
If there is a `/mnt/data/config/ftp/template` directory with a `my.conf.tpl` template in the config file directory, 
then the template will be converted into a `/mnt/data/config/ftp/my.conf`. 
All environment variables in the template will be replaced.

## Aditional config files

   - `/etс/vsftpd/collection/basic.conf` - Генерируется из шаблона `/etс/vsftpd/collection/template/basic.conf.tpl`. 
   Настройки для пасивного режима и локальных юзеров.
   Если добавить следующие настройки `-e VSFTPD_CONFIG="$(echo -e ' guest_enable=YES \n pam_service_name=vsftpd_virtual \n virtual_use_local_privs=YES')"`
   то вы включите виртуальных юзеров, которые будут храниться  в sqlite3 БД.
   Для виртуальных юзеров каталог является обшим и доступ у юзеров одинаковый.
   Для локальных юзеров каталог является обшим , но права на доступ к каталогам и файлам распространяются только
   на создателей дочерних каталогов/файлов.

## Data and Users

ПО умолчанию данные юзеров хранятся в каталоге `/mnt/data/${HOSTNAME}/ftp` - переменная `${FTP_DIR}`.
Если каталог не существует, то он будет создан, и назначен владелец ftp, группа ftp.
Чтобы расширить права общего каталога (если он установлен настройками)  для всех локальных юзеров состоящих в группе `ftp`,
расширьте права каталога для `ftp` группы.
Пример `chown -R :ftp /mnt/data/$HOSTNAME/ftp && chmod -R 660 /mnt/data/$HOSTNAME/ftp && addgroup my_login ftp`.

При запуске контейнера с переменной `-e FTP_USER="my_login"`  и ${FTP_USER} юзер не существует, 
то будет добавлен новый юзер. Если конейнер настроен на локальных юзеров, то юзер ${FTP_USER}, 
будет установлен владельцем каталога, который определен параметром `local_root` в настройках.


### virtual users

Support for virtual users occurs through PAM and the pam_sqlite3.so module
https://github.com/HormyAJP/pam_sqlite3
User registration occurs in the sqlite3 default database -`/mnt/data/\${HOSTNAME}/DB/virtual_users.db` -vatiable ${FTP_VUSER_DB}
Table layout as described in https://github.com/HormyAJP/pam_sqlite3
You can add or remove users using sql queries sqlite3.

To add or remove virtual a user, use the command '/entrypoint/vusers.sh -h'

To add or remove local a user, use the command 'adduser --help' and 'deluser --help'


## Image extension 
Чтобы расширить поведение entrypoint родительского скрипта испольуйте следующий шаблон
```
RUN <<EOF
cat <<EOF2 >/entrypoint/child_before_instructions.sh
# your scripts
EOF2

cat <<EOF2 >/entrypoint/child_after_instructions.sh
# your scripts
EOF2
EOF

```

## Settings vsftpd
https://security.appspot.com/vsftpd/vsftpd_conf.html
https://linux.die.net/man/5/vsftpd.conf



# Logs
Set value "YES" for "background" parameter in config file for to display logs on the screen when the container running.

And set parametrs for logs
```
xferlog_enable=YES
xferlog_file=/var/log/vsftpd.log
xferlog_std_format=NO
```

-------------------


Для этого нужно в параметре 'guest_username' конфига `vsftpd` указать любого несуществующего юзера.
3. Если директория локального юзера создана другим контейнером (например веб сервис),
то для нового локального юзера будет присвоен ID владельца директории (если он не существует в системе).
Если указать имя нового юзера по имени каталога, то FTP сможет подключаться к данному каталогу тома как владелец.
(Смотреть  параметр 'user_sub_token' и 'local_root' ).
Такой формат полезен, если разные контейнеры сохраняют свои рабочие данные в одном томе. 
А к таким данным каждого контейнера как правило назначается свой владелец. 
С учетом локальных настроек для каждого юзера, можно реализовывать доступ к разным томам (к которым подключены др контейнеры).