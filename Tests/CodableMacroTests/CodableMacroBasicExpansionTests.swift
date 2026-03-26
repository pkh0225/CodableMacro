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
