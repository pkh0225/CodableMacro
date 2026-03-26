// swift-tools-version: 5.9
import PackageDescription
import CompilerPluginSupport

let package = Package(
    name: "CodableMacro",
    platforms: [.iOS(.v15), .macOS(.v13)],
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
        .package(
            url: "https://github.com/apple/swift-syntax.git",
            from: "510.0.0"
        ),
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
