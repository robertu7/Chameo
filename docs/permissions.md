# Permissions & Privacy

Chameo uses system permissions for camera, Photos, optional location metadata, and reminders.

## Camera

Purpose: live preview and still photo capture.

Bundle key:

- `NSCameraUsageDescription`

Entitlement:

- `com.apple.security.device.camera`

## Photos

Purpose:

- Create or find the configured album. If an album with the same exact name already exists, the app uses that album.
- Save kept photos.
- Read the album for the Library view.
- Delete selected original photo assets from Photos.

Bundle key:

- `NSPhotoLibraryUsageDescription`

Entitlement:

- `com.apple.security.personal-information.photos-library`

## Location

Purpose: optionally attach current location metadata to photos saved through `Save to Photos`.

Default: off.

Bundle keys:

- `NSLocationUsageDescription`
- `NSLocationWhenInUseUsageDescription`

Entitlement:

- `com.apple.security.personal-information.location`

Behavior:

- The app asks for location only when `Save photo location` is enabled and the user saves a photo.
- If location is unavailable, the app saves without location and shows a status message.
- Authorization and one-shot location requests time out instead of blocking a save indefinitely.
- Library location names are reverse-geocoded from `PHAsset.location`.

## Notifications

Purpose: remind the user to take a selfie.

Bundle key:

- `NSUserNotificationUsageDescription`

Behavior:

- The app schedules dated primary notifications for upcoming reminder days.
- Updating reminder settings reconciles pending requests, and saving a selfie cancels remaining reminders and clears delivered reminder banners for that completed day.
- Clicking a reminder notification opens the app to the Camera tab.

## User-Selected Files

Purpose: write a timelapse MP4 only to the destination selected in the standard Save dialog.

Entitlement:

- `com.apple.security.files.user-selected.read-write`

Behavior:

- Chameo holds security-scoped access only for the duration of the export.
- Video is staged in an item-replacement directory so a failed export does not destroy an existing destination file.

## Library Deletion

Library deletion uses PhotoKit asset deletion. Deleting a photo from Chameo removes the original asset from Photos, not just from the configured album.

Photos may move deleted items to Recently Deleted according to the system Photos behavior.

## Permission Recovery

When access is denied, Chameo shows a status near the action that needs permission and offers a direct System Settings action for Camera, Photos, Location, or Notifications.
