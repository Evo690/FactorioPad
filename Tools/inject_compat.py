#!/usr/bin/env python3
"""Inject freshly built FactorioCompat.framework and/or FactorioPad binary into FactorioPad-template.ipa."""

import pathlib
import stat
import sys
import zipfile


def inject_compat(template_path: pathlib.Path, framework_path: pathlib.Path, output_path: pathlib.Path, app_binary_path: pathlib.Path = None):
    if not template_path.is_file():
        raise FileNotFoundError(f"Template IPA not found: {template_path}")
    if not framework_path.is_dir():
        raise FileNotFoundError(f"Framework not found: {framework_path}")
    if app_binary_path and not app_binary_path.is_file():
        raise FileNotFoundError(f"App binary not found: {app_binary_path}")

    with zipfile.ZipFile(template_path, "r") as src:
        namelist = src.namelist()
        app_prefix = next(n for n in namelist if n.startswith("Payload/") and n.endswith(".app/"))
        compat_prefix = app_prefix + "Frameworks/FactorioCompat.framework/"
        app_binary_entry = app_prefix + "FactorioPad"

        temp_output = output_path.with_suffix(".tmp.zip")
        with zipfile.ZipFile(temp_output, "w", zipfile.ZIP_DEFLATED) as dst:
            for item in src.infolist():
                if item.filename.startswith(compat_prefix):
                    continue
                if app_binary_path and item.filename == app_binary_entry:
                    continue
                dst.writestr(item, src.read(item.filename))

            if app_binary_path:
                entry = zipfile.ZipInfo(app_binary_entry)
                entry.create_system = 3
                entry.external_attr = (stat.S_IFREG | 0o755) << 16
                entry.compress_type = zipfile.ZIP_DEFLATED
                dst.writestr(entry, app_binary_path.read_bytes())
                print(f"Injected updated {app_binary_entry}")

            for file in sorted(framework_path.rglob("*")):
                if file.is_file():
                    rel = file.relative_to(framework_path).as_posix()
                    entry = zipfile.ZipInfo(compat_prefix + rel)
                    entry.create_system = 3
                    entry.external_attr = file.stat().st_mode << 16
                    entry.compress_type = zipfile.ZIP_DEFLATED
                    dst.writestr(entry, file.read_bytes())
            print(f"Injected updated {compat_prefix}")

        temp_output.replace(output_path)


def main():
    if len(sys.argv) not in (4, 5):
        print("Usage: inject_compat.py <template_ipa> <compat_framework> <output_ipa> [<app_binary>]", file=sys.stderr)
        sys.exit(1)
    app_binary = pathlib.Path(sys.argv[4]) if len(sys.argv) == 5 else None
    inject_compat(pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2]), pathlib.Path(sys.argv[3]), app_binary)
    print(f"Successfully injected into {sys.argv[3]}")


if __name__ == "__main__":
    main()
