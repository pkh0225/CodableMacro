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
    /// `@CodedIn("부모타입", "부모프로퍼티명")` — JSON이 아니라 부모 디코딩 후 주입 (자식은 해당 키를 디코드하지 않음)
    let codedInParentType: String?
    let codedInSourceProperty: String?

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

    /// 부모 인스턴스의 프로퍼티로 값을 채우는 경우 (JSON 키와 무관)
    var isCodedIn: Bool {
        codedInParentType != nil && codedInSourceProperty != nil
    }
}
