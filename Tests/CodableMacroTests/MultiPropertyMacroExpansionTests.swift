import SwiftSyntaxMacrosTestSupport
import XCTest

/// 여러 프로퍼티 + `@Default` 조합 (통합 스모크)
final class MultiPropertyMacroExpansionTests: XCTestCase {

    func test_stringAndInt_withDefaultOnName() throws {
        assertMacroExpansion(
            """
            @Codable
            struct User: Sendable {
                @Default("이름 없음")
                var name: String
                var age: Int
            }
            """,
            expandedSource: """
            struct User: Sendable {
                var name: String
                var age: Int
            }

            nonisolated extension User: Decodable {
                init(from decoder: any Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)

                    if let v = try? container.decodeIfPresent(String.self, forKey: CodingKeys.name) {
                        self.name = v
                    } else if let v = try? container.decodeIfPresent(Int.self, forKey: CodingKeys.name) {
                        self.name = \"\u{5C}(v)\"
                    } else if let v = try? container.decodeIfPresent(Double.self, forKey: CodingKeys.name) {
                        self.name = \"\u{5C}(v)\"
                    } else {
                        self.name = "이름 없음"
                    }
                    if let v = try? container.decodeIfPresent(Int.self, forKey: CodingKeys.age) {
                        self.age = v
                    } else if let s = try? container.decodeIfPresent(String.self, forKey: CodingKeys.age), let v = Int(s) {
                        self.age = v
                    } else {
                        self.age = 0
                    }
                }
            }

            nonisolated extension User: Encodable {
                func encode(to encoder: any Encoder) throws {
                    var container = encoder.container(keyedBy: CodingKeys.self)

                    try container.encode(self.name, forKey: CodingKeys.name)
                    try container.encode(self.age, forKey: CodingKeys.age)
                }
            }

            nonisolated extension User {
                enum CodingKeys: String, CodingKey {
                    case name = "name"
                    case age = "age"
                }
            }

            """,
            macros: CodableMacroTestSupport.macros
        )
    }
}
