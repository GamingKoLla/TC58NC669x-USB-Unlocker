$ErrorActionPreference = 'SilentlyContinue'

Write-Host "=== 1. DISKPART ATTRIBUTES ==="
$diskpartScript = @"
select disk 1
detail disk
attributes disk
select partition 1
detail partition
attributes volume
"@
$diskpartScript | diskpart

Write-Host "`n=== 2. STORAGE REGISTRY POLICIES ==="
Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\StorageDevicePolicies" -ErrorAction SilentlyContinue | Format-List
Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Services\USBSTOR" -ErrorAction SilentlyContinue | Format-List

Write-Host "`n=== 3. USB DEVICE PARENT & HARDWARE IDS ==="
$pnp = Get-PnpDevice | Where-Object { $_.InstanceId -like "*MSFTASMTL2001CC0C60D71CC90632023F8*" }
if ($pnp) {
    Write-Host "PnP Device: $($pnp.FriendlyName) - $($pnp.InstanceId)"
    $parentId = (Get-PnpDeviceProperty -InputObject $pnp -KeyName 'DEVPKEY_Device_Parent').Data
    Write-Host "Parent ID: $parentId"
    if ($parentId) {
        $parent = Get-PnpDevice -InstanceId $parentId
        Write-Host "Parent FriendlyName: $($parent.FriendlyName)"
        Write-Host "Parent HardwareID: $($parent.HardwareID -join ', ')"
    }
}

Write-Host "`n=== 4. ALL USB MASS STORAGE / DISK DEVICES ==="
Get-CimInstance Win32_PnPEntity | Where-Object { $_.DeviceID -like "USB*" -or $_.Service -eq "USBSTOR" } | Select-Object Name, DeviceID, Service | Format-Table -AutoSize

Write-Host "`n=== 5. DISK 1 READ-ONLY STATUS ==="
Get-Disk -Number 1 | Select-Object Number, FriendlyName, IsReadOnly, IsOffline, ReadOnlyReason, OperationalStatus, HealthStatus | Format-List
