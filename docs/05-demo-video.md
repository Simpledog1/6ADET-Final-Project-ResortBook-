# Demo video

> **Status (9 October 2026): recorded, compressed, ready to upload, not uploaded yet.**
>
> - **Original:** `ResortBook_Demo_Video.mp4`, 5 min 51 s, 1920 × 1080 at 30 fps, 538 MB. Kept locally, ignored by Git (over GitHub's 100 MB limit).
> - **Compressed:** `ResortBook_Demo_Video_Compressed.mp4`, 9.7 MB, 1280 × 720 at 30 fps, same length and frame count. Made with `ffmpeg -i ResortBook_Demo_Video.mp4 -map 0:v:0 -map 0:a:0 -c:v libx264 -crf 28 -preset slow -vf "scale=-2:720" -c:a aac -b:a 96k -movflags +faststart ResortBook_Demo_Video_Compressed.mp4`. Checked: no decode errors, audio present in the beginning, middle and end, and UI text readable in frames from each part.
> - **Not committed:** the recording shows my webcam, so it will be hosted as an unlisted video or a GitHub Release attachment, and the link will go in the [README](../README.md#video-demonstration).
>
> The shot list below is the plan I made before recording. I have not checked it against the final recording, and the rest of this page is the course template.

## Planned shot list

1. What ResortBook is and who it is for (front-desk staff of a small resort).
2. Sign in, then the dashboard on desktop and on a phone-width window.
3. Manage Resort: show a unit type, a unit, a stay type and a rate.
4. Add a reservation step by step, and show the price.
5. Reservation List, Reservation Details, then Check In, Complete, Cancel and Restore.
6. Calendar.
7. Say honestly what is not done: the double-booking check is only in the app (see [09](09-reservations-and-data-integrity.md)).

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
