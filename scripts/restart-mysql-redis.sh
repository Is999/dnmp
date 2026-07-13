#!/bin/sh
set -eu

cd "$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)"

setup_lock_dir=/tmp/dnmp-restart-mysql-redis.lock

release_setup_lock() {
  rmdir "${setup_lock_dir}" 2>/dev/null || true
}

if ! mkdir -m 700 "${setup_lock_dir}" 2>/dev/null; then
  echo "Another MySQL/Redis setup is running, or a stale setup lock exists: ${setup_lock_dir}." >&2
  echo "After confirming no setup process is running, remove the stale directory with rmdir and retry." >&2
  exit 1
fi
trap release_setup_lock EXIT
trap 'exit 1' HUP INT TERM

if [ ! -f docker-compose.yml ] || [ ! -f docker-compose.mysql-redis.yml ]; then
  echo "Please copy docker-compose.sample.yml and docker-compose.mysql-redis.sample.yml before setup." >&2
  echo "  cp docker-compose.sample.yml docker-compose.yml" >&2
  echo "  cp docker-compose.mysql-redis.sample.yml docker-compose.mysql-redis.yml" >&2
  exit 1
fi

if ! redis_config_checksums="$(cksum services/redis/redis-cluster.conf services/redis/cluster/start-node.sh)"; then
  echo "Unable to checksum Redis Cluster configuration." >&2
  exit 1
fi
if ! redis_digest_output="$(printf '%s\n' "${redis_config_checksums}" | cksum)"; then
  echo "Unable to calculate Redis Cluster configuration digest." >&2
  exit 1
fi
REDIS_CLUSTER_CONFIG_DIGEST="${redis_digest_output%% *}"
export REDIS_CLUSTER_CONFIG_DIGEST

if ! docker compose version >/dev/null 2>&1; then
  echo "Docker Compose v2 (docker compose) is required." >&2
  exit 1
fi

dc() {
  docker compose -f docker-compose.yml -f docker-compose.mysql-redis.yml "$@"
}

mysql_inspection_value() {
  key="$1"
  printf '%s\n' "${mysql_inspection_output}" | awk -F= -v key="${key}" '$1 == key { print substr($0, length($1) + 2); exit }'
}

inspect_mysql_service() {
  service="$1"
  inspect_data="$2"
  # shellcheck disable=SC2016
  if ! mysql_inspection_output="$(dc run -T --rm --no-deps --entrypoint /bin/sh "${service}" -c '
    set -eu
    marker_value() {
      value="$(cat "$1")"
      case "${value}" in
        "" | *[!A-Za-z0-9._-]*)
          echo "Invalid MySQL data marker: $1" >&2
          exit 1
          ;;
      esac
      printf "%s" "${value}"
    }

    checksum="$(cksum /etc/mysql/conf.d/mysql.cnf)"
    state=unchecked
    pending=""
    if [ "$1" = "1" ]; then
      if ! data_entry="$(find /var/lib/mysql -mindepth 1 -maxdepth 1 ! -name .gitignore ! -name .dnmp-initializing-version -print -quit)"; then
        echo "Unable to inspect MySQL data directory." >&2
        exit 1
      fi
      if [ ! -d /var/lib/mysql/mysql ]; then
        if [ -z "${data_entry}" ]; then
          state=empty
        else
          state=partial
        fi
      elif [ ! -f /var/lib/mysql/.dnmp-version ]; then
        state=unmarked
      else
        state="ready:$(marker_value /var/lib/mysql/.dnmp-version)"
      fi
      if [ -f /var/lib/mysql/.dnmp-initializing-version ]; then
        pending="$(marker_value /var/lib/mysql/.dnmp-initializing-version)"
      fi
    fi
    printf "config_digest=%s\n" "${checksum%% *}"
    printf "data_state=%s\n" "${state}"
    printf "pending_version=%s\n" "${pending}"
  ' sh "${inspect_data}")"; then
    echo "Unable to inspect ${service} configuration and data state." >&2
    echo "Merge the latest docker-compose.mysql-redis.sample.yml into docker-compose.mysql-redis.yml before retrying." >&2
    return 1
  fi

  mysql_config_digest="$(mysql_inspection_value config_digest)"
  mysql_data_state="$(mysql_inspection_value data_state)"
  mysql_pending_version="$(mysql_inspection_value pending_version)"
  case "${mysql_config_digest}" in
    '' | *[!0-9]*)
      echo "Invalid ${service} configuration digest." >&2
      return 1
      ;;
  esac
}

