# Windows Temperature Monitoring for Prometheus

Export CPU, GPU, and motherboard temperatures to Prometheus using `windows_exporter` and LibreHardwareMonitor.
Assumes that you already have `prometheus` and `graphana` set up.

## Prerequisites

- Windows 10/11
- [windows_exporter](https://github.com/prometheus-community/windows_exporter/releases) installed
- [LibreHardwareMonitor](https://github.com/LibreHardwareMonitor/LibreHardwareMonitor/releases) installed
- [NSSM](https://nssm.cc/download) (Non-Sucking Service Manager)

## Installation

### 1. Install LibreHardwareMonitor

1. Download and extract LibreHardwareMonitor to `C:\Program Files\LibreHardwareMonitor\`
2. Add Windows Defender exclusion for the folder (it flags WinRing0 driver as potentially vulnerable)
3. Set it to start automatically:
   - Press `Win + R`, type `shell:startup`, press Enter
   - Create a shortcut to `LibreHardwareMonitor.exe` in the Startup folder
   - Or use Task Scheduler for elevated privileges

### 2. Configure windows_exporter

1. Create textfile directory:
   ```cmd
   mkdir C:\prometheus_textfiles
   ```

2. Update your `config.yaml` to include the textfile collector:
   ```yaml
   collectors:
     enabled: cpu,os,textfile  # add other collectors as needed
   collector:
     textfile:
       directories:
         - C:\prometheus_textfiles
   ```

3. Restart windows_exporter service

### 3. Install the Temperature Collector Script

1. Save `collect_temps.ps1` to `C:\prometheus_textfiles\`

2. Install as a Windows service using NSSM:
   ```cmd
   cd "C:\Program Files\nssm\win64"
   nssm install PrometheusTemperatureCollector "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" "-ExecutionPolicy Bypass -NoProfile -File C:\prometheus_textfiles\collect_temps.ps1"
   nssm start PrometheusTemperatureCollector
   ```

## Usage

Temperature metrics are exported at your windows_exporter endpoint (default: `http://localhost:9182/metrics`)

### Example Metrics

```promql
# CPU Package temperature
hardware_temperature_celsius{sensor="CPU_Package"}

# GPU Core temperature  
hardware_temperature_celsius{sensor="GPU_Core"}

# All CPU core temperatures
hardware_temperature_celsius{sensor=~"CPU_Core__.*"}

# Max GPU temperature
max(hardware_temperature_celsius{sensor=~"GPU.*"})
```

## Troubleshooting

**No temperature data:**
- Ensure LibreHardwareMonitor is running (check system tray)
- Verify `C:\prometheus_textfiles\hardware_temps.prom` is being updated
- Check service status: `nssm status PrometheusTemperatureCollector`

**Service won't start:**
- Check Event Viewer for errors
- Run script manually to test: `powershell -File C:\prometheus_textfiles\collect_temps.ps1`

**LibreHardwareMonitor blocked by Windows Defender:**
- Add folder exclusion in Windows Security → Virus & threat protection → Exclusions