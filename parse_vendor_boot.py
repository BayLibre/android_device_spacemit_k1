#!/usr/bin/env python3
"""Parse vendor_boot.img header and verify DTB location."""

import struct
import sys
import math

def parse_vendor_boot(path):
    with open(path, 'rb') as f:
        magic = f.read(8)
        print(f'Magic: {magic}')
        hdr_ver = struct.unpack('<I', f.read(4))[0]
        print(f'Header version: {hdr_ver}')
        page_size = struct.unpack('<I', f.read(4))[0]
        print(f'Page size: {page_size}')
        kernel_addr = struct.unpack('<I', f.read(4))[0]
        print(f'Kernel addr: 0x{kernel_addr:x}')
        ramdisk_addr = struct.unpack('<I', f.read(4))[0]
        print(f'Ramdisk addr: 0x{ramdisk_addr:x}')
        vendor_ramdisk_size = struct.unpack('<I', f.read(4))[0]
        print(f'Vendor ramdisk size: {vendor_ramdisk_size}')
        cmdline = f.read(2048).split(b'\x00')[0]
        print(f'Cmdline: {cmdline.decode()}')
        tags_addr = struct.unpack('<I', f.read(4))[0]
        print(f'Tags addr: 0x{tags_addr:x}')
        product_name = f.read(16).split(b'\x00')[0]
        print(f'Product: {product_name.decode() if product_name else "(empty)"}')
        hdr_size = struct.unpack('<I', f.read(4))[0]
        print(f'Header size: {hdr_size}')
        dtb_size = struct.unpack('<I', f.read(4))[0]
        print(f'DTB size: {dtb_size}')
        dtb_addr = struct.unpack('<Q', f.read(8))[0]
        print(f'DTB addr: 0x{dtb_addr:x}')

        def align_up(val, alignment):
            return math.ceil(val / alignment) * alignment

        # Header aligned size
        hdr_aligned = align_up(hdr_size, page_size)
        print(f'\nHeader aligned size: {hdr_aligned} (0x{hdr_aligned:x})')

        # Correct DTB offset
        dtb_offset = hdr_aligned + align_up(vendor_ramdisk_size, page_size)
        print(f'DTB offset (correct): {dtb_offset} (0x{dtb_offset:x})')

        # Buggy DTB offset (uses page_size for header instead of aligned header size)
        dtb_offset_buggy = page_size + align_up(vendor_ramdisk_size, page_size)
        print(f'DTB offset (buggy):   {dtb_offset_buggy} (0x{dtb_offset_buggy:x})')

        # Read DTB magic at correct offset
        f.seek(dtb_offset)
        dtb_magic = f.read(4)
        print(f'\nDTB magic at correct offset 0x{dtb_offset:x}: {dtb_magic.hex()}', end='')
        if dtb_magic == b'\xd0\x0d\xfe\xed':
            f.seek(dtb_offset + 4)
            dtb_total = struct.unpack('>I', f.read(4))[0]
            print(f' (VALID FDT, size={dtb_total})')
        else:
            print(' (NOT FDT)')

        # Read at buggy offset
        f.seek(dtb_offset_buggy)
        dtb_magic_buggy = f.read(4)
        print(f'DTB magic at buggy offset 0x{dtb_offset_buggy:x}:   {dtb_magic_buggy.hex()}', end='')
        if dtb_magic_buggy == b'\xd0\x0d\xfe\xed':
            print(' (VALID FDT)')
        else:
            print(' (NOT FDT)')

if __name__ == '__main__':
    path = sys.argv[1] if len(sys.argv) > 1 else 'vendor_boot.img'
    parse_vendor_boot(path)
