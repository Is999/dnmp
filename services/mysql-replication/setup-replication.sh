#!/bin/sh
set -eu

primary_host="${MYSQL_PRIMARY_HOST:-mysql-primary}"
primary_port="${MYSQL_PRIMARY_PORT:-3306}"
replica_host="${MYSQL_REPLICA_HOST:-mysql-replica}"
replica_port="${MYSQL_REPLICA_PORT:-3306}"
wait_seconds="${MYSQL_REPLICATION_WAIT_SECONDS:-300}"
max_lag="${MYSQL_REPLICATION_MAX_LAG_SECONDS:-30}"
existing_channel=0
password_rotation_active=0
password_normalization_required=0

mysql_client() {
  command mysql --connect-timeout=2 "$@"
}

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

status_value() {
  status="$1"
  key="$2"
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

wait_for_mysql() {
  host="$1"
  port="$2"
  password="$3"
  started_at="$(date +%s)"

  echo "Waiting for MySQL at ${host}:${port} ..."
  until MYSQL_PWD="${password}" mysql_client -h"${host}" -P"${port}" -uroot --batch --skip-column-names -e "SELECT 1" >/dev/null 2>&1; do
    elapsed=$(($(date +%s) - started_at))
    if [ "${elapsed}" -ge "${wait_seconds}" ]; then
      echo "Timed out waiting for authenticated MySQL at ${host}:${port}." >&2
      return 1
    fi
    sleep 2
  done
}

check_source_status() {
  if MYSQL_PWD="${MYSQL_REPLICATION_PASSWORD}" mysql_client -h"${primary_host}" -P"${primary_port}" -u"${MYSQL_REPLICATION_USER}" -e "SHOW BINARY LOG STATUS" >/dev/null 2>&1; then
    return 0
  fi

  MYSQL_PWD="${MYSQL_REPLICATION_PASSWORD}" mysql_client -h"${primary_host}" -P"${primary_port}" -u"${MYSQL_REPLICATION_USER}" -e "SHOW MASTER STATUS" >/dev/null 2>&1
}

wait_for_replication_user() {
  started_at="$(date +%s)"

  echo "Waiting for replication user ${MYSQL_REPLICATION_USER} on ${primary_host}:${primary_port} ..."
  until check_source_status; do
    elapsed=$(($(date +%s) - started_at))
    if [ "${elapsed}" -ge "${wait_seconds}" ]; then
      echo "Timed out waiting for replication user ${MYSQL_REPLICATION_USER} on ${primary_host}:${primary_port}." >&2
      return 1
    fi
    sleep 2
  done
}

validate_debezium_env() {
  if [ -n "${MYSQL_DEBEZIUM_USER:-}" ] || [ -n "${MYSQL_DEBEZIUM_PASSWORD:-}" ]; then
    if [ -z "${MYSQL_DEBEZIUM_USER:-}" ] || [ -z "${MYSQL_DEBEZIUM_PASSWORD:-}" ]; then
      echo "MYSQL_DEBEZIUM_USER and MYSQL_DEBEZIUM_PASSWORD must be set together." >&2
      return 1
    fi
    if [ "${MYSQL_DEBEZIUM_USER}" = "${MYSQL_REPLICATION_USER}" ]; then
      echo "MYSQL_DEBEZIUM_USER must differ from MYSQL_REPLICATION_USER." >&2
      return 1
    fi
    if [ "${MYSQL_DEBEZIUM_USER}" = "root" ]; then
      echo "MYSQL_DEBEZIUM_USER must be a dedicated non-root account." >&2
      return 1
    fi
  fi
}

replication_password_works() {
  MYSQL_PWD="${MYSQL_REPLICATION_PASSWORD}" mysql_client -h"${primary_host}" -P"${primary_port}" -u"${MYSQL_REPLICATION_USER}" -e "SELECT 1" >/dev/null 2>&1
}

debezium_password_works() {
  MYSQL_PWD="${MYSQL_DEBEZIUM_PASSWORD}" mysql_client -h"${primary_host}" -P"${primary_port}" -u"${MYSQL_DEBEZIUM_USER}" -e "SELECT 1" >/dev/null 2>&1
}

replication_secondary_password_exists() {
  replication_user_sql="$(sql_string "${MYSQL_REPLICATION_USER}")"
  MYSQL_PWD="${MYSQL_PRIMARY_ROOT_PASSWORD}" mysql_client -h"${primary_host}" -P"${primary_port}" -uroot --batch --skip-column-names -e "
SELECT COALESCE(JSON_CONTAINS_PATH(User_attributes, 'one', '$.additional_password'), 0)
FROM mysql.user
WHERE User = '${replication_user_sql}' AND Host = '%';
"
}

replication_password_reuse_allows_rotation() {
  replication_user_sql="$(sql_string "${MYSQL_REPLICATION_USER}")"
  MYSQL_PWD="${MYSQL_PRIMARY_ROOT_PASSWORD}" mysql_client -h"${primary_host}" -P"${primary_port}" -uroot --batch --skip-column-names -e "
SELECT COALESCE(Password_reuse_history, @@GLOBAL.password_history) = 0
  AND COALESCE(Password_reuse_time, @@GLOBAL.password_reuse_interval) = 0
FROM mysql.user
WHERE User = '${replication_user_sql}' AND Host = '%';
"
}

ensure_replication_user() {
  replication_user_sql="$(sql_string "${MYSQL_REPLICATION_USER}")"
  replication_password_sql="$(sql_string "${MYSQL_REPLICATION_PASSWORD}")"

  echo "Ensuring replication user ${MYSQL_REPLICATION_USER} on ${primary_host}:${primary_port} ..."
  MYSQL_PWD="${MYSQL_PRIMARY_ROOT_PASSWORD}" mysql_client -h"${primary_host}" -P"${primary_port}" -uroot <<-EOSQL
	CREATE USER IF NOT EXISTS '${replication_user_sql}'@'%' IDENTIFIED BY '${replication_password_sql}';
	REVOKE ALL PRIVILEGES, GRANT OPTION FROM '${replication_user_sql}'@'%';
	GRANT REPLICATION SLAVE, REPLICATION CLIENT ON *.* TO '${replication_user_sql}'@'%';
	FLUSH PRIVILEGES;
	EOSQL

  if ! secondary_password_exists="$(replication_secondary_password_exists)"; then
    echo "Unable to inspect replication password state." >&2
    return 1
  fi
  case "${secondary_password_exists}" in
    0 | 1) ;;
    *)
      echo "Replication account state is missing or invalid for ${MYSQL_REPLICATION_USER}@%." >&2
      return 1
      ;;
  esac

  if replication_password_works; then
    if [ "${secondary_password_exists}" = "1" ]; then
      password_rotation_active=1
      password_normalization_required=1
    fi
    return 0
  fi

  if [ "${secondary_password_exists}" = "1" ]; then
    echo "Replication account already has a secondary password; refusing to replace it with an unverified third credential." >&2
    echo "Rerun with the current or secondary password to normalize the account, or use the approved manual rotation process." >&2
    return 1
  fi

  if [ "${existing_channel}" -eq 1 ]; then
    if ! password_reuse_allows="$(replication_password_reuse_allows_rotation)" || [ "${password_reuse_allows}" != "1" ]; then
      echo "Automatic replication password rotation requires password history and reuse interval to be disabled for this account." >&2
      echo "Rotate the credential manually, then rerun with the final password." >&2
      return 1
    fi
    echo "Retaining the current replication password until the channel accepts the new credential ..."
    MYSQL_PWD="${MYSQL_PRIMARY_ROOT_PASSWORD}" mysql_client -h"${primary_host}" -P"${primary_port}" -uroot <<-EOSQL
	ALTER USER '${replication_user_sql}'@'%' IDENTIFIED BY '${replication_password_sql}' RETAIN CURRENT PASSWORD;
	EOSQL
    password_rotation_active=1
    return
  fi

  MYSQL_PWD="${MYSQL_PRIMARY_ROOT_PASSWORD}" mysql_client -h"${primary_host}" -P"${primary_port}" -uroot -e "ALTER USER '${replication_user_sql}'@'%' IDENTIFIED BY '${replication_password_sql}';"
}

