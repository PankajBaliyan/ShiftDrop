// swift-tools-version:5.9
import PackageDescription

let webp = "/opt/homebrew/opt/webp/lib"
let sharpyuv = "/opt/homebrew/opt/webp/lib"

let package = Package(
    name: "ShiftDrop",
    platforms: [.macOS("13.4")],
    targets: [
        // libwebp (Homebrew) for WebP encoding, which ImageIO can't write. Linked statically.
        .systemLibrary(name: "CWebP", path: "Sources/CWebP"),
        .executableTarget(
            name: "ShiftDrop",
            dependencies: ["CWebP"],
            path: "Sources/ShiftDrop",
            linkerSettings: [
                .unsafeFlags(["-L\(webp)", "\(webp)/libwebp.a", "\(sharpyuv)/libsharpyuv.a"]),
            ]
        ),
    ]
)
