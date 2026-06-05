#!/bin/bash
set -euo pipefail

BOOTSTRAP="${KAFKA_BOOTSTRAP:-broker:9092}"
MAX_RETRIES=30
RETRY_DELAY=2

echo "Waiting for Kafka broker at ${BOOTSTRAP}..."
for i in $(seq 1 $MAX_RETRIES); do
  if kafka-broker-api-versions --bootstrap-server "${BOOTSTRAP}" >/dev/null 2>&1; then
    echo "Broker is ready."
    break
  fi
  if [ "$i" -eq "$MAX_RETRIES" ]; then
    echo "Broker not ready after ${MAX_RETRIES} attempts." >&2
    exit 1
  fi
  sleep "${RETRY_DELAY}"
done

create_topic() {
  local topic="$1"
  local partitions="$2"
  if kafka-topics --bootstrap-server "${BOOTSTRAP}" --list | grep -qx "${topic}"; then
    echo "Topic already exists: ${topic}"
  else
    kafka-topics --create \
      --topic "${topic}" \
      --bootstrap-server "${BOOTSTRAP}" \
      --partitions "${partitions}" \
      --replication-factor 1
    echo "Created topic: ${topic} (${partitions} partitions)"
  fi
}

create_topic "products.catalog" 3
create_topic "sales.events" 3
create_topic "deliveries.events" 3
create_topic "inventory.states" 3
create_topic "inventory.alerts" 1
create_topic "forecasts.demand" 3
create_topic "orders.purchase" 1

echo "All topics ready:"
kafka-topics --bootstrap-server "${BOOTSTRAP}" --list