ensure_debezium_user() {
  if [ -z "${MYSQL_DEBEZIUM_USER:-}" ]; then
    return 0
  fi

  debezium_user_sql="$(sql_string "${MYSQL_DEBEZIUM_USER}")"
  debezium_password_sql="$(sql_string "${MYSQL_DEBEZIUM_PASSWORD}")"

  echo "Ensuring Debezium user ${MYSQL_DEBEZIUM_USER} on ${primary_host}:${primary_port} ..."
  MYSQL_PWD="${MYSQL_PRIMARY_ROOT_PASSWORD}" mysql_client -h"${primary_host}" -P"${primary_port}" -uroot <<-EOSQL
	CREATE USER IF NOT EXISTS '${debezium_user_sql}'@'%' IDENTIFIED BY '${debezium_password_sql}';
	REVOKE ALL PRIVILEGES, GRANT OPTION FROM '${debezium_user_sql}'@'%';
	GRANT SELECT, RELOAD, SHOW DATABASES, REPLICATION SLAVE, REPLICATION CLIENT ON *.* TO '${debezium_user_sql}'@'%';
	FLUSH PRIVILEGES;
	EOSQL

  if debezium_password_works; then
    return 0
  fi

  MYSQL_PWD="${MYSQL_PRIMARY_ROOT_PASSWORD}" mysql_client -h"${primary_host}" -P"${primary_port}" -uroot -e "ALTER USER '${debezium_user_sql}'@'%' IDENTIFIED BY '${debezium_password_sql}';"
}

