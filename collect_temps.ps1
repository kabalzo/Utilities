# Run continuously as a service - Uses LibreHardwareMonitor library directly
# Requires LibreHardwareMonitorLib.dll in the same directory

# Load the LibreHardwareMonitor library
$dllPath = Join-Path $PSScriptRoot "LibreHardwareMonitorLib.dll"
if (-not (Test-Path $dllPath)) {
    Write-Error "LibreHardwareMonitorLib.dll not found at $dllPath"
    Write-Error "Please download it from NuGet or GitHub releases"
    exit 1
}

Add-Type -Path $dllPath

# Create a Computer instance
$computer = New-Object LibreHardwareMonitor.Hardware.Computer

# Enable all hardware monitoring
$computer.IsCpuEnabled = $true
$computer.IsGpuEnabled = $true
$computer.IsMemoryEnabled = $true
$computer.IsMotherboardEnabled = $true
$computer.IsControllerEnabled = $true
$computer.IsNetworkEnabled = $true
$computer.IsStorageEnabled = $true

# Open the computer to start monitoring
$computer.Open()

Write-Host "Temperature monitoring started. Press Ctrl+C to stop."

while ($true) {
    try {
        # Output file
        $outputFile = "C:\prometheus_textfiles\hardware_temps.prom"
        
        # Clear the file
        "" | Out-File -FilePath $outputFile -Encoding ASCII
        
        # Update all hardware sensors
        foreach ($hardware in $computer.Hardware) {
            $hardware.Update()
            
            # Process sensors for this hardware
            foreach ($sensor in $hardware.Sensors) {
                # Only process temperature sensors
                if ($sensor.SensorType -eq [LibreHardwareMonitor.Hardware.SensorType]::Temperature) {
                    # Clean up names for Prometheus labels
                    $hardwareName = $hardware.Name -replace '[^a-zA-Z0-9_]', '_'
                    $sensorName = $sensor.Name -replace '[^a-zA-Z0-9_]', '_'
                    $value = $sensor.Value
                    
                    if ($value) {
                        $metric = "hardware_temperature_celsius{hardware=`"$hardwareName`",sensor=`"$sensorName`"} $value"
                        $metric | Out-File -FilePath $outputFile -Append -Encoding ASCII
                    }
                }
            }
            
            # Process sub-hardware (e.g., individual CPU cores, GPU sensors)
            foreach ($subhardware in $hardware.SubHardware) {
                $subhardware.Update()
                
                foreach ($sensor in $subhardware.Sensors) {
                    if ($sensor.SensorType -eq [LibreHardwareMonitor.Hardware.SensorType]::Temperature) {
                        $hardwareName = $subhardware.Name -replace '[^a-zA-Z0-9_]', '_'
                        $sensorName = $sensor.Name -replace '[^a-zA-Z0-9_]', '_'
                        $value = $sensor.Value
                        
                        if ($value) {
                            $metric = "hardware_temperature_celsius{hardware=`"$hardwareName`",sensor=`"$sensorName`"} $value"
                            $metric | Out-File -FilePath $outputFile -Append -Encoding ASCII
                        }
                    }
                }
            }
        }
        
    } catch {
        Write-Host "Failed to collect temperatures: $_"
    }
    
    # Wait 10 seconds before next collection
    Start-Sleep -Seconds 10
}

# Cleanup (won't be reached unless script is stopped gracefully)
$computer.Close()