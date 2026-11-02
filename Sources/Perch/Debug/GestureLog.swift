import AppKit

/// Writes trackpad gesture events to ~/Library/Logs/Perch/gestures.log, only while
/// `defaults write com.merterbil.perch logGestures -bool YES` is set. For finding out
/// which gestures actually reach Perch.
enum GestureLog {
    static var isOn: Bool { UserDefaults.standard.bool(forKey: "logGestures") }

    private static let url: URL = {
        let folder = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/Perch")
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("gestures.log")
    }()

    static let gestureTypes: Set<NSEvent.EventType> = [.magnify, .smartMagnify, .rotate, .swipe, .beginGesture, .endGesture, .gesture]

    static func write(_ line: String) {
        guard isOn else { return }
        let stamp = ISO8601DateFormatter().string(from: Date())
        let data = Data("\(stamp) \(line)\n".utf8)
        if let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(data)
            try? handle.close()
        } else {
            try? data.write(to: url)
        }
    }

    static func describe(_ event: NSEvent, from source: String) -> String {
        var text = "\(source) type=\(event.type.rawValue)"
        if event.type == .magnify { text += " magnification=\(event.magnification) phase=\(event.phase.rawValue)" }
        let mouse = NSEvent.mouseLocation
        text += " mouse=\(Int(mouse.x)),\(Int(mouse.y)) window=\(event.window?.className ?? "none")"
        return text
    }
}
