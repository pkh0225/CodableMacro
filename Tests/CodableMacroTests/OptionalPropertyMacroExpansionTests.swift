import SwiftSyntaxMacrosTestSupport
import XCTest

/// 옵셔널 저장 프로퍼티 — decodeIfPresent / encodeIfPresent
final class OptionalPropertyMacroExpansionTests: XCTestCase {

    func test_optionalString_decodeAndEncodeIfPresent() throws {
        assertMacroExpansion(
            """
            @Codable
            struct S: Sendable {
                var note: String?
            }
            """,
            expandedSource: """
            struct S: Sendable {
                var note: String?
            }

            nonisolated extension S: Decodable {
                init(from decoder: any Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)

                    self.note = try? container.decodeIfPresent(String.self, forKey: CodingKeys.note)
                }
            }

            nonisolated extension S: Encodable {
                func encode(to encoder: any Encoder) throws {
                    var container = encoder.container(keyedBy: CodingKeys.self)

                    try container.encodeIfPresent(self.note, forKey: CodingKeys.note)
                }
            }

            nonisolated extension S {
                enum CodingKeys: String, CodingKey {
                    case note = "note"
                }
            }

            """,
            macros: CodableMacroTestSupport.macros
        )
    }
}
