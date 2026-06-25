#!/bin/sh
set -eu

sql_string() {
  printf '%s' "$1" | sed "s/\\\\/\\\\\\\\/g; s/'/''/g"
}

require_env() {
  name="$1"
  eval "value=\${$name:-}"
  if [ -z "${value}" ]; then
    echo "${name} must be set." >&2
    exit 1
  fi
}

require_env MYSQL_ROOT_PASSWORD
require_env MYSQL_REPLICATION_USER
require_env MYSQL_REPLICATION_PASSWORD

replication_user="$(sql_string "${MYSQL_REPLICATION_USER}")"
replication_password="$(sql_string "${MYSQL_REPLICATION_PASSWORD}")"

if [ -n "${MYSQL_DEBEZIUM_USER:-}" ] || [ -n "${MYSQL_DEBEZIUM_PASSWORD:-}" ]; then
  if [ -z "${MYSQL_DEBEZIUM_USER:-}" ] || [ -z "${MYSQL_DEBEZIUM_PASSWORD:-}" ]; then
    echo "MYSQL_DEBEZIUM_USER and MYSQL_DEBEZIUM_PASSWORD must be set together." >&2
    exit 1
  fi
fi

mysql -uroot -p"${MYSQL_ROOT_PASSWORD}" <<-EOSQL
CREATE USER IF NOT EXISTS '${replication_user}'@'%' IDENTIFIED BY '${replication_password}';
ALTER USER '${replication_user}'@'%' IDENTIFIED BY '${replication_password}';
GRANT REPLICATION SLAVE, REPLICATION CLIENT ON *.* TO '${replication_user}'@'%';
REVOKE SELECT, RELOAD, SHOW DATABASES ON *.* FROM '${replication_user}'@'%';
FLUSH PRIVILEGES;
EOSQL

if [ -n "${MYSQL_DEBEZIUM_USER:-}" ]; then
  debezium_user="$(sql_string "${MYSQL_DEBEZIUM_USER}")"
  debezium_password="$(sql_string "${MYSQL_DEBEZIUM_PASSWORD}")"

  mysql -uroot -p"${MYSQL_ROOT_PASSWORD}" <<-EOSQL
CREATE USER IF NOT EXISTS '${debezium_user}'@'%' IDENTIFIED BY '${debezium_password}';
ALTER USER '${debezium_user}'@'%' IDENTIFIED BY '${debezium_password}';
GRANT SELECT, RELOAD, SHOW DATABASES, REPLICATION SLAVE, REPLICATION CLIENT ON *.* TO '${debezium_user}'@'%';
FLUSH PRIVILEGES;
EOSQL
fi
