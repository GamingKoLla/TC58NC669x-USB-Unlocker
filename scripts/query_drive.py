import ctypes
from ctypes import wintypes
import sys

GENERIC_READ = 0x80000000
GENERIC_WRITE = 0x40000000
FILE_SHARE_READ = 1
FILE_SHARE_WRITE = 2
OPEN_EXISTING = 3
FILE_ATTRIBUTE_NORMAL = 0x80

IOCTL_STORAGE_QUERY_PROPERTY = 0x002D1400
IOCTL_DISK_IS_WRITABLE = 0x00070024
IOCTL_SCSI_PASS_THROUGH = 0x0004D004
IOCTL_SCSI_PASS_THROUGH_DIRECT = 0x0004D014

class STORAGE_PROPERTY_QUERY(ctypes.Structure):
    _fields_ = [
        ("PropertyId", wintypes.DWORD),
        ("QueryType", wintypes.DWORD),
        ("AdditionalParameters", wintypes.BYTE * 1),
    ]

def check_drive(path):
    print(f"=== Opening {path} ===")
    # Try open with 0 access first (metadata)
    h = ctypes.windll.kernel32.CreateFileW(
        path,
        0,
        FILE_SHARE_READ | FILE_SHARE_WRITE,
        None,
        OPEN_EXISTING,
        0,
        None
    )
    if h == -1 or h == 0:
        err = ctypes.GetLastError()
        print(f"Failed to open with access 0: error {err}")
        return
    else:
        print(f"Successfully opened {path} with access 0 (Handle: {h})")

    # Check IOCTL_DISK_IS_WRITABLE
    bytes_returned = wintypes.DWORD(0)
    res = ctypes.windll.kernel32.DeviceIoControl(
        h,
        IOCTL_DISK_IS_WRITABLE,
        None, 0,
        None, 0,
        ctypes.byref(bytes_returned),
        None
    )
    if res == 0:
        err = ctypes.GetLastError()
        print(f"IOCTL_DISK_IS_WRITABLE failed: error {err} (0x{err:X})")
        # 19 = ERROR_WRITE_PROTECT
        if err == 19:
            print("--> DRIVE REPORTS HARDWARE / DRIVER WRITE PROTECTED (ERROR_WRITE_PROTECT / 19)")
    else:
        print("IOCTL_DISK_IS_WRITABLE succeeded! Device reports writable!")

    # Check StorageDeviceProperty
    query = STORAGE_PROPERTY_QUERY()
    query.PropertyId = 0 # StorageDeviceProperty
    query.QueryType = 0 # PropertyStandardQuery
    buf = ctypes.create_string_buffer(4096)
    res = ctypes.windll.kernel32.DeviceIoControl(
        h,
        IOCTL_STORAGE_QUERY_PROPERTY,
        ctypes.byref(query), ctypes.sizeof(query),
        buf, ctypes.sizeof(buf),
        ctypes.byref(bytes_returned),
        None
    )
    if res != 0:
        raw = buf.raw[:bytes_returned.value]
        # Parse STORAGE_DEVICE_DESCRIPTOR
        # Offset 16: BusType (1 byte)
        # Offset 24: VendorIdOffset (DWORD)
        # Offset 28: ProductIdOffset (DWORD)
        # Offset 32: ProductRevisionOffset (DWORD)
        # Offset 36: SerialNumberOffset (DWORD)
        import struct
        version, size, dev_type, dev_type_mod, removable, command_queuing, vendor_off, prod_off, rev_off, sn_off, bus_type = struct.unpack_from("<IIBBBBIIIIb", raw, 0)
        def get_str(offset):
            if offset > 0 and offset < len(raw):
                end = raw.find(b'\x00', offset)
                if end != -1:
                    return raw[offset:end].decode('latin1', 'ignore').strip()
            return ""
        print(f"Device Descriptor:")
        print(f"  Removable: {removable}")
        print(f"  BusType: {bus_type}")
        print(f"  Vendor: '{get_str(vendor_off)}'")
        print(f"  Product: '{get_str(prod_off)}'")
        print(f"  Revision: '{get_str(rev_off)}'")
        print(f"  Serial: '{get_str(sn_off)}'")

    ctypes.windll.kernel32.CloseHandle(h)

if __name__ == "__main__":
    check_drive(r"\\.\D:")
    check_drive(r"\\.\PhysicalDrive1")
