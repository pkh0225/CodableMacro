import SwiftSyntax

struct CodeGenerator {
    let typeName: String
    let properties: [PropertyInfo]
    let conformsToAfterParsed: Bool

    /// CodingKeys·디코드·인코드에 포함되는 프로퍼티
    private var codableProperties: [PropertyInfo] {
        properties.filter { !$0.isIgnored }
    }

    private var ignoredProperties: [PropertyInfo] {
        properties.filter(\.isIgnored)
    }

    // 기본 들여쓰기 단위
    private let i1 = "    "      // 4칸 (함수 body)
    private let i2 = "        "  // 8칸
    private let i3 = "            "  // 12칸

    func indentedCodingKeysForExtension() -> String {
        indentBlock(generateCodingKeys(), by: "    ")
    }

    func indentedInitFromDecoderForExtension() -> String {
        indentBlock(generateInitFromDecoder(), by: "    ")
    }

    func indentedEncodeToForExtension() -> String {
        indentBlock(generateEncodeTo(), by: "    ")
    }

    private func indentBlock(_ source: String, by prefix: String) -> String {
        source.split(separator: "\n", omittingEmptySubsequences: false)
            .map { line in
                if line.isEmpty { return "" }
                return prefix + String(line)
            }
            .joined(separator: "\n")
    }

    // MARK: - CodingKeys

    func generateCodingKeys() -> String {
        var cases: [String] = []
        var addedKeys = Set<String>()
        var nestedParentKeys = Set<String>()

        for prop in codableProperties {
            let rawValue = prop.codingKeyRawValue
            if !addedKeys.contains(prop.name) {
                cases.append("\(i1)case \(prop.name) = \"\(rawValue)\"")
                addedKeys.insert(prop.name)
            }
            if let parentKey = prop.nestedContainerParentKey {
                nestedParentKeys.insert(parentKey)
            }
            if let asKeys = prop.codedAsKeys {
                for key in asKeys {
                    let caseName = "\(prop.name)_\(key)"
                    if !addedKeys.contains(caseName) {
                        cases.append("\(i1)case \(caseName) = \"\(key)\"")
                        addedKeys.insert(caseName)
                    }
                }
            }
        }
        for parentKey in nestedParentKeys.sorted() {
            if !addedKeys.contains(parentKey) {
                cases.append("\(i1)case \(parentKey) = \"\(parentKey)\"")
                addedKeys.insert(parentKey)
            }
        }

        return """
        enum CodingKeys: String, CodingKey {
        \(cases.joined(separator: "\n"))
        }
        """
    }

    // MARK: - init(from:)

    func generateInitFromDecoder() -> String {
        var lines: [String] = []
        var nestedGroups: [String: [PropertyInfo]] = [:]
        var normalProps: [PropertyInfo] = []

        for prop in codableProperties {
            if let parentKey = prop.nestedContainerParentKey {
                nestedGroups[parentKey, default: []].append(prop)
            }
            else {
                normalProps.append(prop)
            }
        }

        lines.append("\(i1)let container = try decoder.container(keyedBy: CodingKeys.self)")

        // 중첩 컨테이너 선언
        for parentKey in nestedGroups.keys.sorted() {
            lines.append("")
            lines.append("\(i1)let \(parentKey)_container: KeyedDecodingContainer<CodingKeys>?")
            lines.append("\(i1)if (try? container.decodeNil(forKey: CodingKeys.\(parentKey))) == false {")
            lines.append("\(i2)\(parentKey)_container = try? container.nestedContainer(keyedBy: CodingKeys.self, forKey: CodingKeys.\(parentKey))")
            lines.append("\(i1)} else {")
            lines.append("\(i2)\(parentKey)_container = nil")
            lines.append("\(i1)}")
        }

        if !normalProps.isEmpty { lines.append("") }

        for prop in normalProps {
            lines.append(contentsOf: generateDecodeLines(for: prop, containerExpr: "container", indent: i1))
        }

        for (parentKey, props) in nestedGroups.sorted(by: { $0.key < $1.key }) {
            for prop in props {
                lines.append(contentsOf: generateNestedDecodeLines(for: prop, parentKey: parentKey))
            }
        }

        if !ignoredProperties.isEmpty {
            lines.append("")
            for prop in ignoredProperties {
                lines.append("\(i1)self.\(prop.name) = \(prop.defaultValue)")
            }
        }

        if conformsToAfterParsed {
            lines.append("")
            lines.append("\(i1)afterParsed()")
        }

        return """
        init(from decoder: any Decoder) throws {
        \(lines.joined(separator: "\n"))
        }
        """
    }

