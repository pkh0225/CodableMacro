import Foundation

// MARK: - 매크로 선언

/// afterParsedTypes: CodableAfterProtocol을 채택한 프로퍼티 타입 목록 (자동 AfterParsedCoder 적용)
@attached(extension, conformances: Codable, names:
    named(CodingKeys),
    named(init(from:)),
    named(encode(to:)),
    named(applyCodedInFromParent)
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

@attached(peer)
public macro CodedIn(_ parentTypeName: String, _ parentPropertyName: String) = #externalMacro(
    module: "CodableMacroImpl",
    type: "CodedInMacro"
)

// MARK: - CodableAfterProtocol

public protocol CodableAfterProtocol {
    mutating func afterParsed()
}

// MARK: - AfterParsedCoder

public struct AfterParsedCoder<T: Codable & CodableAfterProtocol> {
    public init() {}

    public func decodeIfPresent<Key: CodingKey>(
        from container: KeyedDecodingContainer<Key>,
        forKey key: Key
    ) throws -> T? {
        guard var value = try container.decodeIfPresent(T.self, forKey: key) else { return nil }
        value.afterParsed()
        return value
    }

    public func encodeIfPresent<Key: CodingKey>(
        _ value: T?,
        to container: inout KeyedEncodingContainer<Key>,
        atKey key: Key
    ) throws {
        guard let value else { return }
        try container.encode(value, forKey: key)
    }
}