load_mysql_state() {
  inspect_data="${1:-1}"
  inspect_mysql_service mysql-primary "${inspect_data}" || return 1
  MYSQL_PRIMARY_CONFIG_DIGEST="${mysql_config_digest}"
  primary_state="${mysql_data_state}"
  primary_pending="${mysql_pending_version}"

  inspect_mysql_service mysql-replica "${inspect_data}" || return 1
  MYSQL_REPLICA_CONFIG_DIGEST="${mysql_config_digest}"
  replica_state="${mysql_data_state}"
  replica_pending="${mysql_pending_version}"
}

initial_mysql_inspect_data=1
if [ "${RESET_MYSQL_REPLICATION:-0}" = "1" ]; then
  initial_mysql_inspect_data=0
fi
if ! load_mysql_state "${initial_mysql_inspect_data}"; then
  exit 1
fi
export MYSQL_PRIMARY_CONFIG_DIGEST MYSQL_REPLICA_CONFIG_DIGEST

if ! resolved_config="$(dc config)"; then
  echo "Unable to resolve Docker Compose configuration." >&2
  exit 1
fi

service_environment_value() {
  service="$1"
  key="$2"
  printf '%s\n' "${resolved_config}" | awk -v service="${service}:" -v key="${key}:" '
    $1 == service { in_service = 1; next }
    in_service && /^  [^[:space:]][^:]*:[[:space:]]*$/ { exit }
    in_service && $1 == "environment:" { in_environment = 1; next }
    in_environment && /^    [^[:space:]][^:]*:/ { exit }
    in_environment && $1 == key {
      value = $0
      sub(/^[[:space:]]*[^:]+:[[:space:]]*/, "", value)
      sub(/^"/, "", value)
      sub(/"$/, "", value)
      print value
      exit
    }
  '
}

verify_service_digest() {
  service="$1"
  key="$2"
  expected="$3"
  actual="$(service_environment_value "${service}" "${key}")"
  if [ "${actual}" != "${expected}" ]; then
    echo "${service} does not use the current ${key}." >&2
    echo "Merge the latest docker-compose.mysql-redis.sample.yml into docker-compose.mysql-redis.yml before retrying." >&2
    return 1
  fi
}

cluster_nodes="redis-cluster-7001 redis-cluster-7002 redis-cluster-7003 redis-cluster-7004 redis-cluster-7005 redis-cluster-7006"
verify_service_digest mysql-primary MYSQL_CONFIG_DIGEST "${MYSQL_PRIMARY_CONFIG_DIGEST}"
verify_service_digest mysql-replica MYSQL_CONFIG_DIGEST "${MYSQL_REPLICA_CONFIG_DIGEST}"
for service in ${cluster_nodes}; do
  verify_service_digest "${service}" REDIS_CLUSTER_CONFIG_DIGEST "${REDIS_CLUSTER_CONFIG_DIGEST}"
done

service_exists() {
  dc config --services | grep -qx "$1"
}

service_container_name() {
  service="$1"
  printf '%s\n' "${resolved_config}" | awk -v target="${service}:" '
    $1 == target { in_service = 1; next }
    in_service && /^  [^[:space:]][^:]*:[[:space:]]*$/ { exit }
    in_service && $1 == "container_name:" { print $2; exit }
  '
}

ensure_service_containers_absent() {
  if ! existing_names="$(docker ps -a --format '{{.Names}}')"; then
    echo "Unable to inspect Docker containers." >&2
    return 1
  fi

  for service in "$@"; do
    if ! container_name="$(service_container_name "${service}")" || [ -z "${container_name}" ]; then
      echo "Unable to resolve container_name for ${service}." >&2
      return 1
    fi
    if printf '%s\n' "${existing_names}" | grep -Fxq "${container_name}"; then
      echo "Container ${container_name} still exists; data was not deleted." >&2
      echo "Remove it from its original Compose project before retrying RESET." >&2
      return 1
    fi
  done
}

with_cluster_nodes() {
  # shellcheck disable=SC2086
  "$@" ${cluster_nodes}
}

mysql_replication_version() {
  printf '%s\n' "${resolved_config}" | awk '
    $1 == "mysql-primary:" { in_mysql = 1; next }
    in_mysql && /^  [^[:space:]][^:]*:[[:space:]]*$/ { exit }
    in_mysql && $1 == "image:" {
      image = $2
      sub(/^mysql:/, "", image)
      print image
      exit
    }
  '
}

update_mysql_marker() {
  service="$1"
  operation="$2"
  version="$3"
  # shellcheck disable=SC2016
  dc run -T --rm --no-deps --entrypoint /bin/sh "${service}" -c '
    set -eu
    write_marker() {
      name="$1"
      value="$2"
      target="/var/lib/mysql/${name}"
      temporary="${target}.tmp.$$"
      trap "rm -f \"${temporary}\"" EXIT HUP INT TERM
      printf "%s\n" "${value}" > "${temporary}"
      chown mysql:mysql "${temporary}"
      mv -f "${temporary}" "${target}"
      trap - EXIT HUP INT TERM
    }

    case "$1" in
      pending)
        write_marker .dnmp-initializing-version "$2"
        ;;
      finalize)
        write_marker .dnmp-version "$2"
        rm -f /var/lib/mysql/.dnmp-initializing-version
        ;;
      *)
        echo "Unknown MySQL marker operation: $1" >&2
        exit 1
        ;;
    esac
  ' sh "${operation}" "${version}" >/dev/null
}

