#!/bin/bash
MCSDIR=/usr/local/mariadb/columnstore
mysql=( $MCSDIR/mysql/bin/mysql --defaults-extra-file=$MCSDIR/mysql/my.cnf -uroot)

# usage: file_env VAR [DEFAULT]
#    ie: file_env 'XYZ_DB_PASSWORD' 'example'
# (will allow for "$XYZ_DB_PASSWORD_FILE" to fill in the value of
#  "$XYZ_DB_PASSWORD" from a file, especially for Docker's secrets feature)
file_env() {
    local var="$1"
    local fileVar="${var}_FILE"
    local def="${2:-}"
    if [ "${!var:-}" ] && [ "${!fileVar:-}" ]; then
        echo >&2 "error: both $var and $fileVar are set (but are exclusive)"
        exit 1
    fi
    local val="$def"
    if [ "${!var:-}" ]; then
        val="${!var}"
    elif [ "${!fileVar:-}" ]; then
        val="$(< "${!fileVar}")"
    fi
    export "$var"="$val"
    unset "$fileVar"
}

file_env 'MARIADB_ROOT_PASSWORD'
if [ ! -z "$MARIADB_ROOT_PASSWORD" ]; then
    mysql+=( -p"${MARIADB_ROOT_PASSWORD}" )
fi

if [ ! -z $MARIADB_CS_DEBUG ]; then
    CREATE DATABASE IF NOT EXISTS `##test_db_name##`;
    "${mysql[@]}" -e "CREATE DATABASE IF NOT EXISTS test;"
    "${mysql[@]}" -e "CREATE DATABASE IF NOT EXISTS benchmark;"
    "${mysql[@]}" -e "GRANT ALL ON test.*  TO '$MARIADB_USER'@'%' ;"
    "${mysql[@]}" -e "GRANT ALL ON benchmark.* TO '$MARIADB_USER'@'%' ;" 
else 
    "${mysql[@]}" -e "CREATE DATABASE IF NOT EXISTS test;" 2>&1
    "${mysql[@]}" -e "CREATE DATABASE IF NOT EXISTS benchmark;"  2>&1
    "${mysql[@]}" -e "GRANT ALL ON test.*  TO '$MARIADB_USER'@'%' ;"  2>&1
    "${mysql[@]}" -e "GRANT ALL ON benchmark.* TO '$MARIADB_USER'@'%' ;"  2>&1
fi