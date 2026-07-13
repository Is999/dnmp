#!/bin/sh
set -eu

role="${MYSQL_HEALTH_ROLE:-}"
max_lag="${MYSQL_REPLICATION_MAX_LAG_SECONDS:-30}"

if [ -z "${MYSQL_ROOT_PASSWORD:-}" ]; then
  echo "MYSQL_ROOT_PASSWORD must be set." >&2
  exit 1
fi

case "${max_lag}" in
  '' | *[!0-9]*)
    echo "MYSQL_REPLICATION_MAX_LAG_SECONDS must be a non-negative integer." >&2
    exit 1
    ;;
esac

export MYSQL_PWD="${MYSQL_ROOT_PASSWORD}"

mysql_query() {
  mysql --connect-timeout=2 -h127.0.0.1 -P3306 -uroot "$@"
}

mysql_query --batch --skip-column-names -e "SELECT 1" >/dev/null 2>&1

if [ "${role}" = "primary" ]; then
  primary_ok="$(mysql_query --batch --skip-column-names -e "
SELECT @@GLOBAL.read_only = 0
  AND @@GLOBAL.super_read_only = 0
  AND @@GLOBAL.log_bin = 1
  AND @@GLOBAL.gtid_mode = 'ON'
  AND @@GLOBAL.enforce_gtid_consistency = 'ON'
  AND @@GLOBAL.binlog_format = 'ROW'
  AND @@GLOBAL.sync_binlog = 1;
" 2>/dev/null)"
  [ "${primary_ok}" = "1" ]
  exit
fi

if [ "${role}" != "replica" ]; then
  echo "MYSQL_HEALTH_ROLE must be primary or replica." >&2
  exit 1
fi

replication_ok="$(mysql_query --batch --skip-column-names -e "
SELECT COUNT(*) = 1
FROM performance_schema.replication_connection_status AS connection
JOIN performance_schema.replication_applier_status AS applier USING (CHANNEL_NAME)
WHERE connection.CHANNEL_NAME = ''
  AND connection.SERVICE_STATE = 'ON'
  AND connection.LAST_ERROR_NUMBER = 0
  AND applier.SERVICE_STATE = 'ON'
  AND (SELECT COUNT(*)
       FROM performance_schema.replication_connection_configuration) = 1
  AND @@GLOBAL.read_only = 1
  AND @@GLOBAL.super_read_only = 1
  AND @@GLOBAL.relay_log_recovery = 1
  AND @@GLOBAL.log_bin = 1
  AND @@GLOBAL.gtid_mode = 'ON'
  AND @@GLOBAL.enforce_gtid_consistency = 'ON'
  AND @@GLOBAL.binlog_format = 'ROW'
  AND @@GLOBAL.sync_binlog = 1
  AND @@GLOBAL.log_replica_updates = 1;
" 2>/dev/null)"

if [ "${replication_ok}" != "1" ]; then
  exit 1
fi

status="$(mysql_query --vertical -e "SHOW REPLICA STATUS" 2>/dev/null)"

status_value() {
  key="$1"
  printf '%s\n' "${status}" | awk -F': ' -v key="${key}" '
    {
      name = $1
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", name)
      if (name == key) {
        print $2
        exit
      }
    }
  '
}

source_host="$(status_value Source_Host)"
source_port="$(status_value Source_Port)"
source_user="$(status_value Source_User)"
auto_position="$(status_value Auto_Position)"
lag_seconds="$(status_value Seconds_Behind_Source)"
io_running="$(status_value Replica_IO_Running)"
sql_running="$(status_value Replica_SQL_Running)"
last_io_errno="$(status_value Last_IO_Errno)"
last_sql_errno="$(status_value Last_SQL_Errno)"

if [ "${source_host}" != "${MYSQL_PRIMARY_HOST:-mysql-primary}" ] || \
  [ "${source_port}" != "${MYSQL_PRIMARY_PORT:-3306}" ] || \
  [ "${source_user}" != "${MYSQL_REPLICATION_USER:-}" ] || \
  [ "${auto_position}" != "1" ] || \
  [ "${io_running}" != "Yes" ] || \
  [ "${sql_running}" != "Yes" ] || \
  [ "${last_io_errno}" != "0" ] || \
  [ "${last_sql_errno}" != "0" ]; then
  exit 1
fi

case "${lag_seconds}" in
  '' | *[!0-9]*) exit 1 ;;
esac

[ "${lag_seconds}" -le "${max_lag}" ]