clear_mysql_data() {
  reset_status=0
  clear_service_dir mysql-primary /var/lib/mysql || reset_status=$?
  clear_service_dir mysql-replica /var/lib/mysql || reset_status=$?
  return "${reset_status}"
}

clear_service_dir() {
  service="$1"
  data_dir="$2"
  # shellcheck disable=SC2016
  dc run -T --rm --no-deps --entrypoint /bin/sh "${service}" -c '
    find "$1" -mindepth 1 -maxdepth 1 ! -name .gitignore -exec rm -rf {} \;
  ' sh "${data_dir}"
}

reset_mysql_replication_data() {
  reset_status=0
  echo "RESET_MYSQL_REPLICATION=1: removing local MySQL primary and replica data." >&2
  if ! dc rm -sf mysql-replication-init mysql-primary mysql-replica >/dev/null; then
    echo "Unable to stop and remove MySQL replication containers; data was not deleted." >&2
    return 1
  fi
  if ! running_containers="$(dc ps -q mysql-primary mysql-replica)"; then
    echo "Unable to verify MySQL replication container state; data was not deleted." >&2
    return 1
  fi
  if [ -n "${running_containers}" ]; then
    echo "MySQL replication containers are still running; data was not deleted." >&2
    return 1
  fi
  if ! ensure_service_containers_absent mysql-replication-init mysql-primary mysql-replica; then
    return 1
  fi
  clear_mysql_data || reset_status=$?
  return "${reset_status}"
}

reset_redis_cluster_data() {
  reset_status=0
  echo "RESET_REDIS_CLUSTER=1: removing local Redis Cluster data." >&2
  if ! with_cluster_nodes dc rm -sf redis-cluster-init >/dev/null; then
    echo "Unable to stop and remove Redis Cluster containers; data was not deleted." >&2
    return 1
  fi
  if ! running_containers="$(with_cluster_nodes dc ps -q)"; then
    echo "Unable to verify Redis Cluster container state; data was not deleted." >&2
    return 1
  fi
  if [ -n "${running_containers}" ]; then
    echo "Redis Cluster containers are still running; data was not deleted." >&2
    return 1
  fi
  if ! with_cluster_nodes ensure_service_containers_absent redis-cluster-init; then
    return 1
  fi
  for service in ${cluster_nodes}; do
    clear_service_dir "${service}" /data || reset_status=$?
  done
  return "${reset_status}"
}

