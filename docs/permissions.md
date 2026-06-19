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
- Library location names are reverse-geocoded from `PHAsset.location`.

## Notifications

Purpose: remind the user to take a selfie.

Bundle key:

- `NSUserNotificationUsageDescription`

Behavior:

- The app schedules one stable primary notification request and optional hourly follow-ups for upcoming reminder days.
- Updating reminder settings replaces prior pending requests, and saving a selfie cancels the rest of that day's follow-ups.
- Clicking a reminder notification opens the app to the Camera tab.

## Library Deletion

Library deletion uses PhotoKit asset deletion. Deleting a photo from Chameo removes the original asset from Photos, not just from the configured album.

Photos may move deleted items to Recently Deleted according to the system Photos behavior.

## Permission Recovery

When access is denied, Chameo shows a status near the action that needs permission and offers a direct System Settings action for Camera, Photos, Location, or Notifications.
