#!/bin/sh
set -eu

config_file="/tmp/redis-cluster.conf"
cp /usr/local/etc/redis/redis-cluster-base.conf "${config_file}"

{
  echo ""
  echo "port ${REDIS_CLUSTER_PORT}"
  echo "cluster-announce-port ${REDIS_CLUSTER_PORT}"
  echo "cluster-announce-bus-port ${REDIS_CLUSTER_BUS_PORT}"

  if [ -n "${REDIS_CLUSTER_ANNOUNCE_HOSTNAME:-}" ]; then
    echo "cluster-announce-hostname ${REDIS_CLUSTER_ANNOUNCE_HOSTNAME}"
  fi

  if [ -n "${REDIS_CLUSTER_ANNOUNCE_IP:-}" ]; then
    echo "cluster-announce-ip ${REDIS_CLUSTER_ANNOUNCE_IP}"
  fi

  if [ -n "${REDIS_PASSWORD:-}" ]; then
    echo "requirepass ${REDIS_PASSWORD}"
    echo "masterauth ${REDIS_PASSWORD}"
  fi
} >> "${config_file}"

exec redis-server "${config_file}"
