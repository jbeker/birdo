# birdo

A small native macOS and iOS app that shows which birds your [BirdNET-Go](https://github.com/tphakala/birdnet-go) station is hearing right now.

birdo mirrors the "currently hearing" section of the BirdNET-Go dashboard in a compact window you can leave in the corner of your screen. Each bird appears as a card with its photo, common and scientific names, and the microphone that heard it. A play button streams the recorded clip. When the yard is quiet, the app shows a simple "Listening…" state.

![birdo showing three birds currently being heard](Screenshot.png)

## Features

- **Live updates** over the BirdNET-Go server-sent event stream — no polling, no page refreshes
- **One card per active bird**, with photo, names, and audio source; cards animate in and out as birds start and stop singing
- **Clip playback**: hear the actual recording that triggered each detection
- **Connection status** at a glance, with automatic reconnection and backoff
- **Native SwiftUI** throughout — no webview
- **iOS companion** with the same live list, plus a **"Most Heard" widget** for the Home Screen, Lock Screen, and StandBy

## Requirements

- macOS 26 or iOS 26 or later
- A running [BirdNET-Go](https://github.com/tphakala/birdnet-go) instance reachable from your device (v2 API)

## Getting started

1. Open `birdo.xcodeproj` in Xcode 26 or later.
2. Build and run (⌘R).
3. On first launch, enter your BirdNET-Go server URL. birdo verifies the server answers before saving.

Change the server later in **Settings** (⌘,); the app reconnects immediately.

### iOS

The `birdoiOS` scheme builds the iPhone and iPad app together with its widget extension. The app itself works like the Mac version while it is open. Because iOS does not let an app keep the event stream open in the background, the widget takes a different approach:

- **Most Heard** shows the species detected most often in a trailing window (10, 15, 30, or 60 minutes; default 15) and refreshes on roughly the same cadence. The system decides the exact refresh time, so the widget shows the time its data was fetched.
- Medium and large sizes list the runners-up; Lock Screen sizes show the top bird and its count.
- When the window is quiet, the widget shows the last bird heard and when. When the server is unreachable, it keeps the last result and marks it as stale.
- The window length is set in the app's Settings and can be overridden per widget by long-pressing it and choosing **Edit Widget**.

The widget reads the server URL from an App Group shared with the app, so add the widget after connecting the app once.

## How it works

birdo talks to five BirdNET-Go v2 API endpoints:

| Endpoint | Purpose |
|---|---|
| `GET /api/v2/detections/stream` | SSE stream; `pending` events carry the currently-heard birds |
| `GET /api/v2/media/image/{species}` | Species photo |
| `GET /api/v2/audio/{id}` | Recorded clip for a detection |
| `GET /api/v2/detections/recent` | Seeds clip IDs at launch |
| `GET /api/v2/detections?queryType=hourly` | Widget: detections for the hours covering its window |

The Mac app is sandboxed with only the outgoing-network entitlement; the iOS app and widget share an App Group for the server URL and cached species photos. Bird photos come from your BirdNET-Go server, which sources them from providers such as [Avicommons](https://avicommons.org); hover over a photo to see its credit.

## Tests

`sharedTests` covers the widget's window and ranking logic without a server:

```sh
xcodebuild -project birdo.xcodeproj -scheme sharedTests -destination 'platform=macOS' test
```

## License

birdo is licensed under the GNU Affero General Public License v3.0. See [LICENSE](LICENSE) for the full text.
