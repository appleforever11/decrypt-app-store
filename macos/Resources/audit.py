#!/usr/bin/env python3
"""Read-only ZIP CRC, inventory, identity and every Mach-O slice audit."""
import argparse
import json
import plistlib
import struct
from zipfile import ZipFile

THIN = {b'\xce\xfa\xed\xfe': ('<', 28), b'\xcf\xfa\xed\xfe': ('<', 32),
        b'\xfe\xed\xfa\xce': ('>', 28), b'\xfe\xed\xfa\xcf': ('>', 32)}
FAT = {b'\xca\xfe\xba\xbe': ('>', 20), b'\xbe\xba\xfe\xca': ('<', 20),
       b'\xca\xfe\xba\xbf': ('>', 32), b'\xbf\xba\xfe\xca': ('<', 32)}

def slices(data, path, base=0):
    magic = data[:4]
    if magic in FAT:
        endian, width = FAT[magic]
        if len(data) < 8: raise ValueError('truncated fat header')
        count = struct.unpack_from(endian+'I', data, 4)[0]
        if count > 128 or 8+count*width > len(data): raise ValueError('invalid fat table')
        result = []
        for i in range(count):
            pos = 8+i*width
            offset, size = struct.unpack_from(endian+('II' if width == 20 else 'QQ'), data, pos+8)
            if offset < 8+count*width or size < 28 or offset+size > len(data): raise ValueError('invalid fat slice')
            if data[offset:offset+4] not in THIN: raise ValueError('unknown fat slice format')
            result.extend(slices(data[offset:offset+size], path, base+offset))
        return result
    if magic not in THIN: return []
    endian, header = THIN[magic]
    if len(data) < header: raise ValueError('truncated Mach-O header')
    cpu = struct.unpack_from(endian+'I', data, 4)[0]
    count, size = struct.unpack_from(endian+'II', data, 16)
    if count > 65536 or header+size > len(data): raise ValueError('invalid load command region')
    pos, cryptid = header, 0
    for _ in range(count):
        if pos+8 > header+size: raise ValueError('truncated load command')
        command, length = struct.unpack_from(endian+'II', data, pos)
        if length < 8 or pos+length > header+size: raise ValueError('invalid load command')
        if command in (0x21, 0x2c):
            if length < (24 if command == 0x2c else 20): raise ValueError('invalid encryption command')
            start, amount, value = struct.unpack_from(endian+'III', data, pos+8)
            if start+amount > len(data): raise ValueError('encryption region exceeds slice')
            cryptid = max(cryptid, value)
        pos += length
    if pos != header+size: raise ValueError('load command size mismatch')
    architecture = {0x100000c:'arm64', 0x200000c:'arm64_32', 12:'arm', 0x1000007:'x86_64', 7:'i386'}.get(cpu, hex(cpu))
    return [dict(path=path, offset=base, architecture=architecture, cryptid=cryptid)]

def identity(archive):
    candidates = [n for n in archive.namelist() if n.startswith('Payload/') and n.count('/') == 2 and n.endswith('.app/Info.plist')]
    if len(candidates) != 1: raise ValueError('expected one top-level IPA application')
    info = plistlib.loads(archive.read(candidates[0]))
    executable = candidates[0].rsplit('/', 1)[0]+'/'+info['CFBundleExecutable']
    if executable not in archive.namelist(): raise ValueError('missing main executable')
    return (info['CFBundleIdentifier'], str(info.get('CFBundleShortVersionString', '')), str(info.get('CFBundleVersion', '')), executable)

def audit(path, reference=None):
    with ZipFile(path) as archive:
        names = archive.namelist()
        if len(names) != len(set(names)): raise ValueError('duplicate ZIP members')
        if archive.testzip() is not None: raise ValueError('ZIP CRC failure')
        ident = identity(archive)
        result = []
        for entry in archive.infolist():
            if entry.is_dir(): continue
            with archive.open(entry) as stream:
                prefix = stream.read(4)
                if prefix in THIN or prefix in FAT:
                    result.extend(slices(prefix+stream.read(), entry.filename))
        if not result or not any(s['path'] == ident[3] for s in result): raise ValueError('main executable is not a recognized Mach-O')
        inventory_matches = identity_matches = True
        if reference:
            with ZipFile(reference) as source:
                if source.testzip() is not None: raise ValueError('reference ZIP CRC failure')
                inventory_matches = sorted(names) == sorted(source.namelist())
                identity_matches = ident == identity(source)
                if not inventory_matches or not identity_matches: raise ValueError('output inventory or identity differs from original')
        return dict(bundleID=ident[0], version=ident[1], slices=result, crcValid=True,
                    inventoryMatches=inventory_matches, identityMatches=identity_matches)

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('archive'); parser.add_argument('--reference')
    args = parser.parse_args()
    print(json.dumps(audit(args.archive, args.reference)))
