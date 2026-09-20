<div align="center">

# DuoFold

**Make your MacBook desktop feel physical.**

DuoFold brings a foldable-screen illusion to MacBook: as the lid moves, your
local desktop snapshot tilts, softens, and fades through a GPU-rendered overlay.

</div>

## Features

- Native Swift, AppKit, Metal, ScreenCaptureKit, and IOKit implementation.
- Real-time response to compatible built-in lid-angle sensors.
- Local-only desktop capture; frames are kept in memory and never uploaded.
- Adjustable perspective, blur, and fold behavior.
- Seven selectable fold styles: Duo, Ghost, Roll, Shutter, Flex, Iris, and Replay.
- Menu bar controls with pause, resume, and screen permission status.
- Optional local attention mode that reacts when you look away from the screen.
- Supports English and Simplified Chinese.

## Requirements

- macOS 14 or later.
- A MacBook with a compatible built-in lid-angle sensor.
- Screen Recording permission.
- Camera permission is only required when Attention mode is enabled.

## Build

Requires Swift 6/Xcode command-line tools:

```sh
./build.sh
./build.sh --run
```

The app is written for local development and uses an ad-hoc signature by
default. macOS may ask for Screen Recording permission again after rebuilding.

### Screen Recording troubleshooting

macOS associates Screen Recording permission with the exact app bundle and its
code signature. For local ad-hoc builds, use one stable path and launch that
copy consistently:

```sh
sudo tccutil reset ScreenCapture com.duofold.app
rm -rf /Applications/DuoFold.app
cp -R build/DuoFold.app /Applications/DuoFold.app
open /Applications/DuoFold.app
```

Enable **DuoFold.app** in **System Settings → Privacy & Security → Screen &
System Audio Recording**, quit DuoFold completely, and open the same
`/Applications/DuoFold.app` again. Do not switch between the build folder and
Applications. A stable Apple Development signing identity avoids this reset;
pass it to the build with `SIGN_IDENTITY="Apple Development: ..." ./build.sh`.

## Privacy

DuoFold does not use an account, analytics, network service, microphone, or
remote processing. Desktop frames stay in bounded memory for the visual effect.

## License and attribution

DuoFold is distributed under Apache-2.0. See [LICENSE](LICENSE), [NOTICE](NOTICE),
and [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for license information.

## Fold effects

DuoFold's Duo, Roll, Shutter, Flex, Iris, and Ghost modes use the analytic
inverse maps and stable shader index contract adapted from
[DhananjayBhosale/MacDuo](https://github.com/DhananjayBhosale/MacDuo). The
existing screen capture and lid projection pipeline remains DuoFold code, so
the reference effects can run on live ScreenCaptureKit frames as well as held
snapshots.
