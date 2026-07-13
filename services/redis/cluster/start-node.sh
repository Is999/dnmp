#!/bin/sh
set -eu

redis_cli() {
  REDISCLI_AUTH="${REDIS_CLUSTER_PASSWORD}" timeout 2 redis-cli -t 1 "$@"
}

if [ -z "${REDIS_CLUSTER_PASSWORD:-}" ]; then
  echo "REDIS_CLUSTER_PASSWORD must be set." >&2
  exit 1
fi

if [ "${1:-}" = "health" ]; then
  redis_cli -h 127.0.0.1 -p "${REDIS_CLUSTER_PORT}" ping | grep -qx PONG
  cluster_info="$(redis_cli -h 127.0.0.1 -p "${REDIS_CLUSTER_PORT}" cluster info | tr -d '\r')"
  for expected in \
    cluster_state:ok \
    cluster_slots_assigned:16384 \
    cluster_slots_ok:16384 \
    cluster_slots_pfail:0 \
    cluster_slots_fail:0 \
    cluster_known_nodes:6 \
    cluster_size:3; do
    printf '%s\n' "${cluster_info}" | grep -qx "${expected}"
  done

  role_output="$(redis_cli -h 127.0.0.1 -p "${REDIS_CLUSTER_PORT}" --raw role)"
  case "$(printf '%s\n' "${role_output}" | sed -n '1p')" in
    master) exit 0 ;;
    slave | replica) [ "$(printf '%s\n' "${role_output}" | sed -n '4p')" = "connected" ] ;;
    *) exit 1 ;;
  esac
  exit
fi

if [ "$(id -u)" = "0" ]; then
  redis_uid="$(id -u redis)"
  if ! invalid_owner="$(find /data -mindepth 1 ! -user redis -print -quit)"; then
    echo "Unable to inspect Redis data ownership." >&2
    exit 1
  fi
  if [ "$(stat -c %u /data)" != "${redis_uid}" ] || [ -n "${invalid_owner}" ]; then
    chown -R redis:redis /data
  fi
  export SKIP_FIX_PERMS=1
fi

set -- redis-server /usr/local/etc/redis/redis-cluster-base.conf \
  --port "${REDIS_CLUSTER_PORT}" \
  --cluster-announce-port "${REDIS_CLUSTER_PORT}" \
  --cluster-announce-bus-port "${REDIS_CLUSTER_BUS_PORT}"

if [ -n "${REDIS_CLUSTER_ANNOUNCE_HOSTNAME:-}" ]; then
  set -- "$@" --cluster-announce-hostname "${REDIS_CLUSTER_ANNOUNCE_HOSTNAME}"
fi

if [ -n "${REDIS_CLUSTER_ANNOUNCE_IP:-}" ]; then
  set -- "$@" --cluster-announce-ip "${REDIS_CLUSTER_ANNOUNCE_IP}"
fi

set -- "$@" --requirepass "${REDIS_CLUSTER_PASSWORD}" --masterauth "${REDIS_CLUSTER_PASSWORD}"

exec /usr/local/bin/docker-entrypoint.sh "$@"
