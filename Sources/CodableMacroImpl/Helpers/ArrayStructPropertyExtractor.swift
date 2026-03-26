import SwiftSyntax

/// `var items: [ElementType]` 형태에서 배열 요소 타입 이름을 뽑습니다 (부모 `init(from:)`에서 `@CodedIn` 주입 루프용).
enum ArrayStructPropertyExtractor {
    static func arrayStructBindings(from declaration: DeclGroupSyntax) -> [(propertyName: String, elementTypeName: String)] {
        var result: [(String, String)] = []
        for member in declaration.memberBlock.members {
            guard let variable = member.decl.as(VariableDeclSyntax.self) else { continue }
            guard let binding = variable.bindings.first else { continue }
            guard let namePattern = binding.pattern.as(IdentifierPatternSyntax.self) else { continue }
            guard let typeAnnotation = binding.typeAnnotation else { continue }
            if let pair = elementTypeIfArray(typeAnnotation.type) {
                result.append((namePattern.identifier.text, pair))
            }
        }
        return result
    }

    private static func elementTypeIfArray(_ type: TypeSyntax) -> String? {
        let base = unwrapOptionalWrappers(type)
        if let arr = base.as(ArrayTypeSyntax.self) {
            return arr.element.trimmedDescription
        }
        if let ident = base.as(IdentifierTypeSyntax.self), ident.name.text == "Array",
           let generic = ident.genericArgumentClause,
           let first = generic.arguments.first {
            return first.argument.trimmedDescription
        }
        return nil
    }

    private static func unwrapOptionalWrappers(_ type: TypeSyntax) -> TypeSyntax {
        var t = type
        while let opt = t.as(OptionalTypeSyntax.self) {
            t = opt.wrappedType
        }
        while let iuo = t.as(ImplicitlyUnwrappedOptionalTypeSyntax.self) {
            t = iuo.wrappedType
        }
        return t
    }
}
