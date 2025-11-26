# Windows Temperature Monitoring for Prometheus

Export CPU, GPU, and motherboard temperatures to Prometheus using `windows_exporter` and the LibreHardwareMonitor library.

Assumes that you already have `prometheus` and `grafana` set up.

## Prerequisites

- Windows 10/11
- [windows_exporter](https://github.com/prometheus-community/windows_exporter/releases) installed
- [NSSM](https://nssm.cc/download) (Non-Sucking Service Manager)
- PowerShell 5.1 or later
- Administrator privileges

## Installation

### 1. Download and Extract LibreHardwareMonitor

1. Go to [LibreHardwareMonitor Releases](https://github.com/LibreHardwareMonitor/LibreHardwareMonitor/releases)
2. Download the latest release ZIP file
3. Extract to `C:\Program Files\LibreHardwareMonitor\`
4. You need these files from the extracted folder:
   - `LibreHardwareMonitorLib.dll`
   - `HidSharp.dll`

### 2. Install the DLLs to System32

Due to .NET Framework security restrictions, the DLLs must be placed in a trusted location.

**Run PowerShell as Administrator** and execute:

```powershell
# Copy the DLLs to System32
Copy-Item "C:\Program Files\LibreHardwareMonitor\LibreHardwareMonitorLib.dll" "C:\Windows\System32\"
Copy-Item "C:\Program Files\LibreHardwareMonitor\HidSharp.dll" "C:\Windows\System32\"
```

### 3. Add Windows Defender Exclusion

The WinRing0 driver (required for CPU temperature reading) is flagged by Windows Defender as a vulnerable driver. You must add an exclusion:

**Run PowerShell as Administrator:**

```powershell
Add-MpPreference -ExclusionPath "C:\Program Files\LibreHardwareMonitor"
```

**Or manually:**
1. Open Windows Security
2. Go to Virus & threat protection
3. Click "Manage settings" under Virus & threat protection settings
4. Scroll to Exclusions and click "Add or remove exclusions"
5. Click "Add an exclusion" → "Folder"
6. Select `C:\Program Files\LibreHardwareMonitor`

**Important:** This exclusion is required because LibreHardwareMonitor uses the WinRing0 kernel driver to read CPU temperatures. Without this exclusion, Windows Defender will block the driver and CPU temperatures will not work.

### 4. Run LibreHardwareMonitor GUI Once

The GUI application installs the WinRing0 driver needed for CPU temperature monitoring:

1. Run `C:\Program Files\LibreHardwareMonitor\LibreHardwareMonitor.exe` as Administrator
2. Wait for it to fully load (you should see temperature readings)
3. Close the application

This step installs the WinRing0 driver that the library needs to read CPU temperatures.

### 5. Configure windows_exporter

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

### 6. Install the Temperature Collector Script

1. Save `collect_temps.ps1` to `C:\prometheus_textfiles\`

2. **Test the script manually first:**
   ```powershell
   cd C:\prometheus_textfiles
   powershell -ExecutionPolicy Bypass -File .\collect_temps.ps1
   ```
   You should see temperature data being collected every 10 seconds. Check that both CPU and GPU temps are present.
   Press Ctrl+C after verifying it works.

3. **Verify the output file:**
   ```powershell
   Get-Content C:\prometheus_textfiles\hardware_temps.prom
   ```
   You should see lines like:
   ```
   hardware_temperature_celsius{hardware="Intel_Core_i7_6700K",sensor="CPU_Package"} 45.0
   hardware_temperature_celsius{hardware="NVIDIA_GeForce_RTX_3070_Ti",sensor="GPU_Core"} 34.0
   ```

4. **Install as a Windows service using NSSM:**
   ```cmd
   cd "C:\Program Files\nssm\win64"
   nssm install PrometheusTemperatureCollector "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" "-ExecutionPolicy Bypass -NoProfile -File C:\prometheus_textfiles\collect_temps.ps1"
   nssm set PrometheusTemperatureCollector AppDirectory C:\prometheus_textfiles
   nssm set PrometheusTemperatureCollector AppStdout C:\prometheus_textfiles\service.log
   nssm set PrometheusTemperatureCollector AppStderr C:\prometheus_textfiles\service_error.log
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

# Average CPU temperature
avg(hardware_temperature_celsius{hardware=~".*Intel.*",sensor=~"CPU_Core.*"})
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

## How It Works

1. **DLLs in System32**: The LibreHardwareMonitor library DLLs must be in a trusted location (System32) to bypass .NET Framework security restrictions
2. **WinRing0 Driver**: The script automatically creates and starts a Windows service for the WinRing0 kernel driver, which provides low-level access to CPU temperature sensors
3. **Continuous Monitoring**: The script runs in a loop, collecting temperatures every 10 seconds and writing them to a Prometheus-compatible text file
4. **windows_exporter**: Reads the text file and exposes the metrics at its HTTP endpoint for Prometheus to scrape

## Troubleshooting

### No temperature data

1. Check if the service is running:
   ```cmd
   nssm status PrometheusTemperatureCollector
   ```

2. Check the logs:
   ```powershell
   Get-Content C:\prometheus_textfiles\service.log -Tail 20
   Get-Content C:\prometheus_textfiles\service_error.log -Tail 20
   ```

3. Verify the output file is being updated:
   ```powershell
   Get-Content C:\prometheus_textfiles\hardware_temps.prom
   ```

### CPU temperatures showing "No Value" or missing

1. Verify Windows Defender exclusion is in place:
   ```powershell
   Get-MpPreference | Select-Object -ExpandProperty ExclusionPath
   ```
   Should include `C:\Program Files\LibreHardwareMonitor`

2. Check if WinRing0 driver service is running:
   ```powershell
   Get-Service -Name "WinRing0_1_2_0"
   ```

3. If service doesn't exist or won't start:
   - Make sure you ran LibreHardwareMonitor.exe as Administrator at least once
   - Restart the PrometheusTemperatureCollector service:
     ```cmd
     nssm restart PrometheusTemperatureCollector
     ```

### GPU temperatures work but CPU temperatures don't

This means the WinRing0 driver isn't loaded:
1. Ensure the Windows Defender exclusion for `C:\Program Files\LibreHardwareMonitor` is in place
2. Run LibreHardwareMonitor.exe as Administrator to install the driver
3. Restart the PrometheusTemperatureCollector service

### Service won't start

1. Check Event Viewer → Windows Logs → Application for errors

2. Test the script manually:
   ```powershell
   cd C:\prometheus_textfiles
   powershell -ExecutionPolicy Bypass -File .\collect_temps.ps1
   ```

3. Ensure DLLs are in System32:
   ```powershell
   Test-Path C:\Windows\System32\LibreHardwareMonitorLib.dll
   Test-Path C:\Windows\System32\HidSharp.dll
   ```

### Windows Defender keeps blocking the driver

Make sure you added the exclusion for the **folder** `C:\Program Files\LibreHardwareMonitor`, not just the driver file. The exclusion must be added before the driver is installed.

If you added the exclusion after Windows Defender already quarantined the driver:
1. Open Windows Security → Virus & threat protection → Protection history
2. Find the WinRing0 detection
3. Click "Actions" → "Restore"
4. Restart the PrometheusTemperatureCollector service

## Service Management

**View service status:**
```cmd
nssm status PrometheusTemperatureCollector
```

**Restart service:**
```cmd
nssm restart PrometheusTemperatureCollector
```

**Stop service:**
```cmd
nssm stop PrometheusTemperatureCollector
```

**View logs:**
```powershell
Get-Content C:\prometheus_textfiles\service.log -Tail 50
```

**Uninstall:**
```cmd
nssm stop PrometheusTemperatureCollector
nssm remove PrometheusTemperatureCollector confirm
```

## Security Considerations

### WinRing0 Driver Vulnerability

The WinRing0 driver (CVE-2020-14979) is flagged by Microsoft as vulnerable because it provides kernel-level hardware access. This vulnerability could theoretically be exploited by malware already on your system through a "Bring Your Own Vulnerable Driver" (BYOVD) attack.

**Risk Assessment:**
- The driver itself is not malicious
- The risk exists only if malware is already present on your system
- The driver is widely used by hardware monitoring tools (HWiNFO, MSI Afterburner, etc.)
- Adding a Windows Defender exclusion is necessary for functionality

**Mitigation:**
- Only use this on trusted systems
- Keep Windows and antivirus software up to date
- Monitor for unusual system behavior
- Consider using only GPU temperature monitoring if CPU temps aren't critical (no driver needed for GPU)

## Alternative: GPU-Only Monitoring (No Driver Required)

If you don't want to use the WinRing0 driver, you can modify the script to only monitor GPU temperatures, which don't require the driver. GPU temperature monitoring uses vendor-specific APIs that don't need kernel-level access.

## License

This script uses LibreHardwareMonitor, which is licensed under MPL 2.0.