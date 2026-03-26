// swift-tools-version: 5.9
import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "CodableMacro",
    platforms: [.macOS(.v10_15), .iOS(.v15), .tvOS(.v13), .watchOS(.v6)],
    products: [
        .library(
            name: "CodableMacro",
            targets: ["CodableMacro"]
        ),
        .executable(
            name: "CodableMacroClient",
            targets: ["CodableMacroClient"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", "509.1.1"..<"601.0.0")
    ],
    targets: [
        .target(
            name: "CodableMacro",
            dependencies: ["CodableMacroImpl"]
        ),
        .macro(
            name: "CodableMacroImpl",
            dependencies: [
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftParser", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
            ]
        ),
        .executableTarget(
            name: "CodableMacroClient",
            dependencies: ["CodableMacro"]
        ),
        .testTarget(
            name: "CodableMacroTests",
            dependencies: [
                "CodableMacro",
                "CodableMacroImpl",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ]
        ),
    ]
)
