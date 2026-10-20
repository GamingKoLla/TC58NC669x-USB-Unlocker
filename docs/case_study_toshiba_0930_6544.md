# Hardware Investigation Case Study: Toshiba TransMemory (0930:6544)
**ArcEdge Network** • **Rawishan** • [arcedge.lk](https://arcedge.lk)


## Target Device Specifications
- **Device Description**: Generic Mass Storage USB Device (Reverted from OEM `TOSHIBA TransMemory`)
- **USB VID / PID**: `0930:6544` (Toshiba Corp. / TransMemory)
- **USB Descriptor Revision**: `1.00`
- **Controller Model**: `TC58NC669x` (Solid State System `3S6686-B6` / `0xB6`)
- **NAND Flash Memory**: Toshiba `TC58TEG6T2JTA00` (8GB Toggle TLC, 24nm/19nm)
- **NAND Flash ID (FID)**: `98 DE 98 92 72 57` (Flash CE: 1)
- **Original Content**: Windows 8.1 installation media (dated 2012–2013)

---

## Diagnostic Stages & Evidence

### 1. Operating System & Policy Layer
- **Registry Path**: `HKLM\SYSTEM\CurrentControlSet\Control\StorageDevicePolicies\WriteProtect`
- **Result**: Not present. No Windows group policy or storage restrictions were active on the host machine.

### 2. Windows Storage Management (Elevated Diskpart)
```text
DISKPART> select disk 1
DISKPART> attributes disk
Current Read-only State : Yes
Read-only  : No
DISKPART> attributes disk clear readonly
Disk attributes cleared successfully.
DISKPART> attributes disk
Current Read-only State : Yes
Read-only  : No
```
- **Finding**: While the OS-level attribute (`Read-only`) was `No`, the hardware status register (`Current Read-only State`) remained `Yes`. This confirmed that the lock was originated from the physical USB controller via SCSI `MODE SENSE` parameter headers (WP bit = 1).

### 3. Kernel IOCTL Interrogation (`query_drive.py`)
- `IOCTL_DISK_IS_WRITABLE` returned `Win32 Error 19 (ERROR_WRITE_PROTECT)`.
- The storage port driver rejected raw sector write attempts across volume and disk handles.

### 4. Controller Mass Production Tool Analysis (`3S MPTool`)
- **Tool Version**: `U3S_MP_V2182`
- **Controller Detection**: Slot 1 correctly detected ASIC `0xB6` (`Disk-D 0xB6`).
- **ISP Code Upload**: Succeeded (no Error 60/61).
- **Format Execution**: Consistently failed at ~4.2–4.8s with:
  > **`Error 28: DOS format fail`**
- **Analysis**: The controller accepted microcode execution in internal SRAM, but the NAND flash array rejected committing write/erase cycles. When older binaries (`6690_B1`) were attempted, `Error 61: MP ISP code install fail` occurred in 0.078s due to ASIC revision mismatch.

### 5. Direct Sector Write & Kernel Trace (`BOOTICE`)
- Direct SCSI Block Command (`WRITE(10)`) sent to Logical Block Address 0 (LBA 0):
  ```text
  Formatting: 1%.
  Write file failed! The request could not be performed because of an I/O device error.
  ```
- **Windows Kernel Event Log (`disk.sys`)**:
  ```text
  Event ID: 153
  Source: disk
  Message: The IO operation at logical block address 0x0 for Disk 1 was retried.
  ```
  Followed by SCSI `CHECK CONDITION` (`MEDIUM ERROR` / Write Fault).

---

## Physical Root Cause: NAND Tunnel Oxide Degradation

1. **Floating Gate Wearout**: Flash memory stores charge across a microscopic silicon dioxide dielectric. Over 12+ years and repeated write cycles, high-voltage electron tunneling causes stress-induced leakage current (SILC) and dielectric breakdown.
2. **Block 0 Failure**: Sector 0 maps to physical Block 0 of the NAND die. In flash memory architecture, Block 0 cannot be remapped by wear-leveling algorithms. When its floating gates fail write-verification, the internal comparator returns `STATUS_FAIL`.
3. **Firmware Fail-Safe**: To prevent total loss of readable data, the SSS6692 controller permanently latches into hardware Read-Only mode. Reads remain fully functional, while all write and erase operations are electrically impossible.
