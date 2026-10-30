// swift-tools-version: 5.9
import Foundation
import PackageDescription

// Embed Info.plist in the binary so `swift run` still has the Apple Events usage text.
let infoPlist = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .appendingPathComponent("Resources/Info.plist").path

let package = Package(
    name: "Perch",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Perch",
            path: "Sources/Perch",
            linkerSettings: [
                .unsafeFlags(["-Xlinker", "-sectcreate", "-Xlinker", "__TEXT",
                              "-Xlinker", "__info_plist", "-Xlinker", infoPlist])
            ]
        )
    ]
)
