function Get-MountedVolumesTelemetry {
    $disks = @(Get-PhysicalDisk -ErrorAction SilentlyContinue)
    $logical = @(Get-CimInstance Win32_LogicalDisk -ErrorAction SilentlyContinue)
    $vols = @(Get-Volume -ErrorAction SilentlyContinue | Where-Object { $null -ne $_.DriveLetter } | ForEach-Object {
        $dl = "$($_.DriveLetter):"
        $root = "$dl\"
        $hasSpotlight = Test-Path -LiteralPath "$root.Spotlight-V100" -ErrorAction SilentlyContinue
        $hasTrashes   = Test-Path -LiteralPath "$root.Trashes" -ErrorAction SilentlyContinue
        $ld = $logical | Where-Object { $_.DeviceID -eq $dl } | Select-Object -First 1
        $part = Get-Partition -DriveLetter $_.DriveLetter -ErrorAction SilentlyContinue | Select-Object -First 1
        $pd = if ($part) { $disks | Where-Object { $_.DeviceId -eq "$($part.DiskNumber)" } | Select-Object -First 1 } else { $null }
        [PSCustomObject]@{
            driveLetter         = [string]$_.DriveLetter
            root                = $root
            label               = if ($_.FileSystemLabel) { [string]$_.FileSystemLabel } else { 'Local Volume' }
            fileSystem          = if ($_.FileSystemType -and $_.FileSystemType -ne 'Unknown') { [string]$_.FileSystemType } else { 'exFAT' }
            driveType           = [string]$_.DriveType
            allocationUnitBytes = [int]$_.AllocationUnitSize
            sizeBytes           = [int64]$_.Size
            freeBytes           = [int64]$_.SizeRemaining
            usedBytes           = [int64]($_.Size - $_.SizeRemaining)
            hasSpotlight        = [bool]$hasSpotlight
            hasTrashes          = [bool]$hasTrashes
            serialNumber        = if ($ld -and $ld.VolumeSerialNumber) { [string]$ld.VolumeSerialNumber } else { 'N/A' }
            isReadOnly          = if ($part -and $null -ne $part.IsReadOnly) { [bool]$part.IsReadOnly } else { $false }
            smartHealth         = if ($pd -and $pd.HealthStatus) { [string]$pd.HealthStatus } else { [string]$_.HealthStatus }
            mediaType           = if ($pd -and $pd.MediaType -and $pd.MediaType -ne 'Unspecified') { [string]$pd.MediaType } else { [string]$_.DriveType }
        }
    })
    return $vols
}
