import SwiftSyntaxMacrosTestSupport
import XCTest

/// `@Ignore` — CodingKeys / init / encode에서 제외
final class IgnoreMacroExpansionTests: XCTestCase {

    func test_ignoredProperty_excludedFromCodableSynthesis() throws {
        assertMacroExpansion(
            """
            @Codable
            struct Box: Sendable {
                var x: Int
                @Ignore
                var anyType: Any?
            }
            """,
            expandedSource: """
            struct Box: Sendable {
                var x: Int
                var anyType: Any?
            }

            nonisolated extension Box: Decodable {
                init(from decoder: any Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)

                    if let v = try? container.decodeIfPresent(Int.self, forKey: CodingKeys.x) {
                        self.x = v
                    } else if let s = try? container.decodeIfPresent(String.self, forKey: CodingKeys.x), let v = Int(s) {
                        self.x = v
                    } else {
                        self.x = 0
                    }

                    self.anyType = nil
                }
            }

            nonisolated extension Box: Encodable {
                func encode(to encoder: any Encoder) throws {
                    var container = encoder.container(keyedBy: CodingKeys.self)

                    try container.encode(self.x, forKey: CodingKeys.x)
                }
            }

            nonisolated extension Box {
                enum CodingKeys: String, CodingKey {
                    case x = "x"
                }
            }

            nonisolated extension Box {
                mutating func applyCodedInFromParent(_ parent: UserMetaCodable) {
                }
            }
            """,
            macros: CodableMacroTestSupport.macros
        )
    }

    /// 비옵셔널 `@Ignore`는 JSON에 없으므로 선언부 `= 초기값`이 `init(from:)`에 반영됩니다.
    func test_ignoredNonOptional_usesBindingInitializer() throws {
        assertMacroExpansion(
            """
            @Codable
            struct Box: Sendable {
                var x: Int
                @Ignore
                var any: CodableData = CodableData()
            }
            """,
            expandedSource: """
            struct Box: Sendable {
                var x: Int
                var any: CodableData = CodableData()
            }

            nonisolated extension Box: Decodable {
                init(from decoder: any Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)

                    if let v = try? container.decodeIfPresent(Int.self, forKey: CodingKeys.x) {
                        self.x = v
                    } else if let s = try? container.decodeIfPresent(String.self, forKey: CodingKeys.x), let v = Int(s) {
                        self.x = v
                    } else {
                        self.x = 0
                    }

                    self.any = CodableData()
                }
            }

            nonisolated extension Box: Encodable {
                func encode(to encoder: any Encoder) throws {
                    var container = encoder.container(keyedBy: CodingKeys.self)

                    try container.encode(self.x, forKey: CodingKeys.x)
                }
            }

            nonisolated extension Box {
                enum CodingKeys: String, CodingKey {
                    case x = "x"
                }
            }

            nonisolated extension Box {
                mutating func applyCodedInFromParent(_ parent: UserMetaCodable) {
                }
            }
            """,
            macros: CodableMacroTestSupport.macros
        )
    }
}