    // MARK: - encode(to:)

    func generateEncodeTo() -> String {
        var lines: [String] = []
        var nestedContainers = Set<String>()

        lines.append("\(i1)var container = encoder.container(keyedBy: CodingKeys.self)")
        lines.append("")

        for prop in codableProperties {
            if let parentKey = prop.nestedContainerParentKey {
                if !nestedContainers.contains(parentKey) {
                    nestedContainers.insert(parentKey)
                    lines.append("\(i1)var \(parentKey)_container = container.nestedContainer(keyedBy: CodingKeys.self, forKey: CodingKeys.\(parentKey))")
                }
                lines.append("\(i1)try \(parentKey)_container.encode(self.\(prop.name), forKey: CodingKeys.\(prop.name))")
            }
            else if prop.isOptional {
                lines.append("\(i1)try container.encodeIfPresent(self.\(prop.name), forKey: CodingKeys.\(prop.name))")
            }
            else {
                lines.append("\(i1)try container.encode(self.\(prop.name), forKey: CodingKeys.\(prop.name))")
            }
        }

        return """
        func encode(to encoder: any Encoder) throws {
        \(lines.joined(separator: "\n"))
        }
        """
    }

    // MARK: - 일반 프로퍼티 디코딩

    private func generateDecodeLines(
        for prop: PropertyInfo,
        containerExpr: String,
        indent: String
    ) -> [String] {
        let i = indent
        let ii = indent + "    "
        let iii = indent + "        "
        let def = prop.defaultValue

        // 1순위: @CodedAs 다중 키
        if let asKeys = prop.codedAsKeys {
            let caseNames = [prop.name] + asKeys.map { "\(prop.name)_\($0)" }
            let allKeys = caseNames.map { "CodingKeys.\($0)" }.joined(separator: ", ")
            return [
                "\(i)do {",
                "\(ii)let \(prop.name)Keys = [\(allKeys)].filter { \(containerExpr).allKeys.contains($0) }",
                "\(ii)if let foundKey = \(prop.name)Keys.first {",
                "\(iii)self.\(prop.name) = try \(containerExpr).decodeIfPresent(\(prop.typeName).self, forKey: foundKey) ?? \(def)",
                "\(ii)}",
                "\(ii)else {",
                "\(iii)self.\(prop.name) = \(def)",
                "\(ii)}",
                "\(i)}",
                "\(i)catch {",
                "\(ii)self.\(prop.name) = \(def)",
                "\(i)}",
            ]
        }

        // 2순위: ValueCoder 자동 타입 변환
        return generateValueCoderLines(for: prop, containerExpr: containerExpr, indent: indent)
    }

