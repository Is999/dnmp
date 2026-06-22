#!/bin/sh
set -eu

sql_string() {
  printf '%s' "$1" | sed "s/\\\\/\\\\\\\\/g; s/'/''/g"
}

replication_user="$(sql_string "${MYSQL_REPLICATION_USER}")"
replication_password="$(sql_string "${MYSQL_REPLICATION_PASSWORD}")"

mysql -uroot -p"${MYSQL_ROOT_PASSWORD}" <<-EOSQL
CREATE USER IF NOT EXISTS '${replication_user}'@'%' IDENTIFIED BY '${replication_password}';
GRANT REPLICATION SLAVE, REPLICATION CLIENT ON *.* TO '${replication_user}'@'%';
FLUSH PRIVILEGES;
EOSQL
