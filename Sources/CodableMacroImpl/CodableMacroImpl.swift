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

        let structDecl = declaration.as(StructDeclSyntax.self)!
        let typeName = structDecl.name.text

        let conformsToAfterParsed = declaration.inheritanceClause?.inheritedTypes
            .contains { $0.type.trimmedDescription == "CodableAfterProtocol" }
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

        let memberPrefix = Self.memberModifierPrefix(from: structDecl)

        let generator = CodeGenerator(
            typeName: typeName,
            properties: properties,
            conformsToAfterParsed: conformsToAfterParsed,
            memberModifierPrefix: memberPrefix
        )

        let initBody = generator.indentedInitFromDecoderForExtension()
        let encodeBody = generator.indentedEncodeToForExtension()
        let keysBody = generator.indentedCodingKeysForExtension()

        return [
            try ExtensionDeclSyntax("""
            extension \(type): Decodable {
            \(raw: initBody)
            }
            """),
            try ExtensionDeclSyntax("""
            extension \(type): Encodable {
            \(raw: encodeBody)
            }
            """),
            try ExtensionDeclSyntax("""
            extension \(type) {
            \(raw: keysBody)
            }
            """),
        ]
    }

    /// struct 선언에 붙은 modifier만 생성 `init` / `encode` / `CodingKeys`에 동일하게 반영한다.
    private static func memberModifierPrefix(from structDecl: StructDeclSyntax) -> String {
        guard !structDecl.modifiers.isEmpty else { return "" }
        return structDecl.modifiers.map(\.trimmedDescription).joined(separator: " ") + " "
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

public enum MacroError: Error, CustomStringConvertible {
    case unsupportedType
    case emptyProperties
    case ignoredPropertyNeedsValue(propertyName: String)

    public var description: String {
        switch self {
        case .unsupportedType: return "@Codable은 struct에만 사용할 수 있습니다"
        case .emptyProperties: return "@Codable: 디코딩할 저장 프로퍼티가 필요합니다"
        case .ignoredPropertyNeedsValue(let name):
            return "@Ignore: \(name)는 옵셔널이 아니면 `= 초기값` 또는 `@Default(...)`가 필요합니다 (JSON에서 디코딩하지 않으므로 `init(from:)`에서 대입할 식이 필요합니다)"
        }
    }
}
