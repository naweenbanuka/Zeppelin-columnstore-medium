#!/bin/sh
mkdir -p /tmp/bookstore-csv
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

if [ ! -f "/docker-entrypoint-initdb.d/sandboxdata.tar" ]; then
  echo "Getting the bookstore sandbox archive ..."
  curl https://downloads.mariadb.com/sample-data/books5001.tar --output /docker-entrypoint-initdb.d/sandboxdata.tar
fi

echo "Extracting bookstore files ..."
tar -xf /docker-entrypoint-initdb.d/sandboxdata.tar --directory /tmp/bookstore-csv

# gunzip cover.csv.gz as will use LDI for innodb table later and simplifies
# for loop below.
currentDir=$(pwd)
cd /tmp/bookstore-csv
echo "Creating tables ..."
sed -i 's/%DB%/bookstore/g'  /tmp/bookstore-csv/01_load_ax_init.sql

"${mysql[@]}" < /tmp/bookstore-csv/01_load_ax_init.sql
echo "Loading bookstore data ..."

for i in *.mcs.csv.gz; do
    table=$(echo $i | cut -f 1 -d '.')
    zcat  $table.mcs.csv.gz | /usr/local/mariadb/columnstore/bin/cpimport -s ',' -E "'" bookstore $table
    rm -f $table.mcs.csv.gz
done

for i in *.inno.csv.gz; do
    gunzip $i
    table=$(echo $i | cut -f 1 -d '.')
    "${mysql[@]}" < /tmp/bookstore-csv/01_load_ax_init.sql bookstore -e "load data local infile '$table.inno.csv' into table bookstore.$table fields terminated by ',' enclosed by '''';"
    rm -f $table.inno.csv.gz
done
# now load the covers table which is innodb so use load data local infile
cat readme.md
cd $currentDir
rm -rf /tmp/bookstore-csv
