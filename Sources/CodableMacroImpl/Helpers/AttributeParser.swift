import SwiftParser
import SwiftSyntax

struct AttributeParser {
    static func parse(variable: VariableDeclSyntax) throws -> PropertyInfo? {
        guard let binding = variable.bindings.first else { return nil }
        guard let namePattern = binding.pattern.as(IdentifierPatternSyntax.self) else { return nil }

        if binding.accessorBlock != nil { return nil }

        let name = namePattern.identifier.text

        let typeName: String
        if let typeAnnotation = binding.typeAnnotation {
            typeName = typeAnnotation.type.trimmedDescription
        }
        else if let initializer = binding.initializer {
            typeName = inferType(from: initializer.value)
        }
        else {
            return nil
        }

        let isOptional = typeName.hasSuffix("?") || typeName.hasPrefix("Optional<")
        let baseTypeName = extractBaseTypeName(from: typeName)

        var defaultValue: String? = nil
        var codedAtPath: [String]? = nil
        var codedAsKeys: [String]? = nil
        var codedInParentType: String? = nil
        var codedInSourceProperty: String? = nil
        var isIgnored = false

        for attribute in variable.attributes {
            guard let attr = attribute.as(AttributeSyntax.self) else { continue }
            let attrName = attr.attributeName.trimmedDescription
            if attrName == "Ignore" {
                isIgnored = true
                continue
            }

            switch attrName {
            case "Default":
                defaultValue = extractFirstArg(from: attr)
            case "CodedAt":
                codedAtPath = extractStringArgs(from: attr)
            case "CodedAs":
                codedAsKeys = extractStringArgs(from: attr)
            case "CodedIn":
                guard let args = extractStringArgs(from: attr), args.count == 2 else {
                    throw MacroError.codedInRequiresTwoStringArguments(propertyName: name)
                }
                codedInParentType = args[0]
                codedInSourceProperty = args[1]
            default:
                break
            }
        }

        if isIgnored, codedInParentType != nil {
            throw MacroError.ignoreConflictsWithCodedIn(propertyName: name)
        }
        if codedInParentType != nil, codedAtPath != nil {
            throw MacroError.codedInConflictsWithCodedAt(propertyName: name)
        }

        let resolvedDefault: String
        if let dv = defaultValue {
            resolvedDefault = normalizeDefaultValueSpelling(dv)
        } else if isIgnored, let initClause = binding.initializer {
            // @Ignore + 비옵셔널: JSON에 없으므로 선언부 `= 값`으로 init(from:) 대입
            resolvedDefault = normalizeDefaultValueSpelling(initClause.value.trimmedDescription)
        } else {
            resolvedDefault = normalizeDefaultValueSpelling(
                defaultValueForType(typeName, isOptional: isOptional)
            )
        }

        if isIgnored, !isOptional, resolvedDefault == "nil" {
            throw MacroError.ignoredPropertyNeedsValue(propertyName: name)
        }

        return PropertyInfo(
            name: name,
            typeName: typeName,
            baseTypeName: baseTypeName,
            defaultValue: resolvedDefault,
            codedAtPath: codedAtPath,
            codedAsKeys: codedAsKeys,
            isOptional: isOptional,
            isIgnored: isIgnored,
            codedInParentType: codedInParentType,
            codedInSourceProperty: codedInSourceProperty
        )
    }

    // MARK: - 초기값에서 타입 추론

    private static func inferType(from expr: ExprSyntax) -> String {
        if expr.is(StringLiteralExprSyntax.self) { return "String" }
        if expr.is(BooleanLiteralExprSyntax.self) { return "Bool" }
        if let intLit = expr.as(IntegerLiteralExprSyntax.self) {
            _ = intLit
            return "Int"
        }
        if expr.is(FloatLiteralExprSyntax.self) { return "Double" }
        if expr.is(NilLiteralExprSyntax.self) { return "Any?" }
        return "Any"
    }

    // MARK: - 옵셔널 언래핑

    static func extractBaseTypeName(from typeName: String) -> String {
        let trimmed = typeName.trimmingCharacters(in: .whitespaces)
        if trimmed.hasSuffix("?") {
            return String(trimmed.dropLast()).trimmingCharacters(in: .whitespaces)
        }
        if trimmed.hasPrefix("Optional<") && trimmed.hasSuffix(">") {
            return String(trimmed.dropFirst(9).dropLast())
                .trimmingCharacters(in: .whitespaces)
        }
        return trimmed
    }

    // MARK: - 타입별 기본값

