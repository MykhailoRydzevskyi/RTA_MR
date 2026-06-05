#!/bin/bash
set -euo pipefail

KAFKA_BOOTSTRAP="${KAFKA_BOOTSTRAP:-broker:9092}"
POSTGRES_HOST="${POSTGRES_HOST:-postgres}"
POSTGRES_PORT="${POSTGRES_PORT:-5432}"
POSTGRES_DB="${POSTGRES_DB:-inventory}"
POSTGRES_USER="${POSTGRES_USER:-inventory}"
POSTGRES_PASSWORD="${POSTGRES_PASSWORD:-inventory}"
REDIS_HOST="${REDIS_HOST:-redis}"
REDIS_PORT="${REDIS_PORT:-6379}"

echo "=== Health check: inventory-streaming ==="

echo -n "[Kafka] broker API... "
if kafka-broker-api-versions.sh --bootstrap-server "${KAFKA_BOOTSTRAP}" >/dev/null 2>&1; then
  echo "OK"
else
  echo "FAIL"
  exit 1
fi

echo -n "[Kafka] required topics... "
TOPICS=$(kafka-topics.sh --bootstrap-server "${KAFKA_BOOTSTRAP}" --list)
for topic in products.catalog sales.events deliveries.events inventory.states inventory.alerts forecasts.demand orders.purchase; do
  if ! echo "${TOPICS}" | grep -qx "${topic}"; then
    echo "FAIL (missing: ${topic})"
    exit 1
  fi
done
echo "OK (7 topics)"

echo -n "[PostgreSQL] connection... "
if PGPASSWORD="${POSTGRES_PASSWORD}" psql -h "${POSTGRES_HOST}" -p "${POSTGRES_PORT}" -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -c "SELECT 1" >/dev/null 2>&1; then
  echo "OK"
else
  echo "FAIL"
  exit 1
fi

echo -n "[PostgreSQL] seed products... "
COUNT=$(PGPASSWORD="${POSTGRES_PASSWORD}" psql -h "${POSTGRES_HOST}" -p "${POSTGRES_PORT}" -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" -tAc "SELECT COUNT(*) FROM products")
if [ "${COUNT}" -ge 1 ]; then
  echo "OK (${COUNT} products)"
else
  echo "FAIL"
  exit 1
fi

echo -n "[Redis] ping... "
if redis-cli -h "${REDIS_HOST}" -p "${REDIS_PORT}" ping | grep -q PONG; then
  echo "OK"
else
  echo "FAIL"
  exit 1
fi

echo "=== All checks passed ==="
