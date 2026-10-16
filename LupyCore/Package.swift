// swift-tools-version: 6.0
// LupyCore — Lupy's assistant core: durable journal state, planning, policy/approvals,
// verification, providers, scheduler, computer-control rules. Standard library only, so the
// same sources are also compiled and tested outside Xcode (scripts/test-core.sh, WebAssembly
// in the sandbox). The Mac app links it as a local package (Mac/project.yml).
import PackageDescription

let package = Package(
    name: "LupyCore",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "LupyCore", targets: ["LupyCore"]),
    ],
    targets: [
        .target(name: "LupyCore", path: "Sources/LupyCore"),
    ]
)
