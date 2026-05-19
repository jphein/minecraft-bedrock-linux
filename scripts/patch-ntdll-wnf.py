#!/usr/bin/env python3
"""Patch ntdll.dll to add 14 WNF stub exports (all return STATUS_SUCCESS)."""

import argparse
import lief
import sys
from pathlib import Path

# All WNF functions that Minecraft Bedrock / XGameRuntime expect
WNF_FUNCTIONS = [
    "NtQueryWnfStateData",
    "NtSubscribeWnfStateChange",
    "NtUpdateWnfStateData",
    "NtUnsubscribeWnfStateChange",
    "RtlQueryWnfStateData",
    "RtlSubscribeWnfStateChangeNotification",
    "RtlPublishWnfStateData",
    "RtlUnsubscribeWnfNotification",
    "RtlWnfCompareChangeStamp",
    "RtlWnfDllUnloadCallback",
    "ZwQueryWnfStateData",
    "ZwSubscribeWnfStateChange",
    "ZwUpdateWnfStateData",
    "ZwUnsubscribeWnfStateChange",
]

# xor eax, eax; ret  -- returns 0 (STATUS_SUCCESS)
STUB_CODE = bytes([0x31, 0xC0, 0xC3])


def main():
    parser = argparse.ArgumentParser(
        description="Add WNF stub exports to ntdll.dll using LIEF."
    )
    parser.add_argument("input", help="Path to original ntdll.dll (or .dll.bak)")
    parser.add_argument(
        "-o", "--output",
        help="Output path (default: <input-dir>/ntdll_patched.dll)",
    )
    args = parser.parse_args()

    input_path = Path(args.input)
    if not input_path.exists():
        sys.exit(f"Input not found: {input_path}")

    output_path = Path(args.output) if args.output else input_path.parent / "ntdll_patched.dll"

    print(f"Loading {input_path} ...")
    pe = lief.PE.parse(str(input_path))
    if pe is None:
        sys.exit("Failed to parse PE!")

    print(f"Original exports: {len(list(pe.exported_functions))}")

    # Build code block -- one 16-byte-aligned stub per function
    code = bytearray()
    offsets = {}
    for name in WNF_FUNCTIONS:
        while len(code) % 16:
            code.append(0xCC)  # int3 padding
        offsets[name] = len(code)
        code.extend(STUB_CODE)

    # Add a new executable section
    section = lief.PE.Section(".wnf")
    section.content = list(code)
    section.characteristics = (
        lief.PE.Section.CHARACTERISTICS.MEM_EXECUTE
        | lief.PE.Section.CHARACTERISTICS.MEM_READ
        | lief.PE.Section.CHARACTERISTICS.CNT_CODE
    )
    added = pe.add_section(section)
    base_rva = added.virtual_address
    print(f"Added .wnf section at RVA 0x{base_rva:X}")

    # Register each stub as an export
    export = pe.get_export()
    for name in sorted(WNF_FUNCTIONS):
        rva = base_rva + offsets[name]
        entry = lief.PE.ExportEntry()
        entry.name = name
        entry.address = rva
        export.add_entry(entry)
        print(f"  {name} -> 0x{rva:X}")

    # Write patched DLL
    config = lief.PE.Builder.config_t()
    config.exports = True
    builder = lief.PE.Builder(pe, config)
    builder.build()
    builder.write(str(output_path))

    # Quick verification pass
    pe2 = lief.PE.parse(str(output_path))
    all_exp = list(pe2.exported_functions)
    wnf = sorted(e.name for e in all_exp if "Wnf" in e.name or "wnf" in e.name)
    print(f"\nWrote {output_path}")
    print(f"Total exports: {len(all_exp)}, WNF exports: {len(wnf)}")
    if len(wnf) != len(WNF_FUNCTIONS):
        sys.exit(f"Expected {len(WNF_FUNCTIONS)} WNF exports, got {len(wnf)}")
    print("Verification OK")


if __name__ == "__main__":
    main()
