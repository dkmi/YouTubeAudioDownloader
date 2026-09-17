import SwiftUI

#if os(macOS)
import AppKit

@main
struct YouTubeAudioDownloaderApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 720, minHeight: 520)
        }
        .windowStyle(.titleBar)
    }
}

struct ContentView: View {
    @StateObject private var downloader = AudioDownloader()
    @State private var videoURL = ""
    @State private var outputFolder = FileManager.default.urls(for: .musicDirectory, in: .userDomainMask).first!
        .appendingPathComponent("YouTube Downloads", isDirectory: true)
    @State private var selectedFormat = DownloadFormat.m4a

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header

            VStack(alignment: .leading, spacing: 10) {
                Text("YouTube линк")
                    .font(.headline)

                HStack(spacing: 10) {
                    TextField("https://www.youtube.com/watch?v=...", text: $videoURL)
                        .textFieldStyle(.roundedBorder)
                        .disabled(downloader.isRunning)

                    Button {
                        pasteFromClipboard()
                    } label: {
                        Image(systemName: "doc.on.clipboard")
                    }
                    .help("Постави линк от клипборда")
                    .disabled(downloader.isRunning)
                }
            }

            HStack(spacing: 12) {
                Picker("Формат", selection: $selectedFormat) {
                    ForEach(DownloadFormat.allCases) { format in
                        Text(format.label).tag(format)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 360)
                .disabled(downloader.isRunning)

                Button {
                    chooseFolder()
                } label: {
                    Label("Папка", systemImage: "folder")
                }
                .disabled(downloader.isRunning)

                Text(outputFolder.path)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .foregroundStyle(.secondary)

                Spacer()
            }

            HStack(spacing: 12) {
                Button {
                    downloader.start(urlString: videoURL, outputFolder: outputFolder, format: selectedFormat)
                } label: {
                    Label(selectedFormat.actionTitle, systemImage: selectedFormat.actionSystemImage)
                }
                .keyboardShortcut(.return, modifiers: .command)
                .buttonStyle(.borderedProminent)
                .disabled(!canStart)

                Button {
                    downloader.cancel()
                } label: {
                    Label("Спри", systemImage: "stop.circle")
                }
                .disabled(!downloader.isRunning)

                Button {
                    NSWorkspace.shared.open(outputFolder)
                } label: {
                    Label("Отвори папката", systemImage: "arrow.up.right.square")
                }

                Spacer()
            }

            if downloader.isRunning {
                ProgressView()
                    .progressViewStyle(.linear)
            }

            logView
        }
        .padding(24)
        .onAppear {
            ensureOutputFolderExists()
            downloader.checkDependencies()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("YouTube Audio Downloader")
                .font(.largeTitle.bold())

            Text("Сваля аудио или MP4 видео от посочен YouTube линк чрез пакетирани yt-dlp и ffmpeg. Ползвай го само за съдържание, което имаш право да сваляш.")
                .foregroundStyle(.secondary)
        }
    }

    private var logView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Лог")
                    .font(.headline)

                Spacer()

                Button {
                    downloader.clearLog()
                } label: {
                    Image(systemName: "trash")
                }
                .help("Изчисти лога")
                .disabled(downloader.log.isEmpty || downloader.isRunning)
            }

            ScrollViewReader { proxy in
                ScrollView {
                    Text(downloader.log.isEmpty ? "Готово за работа." : downloader.log)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .id("log-bottom")
                        .padding(12)
                }
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                )
                .onChange(of: downloader.log) {
                    proxy.scrollTo("log-bottom", anchor: .bottom)
                }
            }
        }
    }

    private var canStart: Bool {
        !downloader.isRunning && AudioDownloader.isSupportedYouTubeURL(videoURL)
    }

    private func pasteFromClipboard() {
        if let text = NSPasteboard.general.string(forType: .string) {
            videoURL = text.trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = outputFolder

        if panel.runModal() == .OK, let url = panel.url {
            outputFolder = url
            ensureOutputFolderExists()
        }
    }

    private func ensureOutputFolderExists() {
        try? FileManager.default.createDirectory(at: outputFolder, withIntermediateDirectories: true)
    }
}

enum DownloadFormat: String, CaseIterable, Identifiable {
    case m4a
    case mp3
    case opus
    case mp4

    var id: String { rawValue }

    var label: String {
        switch self {
        case .m4a: "M4A"
        case .mp3: "MP3"
        case .opus: "OPUS"
        case .mp4: "MP4 видео"
        }
    }

    var actionTitle: String {
        switch self {
        case .mp4: "Свали видеото"
        default: "Свали аудиото"
        }
    }

