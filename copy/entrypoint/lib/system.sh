# dependencies
# $config_file -abstract variable
userNameById() {
    grep -E "^[0-9a-zA-Z_]+:[0-9a-zA-Z_]+:$1:[0-9]+" /etc/passwd|xargs|cut -d: -f1
}

userIdByName() {
    grep "^$1:" /etc/passwd|xargs |cut -d: -f3
}

ownerIdDir() {
    ls -ldn $1|xargs|cut -d ' ' -f 3
}

hashUserPass() {
    grep "^$1:" /etc/shadow|xargs|cut -d: -f2
}
$@


