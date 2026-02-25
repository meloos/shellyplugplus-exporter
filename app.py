import os
import time
import requests
from requests.auth import HTTPDigestAuth
from prometheus_client import start_http_server, Gauge, Counter

SCRAPE_INTERVAL = int(os.getenv("SCRAPE_INTERVAL", "10"))
USERNAME = os.getenv("SHELLY_USERNAME", "admin")
PASSWORD = os.getenv("SHELLY_HTTP_PASSWORD")

# ===== DEVICE LIST =====
raw_devices = os.getenv("SHELLY_DEVICES", "")
devices = []

for line in raw_devices.strip().splitlines():
    if not line.strip():
        continue
    name, host = line.split(",")
    devices.append((name.strip(), host.strip()))

# ===== METRICS =====

power = Gauge("shelly_power_watts", "Current power draw", ["device"])
current = Gauge("shelly_current_amperes", "Current", ["device"])
voltage = Gauge("shelly_voltage_volts", "Voltage", ["device"])
frequency = Gauge("shelly_frequency_hertz", "Frequency", ["device"])
output_enabled = Gauge("shelly_output_enabled", "Relay state", ["device"])
temperature = Gauge("shelly_temperature_celsius", "Temperature", ["device"])
device_up = Gauge("shelly_up", "Device reachable", ["device"])

scrape_errors = Counter(
    "shelly_scrape_errors_total",
    "Total scrape errors",
    ["device"]
)

energy_total = Counter(
    "shelly_energy_wattminute_total",
    "Total consumed energy",
    ["device"]
)

energy_returned_total = Counter(
    "shelly_energy_returned_wattminute_total",
    "Total returned energy",
    ["device"]
)

last_energy = {}
last_returned = {}


def fetch(device_name, host):
    global last_energy, last_returned

    url = f"http://{host}/rpc/Switch.GetStatus?id=0"

    try:
        auth = HTTPDigestAuth(USERNAME, PASSWORD) if PASSWORD else None

        r = requests.get(
            url,
            auth=auth,
            timeout=5
        )
        r.raise_for_status()
        data = r.json()

        device_up.labels(device=device_name).set(1)

        power.labels(device=device_name).set(data.get("apower", 0))
        current.labels(device=device_name).set(data.get("current", 0))
        voltage.labels(device=device_name).set(data.get("voltage", 0))
        frequency.labels(device=device_name).set(data.get("freq", 0))
        output_enabled.labels(device=device_name).set(
            1 if data.get("output") else 0
        )

        if "temperature" in data:
            temperature.labels(device=device_name).set(
                data["temperature"].get("tC", 0)
            )

        # === ENERGY CONSUMED ===
        new_energy = data.get("aenergy", {}).get("total", 0)
        prev_energy = last_energy.get(device_name)

        if prev_energy is not None:
            if new_energy >= prev_energy:
                delta = new_energy - prev_energy
            else:
                # device reset
                delta = new_energy

            energy_total.labels(device=device_name).inc(delta)

        last_energy[device_name] = new_energy

        # === ENERGY RETURNED ===
        new_ret = data.get("ret_aenergy", {}).get("total", 0)
        prev_ret = last_returned.get(device_name)

        if prev_ret is not None:
            if new_ret >= prev_ret:
                delta_ret = new_ret - prev_ret
            else:
                delta_ret = new_ret

            energy_returned_total.labels(device=device_name).inc(delta_ret)

        last_returned[device_name] = new_ret

    except Exception as e:
        print(f"[ERROR] {device_name} ({host}): {e}")
        scrape_errors.labels(device=device_name).inc()
        device_up.labels(device=device_name).set(0)


if __name__ == "__main__":
    print("Starting Shelly exporter...")
    print(f"Devices configured: {devices}")

    start_http_server(9924)

    while True:
        for name, host in devices:
            fetch(name, host)
        time.sleep(SCRAPE_INTERVAL)