    var actionSystemImage: String {
        switch self {
        case .mp4: "film.circle.fill"
        default: "arrow.down.circle.fill"
        }
    }
}

@MainActor
final class AudioDownloader: ObservableObject {
    @Published var isRunning = false
    @Published var log = ""

    private var process: Process?
    private var bundledToolsFolder: URL? {
        Bundle.main.resourceURL?.appendingPathComponent("Tools", isDirectory: true)
    }

    private var executableCandidates: [String] {
        candidatePaths(for: "yt-dlp") + [
            "/opt/homebrew/bin/yt-dlp",
            "/usr/local/bin/yt-dlp",
            "/usr/bin/yt-dlp"
        ]
    }

    private var ffmpegCandidates: [String] {
        candidatePaths(for: "ffmpeg") + [
            "/opt/homebrew/bin/ffmpeg",
            "/usr/local/bin/ffmpeg",
            "/usr/bin/ffmpeg"
        ]
    }

    func checkDependencies() {
        append("Проверявам зависимостите...")

        guard findExecutable(named: "yt-dlp", candidates: executableCandidates) != nil else {
            append("Липсва yt-dlp. Инсталирай с: brew install yt-dlp")
            append("За конвертиране към MP3 е нужен и ffmpeg: brew install ffmpeg")
            return
        }

        append("yt-dlp е намерен.")

        if let ffmpegPath = findExecutable(named: "ffmpeg", candidates: ffmpegCandidates) {
            append("ffmpeg е намерен: \(ffmpegPath)")
            if ffmpegSupportsMP3Encoding(ffmpegPath, logFailure: false) {
                append("MP3 encoder е наличен.")
            } else if findFFmpegPath(for: .mp3) != nil {
                append("Bundled ffmpeg няма MP3 encoder; ще използвам друг намерен ffmpeg за MP3.")
            } else {
                append("MP3 encoder не е намерен. MP3 форматът ще иска ffmpeg с libmp3lame.")
            }
        } else {
            append("ffmpeg не е намерен. Инсталирай го с: brew install ffmpeg")
        }
    }

    func start(urlString: String, outputFolder: URL, format: DownloadFormat) {
        guard !isRunning else { return }

        let trimmedURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.isSupportedYouTubeURL(trimmedURL) else {
            append("Моля, постави валиден YouTube линк.")
            return
        }

        guard let ytDlpPath = findExecutable(named: "yt-dlp", candidates: executableCandidates) else {
            append("Не намирам yt-dlp. Инсталирай го с: brew install yt-dlp")
            return
        }

        guard let ffmpegPath = findFFmpegPath(for: format) else {
            if format == .mp3 {
                append("Не намирам Intel ffmpeg с MP3 encoder. Пусни ./Scripts/install-intel-tools.sh в папката на проекта, после build-ни наново.")
            } else {
                append("Не намирам Intel ffmpeg/ffprobe. Пусни ./Scripts/install-intel-tools.sh в папката на проекта, после build-ни наново.")
            }
            return
        }

        try? FileManager.default.createDirectory(at: outputFolder, withIntermediateDirectories: true)

        let outputTemplate = outputFolder
            .appendingPathComponent("%(title).200s [%(id)s].%(ext)s")
            .path

        let ffmpegFolder = URL(fileURLWithPath: ffmpegPath).deletingLastPathComponent().path

        var arguments = [
            "--newline",
            "--ignore-errors",
            "--no-playlist",
            "--ffmpeg-location", ffmpegFolder,
            "-o", outputTemplate
        ]

        switch format {
        case .m4a:
            arguments += ["-f", "bestaudio/best", "--extract-audio", "--audio-format", "m4a"]
        case .mp3:
            arguments += ["-f", "bestaudio/best", "--extract-audio", "--audio-format", "mp3", "--audio-quality", "0"]
        case .opus:
            arguments += ["-f", "bestaudio/best", "--extract-audio", "--audio-format", "opus"]
        case .mp4:
            arguments += [
                "-f", "bv*[ext=mp4][vcodec^=avc1]+ba[ext=m4a]/b[ext=mp4][vcodec^=avc1]/bv*[vcodec^=avc1]+ba/b[ext=mp4]",
                "--merge-output-format", "mp4",
                "--remux-video", "mp4"
            ]
        }

        arguments.append(trimmedURL)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: ytDlpPath)
        process.arguments = arguments
        process.environment = processEnvironment(extraToolFolder: ffmpegFolder)

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let chunk = String(data: data, encoding: .utf8) else { return }

