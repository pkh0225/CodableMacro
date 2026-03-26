import SwiftSyntaxMacrosTestSupport
import XCTest

/// `@CodedAs` — JSON 키 후보가 여러 개일 때 첫 매칭 키로 디코딩
final class CodedAsMacroExpansionTests: XCTestCase {

    func test_codedAs_multipleKeys_firstPresentWins() throws {
        assertMacroExpansion(
            """
            @Codable
            struct S: Sendable {
                @CodedAs("a", "b")
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

                    do {
                        let titleKeys = [CodingKeys.title, CodingKeys.title_a, CodingKeys.title_b].filter {
                            container.allKeys.contains($0)
                        }
                        if let foundKey = titleKeys.first {
                            self.title = try container.decodeIfPresent(String.self, forKey: foundKey) ?? ""
                        }
                        else {
                            self.title = ""
                        }
                    }
                    catch {
                        self.title = ""
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
                    case title_a = "a"
                    case title_b = "b"
                }
            }

            """,
            macros: CodableMacroTestSupport.macros
        )
    }
}
