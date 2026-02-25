# Testing

[![CI](https://github.com/meloos/shellyplugplus-exporter/actions/workflows/ci.yml/badge.svg)](https://github.com/meloos/shellyplugplus-exporter/actions/workflows/ci.yml)

This project includes a reusable end-to-end test that mocks a Shelly device and validates exporter metrics from a real Docker container.

## E2E mock test

Script:
- `tests/e2e/run_e2e_mock.sh`

Mock server payload source:
- `tests/e2e/mock_shelly_server.py`

The script does the following:
1. Creates a dedicated Docker network and starts a mock Shelly RPC container (`/rpc/Switch.GetStatus?id=0`).
2. Builds the exporter Docker image.
3. Runs the exporter container against the mock endpoint on the same Docker network.
4. Scrapes `/metrics` from the exporter.
5. Asserts expected metric values.

## Run locally

From repository root:

```bash
bash tests/e2e/run_e2e_mock.sh
```

Optional environment variables:
- `IMAGE_TAG` (default: `shellyplugplus-exporter:e2e`)
- `CONTAINER_NAME` (default: `shelly-exporter-e2e`)
- `MOCK_HOST` (default: `127.0.0.1`)
- `MOCK_PORT` (default: `18080`)
- `EXPORTER_PORT` (default: `9924`)
- `SCRAPE_INTERVAL` (default: `1`)

Example:

```bash
IMAGE_TAG=shellyplugplus-exporter:dev EXPORTER_PORT=19924 bash tests/e2e/run_e2e_mock.sh
```

## Run in CI

GitHub Actions job `e2e-mock-shelly` runs exactly the same script:
- `.github/workflows/ci.yml` -> `bash tests/e2e/run_e2e_mock.sh`

So local and CI behavior stay aligned.