ensure_mysql_replication_data_safe() {
  if ! version="$(mysql_replication_version)"; then
    echo "Unable to resolve mysql-primary image version from Docker Compose config." >&2
    return 1
  fi
  case "${version}" in
    '' | *[!A-Za-z0-9._-]*)
      echo "Invalid mysql-primary image version: ${version}." >&2
      return 1
      ;;
  esac

  if [ "${primary_state}" = "partial" ] || [ "${replica_state}" = "partial" ]; then
    echo "MySQL data exists without a complete system database; refusing to initialize or adopt it." >&2
    echo "Primary state: ${primary_state}; replica state: ${replica_state}." >&2
    return 1
  fi

  case "${primary_pending}" in
    '' | "${version}") ;;
    *)
      echo "MySQL primary initialization marker does not match image ${version}." >&2
      return 1
      ;;
  esac
  case "${replica_pending}" in
    '' | "${version}") ;;
    *)
      echo "MySQL replica initialization marker does not match image ${version}." >&2
      return 1
      ;;
  esac

  if [ "${primary_state}" = "empty" ] && [ "${replica_state}" = "empty" ]; then
    if [ -z "${primary_pending}" ] && ! update_mysql_marker mysql-primary pending "${version}"; then
      echo "Unable to write MySQL primary initialization marker." >&2
      return 1
    fi
    if [ -z "${replica_pending}" ] && ! update_mysql_marker mysql-replica pending "${version}"; then
      echo "Unable to write MySQL replica initialization marker." >&2
      return 1
    fi
    mysql_initializing=1
    mysql_markers_need_finalize=1
    return 0
  fi

  if [ "${primary_pending}" = "${version}" ] && [ "${replica_pending}" = "${version}" ]; then
    case "${primary_state}" in
      empty | unmarked | "ready:${version}") ;;
      *)
        echo "MySQL primary data state ${primary_state} conflicts with pending image ${version}." >&2
        return 1
        ;;
    esac
    case "${replica_state}" in
      empty | unmarked | "ready:${version}") ;;
      *)
        echo "MySQL replica data state ${replica_state} conflicts with pending image ${version}." >&2
        return 1
        ;;
    esac
    if { [ "${primary_state}" = "ready:${version}" ] && [ "${replica_state}" = "empty" ]; } ||
      { [ "${replica_state}" = "ready:${version}" ] && [ "${primary_state}" = "empty" ]; }; then
      echo "MySQL initialized data cannot be paired with an empty peer." >&2
      echo "Primary state: ${primary_state}; replica state: ${replica_state}." >&2
      return 1
    fi
    mysql_initializing=1
    mysql_markers_need_finalize=1
    return 0
  fi

  if [ "${primary_state}" = "empty" ] || [ "${replica_state}" = "empty" ]; then
    echo "MySQL primary and replica data must be prepared together." >&2
    echo "Primary state: ${primary_state}; replica state: ${replica_state}." >&2
    echo "Restore a consistent replica backup, or rebuild local data with RESET_MYSQL_REPLICATION=1." >&2
    return 1
  fi

  if [ "${primary_state}" = "ready:${version}" ] && [ "${replica_state}" = "ready:${version}" ]; then
    if [ -n "${primary_pending}" ] || [ -n "${replica_pending}" ]; then
      mysql_markers_need_finalize=1
    fi
    return 0
  fi

  if [ "${primary_state}" = "ready:${version}" ] && [ -z "${primary_pending}" ] &&
    [ "${replica_pending}" = "${version}" ]; then
    case "${replica_state}" in
      unmarked | "ready:${version}")
        mysql_initializing=1
        mysql_markers_need_finalize=1
        return 0
        ;;
    esac
  fi
  if [ "${replica_state}" = "ready:${version}" ] && [ -z "${replica_pending}" ] &&
    [ "${primary_pending}" = "${version}" ]; then
    case "${primary_state}" in
      unmarked | "ready:${version}")
        mysql_initializing=1
        mysql_markers_need_finalize=1
        return 0
        ;;
    esac
  fi

  if [ -n "${primary_pending}" ] || [ -n "${replica_pending}" ]; then
    echo "MySQL initialization markers do not match a recoverable primary/replica state." >&2
    echo "Primary state: ${primary_state}; replica state: ${replica_state}." >&2
    return 1
  fi

  if [ "${ADOPT_MYSQL_REPLICATION_VERSION:-0}" = "1" ]; then
    echo "ADOPT_MYSQL_REPLICATION_VERSION=1: validate existing data with MySQL ${version} before updating markers." >&2
    mysql_markers_need_finalize=1
    return 0
  fi

  echo "MySQL replication data version is not confirmed for image ${version}." >&2
  echo "Primary state: ${primary_state}; replica state: ${replica_state}." >&2
  echo "After backup and an official upgrade or verified existing startup, rerun with ADOPT_MYSQL_REPLICATION_VERSION=1." >&2
  echo "For disposable local data, use RESET_MYSQL_REPLICATION=1." >&2
  return 1
}

