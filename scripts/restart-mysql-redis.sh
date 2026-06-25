#!/bin/sh
set -eu

cd "$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"

if [ ! -f docker-compose.yml ] || [ ! -f docker-compose.mysql-redis.yml ]; then
  echo "Please copy docker-compose.sample.yml and docker-compose.mysql-redis.sample.yml before restart." >&2
  echo "  cp docker-compose.sample.yml docker-compose.yml" >&2
  echo "  cp docker-compose.mysql-redis.sample.yml docker-compose.mysql-redis.yml" >&2
  exit 1
fi

compose() {
  if docker compose version >/dev/null 2>&1; then
    docker compose "$@"
    return
  fi
  docker-compose "$@"
}

dc() {
  compose -f docker-compose.yml -f docker-compose.mysql-redis.yml "$@"
}

service_exists() {
  dc config --services | grep -qx "$1"
}

mysql_replication_version() {
  dc config | awk '
    $1 == "mysql-primary:" { in_mysql = 1; next }
    in_mysql && $1 == "image:" {
      image = $2
      sub(/^mysql:/, "", image)
      print image
      exit
    }
  '
}

mysql_replication_data_exists() {
  [ -f data/mysql-primary/auto.cnf ] || [ -f data/mysql-replica/auto.cnf ]
}

legacy_mysql_replication_data_exists() {
  for auto_cnf in data/mysql-*/auto.cnf; do
    [ -e "${auto_cnf}" ] || continue
    case "${auto_cnf}" in
      data/mysql-primary/* | data/mysql-replica/*)
        continue
        ;;
    esac
    return 0
  done

  return 1
}

ensure_mysql_replication_data_safe() {
  version="$(mysql_replication_version)"
  marker_file="data/mysql-replication.version"
  marked_version=""

  if [ -z "${version}" ]; then
    echo "Unable to resolve mysql-primary image version from docker compose config." >&2
    exit 1
  fi

  if legacy_mysql_replication_data_exists && ! mysql_replication_data_exists; then
    echo "Legacy MySQL replication data directories detected, but current compose expects data/mysql-primary and data/mysql-replica." >&2
    echo "Back up and move the old primary/replica data directories to the new names, or rebuild local test data after backup." >&2
    exit 1
  fi

  if ! mysql_replication_data_exists; then
    return
  fi

  if [ -f "${marker_file}" ]; then
    marked_version="$(cat "${marker_file}")"
  fi

  if [ "${marked_version}" = "${version}" ]; then
    return
  fi

  if [ -z "${marked_version}" ]; then
    echo "Existing MySQL replication data detected, but ${marker_file} is missing and requested version is ${version}." >&2
    echo "Refusing to guess the data version. Start once with MYSQL_REPLICATION_VERSION matching the existing data and write ${marker_file}, or rebuild local test data after backup." >&2
    exit 1
  fi

  if [ "${ALLOW_MYSQL_REPLICATION_DATA_UPGRADE:-0}" = "1" ]; then
    echo "ALLOW_MYSQL_REPLICATION_DATA_UPGRADE=1 is set; continue with MySQL replication data version ${marked_version} -> ${version}." >&2
    return
  fi

  echo "Existing MySQL replication data detected, but ${marker_file} is ${marked_version} and requested version is ${version}." >&2
  echo "Back up data and follow the official MySQL upgrade path, then rerun with ALLOW_MYSQL_REPLICATION_DATA_UPGRADE=1, or rebuild the local test data directories." >&2
  exit 1
}

write_mysql_replication_version_marker() {
  mkdir -p data
  mysql_replication_version > data/mysql-replication.version
}

run_init_service() {
  service="$1"
  container_id=""
  exit_code=""

  dc rm -f "${service}" >/dev/null 2>&1 || true
  dc up "${service}"

  container_id="$(dc ps -aq "${service}")"
  if [ -z "${container_id}" ]; then
    echo "${service} did not create a container." >&2
    exit 1
  fi

  exit_code="$(docker inspect -f '{{.State.ExitCode}}' "${container_id}")"
  if [ "${exit_code}" != "0" ]; then
    echo "${service} exited with code ${exit_code}." >&2
    exit "${exit_code}"
  fi
}

redis_service=""
if service_exists redis; then
  redis_service="redis"
fi

cluster_nodes="redis-cluster-7001 redis-cluster-7002 redis-cluster-7003 redis-cluster-7004 redis-cluster-7005 redis-cluster-7006"

ensure_mysql_replication_data_safe

dc stop mysql-replication-init mysql-primary mysql-replica ${redis_service} redis-cluster-init ${cluster_nodes} >/dev/null 2>&1 || true
dc rm -f mysql-replication-init redis-cluster-init >/dev/null 2>&1 || true

if [ "${RESET_REDIS_CLUSTER:-0}" = "1" ]; then
  rm -rf data/redis-cluster/7001/* data/redis-cluster/7002/* data/redis-cluster/7003/* \
    data/redis-cluster/7004/* data/redis-cluster/7005/* data/redis-cluster/7006/*
fi

dc up -d mysql-primary mysql-replica ${redis_service}
run_init_service mysql-replication-init
write_mysql_replication_version_marker
dc up -d ${cluster_nodes}
run_init_service redis-cluster-init
