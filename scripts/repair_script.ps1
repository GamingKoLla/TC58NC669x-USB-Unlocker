# Script to safely inspect and repair the USB drive with elevation
$log = "c:\Users\rawis\Downloads\usb\repair_results.txt"
"==================================================" | Out-File $log
"USB DRIVE RECOVERY EXECUTION: $(Get-Date)" | Out-File $log -Append
"==================================================" | Out-File $log -Append

# 1. STRICT SAFETY VERIFICATION
$ssd = Get-Disk -Number 0 -ErrorAction SilentlyContinue
$usb = Get-Disk -Number 1 -ErrorAction SilentlyContinue

"Target Safety Check:" | Out-File $log -Append
"  Disk 0 (Protected Internal SSD): $($ssd.FriendlyName) - Bus: $($ssd.BusType) - Size: $($ssd.Size)" | Out-File $log -Append
"  Disk 1 (Target USB Drive): $($usb.FriendlyName) - Bus: $($usb.BusType) - Size: $($usb.Size)" | Out-File $log -Append

if ($usb.BusType -ne 'USB') {
    "CRITICAL ABORT: Disk 1 is NOT a USB device! Stopping to protect host system." | Out-File $log -Append
    Write-Host "ABORT: Disk 1 is NOT a USB drive!" -ForegroundColor Red
    pause
    exit 1
}

# 2. CLEAR REGISTRY WRITE-PROTECT POLICY (IF ANY)
"Checking Registry StorageDevicePolicies..." | Out-File $log -Append
$regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\StorageDevicePolicies"
if (Test-Path $regPath) {
    Set-ItemProperty -Path $regPath -Name "WriteProtect" -Value 0 -ErrorAction SilentlyContinue
    "StorageDevicePolicies WriteProtect set to 0." | Out-File $log -Append
} else {
    "No StorageDevicePolicies registry restriction found." | Out-File $log -Append
}

# 3. DISKPART ATTRIBUTES CLEAR
"Executing DiskPart attributes clear..." | Out-File $log -Append
$dpCommands = @"
select disk 1
detail disk
attributes disk
attributes disk clear readonly
attributes disk
select volume D
detail volume
attributes volume
attributes volume clear readonly
attributes volume
"@
$dpOutput = $dpCommands | diskpart
$dpOutput | Out-File $log -Append

# 4. VERIFY IF WRITE-PROTECTION CLEARED
Start-Sleep -Seconds 2
$usb = Get-Disk -Number 1
"Disk 1 Current IsReadOnly status: $($usb.IsReadOnly)" | Out-File $log -Append

if ($usb.IsReadOnly -eq $false) {
    "SUCCESS: Read-only attribute cleared! Proceeding with partition & format..." | Out-File $log -Append
    $cleanCommands = @"
select disk 1
clean
create partition primary
select partition 1
active
format fs=fat32 quick label="RECOVERED"
assign letter=D
"@
    $cleanCommands | diskpart | Out-File $log -Append
    
    # Write verification test
    Start-Sleep -Seconds 2
    try {
        $testPath = "D:\verify_recovery.txt"
        "USB Storage Successfully Recovered and Formatted at $(Get-Date)" | Out-File $testPath
        $readBack = Get-Content $testPath
        "Write/Read Verification: SUCCESS! Read back: '$readBack'" | Out-File $log -Append
    } catch {
        "Write Verification FAILED: $($_.Exception.Message)" | Out-File $log -Append
    }
} else {
    "==================================================" | Out-File $log -Append
    "ANALYSIS: Software attribute clear FAILED." | Out-File $log -Append
    "The USB controller firmware has locked the NAND into hardware write-protect mode." | Out-File $log -Append
    "Controller details: Toshiba VID_0930 PID_6544 (Solid State System SSS6692/SSS6698 / TC58NC)." | Out-File $log -Append
    "Hardware Mass Production (MP) Tool or controller reset is required." | Out-File $log -Append
    "==================================================" | Out-File $log -Append
}

Write-Host "Diagnostic & Repair routine finished. Check repair_results.txt" -ForegroundColor Green
