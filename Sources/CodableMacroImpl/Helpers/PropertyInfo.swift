import SwiftSyntax

struct PropertyInfo {
    let name: String
    let typeName: String
    let baseTypeName: String
    let defaultValue: String
    let codedAtPath: [String]?
    let codedAsKeys: [String]?
    let isOptional: Bool
    /// `@Ignore` — CodingKeys·encode·decode 합성에서 제외. `init(from:)`에서는 `defaultValue`로만 초기화합니다.
    let isIgnored: Bool

    var codingKeyRawValue: String {
        if let path = codedAtPath { return path.last ?? name }
        return name
    }

    var needsNestedContainer: Bool {
        guard let path = codedAtPath else { return false }
        return path.count >= 2
    }

    var nestedContainerParentKey: String? {
        guard let path = codedAtPath, path.count >= 2 else { return nil }
        return path[0]
    }
}
