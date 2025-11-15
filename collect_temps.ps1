# Run continuously as a service - Read from WMI instead of web API
while ($true) {
    try {
        # Output file
        $outputFile = "C:\prometheus_textfiles\hardware_temps.prom"
        
        # Clear the file
        "" | Out-File -FilePath $outputFile -Encoding ASCII
        
        # Query LibreHardwareMonitor WMI namespace for sensors
        $sensors = Get-WmiObject -Namespace "root\LibreHardwareMonitor" -Class Sensor -ErrorAction Stop
        
        foreach ($sensor in $sensors) {
            # Only process temperature sensors
            if ($sensor.SensorType -eq "Temperature") {
                # Clean up names for Prometheus labels
                $hardwareName = $sensor.Parent -replace '[^a-zA-Z0-9_]', '_'
                $sensorName = $sensor.Name -replace '[^a-zA-Z0-9_]', '_'
                $value = $sensor.Value
                
                if ($value) {
                    $metric = "hardware_temperature_celsius{hardware=`"$hardwareName`",sensor=`"$sensorName`"} $value"
                    $metric | Out-File -FilePath $outputFile -Append -Encoding ASCII
                }
            }
        }
        
    } catch {
        Write-Host "Failed to collect temperatures: $_"
    }
    
    # Wait 10 seconds before next collection
    Start-Sleep -Seconds 10
}