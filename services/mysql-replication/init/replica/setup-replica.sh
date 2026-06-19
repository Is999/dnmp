#!/bin/sh
set -eu

master_host="${MYSQL_MASTER_HOST:-mysql-master}"
master_port="${MYSQL_MASTER_PORT:-3306}"
replica_host="${MYSQL_SLAVE_HOST:-mysql-slave}"
replica_port="${MYSQL_SLAVE_PORT:-3306}"

wait_for_mysql_server() {
  host="$1"
  port="$2"

  echo "Waiting for MySQL server at ${host}:${port} ..."
  until mysqladmin ping -h"${host}" -P"${port}" --silent >/dev/null 2>&1; do
    sleep 2
  done
}

wait_for_mysql() {
  host="$1"
  port="$2"
  password="$3"

  echo "Waiting for MySQL at ${host}:${port} ..."
  until mysqladmin ping -h"${host}" -P"${port}" -uroot -p"${password}" --silent >/dev/null 2>&1; do
    sleep 2
  done
}

wait_for_replication_user() {
  echo "Waiting for replication user ${MYSQL_REPLICATION_USER} on ${master_host}:${master_port} ..."
  until mysql -h"${master_host}" -P"${master_port}" -u"${MYSQL_REPLICATION_USER}" -p"${MYSQL_REPLICATION_PASSWORD}" -e "SHOW MASTER STATUS\\G" >/dev/null 2>&1; do
    sleep 2
  done
}

wait_for_mysql_server "${master_host}" "${master_port}"
wait_for_replication_user
wait_for_mysql "${replica_host}" "${replica_port}" "${MYSQL_SLAVE_ROOT_PASSWORD}"

if mysql -h"${replica_host}" -P"${replica_port}" -uroot -p"${MYSQL_SLAVE_ROOT_PASSWORD}" -e "SHOW REPLICA STATUS\\G" 2>/dev/null | grep -q "Source_Host: ${master_host}"; then
  echo "Replication already configured, ensuring replica is running."
  mysql -h"${replica_host}" -P"${replica_port}" -uroot -p"${MYSQL_SLAVE_ROOT_PASSWORD}" -e "START REPLICA; SET GLOBAL super_read_only = ON;" >/dev/null 2>&1 || true
  mysql -h"${replica_host}" -P"${replica_port}" -uroot -p"${MYSQL_SLAVE_ROOT_PASSWORD}" -e "SHOW REPLICA STATUS\\G"
  exit 0
fi

mysql -h"${master_host}" -P"${master_port}" -u"${MYSQL_REPLICATION_USER}" -p"${MYSQL_REPLICATION_PASSWORD}" -e "SHOW MASTER STATUS\\G" >/dev/null

mysql -h"${replica_host}" -P"${replica_port}" -uroot -p"${MYSQL_SLAVE_ROOT_PASSWORD}" -e "STOP REPLICA;" >/dev/null 2>&1 || true
mysql -h"${replica_host}" -P"${replica_port}" -uroot -p"${MYSQL_SLAVE_ROOT_PASSWORD}" -e "RESET REPLICA ALL;" >/dev/null 2>&1 || true

mysql -h"${replica_host}" -P"${replica_port}" -uroot -p"${MYSQL_SLAVE_ROOT_PASSWORD}" <<-EOSQL
CHANGE REPLICATION SOURCE TO
  SOURCE_HOST='${master_host}',
  SOURCE_PORT=${master_port},
  SOURCE_USER='${MYSQL_REPLICATION_USER}',
  SOURCE_PASSWORD='${MYSQL_REPLICATION_PASSWORD}',
  SOURCE_AUTO_POSITION=1,
  GET_SOURCE_PUBLIC_KEY=1;
START REPLICA;
SET GLOBAL super_read_only = ON;
EOSQL

mysql -h"${replica_host}" -P"${replica_port}" -uroot -p"${MYSQL_SLAVE_ROOT_PASSWORD}" -e "SHOW REPLICA STATUS\\G"
