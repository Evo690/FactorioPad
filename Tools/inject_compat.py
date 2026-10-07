#!/usr/bin/env python3
"""Inject a freshly built FactorioCompat.framework into FactorioPad-template.ipa."""

import pathlib
import sys
import zipfile


def inject_compat(template_path: pathlib.Path, framework_path: pathlib.Path, output_path: pathlib.Path):
    if not template_path.is_file():
        raise FileNotFoundError(f"Template IPA not found: {template_path}")
    if not framework_path.is_dir():
        raise FileNotFoundError(f"Framework not found: {framework_path}")

    with zipfile.ZipFile(template_path, "r") as src:
        namelist = src.namelist()
        app_prefix = next(n for n in namelist if n.startswith("Payload/") and n.endswith(".app/"))
        compat_prefix = app_prefix + "Frameworks/FactorioCompat.framework/"

        temp_output = output_path.with_suffix(".tmp.zip")
        with zipfile.ZipFile(temp_output, "w", zipfile.ZIP_DEFLATED) as dst:
            for item in src.infolist():
                if not item.filename.startswith(compat_prefix):
                    dst.writestr(item, src.read(item.filename))

            for file in sorted(framework_path.rglob("*")):
                if file.is_file():
                    rel = file.relative_to(framework_path).as_posix()
                    entry = zipfile.ZipInfo(compat_prefix + rel)
                    entry.create_system = 3
                    entry.external_attr = file.stat().st_mode << 16
                    entry.compress_type = zipfile.ZIP_DEFLATED
                    dst.writestr(entry, file.read_bytes())

        temp_output.replace(output_path)


def main():
    if len(sys.argv) != 4:
        print("Usage: inject_compat.py <template_ipa> <compat_framework> <output_ipa>", file=sys.stderr)
        sys.exit(1)
    inject_compat(pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2]), pathlib.Path(sys.argv[3]))
    print(f"Successfully injected FactorioCompat into {sys.argv[3]}")


if __name__ == "__main__":
    main()