replica_status() {
  MYSQL_PWD="${MYSQL_REPLICA_ROOT_PASSWORD}" mysql_client --vertical -h"${replica_host}" -P"${replica_port}" -uroot -e "SHOW REPLICA STATUS FOR CHANNEL ''" 2>/dev/null
}

replica_channel_state() {
  MYSQL_PWD="${MYSQL_REPLICA_ROOT_PASSWORD}" mysql_client -h"${replica_host}" -P"${replica_port}" -uroot --batch --skip-column-names -e "SELECT CONCAT(COUNT(*), ':', COALESCE(SUM(CHANNEL_NAME = ''), 0)) FROM performance_schema.replication_connection_configuration" 2>/dev/null
}

validate_channel_state() {
  channel_state="$1"
  case "${channel_state}" in
    0:0 | 1:1) return 0 ;;
    1:0)
      echo "Replica has a named replication channel; only the default channel is supported." >&2
      return 1
      ;;
    *:*)
      channel_count="${channel_state%%:*}"
      default_channel_count="${channel_state#*:}"
      case "${channel_count}:${default_channel_count}" in
        *[!0-9:]* | :* | *:)
          echo "Replica channel state is missing or invalid." >&2
          ;;
        *)
          echo "Replica has ${channel_count} replication channels (${default_channel_count} default); only one default channel is supported." >&2
          ;;
      esac
      ;;
    *)
      echo "Replica channel state is missing or invalid." >&2
      ;;
  esac
  return 1
}

validate_existing_channel() {
  status="$1"
  current_host="$(status_value "${status}" Source_Host)"
  current_port="$(status_value "${status}" Source_Port)"
  current_user="$(status_value "${status}" Source_User)"
  auto_position="$(status_value "${status}" Auto_Position)"
  sql_running="$(status_value "${status}" Replica_SQL_Running)"
  last_sql_errno="$(status_value "${status}" Last_SQL_Errno)"

  if [ "${current_host}" != "${primary_host}" ] || [ "${current_port}" != "${primary_port}" ]; then
    echo "Replica is configured for ${current_host}:${current_port}, expected ${primary_host}:${primary_port}." >&2
    echo "Refusing to switch sources automatically. Restore a consistent replica before changing the source." >&2
    return 1
  fi

  if [ "${current_user}" != "${MYSQL_REPLICATION_USER}" ]; then
    echo "Replica uses ${current_user}, expected ${MYSQL_REPLICATION_USER}." >&2
    echo "Replication user renames require an explicit credential migration and old-user cleanup." >&2
    return 1
  fi

  if [ "${auto_position}" != "1" ]; then
    echo "Existing replica channel is not using GTID auto-position." >&2
    return 1
  fi

  if [ "${last_sql_errno}" != "0" ]; then
    echo "Replica SQL thread has error ${last_sql_errno}; refusing to change or restart it automatically." >&2
    printf '%s\n' "${status}"
    return 1
  fi

  case "${sql_running}" in
    Yes) ;;
    No)
      echo "Replica SQL thread is stopped without an SQL error; it will be resumed." >&2
      ;;
    *)
      echo "Replica SQL thread state is missing or invalid." >&2
      printf '%s\n' "${status}"
      return 1
      ;;
  esac
}

