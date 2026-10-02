#!/usr/bin/env python3

"""Set the Sparkle display version for an archive with a SemVer prerelease."""

from __future__ import annotations

import sys
import xml.etree.ElementTree as ET
from pathlib import Path
from urllib.parse import unquote, urlsplit


def local_name(tag: str) -> str:
    return tag.rsplit("}", 1)[-1]


def main() -> int:
    if len(sys.argv) != 4:
        print(
            "usage: update_appcast_display_version.py APPCAST ARCHIVE_FILENAME VERSION",
            file=sys.stderr,
        )
        return 2

    appcast_path = Path(sys.argv[1])
    archive_filename = sys.argv[2]
    version = sys.argv[3]
    base_version = version.split("-", maxsplit=1)[0]

    ET.register_namespace("sparkle", "http://www.andymatuschak.org/xml-namespaces/sparkle")
    tree = ET.parse(appcast_path)
    matches = 0

    for item in tree.iter():
        if local_name(item.tag) != "item":
            continue

        enclosure = next(
            (child for child in item if local_name(child.tag) == "enclosure"),
            None,
        )
        if enclosure is None:
            continue

        archive_url = enclosure.get("url", "")
        filename = unquote(Path(urlsplit(archive_url).path).name)
        if filename != archive_filename:
            continue

        short_version = next(
            (
                child
                for child in item
                if local_name(child.tag) == "shortVersionString"
            ),
            None,
        )
        if short_version is None:
            short_version = ET.SubElement(
                item,
                "{http://www.andymatuschak.org/xml-namespaces/sparkle}shortVersionString",
            )
        if short_version.text not in (None, "", base_version, version):
            raise ValueError(
                f"unexpected appcast display version for {archive_filename}: "
                f"{short_version.text}"
            )
        short_version.text = version

        title = next(
            (child for child in item if local_name(child.tag) == "title"),
            None,
        )
        if title is not None and title.text:
            title.text = title.text.replace(base_version, version, 1)
        matches += 1

    if matches == 0:
        raise ValueError(f"appcast has no item for {archive_filename}")

    tree.write(appcast_path, encoding="utf-8", xml_declaration=True)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (ET.ParseError, OSError, ValueError) as error:
        print(f"error: {error}", file=sys.stderr)
        raise SystemExit(1)
