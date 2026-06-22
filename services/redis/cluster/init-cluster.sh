#!/bin/sh
set -eu

nodes="${REDIS_CLUSTER_NODES:-redis-cluster-7001:7001 redis-cluster-7002:7002 redis-cluster-7003:7003 redis-cluster-7004:7004 redis-cluster-7005:7005 redis-cluster-7006:7006}"
replicas="${REDIS_CLUSTER_REPLICAS:-1}"
check_host="${REDIS_CLUSTER_CHECK_HOST:-redis-cluster-7001}"
check_port="${REDIS_CLUSTER_CHECK_PORT:-7001}"
wait_seconds="${REDIS_CLUSTER_WAIT_SECONDS:-120}"
expected_nodes=0

for node in ${nodes}; do
  expected_nodes=$((expected_nodes + 1))
done

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
  elapsed=0

  echo "Waiting for Redis at ${host}:${port} ..."
  until redis_cli -h "${host}" -p "${port}" ping >/dev/null 2>&1; do
    if [ "${elapsed}" -ge "${wait_seconds}" ]; then
      echo "Timed out waiting for Redis at ${host}:${port}." >&2
      return 1
    fi
    sleep 2
    elapsed=$((elapsed + 2))
  done
}

cluster_info_value() {
  key="$1"

  printf '%s\n' "${cluster_info}" | awk -F: -v key="${key}" '$1 == key {gsub(/\r/, "", $2); print $2; exit}'
}

wait_for_cluster_ready() {
  elapsed=0

  while :; do
    cluster_info="$(redis_cli -h "${check_host}" -p "${check_port}" cluster info 2>/dev/null || true)"
    state="$(cluster_info_value cluster_state)"
    slots_assigned="$(cluster_info_value cluster_slots_assigned)"
    slots_ok="$(cluster_info_value cluster_slots_ok)"
    known_nodes="$(cluster_info_value cluster_known_nodes)"

    if [ "${state}" = "ok" ] && [ "${slots_assigned:-0}" -eq 16384 ] && [ "${slots_ok:-0}" -eq 16384 ] && [ "${known_nodes:-0}" -eq "${expected_nodes}" ]; then
      printf '%s\n' "${cluster_info}"
      return 0
    fi

    if [ "${elapsed}" -ge "${wait_seconds}" ]; then
      printf '%s\n' "${cluster_info}"
      echo "Redis cluster did not become healthy in time." >&2
      return 1
    fi

    sleep 2
    elapsed=$((elapsed + 2))
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

known_nodes="$(cluster_info_value cluster_known_nodes)"
slots_assigned="$(cluster_info_value cluster_slots_assigned)"

if [ "${known_nodes:-0}" -gt 1 ] || [ "${slots_assigned:-0}" -gt 0 ]; then
  if wait_for_cluster_ready; then
    echo "Redis cluster recovered from existing topology."
    exit 0
  fi

  echo "Redis cluster state is not ok but old topology data exists." >&2
  echo "Run RESET_REDIS_CLUSTER=1 scripts/restart-mysql-redis.sh to rebuild local cluster data." >&2
  exit 1
fi

if [ -n "${REDIS_PASSWORD:-}" ]; then
  redis-cli -a "${REDIS_PASSWORD}" --cluster create ${nodes} --cluster-replicas "${replicas}" --cluster-yes
else
  redis-cli --cluster create ${nodes} --cluster-replicas "${replicas}" --cluster-yes
fi

wait_for_cluster_ready
