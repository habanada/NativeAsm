# GNU AVX2 Golden Oracle

The two `.s` files contain the source instructions used for the AVX2 fixed-byte oracle.

The manifest was produced with GNU Binutils 2.44. `verify_golden.py` assembles both sources with `as --64`, disassembles them with `objdump -d -M intel -w`, and requires every source instruction, byte sequence and disassembly row to match `golden_manifest.tsv`.

The Delphi DUnitX golden tests contain the same byte strings but do not invoke an external assembler at test runtime.
