# Default Photo Folder Research

Date: 2026-10-01

## Recommendation

Use the actual user's `~/Pictures/Chameo/` for the original JPEG copies saved by
the **Folder** destination. Enable Folder by default, display its fixed location,
and keep an **Open Folder** action. This is a product recommendation: Apple
defines Pictures as the user's photo directory, and distinguishes user media
from private app data. Application Support is appropriate for indexes and
internal supporting files, rather than the user-facing JPEG copies
([Apple: File System Basics](https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/FileSystemProgrammingGuide/FileSystemOverview/FileSystemOverview.html)).

Apple also says apps should write into user document/media directories only
when explicitly directed by the user. Make the destination clear when the user
saves a capture; do not create unrelated files there during launch. A default
destination for an explicit Save action is the proposed interpretation, not a
documented blanket exception for automatic app-generated files
([Apple: File System Basics](https://developer.apple.com/library/archive/documentation/FileManagement/Conceptual/FileSystemProgrammingGuide/FileSystemOverview/FileSystemOverview.html)).

## macOS implementation constraints

- A sandboxed app needs appropriate access to Pictures. Apple's
  `com.apple.security.assets.pictures.read-write` entitlement permits read/write
  access to the Pictures folder. This is broader than access to Chameo's
  subfolder. Before this change, [`Chameo.entitlements`](../../Chameo.entitlements)
  did not declare it; the user-selected entitlement applies to files
  selected with an Open or Save dialog. Removing the chooser therefore requires
  revisiting the access mechanism
  ([Apple: Pictures read/write](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.assets.pictures.read-write),
  [Apple: User-selected read/write](https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.files.user-selected.read-write)).
- Do not assume `URL.picturesDirectory` gives the visible user's Pictures path
  in a sandbox. Apple documents that it returns a directory inside the app's
  sandbox for sandboxed macOS apps, and `~/Pictures` for nonsandboxed apps; the
  property is equivalent to the standard search-path API. Resolve and verify the
  actual user directory deliberately, rather than hardcoding `/Users/<name>`
  ([Apple: URL.picturesDirectory](https://developer.apple.com/documentation/foundation/url/picturesdirectory)).
- Documents is a weaker match for photos and has a separate privacy-access
  boundary. Apple's Files and Folders guidance lists Documents, Downloads,
  Desktop, iCloud Drive, and network volumes as protected locations. Pictures
  is absent from that list, but this does **not** establish a universal guarantee
  of permission-free writes; sandbox access, filesystem permissions, and unusual
  volume locations still need testing
  ([Apple: Controlling app access to files](https://support.apple.com/guide/security/controlling-app-access-to-files-secddd1d86a6/web)).

## Before shipping

Validate creation, saving, reopening, and Open Folder using the actual signed,
sandboxed app on a fresh installation. Confirm that the resulting directory is
the visible Pictures/Chameo folder. Treat existing custom locations as a separate
migration decision: preserve their files and define whether only future saves
switch to the fixed folder. This research does not implement or validate that
runtime behavior.

## Implementation validation

The fixed-folder implementation passed all 179 Swift tests and the strict
concurrency build on 2026-10-01. An isolated signed sandbox probe compiled the
app's destination and store sources, resolved the real user's
`~/Pictures/Chameo (test)` despite its container home, saved an original, and
reloaded identical bytes through a recreated store. It removed its generated
validation photo afterward. The probe validates file access; the full native
Camera/Photos and Finder UI flow remains a separate manual check.
