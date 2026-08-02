# Chameo

Chameo supports a daily photo practice through independent apps that use a dedicated Photos album as their shared record.

## Language

**Chameo**:
A photo in the Chameo album that has a Photos creation time and is therefore part of the daily photo practice. Undated photos and non-photo assets in matching albums are ignored.
_Avoid_: Selfie, capture

**Pending Chameo**:
The single photo awaiting an explicit Save or Retake decision in the mobile app. It is not part of the Chameo album and does not contribute to daily completion.
_Avoid_: Draft, autosaved Chameo

**Capture location**:
The optional location sampled when a photo is taken. If it is unavailable at capture time, the Chameo has no location; a location obtained later is never substituted.
_Avoid_: Save location, current location

**Chameo album**:
The logical album containing the Chameos visible to both the Mac app and the mobile app. It comprises every Photos album whose title exactly matches the configured album name and is the only state shared between the apps.
_Avoid_: Shared database, synced app state

**Daily completion**:
The state reached when a practice day contains at least one Chameo. A completed day may contain multiple Chameos.
_Avoid_: Daily photo, unique capture

**Practice day**:
The calendar day obtained by interpreting a Chameo's Photos creation time in the viewing device's current time zone. A Chameo near midnight may belong to a different practice day after the device changes time zone.
_Avoid_: Capture day, fixed photo date

**Delete a Chameo**:
Delete the original photo asset from Photos, including every album and synced device. It does not mean removing only the asset's membership in the Chameo album.
_Avoid_: Remove from album, hide

**Timelapse**:
A video generated from every eligible Chameo in chronological order. It is produced only when every source photo is available; a timelapse is an export, not a Chameo, and never belongs to the Chameo album.
_Avoid_: Chameo video, album item

**Mac app**:
The standalone macOS Chameo application. It does not require the mobile app.
_Avoid_: Desktop host, primary app

**Mobile app**:
The standalone iOS and iPadOS Chameo application. It does not require the Mac app.
_Avoid_: Companion app, mobile client
