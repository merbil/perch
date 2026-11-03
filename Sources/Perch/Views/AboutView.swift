import AppKit
import SwiftUI

/// The About popup: what Perch is, its version, links, Ko-fi and the release notes.
struct AboutView: View {
    @Environment(Preferences.self) private var prefs
    @Environment(PlayerModel.self) private var player
    var onClose: () -> Void

    static let website = URL(string: "https://merterbil.com/perch/")!
    static let story = URL(string: "https://merterbil.com/projects/perch/")!
    static let github = URL(string: "https://github.com/merbil/perch")!
    static let kofi = URL(string: "https://ko-fi.com/merterbil")!

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 14) {
                AppIconView(size: 84).frame(width: 84, height: 84)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Perch").titleStyle(24)
                    Text(versionText).font(.perch(12, .bold)).foregroundStyle(Palette.muted)
                    Text("A tiny Spotify player in your Mac's menu bar.")
                        .font(.perch(13, .semibold)).foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4)
                    Text("Works with Spotify. Apple Music is coming.")
                        .font(.perch(12, .bold)).foregroundStyle(Palette.muted)
                }
                Spacer(minLength: 0)
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .black))
                        .foregroundStyle(Palette.ink)
                        .frame(width: 26, height: 26)
                        .background(RoundedRectangle(cornerRadius: 8).fill(Palette.paper))
                        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Palette.ink, lineWidth: 2))
                        .contentShape(Rectangle())
                }
                .buttonStyle(ArcadeButtonStyle(shape: AnyShape(RoundedRectangle(cornerRadius: 8)), shadow: 2))
                .accessibilityLabel("Close")
                .keyboardShortcut(.cancelAction)
            }

            HStack(spacing: 8) {
                LinkButton(symbol: "globe", title: "Website", url: Self.website)
                LinkButton(symbol: "text.book.closed", title: "Why I built it", url: Self.story)
                LinkButton(symbol: "chevron.left.forwardslash.chevron.right", title: "GitHub", url: Self.github)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("WHAT'S NEW").font(.perch(11, .heavy)).foregroundStyle(Palette.muted).tracking(0.6)
                ScrollView {
                    ReleaseNotesText(notes: ReleaseNotes.load())
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 210)
                .background(RoundedRectangle(cornerRadius: 12).fill(Palette.field))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Palette.ink, lineWidth: 2))
            }

            HStack(spacing: 12) {
                Button { NSWorkspace.shared.open(Self.kofi) } label: {
                    HStack(spacing: 7) {
                        Image(systemName: "heart.fill").font(.system(size: 12, weight: .black))
                        Text("SUPPORT ON KO-FI").font(.perch(12))
                    }
                    .foregroundStyle(Palette.onAccent)
                    .padding(.horizontal, 16)
                    .frame(height: 36)
                    .background(Capsule().fill(prefs.accentColor(for: player)))
                    .overlay(Capsule().strokeBorder(Palette.ink, lineWidth: 3))
                    .contentShape(Capsule())
                }
                .buttonStyle(ArcadeButtonStyle())
                Text("Perch is free. If you like it, a coffee helps.")
                    .font(.perch(12, .semibold)).foregroundStyle(Palette.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text("Made by Mert Erbil · MIT license · Not affiliated with Spotify")
                .font(.perch(11, .bold)).foregroundStyle(Palette.muted)
        }
        .padding(20)
        .frame(width: 428)
        .surface(radius: 22)
        .padding(.trailing, 6)
        .padding(.bottom, 6)
    }

    private var versionText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "dev"
        let build = info?["CFBundleVersion"] as? String ?? "0"
        return "Version \(version) (build \(build))"
    }
}

private struct LinkButton: View {
    var symbol: String
    var title: String
    var url: URL

    var body: some View {
        Button { NSWorkspace.shared.open(url) } label: {
            HStack(spacing: 5) {
                Image(systemName: symbol).font(.system(size: 10, weight: .black))
                Text(title.uppercased()).font(.perch(11)).lineLimit(1).fixedSize()
            }
            .foregroundStyle(Palette.ink)
            .frame(maxWidth: .infinity)
            .frame(height: 32)
            .background(RoundedRectangle(cornerRadius: 10).fill(Palette.paper))
            .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Palette.ink, lineWidth: 2))
            .contentShape(Rectangle())
        }
        .buttonStyle(ArcadeButtonStyle(shape: AnyShape(RoundedRectangle(cornerRadius: 10)), shadow: 2))
        .help(url.absoluteString)
    }
}

/// RELEASE_NOTES.md, bundled with the app (or read from the repo in debug runs).
enum ReleaseNotes {
    static func load() -> String {
        if let url = Bundle.main.url(forResource: "RELEASE_NOTES", withExtension: "md"),
           let text = try? String(contentsOf: url, encoding: .utf8) {
            return text
        }
        return (try? String(contentsOfFile: "RELEASE_NOTES.md", encoding: .utf8)) ?? "Release notes are on GitHub."
    }
}

/// A small Markdown reader for the release notes: versions, sections and bullets.
struct ReleaseNotesText: View {
    var notes: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                if line.hasPrefix("## ") {
                    Text(String(line.dropFirst(3)))
                        .font(.perch(14)).foregroundStyle(Palette.ink)
                        .padding(.top, 6)
                } else if line.hasPrefix("### ") {
                    Text(String(line.dropFirst(4)).uppercased())
                        .font(.perch(10, .heavy)).foregroundStyle(Palette.muted).tracking(0.5)
                        .padding(.top, 2)
                } else if line.hasPrefix("- ") {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("•").font(.perch(12, .bold))
                        Text(inline(String(line.dropFirst(2))))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .font(.perch(12, .semibold))
                    .foregroundStyle(Palette.ink)
                } else {
                    Text(inline(line)).font(.perch(12, .semibold)).foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    /// Lines worth showing: everything after the file's own title, without blank lines.
    private var lines: [String] {
        notes.components(separatedBy: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty && !$0.hasPrefix("# ") }
    }

    private func inline(_ text: String) -> AttributedString {
        (try? AttributedString(markdown: text)) ?? AttributedString(text)
    }
}
