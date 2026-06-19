#!/bin/sh
set -eu

nodes="${REDIS_CLUSTER_NODES:-redis-cluster-7001:7001 redis-cluster-7002:7002 redis-cluster-7003:7003 redis-cluster-7004:7004 redis-cluster-7005:7005 redis-cluster-7006:7006}"
replicas="${REDIS_CLUSTER_REPLICAS:-1}"
check_host="${REDIS_CLUSTER_CHECK_HOST:-redis-cluster-7001}"
check_port="${REDIS_CLUSTER_CHECK_PORT:-7001}"

redis_cli() {
  if [ -n "${REDIS_PASSWORD:-}" ]; then
    redis-cli -a "${REDIS_PASSWORD}" "$@"
  else
    redis-cli "$@"
  fi
}

wait_for_redis() {
  host="$1"
  port="$2"

  echo "Waiting for Redis at ${host}:${port} ..."
  until redis_cli -h "${host}" -p "${port}" ping >/dev/null 2>&1; do
    sleep 2
  done
}

for node in ${nodes}; do
  host="${node%:*}"
  port="${node#*:}"
  wait_for_redis "${host}" "${port}"
done

cluster_info="$(redis_cli -h "${check_host}" -p "${check_port}" cluster info 2>/dev/null || true)"
if printf '%s' "${cluster_info}" | grep -q "cluster_state:ok"; then
  echo "Redis cluster already initialized."
  exit 0
fi

if printf '%s' "${cluster_info}" | grep -Eq "cluster_known_nodes:[2-9]|cluster_slots_assigned:[1-9]"; then
  echo "Redis cluster state is not ok but old topology data exists." >&2
  echo "Run RESET_REDIS_CLUSTER=1 scripts/restart-mysql-redis.sh to rebuild local cluster data." >&2
  exit 1
fi

if [ -n "${REDIS_PASSWORD:-}" ]; then
  redis-cli -a "${REDIS_PASSWORD}" --cluster create ${nodes} --cluster-replicas "${replicas}" --cluster-yes
else
  redis-cli --cluster create ${nodes} --cluster-replicas "${replicas}" --cluster-yes
fi