preflight_replication() {
  if ! channel_state="$(replica_channel_state)"; then
    echo "Unable to inspect replica channels before changing source credentials." >&2
    return 1
  fi
  if ! validate_channel_state "${channel_state}"; then
    return 1
  fi
  channel_count="${channel_state%%:*}"
  if ! status="$(replica_status)"; then
    echo "Unable to query replica channel before changing source credentials." >&2
    return 1
  fi

  if [ "${channel_count}" = "0" ]; then
    if [ -n "${status}" ]; then
      echo "Replica channel appeared while preflight was running." >&2
      return 1
    fi
    existing_channel=0
    return 0
  fi

  if [ -z "${status}" ]; then
    echo "Replica channel exists but its status is unavailable." >&2
    return 1
  fi

  if ! validate_existing_channel "${status}"; then
    return 1
  fi
  existing_channel=1
}

configure_replication() {
  if ! channel_state="$(replica_channel_state)"; then
    echo "Unable to inspect replica channels before applying their configuration." >&2
    return 1
  fi
  if ! validate_channel_state "${channel_state}"; then
    return 1
  fi
  channel_count="${channel_state%%:*}"
  if ! status="$(replica_status)"; then
    echo "Unable to query replica channel before applying its configuration." >&2
    return 1
  fi
  primary_host_sql="$(sql_string "${primary_host}")"
  replication_user_sql="$(sql_string "${MYSQL_REPLICATION_USER}")"
  replication_password_sql="$(sql_string "${MYSQL_REPLICATION_PASSWORD}")"

  if [ "${existing_channel}" -eq 0 ]; then
    if [ "${channel_count}" != "0" ] || [ -n "${status}" ]; then
      echo "Replica channel appeared after preflight; refusing to change it." >&2
      return 1
    fi
    echo "Configuring GTID replication from ${primary_host}:${primary_port} ..."
    MYSQL_PWD="${MYSQL_REPLICA_ROOT_PASSWORD}" mysql_client -h"${replica_host}" -P"${replica_port}" -uroot <<-EOSQL
	CHANGE REPLICATION SOURCE TO
	  SOURCE_HOST='${primary_host_sql}',
	  SOURCE_PORT=${primary_port},
	  SOURCE_USER='${replication_user_sql}',
	  SOURCE_PASSWORD='${replication_password_sql}',
	  SOURCE_AUTO_POSITION=1,
	  GET_SOURCE_PUBLIC_KEY=1
	FOR CHANNEL '';
	SET PERSIST super_read_only = ON;
	START REPLICA FOR CHANNEL '';
	EOSQL
    existing_channel=1
    return
  fi

  if [ "${channel_count}" != "1" ] || [ -z "${status}" ]; then
    echo "Existing replica channel disappeared after preflight." >&2
    return 1
  fi
  if ! validate_existing_channel "${status}"; then
    return 1
  fi

  echo "Refreshing replication connection credentials without resetting relay logs ..."
  if ! MYSQL_PWD="${MYSQL_REPLICA_ROOT_PASSWORD}" mysql_client -h"${replica_host}" -P"${replica_port}" -uroot -e "SET GLOBAL rpl_stop_replica_timeout = ${wait_seconds}; STOP REPLICA IO_THREAD FOR CHANNEL ''" >/dev/null 2>&1; then
    echo "Unable to stop the replica IO thread within ${wait_seconds} seconds." >&2
    return 1
  fi
  MYSQL_PWD="${MYSQL_REPLICA_ROOT_PASSWORD}" mysql_client -h"${replica_host}" -P"${replica_port}" -uroot <<-EOSQL
	CHANGE REPLICATION SOURCE TO
	  SOURCE_HOST='${primary_host_sql}',
	  SOURCE_PORT=${primary_port},
	  SOURCE_USER='${replication_user_sql}',
	  SOURCE_PASSWORD='${replication_password_sql}',
	  GET_SOURCE_PUBLIC_KEY=1
	FOR CHANNEL '';
	SET PERSIST super_read_only = ON;
	START REPLICA FOR CHANNEL '';
	EOSQL
}

