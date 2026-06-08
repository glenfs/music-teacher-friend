# Clefira Website

Static marketing and download site for Clefira.

## Pages

- `index.html` — landing page
- `app.html` — app details and features
- `pricing.html` — Student/Teacher edition sale positioning
- `about.html` — Clefira company information
- `privacy.html` — privacy policy
- `terms.html` — end-user license terms
- `download.html` — Windows download page

## Windows download package

The Godot Windows build requires both files in the same folder:

- `ClefiraStudent.exe`
- `ClefiraStudent.pck`

The public download button currently says "Coming soon". When downloads are enabled, point the button to:

`downloads/windows/ClefiraStudent-Windows-v1.0.0.zip`

Rebuild that ZIP after every Windows export.

## Before public launch

- Replace `contact@clefira.app` if the official support inbox is different.
- Connect the Teacher Edition sale button to the selected checkout provider.
- Add code signing or a trusted distribution channel to reduce Windows SmartScreen friction.