run_init_service() {
  service="$1"
  up_status=0

  dc rm -f "${service}" >/dev/null 2>&1 || true
  dc up "${service}" || up_status=$?

  if ! container_id="$(dc ps -aq "${service}")" || [ -z "${container_id}" ]; then
    echo "${service} did not create a container." >&2
    return 1
  fi

  if ! exit_code="$(docker inspect -f '{{.State.ExitCode}}' "${container_id}")"; then
    echo "Unable to inspect ${service} exit code." >&2
    return 1
  fi
  if [ "${exit_code}" != "0" ]; then
    echo "${service} exited with code ${exit_code}." >&2
    return "${exit_code}"
  fi

  return "${up_status}"
}

redis_service=""
redis_status=0
mysql_status=0
mysql_initializing=0
mysql_markers_need_finalize=0

if service_exists redis; then
  redis_service="redis"
fi

if [ "${RESET_REDIS_CLUSTER:-0}" = "1" ]; then
  reset_redis_cluster_data || redis_status=$?
else
  dc rm -f redis-cluster-init >/dev/null 2>&1 || true
fi

if [ "${RESET_MYSQL_REPLICATION:-0}" = "1" ]; then
  reset_mysql_replication_data || mysql_status=$?
  if [ "${mysql_status}" -eq 0 ]; then
    load_mysql_state || mysql_status=$?
  fi
else
  dc rm -f mysql-replication-init >/dev/null 2>&1 || true
fi

if [ "${mysql_status}" -eq 0 ]; then
  ensure_mysql_replication_data_safe || mysql_status=$?
fi

if [ "${redis_status}" -eq 0 ]; then
  if [ -n "${redis_service}" ]; then
    dc up -d "${redis_service}" || redis_status=$?
  fi
  with_cluster_nodes dc up -d || redis_status=$?
fi

if [ "${mysql_status}" -eq 0 ]; then
  dc up -d mysql-primary mysql-replica || mysql_status=$?
fi

if [ "${redis_status}" -eq 0 ]; then
  run_init_service redis-cluster-init || redis_status=$?
fi

if [ "${mysql_status}" -eq 0 ]; then
  run_init_service mysql-replication-init || mysql_status=$?
fi

if [ "${mysql_status}" -eq 0 ] && [ "${mysql_markers_need_finalize}" -eq 1 ]; then
  update_mysql_marker mysql-primary finalize "${version}" || mysql_status=$?
  if [ "${mysql_status}" -eq 0 ]; then
    update_mysql_marker mysql-replica finalize "${version}" || mysql_status=$?
  fi
fi

if [ "${redis_status}" -ne 0 ] || [ "${mysql_status}" -ne 0 ]; then
  if [ "${mysql_status}" -ne 0 ] && [ "${mysql_initializing}" -eq 1 ]; then
    dc stop mysql-replica mysql-primary >/dev/null 2>&1 || true
  fi
  echo "Setup failed: mysql=${mysql_status}, redis=${redis_status}." >&2
  exit 1
fi

echo "MySQL replication and Redis Cluster are healthy."
