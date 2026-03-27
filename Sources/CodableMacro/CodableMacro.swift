import Foundation

// MARK: - 매크로 선언

/// afterParsedTypes: CodableAfterProtocol을 채택한 프로퍼티 타입 목록 (자동 AfterParsedCoder 적용)
@attached(extension, conformances: Codable, names:
    named(CodingKeys),
    named(init(from:)),
    named(encode(to:))
)
public macro Codable() = #externalMacro(
    module: "CodableMacroImpl",
    type: "CodableMacro"
)

@attached(peer)
public macro CodedAt(_ keys: String...) = #externalMacro(
    module: "CodableMacroImpl",
    type: "CodedAtMacro"
)

@attached(peer)
public macro CodedAs(_ keys: String...) = #externalMacro(
    module: "CodableMacroImpl",
    type: "CodedAsMacro"
)

@attached(peer)
public macro Default<T>(_ value: T) = #externalMacro(
    module: "CodableMacroImpl",
    type: "DefaultMacro"
)

@attached(peer)
public macro Ignore() = #externalMacro(
    module: "CodableMacroImpl",
    type: "IgnoreMacro"
)

// MARK: - CodableAfterProtocol

nonisolated public protocol CodableAfterProtocol {
    nonisolated mutating func afterParsed()
}
