#!/usr/bin/env python3
"""Generate the PFFM20 120Hz refresh-rate override XML.

The OPPO PFFM20 refresh_rate_config.xml uses rateId="auto-90-60-120".
This script changes only the fourth slot to 3, leaving all other setting
modes untouched. It also disables per-view refresh-rate overrides for every
configured item so app/window requests cannot force the display back to 60Hz.
Finally, it disables OPPO's global input-method low-rate policy so focused
text fields do not add a separate 60Hz vote.
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys
from pathlib import Path
from xml.etree import ElementTree as ET


DEVICE_CONFIG = "/my_product/etc/refresh_rate_config.xml"
RATE_ID_RE = re.compile(r'rateId="([0-3]-[0-3]-[0-3]-[0-3])"')
ITEM_RE = re.compile(r'(<item\b[^>]*?)\s*/>')
DISABLE_VIEW_OVERRIDE_RE = re.compile(r'disableViewOverride="[^"]*"')
CONFIG_RE = re.compile(r'(<config\b[^>]*?)\s*/>')
CONFIG_ATTRS = {
    "enableRateOverride": "true",
    "inputMethodLowRate": "false",
    "enableFodHighRate": "true",
}


def rewrite_rate_id(match: re.Match[str]) -> str:
    parts = match.group(1).split("-")
    parts[3] = "3"
    return f'rateId="{"-".join(parts)}"'


def set_xml_attr(tag_start: str, name: str, value: str) -> str:
    attr_re = re.compile(rf'{re.escape(name)}="[^"]*"')
    replacement = f'{name}="{value}"'
    if attr_re.search(tag_start):
        return attr_re.sub(replacement, tag_start)
    return f'{tag_start.rstrip()} {replacement}'


def generate(source: Path, destination: Path) -> int:
    text = source.read_text(encoding="utf-8")
    rate_id_changed = 0

    def counted(match: re.Match[str]) -> str:
        nonlocal rate_id_changed
        old = match.group(1)
        new = rewrite_rate_id(match)
        if new != f'rateId="{old}"':
            rate_id_changed += 1
        return new

    output = RATE_ID_RE.sub(counted, text)

    def add_disable_view_override(match: re.Match[str]) -> str:
        item_start = match.group(1)
        if "disableViewOverride=" in item_start:
            item_start = DISABLE_VIEW_OVERRIDE_RE.sub(
                'disableViewOverride="true"', item_start
            )
            return f"{item_start.rstrip()} />"
        return f'{item_start.rstrip()} disableViewOverride="true" />'

    destination.parent.mkdir(parents=True, exist_ok=True)
    output = ITEM_RE.sub(add_disable_view_override, output)

    def rewrite_config(match: re.Match[str]) -> str:
        config_start = match.group(1)
        for name, value in CONFIG_ATTRS.items():
            config_start = set_xml_attr(config_start, name, value)
        return f"{config_start.rstrip()} />"

    output, config_count = CONFIG_RE.subn(rewrite_config, output)
    if config_count == 0:
        config_attrs = " ".join(f'{name}="{value}"' for name, value in CONFIG_ATTRS.items())
        output = output.replace(
            "</refresh_rate_config>",
            f"  <config {config_attrs} />\n</refresh_rate_config>",
            1,
        )

    destination.write_text(output, encoding="utf-8", newline="")

    ET.parse(destination)
    return rate_id_changed


def pull_from_device(destination: Path, serial: str | None, device_path: str) -> None:
    cmd = ["adb"]
    if serial:
        cmd.extend(["-s", serial])
    cmd.extend(["shell", "su", "-c", f"cat {device_path}"])

    result = subprocess.run(cmd, check=True, capture_output=True)
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_bytes(result.stdout)
    ET.parse(destination)


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(
        description="Generate a PFFM20 120Hz refresh-rate override XML."
    )
    parser.add_argument("source_xml", nargs="?", help="source XML path")
    parser.add_argument("dest_xml", help="destination XML path")
    parser.add_argument(
        "--from-device",
        action="store_true",
        help=f"pull source XML from device path {DEVICE_CONFIG}",
    )
    parser.add_argument("--serial", help="adb serial, for example 192.168.50.101:35555")
    parser.add_argument("--device-path", default=DEVICE_CONFIG, help="device XML path")
    parser.add_argument(
        "--save-source",
        type=Path,
        help="optional local path where the device source XML is saved",
    )
    args = parser.parse_args(argv[1:])

    if args.from_device:
        source = args.save_source or Path("references/refresh_rate_config.device.xml")
        pull_from_device(source, args.serial, args.device_path)
        print(f"source={source}")
    elif args.source_xml:
        source = Path(args.source_xml)
    else:
        parser.error("source_xml is required unless --from-device is used")

    changed = generate(source, Path(args.dest_xml))
    print(f"rate_id_changed={changed}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