    /// 배열/딕셔너리 타입 표기에서 공백을 줄여 `"\(t)()"`가 `[T] ()`처럼 깨지지 않게 합니다.
    private static func condensedTypeNameForDefault(_ typeName: String) -> String {
        var t = typeName.trimmingCharacters(in: .whitespacesAndNewlines)
        // `[ Foo ]` → `[Foo]`에 가깝게: `]` 앞 공백 제거
        t = t.replacingOccurrences(of: "\\s+\\]", with: "]", options: .regularExpression)
        // `] ` 반복 제거 (토큰 trivia 등)
        while t != t.replacingOccurrences(of: "\\]\\s+", with: "]", options: .regularExpression) {
            t = t.replacingOccurrences(of: "\\]\\s+", with: "]", options: .regularExpression)
        }
        return t
    }

    /// `[T] ()`, `[T]  ()`처럼 `]`와 `(` 사이 공백을 제거합니다. (매크로 출력·`@Default` 인자 모두)
    static func normalizeDefaultValueSpelling(_ value: String) -> String {
        value.replacingOccurrences(
            of: "\\]\\s+\\(",
            with: "](",
            options: .regularExpression
        )
    }

    /// `]` 다음 `(`는 SwiftSyntax `BasicFormat`이 공백을 넣어 `[T] ()`로 바꿉니다. 빈 컬렉션은 `Array`/`Dictionary` 표기로 두면 `>`와 `(` 사이만 오므로 포맷해도 깨지지 않습니다.
    private static func convertBracketTypeToGenericForm(_ typeSpelling: String) -> String {
        let trimmed = condensedTypeNameForDefault(typeSpelling)
        guard trimmed.hasPrefix("["), trimmed.hasSuffix("]") else { return trimmed }
        let inner = String(trimmed.dropFirst().dropLast())
        if let colonIdx = findTopLevelColonInCollectionInner(inner) {
            let key = String(inner[..<colonIdx]).trimmingCharacters(in: .whitespacesAndNewlines)
            let value = String(inner[inner.index(after: colonIdx)...]).trimmingCharacters(in: .whitespacesAndNewlines)
            return "Dictionary<\(convertBracketTypeToGenericForm(key)), \(convertBracketTypeToGenericForm(value))>"
        }
        let element = inner.trimmingCharacters(in: .whitespacesAndNewlines)
        return "Array<\(convertBracketTypeToGenericForm(element))>"
    }

    /// `[`/`]`·`<`/`>` 중첩을 고려해, 컬렉션 내부에서 depth 0인 `:`만 딕셔너리 구분으로 취급합니다.
    private static func findTopLevelColonInCollectionInner(_ inner: String) -> String.Index? {
        var depth = 0
        var i = inner.startIndex
        while i < inner.endIndex {
            let ch = inner[i]
            switch ch {
            case "[", "<": depth += 1
            case "]", ">": depth -= 1
            case ":" where depth == 0: return i
            default: break
            }
            i = inner.index(after: i)
        }
        return nil
    }

    private static func arrayOrDictionaryEmptyInit(from typeSpelling: String) -> String {
        let t = condensedTypeNameForDefault(typeSpelling)
        guard t.hasPrefix("["), t.hasSuffix("]") else {
            return normalizeDefaultValueSpelling("\(t)()")
        }
        return "\(convertBracketTypeToGenericForm(t))()"
    }

    static func defaultValueForType(_ typeName: String, isOptional: Bool) -> String {
        if isOptional { return "nil" }
        let trimmed = condensedTypeNameForDefault(typeName)
        if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") && !trimmed.contains(":") {
            return arrayOrDictionaryEmptyInit(from: typeName)
        }
        if trimmed.hasPrefix("[") && trimmed.contains(":") && trimmed.hasSuffix("]") {
            return arrayOrDictionaryEmptyInit(from: typeName)
        }
        switch trimmed {
        case "String": return "\"\""
        case "Bool": return "false"
        case "Int", "Int8", "Int16", "Int32", "Int64",
             "UInt", "UInt8", "UInt16", "UInt32", "UInt64":
            return "0"
        case "Float", "Double", "CGFloat": return "0"
        default: return "nil"
        }
    }

    // MARK: - Syntax 헬퍼

    static func extractFirstArg(from attr: AttributeSyntax) -> String? {
        guard let args = attr.arguments?.as(LabeledExprListSyntax.self),
              let first = args.first
        else { return nil }
        return first.expression.trimmedDescription
    }

    /// 이스케이프·멀티라인을 해석한 값. 보간 문자열이면 `nil`을 반환해 호출부에서 실패 처리합니다.
    static func extractStringArgs(from attr: AttributeSyntax) -> [String]? {
        guard let args = attr.arguments?.as(LabeledExprListSyntax.self), !args.isEmpty else { return nil }
        var result: [String] = []
        for element in args {
            guard let strLiteral = element.expression.as(StringLiteralExprSyntax.self),
                  let value = strLiteral.representedLiteralValue
            else {
                return nil
            }
            result.append(value)
        }
        return result
    }
}
