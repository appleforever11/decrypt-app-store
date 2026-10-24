import importlib.util
import plistlib
import struct
import tempfile
import unittest
from pathlib import Path
from zipfile import ZipFile

spec = importlib.util.spec_from_file_location('audit', Path(__file__).parents[1]/'macos/Resources/audit.py')
audit = importlib.util.module_from_spec(spec); spec.loader.exec_module(audit)

def thin(cpu=0x100000c, cryptid=0):
    return struct.pack('<IIIIIIII', 0xfeedfacf, cpu, 0, 2, 1, 24, 0, 0)+struct.pack('<IIIIII', 0x2c, 24, 0, 0, cryptid, 0)

class AuditTests(unittest.TestCase):
    def test_mixed_fat_slices(self):
        a, b = thin(), thin(0x200000c, 1)
        fat = struct.pack('>II', 0xcafebabe, 2)+struct.pack('>IIIII', 0x100000c, 0, 48, len(a), 0)+struct.pack('>IIIII', 0x200000c, 0, 48+len(a), len(b), 0)+a+b
        result = audit.slices(fat, 'Watch')
        self.assertEqual([s['cryptid'] for s in result], [0, 1])
        self.assertEqual(result[1]['architecture'], 'arm64_32')
    def test_malformed_commands_fail(self):
        data = bytearray(thin()); struct.pack_into('<I', data, 36, 4)
        with self.assertRaises(ValueError): audit.slices(bytes(data), 'App')
    def test_malformed_fat_fails(self):
        with self.assertRaises(ValueError): audit.slices(struct.pack('>II', 0xcafebabe, 900), 'App')
    def test_identity_and_inventory(self):
        with tempfile.TemporaryDirectory() as directory:
            source, output = Path(directory)/'original.ipa', Path(directory)/'clear.ipa'
            for path, cryptid in [(source, 1), (output, 0)]:
                with ZipFile(path, 'w') as z:
                    z.writestr('Payload/Test.app/Info.plist', plistlib.dumps(dict(CFBundleIdentifier='test.app', CFBundleExecutable='Test', CFBundleVersion='1')))
                    z.writestr('Payload/Test.app/Test', thin(cryptid=cryptid))
            self.assertEqual(audit.audit(output, source)['slices'][0]['cryptid'], 0)
            with ZipFile(output, 'a') as z: z.writestr('extra', b'x')
            with self.assertRaises(ValueError): audit.audit(output, source)
    def test_encrypted_big_endian_32(self):
        data = struct.pack('>IIIIIII', 0xfeedface, 12, 0, 2, 1, 20, 0)+struct.pack('>IIIII', 0x21, 20, 0, 0, 1)
        self.assertEqual(audit.slices(data, 'arm')[0]['cryptid'], 1)

if __name__ == '__main__': unittest.main()