discard_old_replication_password() {
  if [ "${password_rotation_active}" -eq 0 ]; then
    return 0
  fi

  replication_user_sql="$(sql_string "${MYSQL_REPLICATION_USER}")"
  # Keep the old credential until the retained password reaches the replica.
  wait_for_replica_gtid
  MYSQL_PWD="${MYSQL_PRIMARY_ROOT_PASSWORD}" mysql_client -h"${primary_host}" -P"${primary_port}" -uroot -e "ALTER USER '${replication_user_sql}'@'%' DISCARD OLD PASSWORD;"
}

wait_for_replica_running() {
  started_at="$(date +%s)"
  status=""

  while :; do
    if ! status="$(replica_status)"; then
      elapsed=$(($(date +%s) - started_at))
      if [ "${elapsed}" -ge "${wait_seconds}" ]; then
        break
      fi
      sleep 2
      continue
    fi
    io_running="$(status_value "${status}" Replica_IO_Running)"
    sql_running="$(status_value "${status}" Replica_SQL_Running)"
    lag_seconds="$(status_value "${status}" Seconds_Behind_Source)"
    auto_position="$(status_value "${status}" Auto_Position)"
    source_host="$(status_value "${status}" Source_Host)"
    source_port="$(status_value "${status}" Source_Port)"
    source_user="$(status_value "${status}" Source_User)"
    runtime_state="$(MYSQL_PWD="${MYSQL_REPLICA_ROOT_PASSWORD}" mysql_client -h"${replica_host}" -P"${replica_port}" -uroot --batch --skip-column-names -e "SELECT @@GLOBAL.read_only, @@GLOBAL.super_read_only, @@GLOBAL.relay_log_recovery, @@GLOBAL.log_bin, @@GLOBAL.gtid_mode, @@GLOBAL.enforce_gtid_consistency, @@GLOBAL.binlog_format, @@GLOBAL.sync_binlog, @@GLOBAL.log_replica_updates, (SELECT COUNT(*) FROM performance_schema.replication_connection_configuration), (SELECT COUNT(*) FROM performance_schema.replication_connection_configuration WHERE CHANNEL_NAME = '')" 2>/dev/null | tr '\t' ' ' || true)"
    lag_ok=0

    case "${lag_seconds}" in
      '' | *[!0-9]*) ;;
      *)
        if [ "${lag_seconds}" -le "${max_lag}" ]; then
          lag_ok=1
        fi
        ;;
    esac

    if [ "${io_running}" = "Yes" ] && [ "${sql_running}" = "Yes" ] && \
      [ "${lag_ok}" = "1" ] && [ "${auto_position}" = "1" ] && \
      [ "${source_host}" = "${primary_host}" ] && [ "${source_port}" = "${primary_port}" ] && \
      [ "${source_user}" = "${MYSQL_REPLICATION_USER}" ] && \
      [ "${runtime_state}" = "1 1 1 1 ON ON ROW 1 1 1 1" ]; then
      printf '%s\n' "${status}"
      return 0
    fi

    elapsed=$(($(date +%s) - started_at))
    if [ "${elapsed}" -ge "${wait_seconds}" ]; then
      break
    fi
    sleep 2
  done

  printf '%s\n' "${status}"
  echo "Replica did not become healthy in time." >&2
  return 1
}

