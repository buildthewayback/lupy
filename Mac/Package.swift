// swift-tools-version: 6.0
// Lupy, built WITHOUT Xcode.
//
// The founder's connection made the 8 GB Xcode download cruel; Apple's Command Line
// Tools (free, small, already on his Mac) carry the whole Swift compiler and the macOS
// SDK. This manifest mirrors Mac/project.yml's single target exactly — same sources,
// same defines (LUPY, LUPY_NO_LOCAL_LLM), same strict concurrency, same two packages
// (FluidAudio 0.17.7, local LupyCore) — so `swift build` produces the same binary the
// Xcode project would. scripts/build-no-xcode.sh then assembles the .app bundle by
// hand (Info.plist verbatim from Mac/Resources, menu-bar icon and sounds as loose
// resources) and ad-hoc signs it. Xcode remains the reference build; this is the
// founder's low-data road, and both roads lead to the same pill.
import PackageDescription

let package = Package(
    name: "Lupy",
    platforms: [.macOS(.v15)],
    dependencies: [
        .package(url: "https://github.com/FluidInference/FluidAudio", exact: "0.17.7"),
        .package(path: "../LupyCore"),
    ],
    targets: [
        .executableTarget(
            name: "Lupy",
            dependencies: [
                .product(name: "FluidAudio", package: "FluidAudio"),
                .product(name: "LupyCore", package: "LupyCore"),
            ],
            path: "Sources",
            swiftSettings: [
                .define("LUPY"),
                .define("LUPY_NO_LOCAL_LLM"),
                .unsafeFlags(["-strict-concurrency=complete"]),
            ]
        ),
    ]
)
