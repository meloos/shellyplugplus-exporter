# Shelly Plug Gen3 Prometheus Exporter

[![CI](https://github.com/meloos/shellyplugplus-exporter/actions/workflows/ci.yml/badge.svg)](https://github.com/meloos/shellyplugplus-exporter/actions/workflows/ci.yml)

A lightweight Prometheus exporter for Shelly Plug Gen3 devices.

Tested with:
- https://www.shelly.com/products/shelly-outdoor-plug-s-gen3?srsltid=AfmBOor0IBJTDakG3CpcXaUC6hKgCSCZ98-kG0Pd_PK3eRQLCZVDHjOt

## What it does

The exporter polls Shelly Gen3 devices using the RPC endpoint:
- `Switch.GetStatus?id=0`

It exposes Prometheus metrics on:
- `http://<exporter-host>:9924/metrics`

## Configuration

Use `docker-compose.yml.example` as an example template and replace placeholder values with your own.

Environment variables:
- `SHELLY_DEVICES` - newline-separated list of `name,ip_or_host`
- `SHELLY_USERNAME` - device username (default: `admin`)
- `SHELLY_HTTP_PASSWORD` - HTTP Digest password (optional if not configured on device)
- `SCRAPE_INTERVAL` - polling interval in seconds (default in app: `10`)

Example:

```yaml
services:
  shelly-exporter:
    build: .
    container_name: shelly-exporter
    restart: always
    network_mode: host
    environment:
      SHELLY_DEVICES: |
        living_room_plug,192.168.1.100
        garage_plug,192.168.1.101
      SHELLY_USERNAME: "admin"
      SHELLY_HTTP_PASSWORD: "your_http_digest_password"
      SCRAPE_INTERVAL: "10"
```

## Exposed metrics

All metrics include the `device` label.

- `shelly_power_watts` (Gauge): Instant active power in watts.
- `shelly_current_amperes` (Gauge): Instant current in amperes.
- `shelly_voltage_volts` (Gauge): Instant voltage in volts.
- `shelly_frequency_hertz` (Gauge): Measured AC frequency in hertz.
- `shelly_output_enabled` (Gauge): Relay output state (`1` = ON, `0` = OFF).
- `shelly_temperature_celsius` (Gauge): Device temperature in Celsius (when provided by device).
- `shelly_up` (Gauge): Device scrape health (`1` = reachable and parsed, `0` = scrape failed).
- `shelly_scrape_errors_total` (Counter): Number of failed scrapes.
- `shelly_energy_watthour_total` (Counter): Cumulative imported/consumed energy increments, in watt-hours.
- `shelly_energy_returned_watthour_total` (Counter): Cumulative returned/exported energy increments, in watt-hours.

## Run

```bash
cp docker-compose.yml.example docker-compose.yml
docker compose up -d --build
```

Then configure Prometheus to scrape:
- `http://<exporter-host>:9924/metrics`

## Testing

For local and CI end-to-end mock testing instructions, see:
- `tests/README.md`
