#!/usr/bin/env bash
set -euo pipefail

IMAGE_TAG="${IMAGE_TAG:-shellyplugplus-exporter:e2e}"
CONTAINER_NAME="${CONTAINER_NAME:-shelly-exporter-e2e}"
MOCK_CONTAINER_NAME="${MOCK_CONTAINER_NAME:-shelly-mock-e2e}"
NETWORK_NAME="${NETWORK_NAME:-shelly-e2e-net}"
MOCK_HOST="${MOCK_HOST:-127.0.0.1}"
MOCK_PORT="${MOCK_PORT:-18080}"
EXPORTER_PORT="${EXPORTER_PORT:-9924}"
SCRAPE_INTERVAL="${SCRAPE_INTERVAL:-1}"
METRICS_FILE="${METRICS_FILE:-/tmp/shelly_metrics.txt}"

wait_for_url() {
  local url="$1"
  local retries="$2"

  for _ in $(seq 1 "$retries"); do
    if curl -fsS "$url" >/dev/null 2>&1; then
      return 0
    fi
    sleep 1
  done

  return 1
}

cleanup() {
  if docker ps -a --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
    docker rm -f "${CONTAINER_NAME}" >/dev/null 2>&1 || true
  fi

  if docker ps -a --format '{{.Names}}' | grep -q "^${MOCK_CONTAINER_NAME}$"; then
    docker rm -f "${MOCK_CONTAINER_NAME}" >/dev/null 2>&1 || true
  fi

  if docker network ls --format '{{.Name}}' | grep -q "^${NETWORK_NAME}$"; then
    docker network rm "${NETWORK_NAME}" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

echo "[E2E] Building Docker image: ${IMAGE_TAG}"
docker build -t "${IMAGE_TAG}" .

echo "[E2E] Creating Docker network: ${NETWORK_NAME}"
docker network create "${NETWORK_NAME}" >/dev/null

echo "[E2E] Starting mock Shelly container"
docker run -d --rm \
  --name "${MOCK_CONTAINER_NAME}" \
  --network "${NETWORK_NAME}" \
  -p "${MOCK_PORT}:${MOCK_PORT}" \
  -v "$PWD/tests/e2e/mock_shelly_server.py:/mock_shelly_server.py:ro" \
  python:3.12-alpine \
  python /mock_shelly_server.py >/dev/null

if ! wait_for_url "http://${MOCK_HOST}:${MOCK_PORT}/rpc/Switch.GetStatus?id=0" 20; then
  echo "[E2E] Mock Shelly endpoint did not become ready in time"
  docker logs "${MOCK_CONTAINER_NAME}" || true
  exit 1
fi

echo "[E2E] Starting exporter container"
docker run -d --rm \
  --name "${CONTAINER_NAME}" \
  --network "${NETWORK_NAME}" \
  -p "${EXPORTER_PORT}:9924" \
  -e SHELLY_DEVICES="mock,${MOCK_CONTAINER_NAME}:${MOCK_PORT}" \
  -e SCRAPE_INTERVAL="${SCRAPE_INTERVAL}" \
  "${IMAGE_TAG}" >/dev/null

for _ in $(seq 1 30); do
  if curl -fsS "http://127.0.0.1:${EXPORTER_PORT}/metrics" > "${METRICS_FILE}" 2>/dev/null; then
    if grep -q 'shelly_up{device="mock"} 1.0\|shelly_up{device="mock"} 1' "${METRICS_FILE}"; then
      break
    fi
  fi
  sleep 1
done

if ! grep -q 'shelly_up{device="mock"} 1.0\|shelly_up{device="mock"} 1' "${METRICS_FILE}"; then
  echo "[E2E] Exporter did not expose expected mock metrics in time"
  docker logs "${CONTAINER_NAME}" || true
  exit 1
fi

echo "[E2E] Validating metrics"
METRICS_FILE="${METRICS_FILE}" python3 - <<'PY'
import os
import re

with open(os.environ['METRICS_FILE'], 'r', encoding='utf-8') as f:
    metrics = f.read()

def get_value(name):
    pattern = rf'^{name}\{{device="mock"\}}\s+([-+]?\d*\.?\d+(?:[eE][-+]?\d+)?)$'
    match = re.search(pattern, metrics, flags=re.MULTILINE)
    if not match:
        raise SystemExit(f'Missing metric line for {name}')
    return float(match.group(1))

expected = {
    'shelly_up': 1.0,
    'shelly_power_watts': 0.0,
    'shelly_voltage_volts': 227.2,
    'shelly_frequency_hertz': 49.9,
    'shelly_current_amperes': 0.0,
    'shelly_output_enabled': 1.0,
    'shelly_temperature_celsius': 22.7,
}

for metric_name, expected_value in expected.items():
    actual = get_value(metric_name)
    if abs(actual - expected_value) > 0.001:
        raise SystemExit(
            f'Metric {metric_name} mismatch: expected {expected_value}, got {actual}'
        )

print('E2E metrics validation passed.')
PY

echo "[E2E] Success"
