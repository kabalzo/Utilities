# Windows Temperature Monitoring for Prometheus

Export CPU, GPU, and motherboard temperatures to Prometheus using `windows_exporter` and the LibreHardwareMonitor library.

Assumes that you already have `prometheus` and `grafana` set up.

## Prerequisites

- Windows 10/11
- [windows_exporter](https://github.com/prometheus-community/windows_exporter/releases) installed
- [NSSM](https://nssm.cc/download) (Non-Sucking Service Manager)
- PowerShell 5.1 or later

## Installation

### 1. Download LibreHardwareMonitor Library

**Option A: Download from GitHub Releases**
1. Go to [LibreHardwareMonitor Releases](https://github.com/LibreHardwareMonitor/LibreHardwareMonitor/releases)
2. Download the latest release ZIP file
3. Extract `LibreHardwareMonitorLib.dll` from the ZIP

**Option B: Use NuGet Package**
1. Install NuGet CLI or use Visual Studio
2. Run: `nuget install LibreHardwareMonitorLib`
3. Find `LibreHardwareMonitorLib.dll` in the downloaded package

**Place the DLL:**
- Copy `LibreHardwareMonitorLib.dll` to `C:\prometheus_textfiles\`

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

3. Restart windows_exporter service:
   ```cmd
   net stop windows_exporter
   net start windows_exporter
   ```

### 3. Install the Temperature Collector Script

1. Save `collect_temps.ps1` to `C:\prometheus_textfiles\`

2. Test the script manually first:
   ```powershell
   cd C:\prometheus_textfiles
   powershell -ExecutionPolicy Bypass -File .\collect_temps.ps1
   ```
   Press Ctrl+C after verifying it works

3. Install as a Windows service using NSSM:
   ```cmd
   cd "C:\Program Files\nssm\win64"
   nssm install PrometheusTemperatureCollector "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" "-ExecutionPolicy Bypass -NoProfile -File C:\prometheus_textfiles\collect_temps.ps1"
   nssm set PrometheusTemperatureCollector AppDirectory C:\prometheus_textfiles
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
hardware_temperature_celsius{sensor=~"CPU_Core.*"}

# Max GPU temperature
max(hardware_temperature_celsius{sensor=~"GPU.*"})

# Average motherboard temperature
avg(hardware_temperature_celsius{hardware=~".*Motherboard.*"})
```

### Grafana Dashboard Example

```promql
# Panel 1: CPU Temperature
hardware_temperature_celsius{sensor=~"CPU.*"}

# Panel 2: GPU Temperature
hardware_temperature_celsius{sensor=~"GPU.*"}

# Panel 3: Max Temperature Alert
max(hardware_temperature_celsius) > 80
```

## Advantages Over GUI Application

- **No GUI required**: Runs as a pure service without desktop dependencies
- **Lower resource usage**: Library-only approach uses less memory
- **More reliable**: No need to keep GUI application running
- **Easier automation**: Direct API access for better control
- **No WMI dependency**: Reads sensors directly from hardware

## Troubleshooting

**No temperature data:**
- Verify `C:\prometheus_textfiles\hardware_temps.prom` is being created and updated
- Check service status: `nssm status PrometheusTemperatureCollector`
- View service logs: `nssm rotate PrometheusTemperatureCollector`

**"LibreHardwareMonitorLib.dll not found" error:**
- Ensure the DLL is in `C:\prometheus_textfiles\`
- Verify the script's working directory is set correctly in NSSM

**Service won't start:**
- Check Event Viewer → Windows Logs → Application for errors
- Run script manually to test: 
  ```powershell
  cd C:\prometheus_textfiles
  powershell -ExecutionPolicy Bypass -File .\collect_temps.ps1
  ```

**No temperature readings for specific hardware:**
- Some hardware may require administrator privileges
- Install service with elevated privileges:
  ```cmd
  nssm set PrometheusTemperatureCollector ObjectName LocalSystem
  nssm restart PrometheusTemperatureCollector
  ```

**Access denied / Permission errors:**
- The LibreHardwareMonitor library requires administrator privileges to access hardware sensors
- Ensure the service is running as LocalSystem or an administrator account

## Uninstall

```cmd
nssm stop PrometheusTemperatureCollector
nssm remove PrometheusTemperatureCollector confirm
```

## License

This script uses LibreHardwareMonitor, which is licensed under MPL 2.0.