import SwiftSyntaxMacrosTestSupport
import XCTest

/// `@Codable`만 붙인 최소 struct — CodingKeys / init(from:) / encode(to:) 생성 여부
final class CodableMacroBasicExpansionTests: XCTestCase {

    func test_expandsSingleIntProperty_withValueCoderInt() throws {
        assertMacroExpansion(
            """
            @Codable
            struct Box: Sendable {
                var x: Int
            }
            """,
            expandedSource: """
            struct Box: Sendable {
                var x: Int
            }

            extension Box: Decodable {
                init(from decoder: any Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)

                    if let v = try? container.decodeIfPresent(Int.self, forKey: CodingKeys.x) {
                        self.x = v
                    } else if let s = try? container.decodeIfPresent(String.self, forKey: CodingKeys.x), let v = Int(s) {
                        self.x = v
                    } else {
                        self.x = 0
                    }
                }
            }

            extension Box: Encodable {
                func encode(to encoder: any Encoder) throws {
                    var container = encoder.container(keyedBy: CodingKeys.self)

                    try container.encode(self.x, forKey: CodingKeys.x)
                }
            }

            extension Box {
                enum CodingKeys: String, CodingKey {
                    case x = "x"
                }
            }

            """,
            macros: CodableMacroTestSupport.macros
        )
    }

    /// struct에 붙은 선언 modifier는 extension이 아니라 생성 `init` / `encode` / `CodingKeys`에만 복사된다.
    func test_structDeclarationModifiers_copiedToSynthesizedMembers() throws {
        assertMacroExpansion(
            """
            @Codable
            nonisolated public struct Box: Sendable {
                var x: Int
            }
            """,
            expandedSource: """
            nonisolated public struct Box: Sendable {
                var x: Int
            }

            extension Box: Decodable {
                nonisolated public init(from decoder: any Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)

                    if let v = try? container.decodeIfPresent(Int.self, forKey: CodingKeys.x) {
                        self.x = v
                    } else if let s = try? container.decodeIfPresent(String.self, forKey: CodingKeys.x), let v = Int(s) {
                        self.x = v
                    } else {
                        self.x = 0
                    }
                }
            }

            extension Box: Encodable {
                nonisolated public func encode(to encoder: any Encoder) throws {
                    var container = encoder.container(keyedBy: CodingKeys.self)

                    try container.encode(self.x, forKey: CodingKeys.x)
                }
            }

            extension Box {
                nonisolated public enum CodingKeys: String, CodingKey {
                    case x = "x"
                }
            }

            """,
            macros: CodableMacroTestSupport.macros
        )
    }
}
