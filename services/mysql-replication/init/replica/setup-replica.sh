#!/bin/sh
set -eu

master_host="${MYSQL_MASTER_HOST:-mysql-master}"
master_port="${MYSQL_MASTER_PORT:-3306}"
replica_host="${MYSQL_SLAVE_HOST:-mysql-slave}"
replica_port="${MYSQL_SLAVE_PORT:-3306}"
wait_seconds="${MYSQL_REPLICATION_WAIT_SECONDS:-120}"

sql_string() {
  printf '%s' "$1" | sed "s/\\\\/\\\\\\\\/g; s/'/''/g"
}

wait_for_mysql_server() {
  host="$1"
  port="$2"
  elapsed=0

  echo "Waiting for MySQL server at ${host}:${port} ..."
  until mysqladmin ping -h"${host}" -P"${port}" --silent >/dev/null 2>&1; do
    if [ "${elapsed}" -ge "${wait_seconds}" ]; then
      echo "Timed out waiting for MySQL server at ${host}:${port}." >&2
      return 1
    fi
    sleep 2
    elapsed=$((elapsed + 2))
  done
}

wait_for_mysql() {
  host="$1"
  port="$2"
  password="$3"
  elapsed=0

  echo "Waiting for MySQL at ${host}:${port} ..."
  until mysqladmin ping -h"${host}" -P"${port}" -uroot -p"${password}" --silent >/dev/null 2>&1; do
    if [ "${elapsed}" -ge "${wait_seconds}" ]; then
      echo "Timed out waiting for MySQL at ${host}:${port}." >&2
      return 1
    fi
    sleep 2
    elapsed=$((elapsed + 2))
  done
}

check_source_status() {
  if mysql -h"${master_host}" -P"${master_port}" -u"${MYSQL_REPLICATION_USER}" -p"${MYSQL_REPLICATION_PASSWORD}" -e "SHOW BINARY LOG STATUS" >/dev/null 2>&1; then
    return 0
  fi

  mysql -h"${master_host}" -P"${master_port}" -u"${MYSQL_REPLICATION_USER}" -p"${MYSQL_REPLICATION_PASSWORD}" -e "SHOW MASTER STATUS" >/dev/null 2>&1
}

wait_for_replication_user() {
  elapsed=0

  echo "Waiting for replication user ${MYSQL_REPLICATION_USER} on ${master_host}:${master_port} ..."
  until check_source_status; do
    if [ "${elapsed}" -ge "${wait_seconds}" ]; then
      echo "Timed out waiting for replication user ${MYSQL_REPLICATION_USER} on ${master_host}:${master_port}." >&2
      return 1
    fi
    sleep 2
    elapsed=$((elapsed + 2))
  done
}

ensure_replication_user() {
  replication_user_sql="$(sql_string "${MYSQL_REPLICATION_USER}")"
  replication_password_sql="$(sql_string "${MYSQL_REPLICATION_PASSWORD}")"

  echo "Ensuring replication user ${MYSQL_REPLICATION_USER} on ${master_host}:${master_port} ..."
  mysql -h"${master_host}" -P"${master_port}" -uroot -p"${MYSQL_MASTER_ROOT_PASSWORD}" <<-EOSQL
CREATE USER IF NOT EXISTS '${replication_user_sql}'@'%' IDENTIFIED BY '${replication_password_sql}';
ALTER USER '${replication_user_sql}'@'%' IDENTIFIED BY '${replication_password_sql}';
GRANT REPLICATION SLAVE, REPLICATION CLIENT ON *.* TO '${replication_user_sql}'@'%';
FLUSH PRIVILEGES;
EOSQL
}

wait_for_replica_running() {
  tries=0
  status=""

  while [ "${tries}" -lt 30 ]; do
    status="$(mysql --vertical -h"${replica_host}" -P"${replica_port}" -uroot -p"${MYSQL_SLAVE_ROOT_PASSWORD}" -e "SHOW REPLICA STATUS" 2>/dev/null || true)"
    io_running="$(printf "%s\n" "${status}" | awk -F': ' '/Replica_IO_Running:/ {print $2; exit}')"
    sql_running="$(printf "%s\n" "${status}" | awk -F': ' '/Replica_SQL_Running:/ {print $2; exit}')"

    if [ "${io_running}" = "Yes" ] && [ "${sql_running}" = "Yes" ]; then
      printf "%s\n" "${status}"
      return 0
    fi

    sleep 2
    tries=$((tries + 1))
  done

  printf "%s\n" "${status}"
  echo "Replica did not become healthy in time." >&2
  return 1
}

wait_for_mysql_server "${master_host}" "${master_port}"
wait_for_mysql "${master_host}" "${master_port}" "${MYSQL_MASTER_ROOT_PASSWORD}"
ensure_replication_user
wait_for_replication_user
wait_for_mysql "${replica_host}" "${replica_port}" "${MYSQL_SLAVE_ROOT_PASSWORD}"

if mysql --vertical -h"${replica_host}" -P"${replica_port}" -uroot -p"${MYSQL_SLAVE_ROOT_PASSWORD}" -e "SHOW REPLICA STATUS" 2>/dev/null | grep -Fq "Source_Host: ${master_host}"; then
  echo "Replication already configured, ensuring replica is running."
  mysql -h"${replica_host}" -P"${replica_port}" -uroot -p"${MYSQL_SLAVE_ROOT_PASSWORD}" -e "START REPLICA; SET GLOBAL super_read_only = ON;" >/dev/null 2>&1 || true
  wait_for_replica_running
  exit 0
fi

check_source_status

mysql -h"${replica_host}" -P"${replica_port}" -uroot -p"${MYSQL_SLAVE_ROOT_PASSWORD}" -e "STOP REPLICA;" >/dev/null 2>&1 || true
mysql -h"${replica_host}" -P"${replica_port}" -uroot -p"${MYSQL_SLAVE_ROOT_PASSWORD}" -e "RESET REPLICA ALL;" >/dev/null 2>&1 || true

master_host_sql="$(sql_string "${master_host}")"
replication_user_sql="$(sql_string "${MYSQL_REPLICATION_USER}")"
replication_password_sql="$(sql_string "${MYSQL_REPLICATION_PASSWORD}")"

mysql -h"${replica_host}" -P"${replica_port}" -uroot -p"${MYSQL_SLAVE_ROOT_PASSWORD}" <<-EOSQL
CHANGE REPLICATION SOURCE TO
  SOURCE_HOST='${master_host_sql}',
  SOURCE_PORT=${master_port},
  SOURCE_USER='${replication_user_sql}',
  SOURCE_PASSWORD='${replication_password_sql}',
  SOURCE_AUTO_POSITION=1,
  GET_SOURCE_PUBLIC_KEY=1;
START REPLICA;
SET GLOBAL super_read_only = ON;
EOSQL

wait_for_replica_running