normalize_replication_password() {
  if [ "${password_normalization_required}" -eq 0 ]; then
    return 0
  fi

  if ! password_reuse_allows="$(replication_password_reuse_allows_rotation)" || [ "${password_reuse_allows}" != "1" ]; then
    echo "Automatic replication password normalization requires password history and reuse interval to be disabled for this account." >&2
    echo "Normalize the configured password as the current credential through the approved rotation process, refresh and verify the replica channel, then discard the secondary password." >&2
    return 1
  fi

  replication_user_sql="$(sql_string "${MYSQL_REPLICATION_USER}")"
  replication_password_sql="$(sql_string "${MYSQL_REPLICATION_PASSWORD}")"
  echo "Normalizing the configured replication password before removing the secondary credential ..."
  MYSQL_PWD="${MYSQL_PRIMARY_ROOT_PASSWORD}" mysql_client -h"${primary_host}" -P"${primary_port}" -uroot -e "ALTER USER '${replication_user_sql}'@'%' IDENTIFIED BY '${replication_password_sql}';"
  configure_replication
  wait_for_replica_running
}

wait_for_replica_gtid() {
  if ! source_gtid="$(MYSQL_PWD="${MYSQL_PRIMARY_ROOT_PASSWORD}" mysql_client -h"${primary_host}" -P"${primary_port}" -uroot --batch --skip-column-names -e "SELECT @@GLOBAL.gtid_executed" 2>/dev/null)"; then
    echo "Unable to read the primary GTID set after account changes." >&2
    return 1
  fi
  source_gtid="$(printf '%s' "${source_gtid}" | tr -d '[:space:]')"
  if [ -z "${source_gtid}" ]; then
    echo "Primary GTID set is empty after account changes." >&2
    return 1
  fi

  source_gtid_sql="$(sql_string "${source_gtid}")"
  if ! wait_result="$(MYSQL_PWD="${MYSQL_REPLICA_ROOT_PASSWORD}" mysql_client -h"${replica_host}" -P"${replica_port}" -uroot --batch --skip-column-names -e "SELECT WAIT_FOR_EXECUTED_GTID_SET('${source_gtid_sql}', ${wait_seconds})" 2>/dev/null)"; then
    echo "Unable to wait for the replica to execute account changes." >&2
    return 1
  fi
  wait_result="$(printf '%s' "${wait_result}" | tr -d '[:space:]')"
  if [ "${wait_result}" != "0" ]; then
    echo "Replica did not execute the primary GTID set within ${wait_seconds} seconds." >&2
    return 1
  fi
}

require_env MYSQL_PRIMARY_ROOT_PASSWORD
require_env MYSQL_REPLICA_ROOT_PASSWORD
require_env MYSQL_REPLICATION_USER
require_env MYSQL_REPLICATION_PASSWORD

if [ "${MYSQL_REPLICATION_USER}" = "root" ]; then
  echo "MYSQL_REPLICATION_USER must be a dedicated non-root account." >&2
  exit 1
fi

case "${primary_port}:${replica_port}:${wait_seconds}:${max_lag}" in
  *[!0-9:]*)
    echo "MySQL ports and replication thresholds must be integers." >&2
    exit 1
    ;;
esac

if [ "${primary_port}" -le 0 ] || [ "${replica_port}" -le 0 ] || [ "${wait_seconds}" -lt 2 ]; then
  echo "MySQL ports must be positive and MYSQL_REPLICATION_WAIT_SECONDS must be at least 2." >&2
  exit 1
fi

validate_debezium_env
wait_for_mysql "${primary_host}" "${primary_port}" "${MYSQL_PRIMARY_ROOT_PASSWORD}"
wait_for_mysql "${replica_host}" "${replica_port}" "${MYSQL_REPLICA_ROOT_PASSWORD}"
preflight_replication
ensure_replication_user
wait_for_replication_user
configure_replication
wait_for_replica_running
normalize_replication_password
discard_old_replication_password
ensure_debezium_user
wait_for_replica_gtid
wait_for_replica_running
