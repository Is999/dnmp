#!/bin/sh
set -eu

nodes="${REDIS_CLUSTER_NODES:-redis-cluster-7001:7001 redis-cluster-7002:7002 redis-cluster-7003:7003 redis-cluster-7004:7004 redis-cluster-7005:7005 redis-cluster-7006:7006}"
check_host="${REDIS_CLUSTER_CHECK_HOST:-redis-cluster-7001}"
check_port="${REDIS_CLUSTER_CHECK_PORT:-7001}"
wait_seconds="${REDIS_CLUSTER_WAIT_SECONDS:-120}"
expected_nodes=6
expected_masters=3
expected_replicas=3

redis_cli() {
  REDISCLI_AUTH="${REDIS_CLUSTER_PASSWORD:-}" timeout 2 redis-cli -t 1 "$@"
}

redis_cli_wait() {
  REDISCLI_AUTH="${REDIS_CLUSTER_PASSWORD:-}" timeout "${wait_seconds}" redis-cli -t 1 "$@"
}

cluster_info_value() {
  key="$1"
  printf '%s\n' "${cluster_info}" | awk -F: -v key="${key}" '$1 == key {gsub(/\r/, "", $2); print $2; exit}'
}

wait_for_redis() {
  host="$1"
  port="$2"
  started_at="$(date +%s)"

  echo "Waiting for Redis at ${host}:${port} ..."
  until redis_cli -h "${host}" -p "${port}" ping 2>/dev/null | grep -qx PONG; do
    elapsed=$(($(date +%s) - started_at))
    if [ "${elapsed}" -ge "${wait_seconds}" ]; then
      echo "Timed out waiting for Redis at ${host}:${port}." >&2
      return 1
    fi
    sleep 2
  done
}

cluster_nodes_summary() {
  printf '%s\n' "$1" | awk '
    NF >= 8 {
      flags = "," $3 ","
      if (flags ~ /,master,/) {
        masters++
        master_ids[$1] = 1
        for (field = 9; field <= NF; field++) {
          slot_range = $field
          if (slot_range ~ /^[0-9]+$/) {
            slot_start = slot_range + 0
            slot_end = slot_start
          } else if (slot_range ~ /^[0-9]+-[0-9]+$/) {
            split(slot_range, bounds, "-")
            slot_start = bounds[1] + 0
            slot_end = bounds[2] + 0
          } else {
            bad_slot_tokens++
            continue
          }
          if (slot_start < 0 || slot_end > 16383 || slot_start > slot_end) {
            bad_slot_tokens++
            continue
          }
          for (slot = slot_start; slot <= slot_end; slot++) {
            if (++slot_owners[slot] > 1) {
              duplicate_slots++
            }
          }
        }
      }
      if (flags ~ /,(slave|replica),/) {
        replicas++
        replicas_by_master[$4]++
      }
      if (flags ~ /,(fail|fail[?]|handshake|noaddr),/) {
        bad_flags++
      }
      if ($8 != "connected") {
        disconnected++
      }
    }
    END {
      for (master_id in master_ids) {
        if (replicas_by_master[master_id] != 1) {
          bad_layout++
        }
      }
      for (master_id in replicas_by_master) {
        if (!(master_id in master_ids)) {
          bad_layout++
        }
      }
      for (slot in slot_owners) {
        covered_slots++
      }
      print masters + 0, replicas + 0, bad_flags + 0, disconnected + 0, bad_layout + 0, \
        covered_slots + 0, duplicate_slots + 0, bad_slot_tokens + 0
    }
  '
}

cluster_nodes_layout() {
  printf '%s\n' "$1" | awk '
    NF >= 8 {
      flags = "," $3 ","
      if (flags ~ /,master,/) {
        for (field = 9; field <= NF; field++) {
          print $1 ":" $field
        }
      }
    }
  ' | sort
}

cluster_view_matches() {
  view_summary="$(cluster_nodes_summary "$1")"
  IFS=' ' read -r view_masters view_replicas view_bad_flags view_disconnected view_bad_layout view_covered_slots view_duplicate_slots view_bad_slot_tokens <<-EOSUMMARY
	${view_summary}
	EOSUMMARY

  [ "${view_masters}" -eq "${expected_masters}" ] && \
    [ "${view_replicas}" -eq "${expected_replicas}" ] && \
    [ "${view_bad_flags}" -eq 0 ] && \
    [ "${view_disconnected}" -eq 0 ] && \
    [ "${view_bad_layout}" -eq 0 ] && \
    [ "${view_covered_slots}" -eq 16384 ] && \
    [ "${view_duplicate_slots}" -eq 0 ] && \
    [ "${view_bad_slot_tokens}" -eq 0 ] && \
    [ "$(cluster_nodes_layout "$1")" = "${expected_layout}" ]
}

endpoints_summary() {
  node_masters=0
  node_replicas=0
  bad_replica_links=0
  bad_cluster_views=0

  for node in ${nodes}; do
    host="${node%:*}"
    port="${node#*:}"
    if [ "${host}" = "${check_host}" ] && [ "${port}" = "${check_port}" ]; then
      node_cluster_nodes="${cluster_nodes}"
    else
      node_cluster_nodes="$(redis_cli -h "${host}" -p "${port}" cluster nodes 2>/dev/null || true)"
    fi
    if ! cluster_view_matches "${node_cluster_nodes}"; then
      bad_cluster_views=$((bad_cluster_views + 1))
    fi

    role_output="$(redis_cli -h "${host}" -p "${port}" --raw role 2>/dev/null || true)"
    role="$(printf '%s\n' "${role_output}" | sed -n '1p')"

    case "${role}" in
      master)
        node_masters=$((node_masters + 1))
        ;;
      slave | replica)
        node_replicas=$((node_replicas + 1))
        if [ "$(printf '%s\n' "${role_output}" | sed -n '4p')" != "connected" ]; then
          bad_replica_links=$((bad_replica_links + 1))
        fi
        ;;
      *)
        bad_replica_links=$((bad_replica_links + 1))
        ;;
    esac
  done

  printf '%s %s %s %s\n' "${node_masters}" "${node_replicas}" "${bad_replica_links}" "${bad_cluster_views}"
}