            Task { @MainActor in
                self?.append(chunk.trimmingCharacters(in: .newlines))
            }
        }

        process.terminationHandler = { [weak self] finishedProcess in
            Task { @MainActor in
                pipe.fileHandleForReading.readabilityHandler = nil
                self?.isRunning = false
                self?.process = nil

                if finishedProcess.terminationStatus == 0 {
                    self?.append("Готово. Файлът е записан в: \(outputFolder.path)")
                } else {
                    self?.append("Процесът приключи с код \(finishedProcess.terminationStatus).")
                }
            }
        }

        do {
            clearLog()
            append("Стартирам сваляне...")
            self.process = process
            isRunning = true
            try process.run()
        } catch {
            isRunning = false
            self.process = nil
            append("Не успях да стартирам yt-dlp: \(error.localizedDescription)")
        }
    }

    func cancel() {
        process?.terminate()
        append("Свалянето е спряно.")
    }

    func clearLog() {
        log = ""
    }

    private func append(_ message: String) {
        guard !message.isEmpty else { return }

        if log.isEmpty {
            log = message
        } else {
            log += "\n\(message)"
        }
    }

    private func findExecutable(named name: String, candidates: [String]) -> String? {
        for path in candidates where FileManager.default.isExecutableFile(atPath: path) {
            return path
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["which", name]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return nil
        }

        guard process.terminationStatus == 0 else { return nil }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let path = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let path, !path.isEmpty else { return nil }
        return path
    }

    private func findFFmpegPath(for format: DownloadFormat) -> String? {
        guard format == .mp3 else {
            return findExecutable(named: "ffmpeg", candidates: ffmpegCandidates)
        }

        let candidates = ffmpegCandidates
        let firstCandidate = candidates.first
        for candidate in candidates where FileManager.default.isExecutableFile(atPath: candidate) {
            let shouldLogFailure = firstCandidate.map { candidate == $0 } ?? false
            if ffmpegSupportsMP3Encoding(candidate, logFailure: shouldLogFailure) {
                return candidate
            }
        }

        guard let ffmpegPath = findExecutable(named: "ffmpeg", candidates: []) else {
            return nil
        }

        return ffmpegSupportsMP3Encoding(ffmpegPath, logFailure: true) ? ffmpegPath : nil
    }

    private func ffmpegSupportsMP3Encoding(_ ffmpegPath: String, logFailure: Bool) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: ffmpegPath)
        process.arguments = ["-hide_banner", "-encoders"]
        process.environment = processEnvironment(extraToolFolder: URL(fileURLWithPath: ffmpegPath).deletingLastPathComponent().path)

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            if logFailure {
                append("Не успях да проверя ffmpeg: \(error.localizedDescription)")
            }
            return false
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        guard process.terminationStatus == 0 else {
            if logFailure {
                append("ffmpeg проверката не мина: \(shortLog(output))")
            }
            return false
        }

        let supportsMP3 = output.contains("libmp3lame") || output.contains(" mp3 ")
        if !supportsMP3 && logFailure {
            append("ffmpeg работи, но не показва MP3 encoder: \(ffmpegPath)")
        }
        return supportsMP3
    }

    private func shortLog(_ output: String) -> String {
        output
            .split(separator: "\n")
            .suffix(4)
            .joined(separator: "\n")
    }

    private func candidatePaths(for executable: String) -> [String] {
        guard let bundledToolsFolder else { return [] }

        return [
            bundledToolsFolder.appendingPathComponent(executable).path,
            bundledToolsFolder.appendingPathComponent("bin").appendingPathComponent(executable).path,
            bundledToolsFolder.appendingPathComponent("yt-dlp").appendingPathComponent(executable).path,
            bundledToolsFolder.appendingPathComponent("ffmpeg").appendingPathComponent("bin").appendingPathComponent(executable).path
        ]
    }

    private func processEnvironment(extraToolFolder: String) -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        var pathEntries = [extraToolFolder]

        if let bundledToolsFolder {
            pathEntries.append(contentsOf: [
                bundledToolsFolder.path,
                bundledToolsFolder.appendingPathComponent("bin").path,
                bundledToolsFolder.appendingPathComponent("yt-dlp").path,
                bundledToolsFolder.appendingPathComponent("ffmpeg").appendingPathComponent("bin").path
            ])
        }

        pathEntries.append(environment["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin")
        environment["PATH"] = pathEntries.joined(separator: ":")
        return environment
    }

    static func isSupportedYouTubeURL(_ urlString: String) -> Bool {
        let trimmedURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmedURL), let host = url.host?.lowercased() else {
            return false
        }

        return host == "youtube.com"
            || host.hasSuffix(".youtube.com")
            || host == "youtu.be"
            || host == "music.youtube.com"
    }
}
#else
#error("YouTubeAudioDownloader is a macOS app. In Xcode, select the My Mac destination instead of an iPhone/iPad destination.")
#endif
