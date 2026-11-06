// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "LoongToDo",
    platforms: [.macOS(.v14)],
    products: [.executable(name: "LoongToDo", targets: ["LoongToDo"])],
    targets: [
        .target(name: "TodoCore"),
        .executableTarget(name: "LoongToDo", dependencies: ["TodoCore"]),
        .executableTarget(name: "TodoCoreChecks", dependencies: ["TodoCore"], path: "Tests/TodoCoreTests")
    ],
    swiftLanguageModes: [.v5]
)
