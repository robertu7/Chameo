"""Pin the Homebrew cask to a published stable Chameo disk image."""

import argparse
import hashlib
from pathlib import Path
import re


def update_cask(version: str, disk_image: Path, cask: Path) -> None:
    if not re.fullmatch(r"(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)", version):
        raise ValueError("Homebrew requires a stable X.Y.Z version")
    if disk_image.name != f"Chameo-{version}-arm64.dmg" or disk_image.stat().st_size == 0:
        raise ValueError("Expected the published disk image for this version")

    checksum = hashlib.sha256(disk_image.read_bytes()).hexdigest()
    if cask.exists():
        current = cask.read_text()
        current_version = re.search(r'^  version "([0-9]+\.[0-9]+\.[0-9]+)"$', current, re.MULTILINE)
        current_checksum = re.search(r'^  sha256 "([0-9a-f]{64})"$', current, re.MULTILINE)
        if current_version is None or current_checksum is None:
            raise ValueError("Existing cask must declare a stable version and SHA-256 checksum")
        if tuple(map(int, version.split("."))) < tuple(map(int, current_version[1].split("."))):
            raise ValueError("Refusing to downgrade the Homebrew cask")
        if version == current_version[1] and checksum != current_checksum[1]:
            raise ValueError("Refusing to replace an already published version with different bytes")

    cask.parent.mkdir(parents=True, exist_ok=True)
    cask.write_text(f'''cask "chameo" do
  version "{version}"
  sha256 "{checksum}"

  url "https://github.com/robertu7/Chameo/releases/download/v#{{version}}/Chameo-#{{version}}-arm64.dmg"
  name "Chameo"
  desc "Menu bar app for daily selfies and timelapses"
  homepage "https://github.com/robertu7/Chameo"

  livecheck do
    url :url
    strategy :github_latest
  end

  auto_updates true
  depends_on arch: :arm64
  depends_on macos: :tahoe

  app "Chameo.app"

  postflight_steps do
    run "/usr/bin/xattr",
        args:           ["-drs", "com.apple.quarantine", "{{{{appdir}}}}/Chameo.app"],
        writable_paths: ["{{{{appdir}}}}/Chameo.app"]
  end

  uninstall quit: "com.robertu.Chameo"

  zap trash: [
    "~/Library/Application Support/com.robertu.Chameo",
    "~/Library/Caches/com.robertu.Chameo",
    "~/Library/Preferences/com.robertu.Chameo.plist",
    "~/Library/Saved Application State/com.robertu.Chameo.savedState",
  ]

  caveats <<~EOS
    This cask clears quarantine from the installed Chameo.app, skipping the usual
    first-launch Gatekeeper check. Chameo is ad-hoc signed.
    If macOS blocks launch, choose Open Anyway in System Settings > Privacy & Security.
  EOS
end
''')


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("version")
    parser.add_argument("disk_image", type=Path)
    parser.add_argument("cask", type=Path)
    arguments = parser.parse_args()
    update_cask(arguments.version, arguments.disk_image, arguments.cask)
