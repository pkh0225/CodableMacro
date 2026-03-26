import SwiftSyntaxMacrosTestSupport
import XCTest

/// `@CodedIn` — 자식은 JSON에서 제외 후 부모 주입, 부모는 `[Element]`에 대해 `applyCodedInFromParent` 호출
final class CodedInMacroExpansionTests: XCTestCase {

    func test_codedIn_childSkipsDecode_parentLoopsArray() throws {
        assertMacroExpansion(
            """
            @Codable
            struct UserMetaCodable: Sendable {
                var score: Double
                var items: [CodableData2]
            }

            @Codable
            struct CodableData2: Sendable {
                var title: String
                @CodedIn("UserMetaCodable", "score")
                var price: Double
            }
            """,
            expandedSource: """
            struct UserMetaCodable: Sendable {
                var score: Double
                var items: [CodableData2]
            }
            struct CodableData2: Sendable {
                var title: String
                var price: Double
            }

            nonisolated extension UserMetaCodable: Decodable {
                init(from decoder: any Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)

                    if let v = try? container.decodeIfPresent(Double.self, forKey: CodingKeys.score) {
                        self.score = v
                    } else if let s = try? container.decodeIfPresent(String.self, forKey: CodingKeys.score), let v = Double(s) {
                        self.score = v
                    } else if let v = try? container.decodeIfPresent(Int.self, forKey: CodingKeys.score) {
                        self.score = Double(v)
                    } else {
                        self.score = 0
                    }
                    do {
                        self.items = try container.decodeIfPresent([CodableData2].self, forKey: CodingKeys.items) ?? Array<CodableData2>()
                    }
                    catch {
                        self.items = Array<CodableData2>()
                    }

                }
            }

            nonisolated extension UserMetaCodable: Encodable {
                func encode(to encoder: any Encoder) throws {
                    var container = encoder.container(keyedBy: CodingKeys.self)

                    try container.encode(self.score, forKey: CodingKeys.score)
                    try container.encode(self.items, forKey: CodingKeys.items)
                }
            }

            nonisolated extension UserMetaCodable {
                enum CodingKeys: String, CodingKey {
                    case score = "score"
                    case items = "items"
                }
            }

            nonisolated extension CodableData2: Decodable {
                init(from decoder: any Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)

                    if let v = try? container.decodeIfPresent(String.self, forKey: CodingKeys.title) {
                        self.title = v
                    } else if let v = try? container.decodeIfPresent(Int.self, forKey: CodingKeys.title) {
                        self.title = \"\u{5C}(v)\"
                    } else if let v = try? container.decodeIfPresent(Double.self, forKey: CodingKeys.title) {
                        self.title = \"\u{5C}(v)\"
                    } else {
                        self.title = ""
                    }
                    self.price = 0
                }
            }

            nonisolated extension CodableData2: Encodable {
                func encode(to encoder: any Encoder) throws {
                    var container = encoder.container(keyedBy: CodingKeys.self)

                    try container.encode(self.title, forKey: CodingKeys.title)
                    try container.encode(self.price, forKey: CodingKeys.price)
                }
            }

            nonisolated extension CodableData2 {
                enum CodingKeys: String, CodingKey {
                    case title = "title"
                    case price = "price"
                }
            }

            nonisolated extension CodableData2 {
                mutating func applyCodedInFromParent(_ parent: UserMetaCodable) {
                    self.price = parent.score
                }
            }
            """,
            macros: CodableMacroTestSupport.macros
        )
    }
}
