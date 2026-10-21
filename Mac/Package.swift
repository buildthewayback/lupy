// swift-tools-version: 6.0
// Lupy, built WITHOUT Xcode.
//
// The founder's connection made the 8 GB Xcode download cruel; Apple's Command Line
// Tools (free, small, already on his Mac) carry the whole Swift compiler and the macOS
// SDK. This manifest mirrors Mac/project.yml's single target — same sources, same
// defines (LUPY, LUPY_NO_LOCAL_LLM), same two packages (FluidAudio 0.17.7, local
// LupyCore). One claimed mirror was FALSE and cost three founder runs: an earlier
// session forced `-strict-concurrency=complete` in Swift 6 language mode, while the
// Xcode road (SWIFT_VERSION 6.0, no strict-concurrency setting) compiles this code
// in Swift 5 language mode with default checking — the personality Louis Raillé
// shipped product was built under. The founder's reports listed ~30 hard errors in
// that shipped code (NotificationCenter closures touching @MainActor state they in
// practice only ever reach on the main queue). So: .v5 mode, no strict flag — the
// same water this code already swims in. Re-migrating to Swift 6 mode is honest
// future work for a day when a real compiler is in the loop (see compile-check.yml). scripts/build-no-xcode.sh then assembles the .app bundle by
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
                .swiftLanguageMode(.v5),
            ]
        ),
    ]
)
