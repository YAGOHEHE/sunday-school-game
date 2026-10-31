// swift-tools-version:5.9
import PackageDescription

// Layout:
//   JuegosCore  modelos, catálogo (games.json), sesiones, persistencia, generadores. Sin UI. macOS + iOS.
//   JuegosUI    vistas SwiftUI compartidas (sin AppKit directo) para reutilizar en iPadOS.
//   JuegosMac   punto de entrada macOS: ventanas, menús, ventana de proyector.
let package = Package(
    name: "JuegosDominical",
    defaultLocalization: "es",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [
        .library(name: "JuegosCore", targets: ["JuegosCore"]),
        .library(name: "JuegosUI", targets: ["JuegosUI"]),
        .executable(name: "JuegosMac", targets: ["JuegosMac"]),
    ],
    targets: [
        .target(
            name: "JuegosCore",
            path: "Sources/JuegosCore",
            resources: [.copy("Resources/games.json")]
        ),
        .target(
            name: "JuegosUI",
            dependencies: ["JuegosCore"],
            path: "Sources/JuegosUI",
            // Fredoka (SIL OFL 1.1, Google Fonts). Se registra al arrancar en Theme.
            resources: [.copy("Resources/Fonts")]
        ),
        .executableTarget(
            name: "JuegosMac",
            dependencies: ["JuegosCore", "JuegosUI"],
            path: "Sources/JuegosMac"
        ),
        .testTarget(
            name: "JuegosCoreTests",
            dependencies: ["JuegosCore"],
            path: "Tests/JuegosCoreTests"
        ),
    ]
)
