import SwiftSyntaxMacrosTestSupport
import XCTest

/// 타입이 `AfterParsedProtocol`을 채택하면 `init(from:)` 끝에 `afterParsed()` 호출
final class AfterParsedProtocolMacroExpansionTests: XCTestCase {

    func test_afterParsed_calledAtEndOfInit() throws {
        assertMacroExpansion(
            """
            @Codable
            struct UserMeta: AfterParsedProtocol, Sendable {
                @Default("이름 없음")
                var name: String
                mutating func afterParsed() {}
            }
            """,
            expandedSource: """
            struct UserMeta: AfterParsedProtocol, Sendable {
                var name: String
                mutating func afterParsed() {}
            }

            nonisolated extension UserMeta: Decodable {
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

                    afterParsed()
                }
            }

            nonisolated extension UserMeta: Encodable {
                func encode(to encoder: any Encoder) throws {
                    var container = encoder.container(keyedBy: CodingKeys.self)

                    try container.encode(self.name, forKey: CodingKeys.name)
                }
            }

            nonisolated extension UserMeta {
                enum CodingKeys: String, CodingKey {
                    case name = "name"
                }
            }

            nonisolated extension UserMeta {
                mutating func applyCodedInFromParent(_ parent: UserMetaCodable) {
                }
            }
            """,
            macros: CodableMacroTestSupport.macros
        )
    }
}
