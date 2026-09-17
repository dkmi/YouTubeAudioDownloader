# Third-Party Notices

This project bundles command-line tools in `Sources/YouTubeAudioDownloader/Tools` so the app can run without Homebrew.

## yt-dlp

- Project: https://github.com/yt-dlp/yt-dlp
- Bundled file: `yt-dlp`
- Source binary: `yt-dlp_macos` from the latest GitHub release
- License: Unlicense

## FFmpeg / FFprobe

- Project: https://ffmpeg.org/
- Bundled files: `ffmpeg`, `ffprobe`
- Binary source used here: local Homebrew FFmpeg, patched with relative library paths for app bundling
- Bundled architecture: macOS arm64
- License note: FFmpeg licensing depends on build configuration and enabled codecs. The bundled build reports GPL and version3 configuration flags and includes `libmp3lame`. Review licensing before redistributing this app.
