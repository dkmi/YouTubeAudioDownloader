#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TOOLS_DIR="$PROJECT_DIR/Sources/YouTubeAudioDownloader/Tools"
DOWNLOAD_DIR="$PROJECT_DIR/.tool-downloads"

mkdir -p "$TOOLS_DIR" "$DOWNLOAD_DIR"

#if [[ "$(uname -m)" != "x86_64" ]]; then
#  echo "This installer is for Intel Macs only. Current architecture: $(uname -m)"
#  exit 1
#fi

echo "Downloading universal yt-dlp..."
curl -L --fail -o "$TOOLS_DIR/yt-dlp" \
  "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_macos"

echo "Downloading Intel ffmpeg/ffprobe..."
if curl -L --fail -o "$DOWNLOAD_DIR/ffmpeg-macos-x64.tar.gz" \
  "https://github.com/vanloctech/ffmpeg-macos/releases/latest/download/ffmpeg-macos-x64.tar.gz"; then
  mkdir -p "$DOWNLOAD_DIR/ffmpeg-x64"
  tar -xzf "$DOWNLOAD_DIR/ffmpeg-macos-x64.tar.gz" -C "$DOWNLOAD_DIR/ffmpeg-x64"
  find "$DOWNLOAD_DIR/ffmpeg-x64" -type f -name ffmpeg -exec cp {} "$TOOLS_DIR/ffmpeg" \;
  find "$DOWNLOAD_DIR/ffmpeg-x64" -type f -name ffprobe -exec cp {} "$TOOLS_DIR/ffprobe" \;
else
  echo "Primary download failed. Trying fallback FFmpeg build server..."
  curl -L --fail -o "$DOWNLOAD_DIR/ffmpeg.zip" \
    "https://ffmpeg.martin-riedl.de/download/macos/amd64/1785871427_9.0/ffmpeg.zip"
  curl -L --fail -o "$DOWNLOAD_DIR/ffprobe.zip" \
    "https://ffmpeg.martin-riedl.de/download/macos/amd64/1785871427_9.0/ffprobe.zip"
  ditto -x -k "$DOWNLOAD_DIR/ffmpeg.zip" "$DOWNLOAD_DIR/ffmpeg"
  ditto -x -k "$DOWNLOAD_DIR/ffprobe.zip" "$DOWNLOAD_DIR/ffprobe"
  find "$DOWNLOAD_DIR/ffmpeg" -type f -name ffmpeg -exec cp {} "$TOOLS_DIR/ffmpeg" \;
  find "$DOWNLOAD_DIR/ffprobe" -type f -name ffprobe -exec cp {} "$TOOLS_DIR/ffprobe" \;
fi

chmod 755 "$TOOLS_DIR/yt-dlp" "$TOOLS_DIR/ffmpeg" "$TOOLS_DIR/ffprobe"
xattr -d com.apple.quarantine "$TOOLS_DIR/yt-dlp" "$TOOLS_DIR/ffmpeg" "$TOOLS_DIR/ffprobe" 2>/dev/null || true
codesign --force --sign - --timestamp=none "$TOOLS_DIR/yt-dlp" "$TOOLS_DIR/ffmpeg" "$TOOLS_DIR/ffprobe" 2>/dev/null || true

file "$TOOLS_DIR/yt-dlp" "$TOOLS_DIR/ffmpeg" "$TOOLS_DIR/ffprobe"

echo "Verifying Intel ffmpeg MP3 encoder..."
"$TOOLS_DIR/ffmpeg" -hide_banner -encoders | grep -i libmp3lame >/dev/null

echo "Done. Intel tools are installed in:"
echo "$TOOLS_DIR"