    private func generateValueCoderLines(
        for prop: PropertyInfo,
        containerExpr: String,
        indent: String
    ) -> [String] {
        let i = indent
        let ii = indent + "    "
        let def = prop.defaultValue
        let key = "CodingKeys.\(prop.name)"

        if prop.isOptional {
            return ["\(i)self.\(prop.name) = try? \(containerExpr).decodeIfPresent(\(prop.baseTypeName).self, forKey: \(key))"]
        }

        switch prop.baseTypeName {
        case "String":
            return [
                "\(i)if let v = try? \(containerExpr).decodeIfPresent(String.self, forKey: \(key)) {",
                "\(ii)self.\(prop.name) = v",
                "\(i)} else if let v = try? \(containerExpr).decodeIfPresent(Int.self, forKey: \(key)) {",
                "\(ii)self.\(prop.name) = \"\\(v)\"",
                "\(i)} else if let v = try? \(containerExpr).decodeIfPresent(Double.self, forKey: \(key)) {",
                "\(ii)self.\(prop.name) = \"\\(v)\"",
                "\(i)} else {",
                "\(ii)self.\(prop.name) = \(def)",
                "\(i)}",
            ]

        case "Int", "Int8", "Int16", "Int32", "Int64",
             "UInt", "UInt8", "UInt16", "UInt32", "UInt64":
            return [
                "\(i)if let v = try? \(containerExpr).decodeIfPresent(\(prop.baseTypeName).self, forKey: \(key)) {",
                "\(ii)self.\(prop.name) = v",
                "\(i)} else if let s = try? \(containerExpr).decodeIfPresent(String.self, forKey: \(key)), let v = \(prop.baseTypeName)(s) {",
                "\(ii)self.\(prop.name) = v",
                "\(i)} else {",
                "\(ii)self.\(prop.name) = \(def)",
                "\(i)}",
            ]

        case "Double", "Float":
            return [
                "\(i)if let v = try? \(containerExpr).decodeIfPresent(\(prop.baseTypeName).self, forKey: \(key)) {",
                "\(ii)self.\(prop.name) = v",
                "\(i)} else if let s = try? \(containerExpr).decodeIfPresent(String.self, forKey: \(key)), let v = \(prop.baseTypeName)(s) {",
                "\(ii)self.\(prop.name) = v",
                "\(i)} else if let v = try? \(containerExpr).decodeIfPresent(Int.self, forKey: \(key)) {",
                "\(ii)self.\(prop.name) = \(prop.baseTypeName)(v)",
                "\(i)} else {",
                "\(ii)self.\(prop.name) = \(def)",
                "\(i)}",
            ]

        case "CGFloat":
            return [
                "\(i)if let v = try? \(containerExpr).decodeIfPresent(CGFloat.self, forKey: \(key)) {",
                "\(ii)self.\(prop.name) = v",
                "\(i)} else if let s = try? \(containerExpr).decodeIfPresent(String.self, forKey: \(key)), let d = Double(s) {",
                "\(ii)self.\(prop.name) = CGFloat(d)",
                "\(i)} else if let v = try? \(containerExpr).decodeIfPresent(Int.self, forKey: \(key)) {",
                "\(ii)self.\(prop.name) = CGFloat(v)",
                "\(i)} else {",
                "\(ii)self.\(prop.name) = \(def)",
                "\(i)}",
            ]

        case "Bool":
            return [
                "\(i)if let v = try? \(containerExpr).decodeIfPresent(Bool.self, forKey: \(key)) {",
                "\(ii)self.\(prop.name) = v",
                "\(i)} else if let v = try? \(containerExpr).decodeIfPresent(Int.self, forKey: \(key)) {",
                "\(ii)self.\(prop.name) = v != 0",
                "\(i)} else if let s = try? \(containerExpr).decodeIfPresent(String.self, forKey: \(key)) {",
                "\(ii)self.\(prop.name) = s.lowercased() == \"true\" || s == \"1\" || s.lowercased() == \"yes\" || s.lowercased() == \"y\"",
                "\(i)} else {",
                "\(ii)self.\(prop.name) = \(def)",
                "\(i)}",
            ]

        default:
            // enum, 커스텀 struct 등
            return [
                "\(i)do {",
                "\(ii)self.\(prop.name) = try \(containerExpr).decodeIfPresent(\(prop.typeName).self, forKey: \(key)) ?? \(def)",
                "\(i)}",
                "\(i)catch {",
                "\(ii)self.\(prop.name) = \(def)",
                "\(i)}",
            ]
        }
    }

    // MARK: - 중첩 컨테이너 프로퍼티 디코딩

    private func generateNestedDecodeLines(for prop: PropertyInfo, parentKey: String) -> [String] {
        let def = prop.defaultValue
        let key = "CodingKeys.\(prop.name)"
        return [
            "",
            "\(i1)if let \(parentKey)_c = \(parentKey)_container {",
            "\(i2)do {",
            "\(i3)self.\(prop.name) = try \(parentKey)_c.decodeIfPresent(\(prop.typeName).self, forKey: \(key)) ?? \(def)",
            "\(i2)}",
            "\(i2)catch {",
            "\(i3)self.\(prop.name) = \(def)",
            "\(i2)}",
            "\(i1)}",
            "\(i1)else {",
            "\(i2)self.\(prop.name) = \(def)",
            "\(i1)}",
        ]
    }
}
