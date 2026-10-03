from pathlib import Path
import csv
import re
import subprocess
import tempfile

base = Path(__file__).resolve().parent
manifest = list(csv.DictReader((base / 'golden_manifest.tsv').open(newline=''), delimiter='\t'))
actual = []
for source_name in ('avx2_golden_core.s', 'avx2_golden_extended.s'):
    source = base / source_name
    with tempfile.TemporaryDirectory() as td:
        obj = Path(td) / 'golden.o'
        subprocess.check_call(['as', '--64', '-o', str(obj), str(source)])
        text = subprocess.check_output(['objdump', '-d', '-M', 'intel', '-w', str(obj)], text=True)
        decoded = []
        for line in text.splitlines():
            match = re.match(r'\s*[0-9a-f]+:\s+((?:[0-9a-f]{2}\s+)+)\s*(.+)$', line)
            if match:
                decoded.append((' '.join(match.group(1).upper().split()), match.group(2).strip()))
        instructions = []
        for line in source.read_text().splitlines():
            line = line.strip()
            if line and not line.startswith('.') and not line.endswith(':'):
                instructions.append(line)
        if len(instructions) != len(decoded):
            raise SystemExit(f'{source_name}: source={len(instructions)} decoded={len(decoded)}')
        for instruction, (byte_string, disassembly) in zip(instructions, decoded):
            actual.append((source_name, instruction, byte_string, disassembly))
if len(actual) != len(manifest):
    raise SystemExit(f'row count mismatch: actual={len(actual)} manifest={len(manifest)}')
for index, (row, got) in enumerate(zip(manifest, actual)):
    expected = (row['source'], row['instruction'], row['bytes'], row['objdump'])
    if expected != got:
        raise SystemExit(f'row {index}: expected={expected!r} actual={got!r}')
print(f'PASS GNU AVX2 golden matrix: {len(actual)} encodings')
