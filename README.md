# YouTubeAudioDownloaderBundledIntel

Малко macOS SwiftUI приложение за Xcode, което сваля аудио или MP4 видео от YouTube линк.

Този вариант пакетира нужните външни инструменти вътре в проекта:

- `yt-dlp`
- `ffmpeg`
- `ffprobe`

## Изисквания

- macOS 14+
- Xcode 15+
- Intel Mac

## Стартиране

1. В Terminal отвори папката на проекта.
2. Пусни `./Scripts/install-intel-tools.sh`.
3. Отвори `YouTubeAudioDownloader.xcodeproj` в Xcode.
4. Избери схемата `YouTubeAudioDownloader`.
5. В горната лента избери destination `My Mac`, не iPhone/iPad симулатор.
6. Натисни Run.
7. Постави YouTube линк, избери формат и натисни `Свали аудиото` или `Свали видеото`.

Файловете по подразбиране се записват в `~/Music/YouTube Downloads`.

## Build на самостоятелна app версия

От Terminal:

```bash
./Scripts/build-release.sh
```

Готовият `.app` bundle ще бъде в:

```text
build/Build/Products/Release/YouTubeAudioDownloader.app
```

Ако преди това Xcode е build-нал стара версия без `Tools/lib`, изчисти `DerivedData` за проекта или използвай горния script, защото той копира и подписва tools при всяко build-ване.

## Пакетирани инструменти

Инструментите са в:

```text
Sources/YouTubeAudioDownloader/Tools
```

Този bundled вариант е за Intel macOS (`x86_64`). Папката първоначално съдържа universal `yt-dlp` и placeholder `ffmpeg/ffprobe`; `./Scripts/install-intel-tools.sh` сваля правилните Intel binaries.

Intel `ffmpeg` build-ът трябва да съдържа `libmp3lame`, за да работи MP3 режимът.

MP4 режимът предпочита H.264 (`avc1`) видео и M4A/AAC аудио, за да се отваря коректно с QuickTime. VLC може да пуска и MP4 файлове с VP9/AV1 видео, но QuickTime често възпроизвежда само аудиото при такива файлове.

## Бележка

Ползвай приложението само за съдържание, което имаш право да сваляш, например твое съдържание, royalty-free материали или клипове с разрешение за офлайн употреба.

Ако ще разпространяваш приложението извън лична употреба, прегледай `THIRD_PARTY_NOTICES.md`, защото FFmpeg build-ът има важни licensing условия.
