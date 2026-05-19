#!/usr/bin/env python3
"""Patch combase.dll to add ObjectStublessClient3..32 exports (LIEF approach, reference only).

NOTE: This LIEF-based binary patch does not fully work for combase.dll because
Wine treats combase as a builtin and overrides the on-disk DLL with its own
stub table at load time.  The working fix is to rebuild combase from Wine
source with the stubs compiled in.  This script is kept as a reference for
the approach and for testing outside Wine.
"""

import argparse
import lief
import sys
from pathlib import Path

STUB_RANGE = range(3, 33)  # ObjectStublessClient3 through ObjectStublessClient32

# mov eax, 0x80004001; ret  -- returns E_NOTIMPL
E_NOTIMPL_STUB = bytes([0xB8, 0x01, 0x40, 0x00, 0x80, 0xC3])


def main():
    parser = argparse.ArgumentParser(
        description="Add ObjectStublessClient stub exports to combase.dll using LIEF. "
        "(Reference only -- see script header for why the Wine source-build "
        "approach is needed instead.)"
    )
    parser.add_argument("input", help="Path to original combase.dll")
    parser.add_argument(
        "-o", "--output",
        help="Output path (default: <input-dir>/combase_patched.dll)",
    )
    args = parser.parse_args()

    input_path = Path(args.input)
    if not input_path.exists():
        sys.exit(f"Input not found: {input_path}")

    output_path = Path(args.output) if args.output else input_path.parent / "combase_patched.dll"

    print(f"Loading {input_path} ...")
    pe = lief.PE.parse(str(input_path))
    if pe is None:
        sys.exit("Failed to parse PE!")

    orig = list(pe.exported_functions)
    existing_names = {e.name for e in orig if e.name}
    print(f"Original exports: {len(orig)}")

    # Build code block -- one 16-byte-aligned stub per function
    code = bytearray()
    offsets = {}
    for i in STUB_RANGE:
        name = f"ObjectStublessClient{i}"
        while len(code) % 16:
            code.append(0xCC)
        offsets[name] = len(code)
        code.extend(E_NOTIMPL_STUB)

    # Add a new executable section
    section = lief.PE.Section(".cstb")
    section.content = list(code)
    section.characteristics = (
        lief.PE.Section.CHARACTERISTICS.MEM_EXECUTE
        | lief.PE.Section.CHARACTERISTICS.MEM_READ
        | lief.PE.Section.CHARACTERISTICS.CNT_CODE
    )
    added = pe.add_section(section)
    base_rva = added.virtual_address
    print(f"Added .cstb section at RVA 0x{base_rva:X}")

    # Add or update each export
    export = pe.get_export()
    for name, offset in sorted(offsets.items()):
        rva = base_rva + offset
        existing_entry = export.find_entry(name)
        if existing_entry is not None:
            existing_entry.address = rva
            print(f"  Updated: {name} -> 0x{rva:X}")
        else:
            entry = lief.PE.ExportEntry()
            entry.name = name
            entry.address = rva
            export.add_entry(entry)
            print(f"  Added:   {name} -> 0x{rva:X}")

    # Write patched DLL
    config = lief.PE.Builder.config_t()
    config.exports = True
    builder = lief.PE.Builder(pe, config)
    builder.build()
    builder.write(str(output_path))

    # Quick verification
    pe2 = lief.PE.parse(str(output_path))
    all_exp = list(pe2.exported_functions)
    stubless = [e.name for e in all_exp if "ObjectStubless" in e.name]
    print(f"\nWrote {output_path}")
    print(f"Total exports: {len(all_exp)}, ObjectStublessClient exports: {len(stubless)}")


if __name__ == "__main__":
    main()
