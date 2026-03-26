import SwiftSyntaxMacrosTestSupport
import XCTest

/// String·Int·Double·Bool 이외 타입 — `decodeIfPresent` + `do/catch` 폴백
final class CustomTypeDecodeMacroExpansionTests: XCTestCase {

    func test_customEnum_decodeIfPresentWithCatch() throws {
        assertMacroExpansion(
            """
            @Codable
            struct S: Sendable {
                var kind: Kind
            }
            enum Kind: String, Codable { case a
            }
            """,
            expandedSource: """
            struct S: Sendable {
                var kind: Kind
            }
            enum Kind: String, Codable { case a }

            nonisolated extension S: Decodable {
                init(from decoder: any Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)

                    do {
                        self.kind = try container.decodeIfPresent(Kind.self, forKey: CodingKeys.kind) ?? nil
                    }
                    catch {
                        self.kind = nil
                    }
                }
            }

            nonisolated extension S: Encodable {
                func encode(to encoder: any Encoder) throws {
                    var container = encoder.container(keyedBy: CodingKeys.self)

                    try container.encode(self.kind, forKey: CodingKeys.kind)
                }
            }

            nonisolated extension S {
                enum CodingKeys: String, CodingKey {
                    case kind = "kind"
                }
            }

            """,
            macros: CodableMacroTestSupport.macros
        )
    }
}
