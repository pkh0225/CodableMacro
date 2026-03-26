import SwiftSyntaxMacrosTestSupport
import XCTest

/// `@Default` — 생성 코드에 폴백으로 반영되는지
final class DefaultMacroExpansionTests: XCTestCase {

    func test_defaultString_usedInDecodeFallback() throws {
        assertMacroExpansion(
            """
            @Codable
            struct S: Sendable {
                @Default("fallback")
                var title: String
            }
            """,
            expandedSource: """
            struct S: Sendable {
                var title: String
            }

            nonisolated extension S: Decodable {
                init(from decoder: any Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)

                    if let v = try? container.decodeIfPresent(String.self, forKey: CodingKeys.title) {
                        self.title = v
                    } else if let v = try? container.decodeIfPresent(Int.self, forKey: CodingKeys.title) {
                        self.title = \"\u{5C}(v)\"
                    } else if let v = try? container.decodeIfPresent(Double.self, forKey: CodingKeys.title) {
                        self.title = \"\u{5C}(v)\"
                    } else {
                        self.title = "fallback"
                    }
                }
            }

            nonisolated extension S: Encodable {
                func encode(to encoder: any Encoder) throws {
                    var container = encoder.container(keyedBy: CodingKeys.self)

                    try container.encode(self.title, forKey: CodingKeys.title)
                }
            }

            nonisolated extension S {
                enum CodingKeys: String, CodingKey {
                    case title = "title"
                }
            }

            """,
            macros: CodableMacroTestSupport.macros
        )
    }

    func test_defaultInt_usedInDecodeFallback() throws {
        assertMacroExpansion(
            """
            @Codable
            struct S: Sendable {
                @Default(42)
                var n: Int
            }
            """,
            expandedSource: """
            struct S: Sendable {
                var n: Int
            }

            nonisolated extension S: Decodable {
                init(from decoder: any Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)

                    if let v = try? container.decodeIfPresent(Int.self, forKey: CodingKeys.n) {
                        self.n = v
                    } else if let s = try? container.decodeIfPresent(String.self, forKey: CodingKeys.n), let v = Int(s) {
                        self.n = v
                    } else {
                        self.n = 42
                    }
                }
            }

            nonisolated extension S: Encodable {
                func encode(to encoder: any Encoder) throws {
                    var container = encoder.container(keyedBy: CodingKeys.self)

                    try container.encode(self.n, forKey: CodingKeys.n)
                }
            }

            nonisolated extension S {
                enum CodingKeys: String, CodingKey {
                    case n = "n"
                }
            }

            """,
            macros: CodableMacroTestSupport.macros
        )
    }
}
