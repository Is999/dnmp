#!/bin/sh
set -eu

cd "$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"

if [ ! -f docker-compose.yml ] || [ ! -f docker-compose.cluster.yml ]; then
  echo "Please copy docker-compose.sample.yml and docker-compose.cluster.sample.yml before restart." >&2
  echo "  cp docker-compose.sample.yml docker-compose.yml" >&2
  echo "  cp docker-compose.cluster.sample.yml docker-compose.cluster.yml" >&2
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
  compose -f docker-compose.yml -f docker-compose.cluster.yml "$@"
}

service_exists() {
  dc config --services | grep -qx "$1"
}

redis_service=""
if service_exists redis; then
  redis_service="redis"
fi

cluster_nodes="redis-cluster-7001 redis-cluster-7002 redis-cluster-7003 redis-cluster-7004 redis-cluster-7005 redis-cluster-7006"

dc stop mysql-replica-init mysql-master mysql-slave ${redis_service} redis-cluster-init ${cluster_nodes} >/dev/null 2>&1 || true
dc rm -f mysql-replica-init redis-cluster-init >/dev/null 2>&1 || true

if [ "${RESET_REDIS_CLUSTER:-0}" = "1" ]; then
  rm -rf data/redis-cluster/7001/* data/redis-cluster/7002/* data/redis-cluster/7003/* \
    data/redis-cluster/7004/* data/redis-cluster/7005/* data/redis-cluster/7006/*
fi

dc up -d mysql-master mysql-slave ${redis_service}
dc up mysql-replica-init
dc up -d ${cluster_nodes}
dc up redis-cluster-init
