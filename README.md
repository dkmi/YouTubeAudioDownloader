# YouTubeAudioDownloaderBundledIntel

A small macOS SwiftUI app for Xcode that downloads audio or MP4 video from a YouTube URL.

This version bundles the required external tools within the project:

- `yt-dlp`
- `ffmpeg`
- `ffprobe`

## Requirements

- macOS 14+
- Xcode 15+
- Intel Mac

## Getting Started

1. Open the project directory in Terminal.
2. Run `./Scripts/install-intel-tools.sh`.
3. Open `YouTubeAudioDownloader.xcodeproj` in Xcode.
4. Select the `YouTubeAudioDownloader` scheme.
5. Select `My Mac` as the run destination in the top toolbar, rather than an iPhone or iPad simulator.
6. Click Run.
7. Paste a YouTube URL, choose a format, and click the download audio or download video button. The app's interface is in Bulgarian.

Files are saved to `~/Music/YouTube Downloads` by default.

## Building a Standalone App

Run the following in Terminal:

```bash
./Scripts/build-release.sh
```

The resulting `.app` bundle will be located at:

```text
build/Build/Products/Release/YouTubeAudioDownloader.app
```

If Xcode previously built an older version without `Tools/lib`, clear the project's `DerivedData` or use the script above, which copies and signs the tools on every build.

## Bundled Tools

The tools are located in:

```text
Sources/YouTubeAudioDownloader/Tools
```

This bundled version targets Intel macOS (`x86_64`). The directory initially contains a universal `yt-dlp` binary and placeholder `ffmpeg/ffprobe` scripts; `./Scripts/install-intel-tools.sh` downloads the correct Intel binaries.

The Intel `ffmpeg` build must include `libmp3lame` for MP3 mode to work.

MP4 mode prefers H.264 (`avc1`) video and M4A/AAC audio for QuickTime compatibility. VLC can also play MP4 files containing VP9/AV1 video, but QuickTime often plays only the audio in those files.

## Note

Use the app only for content you have permission to download, such as your own content, royalty-free material, or videos authorized for offline use.

If you plan to distribute the app beyond personal use, review `THIRD_PARTY_NOTICES.md`, as the FFmpeg build has important licensing requirements.
