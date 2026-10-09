# Demo video

> **Status (October 2026): not recorded yet.** There is no `demo.mp4` in this folder. The rest of this page is the template, and the shot list below is a plan, not a description of an existing video.

## Planned shot list

1. What ResortBook is and who it is for (front-desk staff of a small resort).
2. Sign in, then the dashboard on desktop and on a phone-width window.
3. Manage Resort: show a unit type, a unit, a stay type and a rate.
4. Add a reservation step by step, and show the price.
5. Try to add an overlapping reservation and show the **Date Conflict Detected** message.
6. Reservation List, Reservation Details, then Check In, Complete, Cancel and Restore.
7. Calendar.
8. Say honestly what is not done: the double-booking check is only in the app (see [09](09-reservations-and-data-integrity.md)).

**File:** `demo.mp4` in this folder, or the hosted link (see below)
**Length:** aim for 3 to 5 minutes
**Recorded on:** the device you used

## What it shows

A short list, in order, so a viewer can skip to what they need:

- 0:00 what the app is and who it is for
- 0:20 ...
- 1:10 ...

Cover, in this order: the main user journey end to end, anything that only works
on a real device (camera, GPS, sensors), and the thing you are proudest of.

## Getting it into the repo

GitHub **blocks any file over 100 MB** and warns over 50 MB, so compress before
you commit:

```bash
ffmpeg -i raw.mp4 -vcodec libx264 -crf 28 -preset slow \
       -vf scale=-2:720 -acodec aac -b:a 96k demo.mp4
```

Raise `-crf` (28 to 32) or drop to `-2:480` if it is still too large. If it still
does not fit, attach it to a **GitHub Release** or upload it unlisted and link it
here. Never commit the raw capture: git keeps it forever even after you delete
it.

## Before you record

- Real data off the screen: no classmates' names, numbers, faces or messages.
- Notifications off.
- Sensible sample data, not "asdf".
- One unbroken take per feature. Say what you are doing while you do it.