cluster_ready() {
  cluster_info="$(redis_cli -h "${check_host}" -p "${check_port}" cluster info 2>/dev/null || true)"
  cluster_nodes="$(redis_cli -h "${check_host}" -p "${check_port}" cluster nodes 2>/dev/null || true)"

  state="$(cluster_info_value cluster_state)"
  slots_assigned="$(cluster_info_value cluster_slots_assigned)"
  slots_ok="$(cluster_info_value cluster_slots_ok)"
  slots_pfail="$(cluster_info_value cluster_slots_pfail)"
  slots_fail="$(cluster_info_value cluster_slots_fail)"
  known_nodes="$(cluster_info_value cluster_known_nodes)"
  cluster_size="$(cluster_info_value cluster_size)"

  node_summary="$(cluster_nodes_summary "${cluster_nodes}")"
  IFS=' ' read -r masters replicas bad_flags disconnected bad_layout covered_slots duplicate_slots bad_slot_tokens <<-EOSUMMARY
	${node_summary}
	EOSUMMARY
  expected_layout="$(cluster_nodes_layout "${cluster_nodes}")"
  endpoint_summary="$(endpoints_summary)"
  IFS=' ' read -r node_masters node_replicas bad_replica_links bad_cluster_views <<-EOSUMMARY
	${endpoint_summary}
	EOSUMMARY

  [ "${state}" = "ok" ] && \
    [ "${slots_assigned:-0}" -eq 16384 ] && \
    [ "${slots_ok:-0}" -eq 16384 ] && \
    [ "${slots_pfail:-0}" -eq 0 ] && \
    [ "${slots_fail:-0}" -eq 0 ] && \
    [ "${known_nodes:-0}" -eq "${expected_nodes}" ] && \
    [ "${cluster_size:-0}" -eq "${expected_masters}" ] && \
    [ "${masters}" -eq "${expected_masters}" ] && \
    [ "${replicas}" -eq "${expected_replicas}" ] && \
    [ "${bad_flags}" -eq 0 ] && \
    [ "${disconnected}" -eq 0 ] && \
    [ "${bad_layout}" -eq 0 ] && \
    [ "${covered_slots}" -eq 16384 ] && \
    [ "${duplicate_slots}" -eq 0 ] && \
    [ "${bad_slot_tokens}" -eq 0 ] && \
    [ "${node_masters}" -eq "${expected_masters}" ] && \
    [ "${node_replicas}" -eq "${expected_replicas}" ] && \
    [ "${bad_replica_links}" -eq 0 ] && \
    [ "${bad_cluster_views}" -eq 0 ]
}

wait_for_cluster_ready() {
  started_at="$(date +%s)"

  while ! cluster_ready; do
    elapsed=$(($(date +%s) - started_at))
    if [ "${elapsed}" -ge "${wait_seconds}" ]; then
      printf '%s\n' "${cluster_info}"
      printf '%s\n' "${cluster_nodes}"
      echo "Redis Cluster did not become healthy in time." >&2
      echo "Run RESET_REDIS_CLUSTER=1 scripts/restart-mysql-redis.sh to rebuild local cluster data." >&2
      return 1
    fi
    sleep 2
  done

  printf '%s\n' "${cluster_info}"
}

cluster_has_membership() {
  for node in ${nodes}; do
    host="${node%:*}"
    port="${node#*:}"
    cluster_info="$(redis_cli -h "${host}" -p "${port}" cluster info 2>/dev/null || true)"
    known_nodes="$(cluster_info_value cluster_known_nodes)"
    slots_assigned="$(cluster_info_value cluster_slots_assigned)"
    if [ "${known_nodes:-0}" -gt 1 ] || [ "${slots_assigned:-0}" -gt 0 ]; then
      return 0
    fi
  done
  return 1
}

cluster_check() {
  redis_cli_wait --cluster check "${check_host}:${check_port}" --cluster-search-multiple-owners
}

if [ "${1:-}" = "health" ]; then
  cluster_ready
  exit
fi

case "${wait_seconds}" in
  '' | *[!0-9]*)
    echo "REDIS_CLUSTER_WAIT_SECONDS must be a positive integer." >&2
    exit 1
    ;;
esac

if [ "${wait_seconds}" -le 0 ]; then
  echo "REDIS_CLUSTER_WAIT_SECONDS must be a positive integer." >&2
  exit 1
fi

node_count=0
for node in ${nodes}; do
  host="${node%:*}"
  port="${node#*:}"
  wait_for_redis "${host}" "${port}"
  node_count=$((node_count + 1))
done

if [ "${node_count}" -ne "${expected_nodes}" ]; then
  echo "Redis Cluster requires exactly ${expected_nodes} nodes, got ${node_count}." >&2
  exit 1
fi

if cluster_has_membership; then
  wait_for_cluster_ready
  cluster_check
  echo "Redis Cluster topology is healthy."
  exit 0
fi

set --
for node in ${nodes}; do
  set -- "$@" "${node}"
done

redis_cli_wait --cluster create "$@" --cluster-replicas 1 --cluster-yes
wait_for_cluster_ready
cluster_check
