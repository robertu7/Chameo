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
- Remove selected photos from the configured album.

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

- The app schedules one stable notification request.
- Updating reminder settings replaces the prior pending request.
- Clicking a reminder notification opens the app to the Camera tab.

## Album Removal

Library removal uses PhotoKit album membership changes. Removing a photo from Chameo does not delete the original asset from Photos or iCloud Photos.

After a removal, the app shows an undo action that adds the original asset back to the configured album.

## Permission Recovery

When access is denied, Chameo shows a status near the action that needs permission and offers a direct System Settings action for Camera, Photos, Location, or Notifications.
