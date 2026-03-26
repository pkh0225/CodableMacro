import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct CodableMacro: ExtensionMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        guard declaration.is(StructDeclSyntax.self) else {
            throw MacroError.unsupportedType
        }

        let typeName = declaration.as(StructDeclSyntax.self)?.name.text ?? ""

        let conformsToAfterParsed = declaration.inheritanceClause?.inheritedTypes
            .contains { $0.type.trimmedDescription == "AfterParsedProtocol" }
        ?? false

        let members = declaration.memberBlock.members
        var properties: [PropertyInfo] = []
        for member in members {
            guard let variable = member.decl.as(VariableDeclSyntax.self) else { continue }
            if let info = try AttributeParser.parse(variable: variable) {
                properties.append(info)
            }
        }

        guard properties.contains(where: { !$0.isIgnored }) else {
            throw MacroError.emptyProperties
        }

        try validateCodedInMetadata(properties)

        let arrayStructProps = ArrayStructPropertyExtractor.arrayStructBindings(from: declaration)

        let generator = CodeGenerator(
            typeName: typeName,
            properties: properties,
            conformsToAfterParsed: conformsToAfterParsed,
            arrayStructProperties: arrayStructProps
        )

        let initBody = generator.indentedInitFromDecoderForExtension()
        let encodeBody = generator.indentedEncodeToForExtension()
        let keysBody = generator.indentedCodingKeysForExtension()
        let codedInBody = generator.indentedApplyCodedInFromParentExtension()

        return [
            try ExtensionDeclSyntax("""
            nonisolated extension \(type): Decodable {
            \(raw: initBody)
            }
            """),
            try ExtensionDeclSyntax("""
            nonisolated extension \(type): Encodable {
            \(raw: encodeBody)
            }
            """),
            try ExtensionDeclSyntax("""
            nonisolated extension \(type) {
            \(raw: keysBody)
            }
            """),
            try ExtensionDeclSyntax("""
            nonisolated extension \(type) {
            \(raw: codedInBody)
            }
            """),
        ]
    }

    private static func validateCodedInMetadata(_ properties: [PropertyInfo]) throws {
        let parents = properties.compactMap(\.codedInParentType)
        guard !parents.isEmpty else { return }
        guard parents.allSatisfy({ $0 == parents[0] }) else {
            throw MacroError.codedInParentTypeMismatch
        }
    }
}

public struct CodedAtMacro: PeerMacro {
    public static func expansion(of node: AttributeSyntax, providingPeersOf declaration: some DeclSyntaxProtocol, in context: some MacroExpansionContext) throws -> [DeclSyntax] { [] }
}
public struct CodedAsMacro: PeerMacro {
    public static func expansion(of node: AttributeSyntax, providingPeersOf declaration: some DeclSyntaxProtocol, in context: some MacroExpansionContext) throws -> [DeclSyntax] { [] }
}
public struct DefaultMacro: PeerMacro {
    public static func expansion(of node: AttributeSyntax, providingPeersOf declaration: some DeclSyntaxProtocol, in context: some MacroExpansionContext) throws -> [DeclSyntax] { [] }
}
public struct IgnoreMacro: PeerMacro {
    public static func expansion(of node: AttributeSyntax, providingPeersOf declaration: some DeclSyntaxProtocol, in context: some MacroExpansionContext) throws -> [DeclSyntax] { [] }
}
public struct CodedInMacro: PeerMacro {
    public static func expansion(of node: AttributeSyntax, providingPeersOf declaration: some DeclSyntaxProtocol, in context: some MacroExpansionContext) throws -> [DeclSyntax] { [] }
}

public enum MacroError: Error, CustomStringConvertible {
    case unsupportedType
    case emptyProperties
    case ignoredPropertyNeedsValue(propertyName: String)
    case codedInRequiresTwoStringArguments(propertyName: String)
    case ignoreConflictsWithCodedIn(propertyName: String)
    case codedInConflictsWithCodedAt(propertyName: String)
    case codedInParentTypeMismatch

    public var description: String {
        switch self {
        case .unsupportedType: return "@Codable은 struct에만 사용할 수 있습니다"
        case .emptyProperties: return "@Codable: 디코딩할 저장 프로퍼티가 필요합니다"
        case .ignoredPropertyNeedsValue(let name):
            return "@Ignore: \(name)는 옵셔널이 아니면 `= 초기값` 또는 `@Default(...)`가 필요합니다 (JSON에서 디코딩하지 않으므로 `init(from:)`에서 대입할 식이 필요합니다)"
        case .codedInRequiresTwoStringArguments(let name):
            return "@CodedIn: \(name)에는 부모 타입명과 부모 프로퍼티명 문자열 두 개가 필요합니다 (예: @CodedIn(\"UserMetaCodable\", \"score\"))"
        case .ignoreConflictsWithCodedIn(let name):
            return "@Ignore와 @CodedIn을 같은 프로퍼티에 함께 쓸 수 없습니다: \(name)"
        case .codedInConflictsWithCodedAt(let name):
            return "@CodedAt와 @CodedIn을 같은 프로퍼티에 함께 쓸 수 없습니다: \(name)"
        case .codedInParentTypeMismatch:
            return "@CodedIn: 같은 타입 안에서는 첫 번째 인자(부모 타입명)가 모두 같아야 합니다"
        }
    }
}
