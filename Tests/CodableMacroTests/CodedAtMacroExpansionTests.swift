import SwiftSyntaxMacrosTestSupport
import XCTest

/// `@CodedAt` — 단일 경로(키 이름만 변경) vs 중첩 컨테이너
final class CodedAtMacroExpansionTests: XCTestCase {

    func test_codedAt_singleSegment_renamesCodingKeyOnly() throws {
        assertMacroExpansion(
            """
            @Codable
            struct S: Sendable {
                @CodedAt("user_title")
                var title: String
            }
            """,
            expandedSource: """
            struct S: Sendable {
                var title: String
            }

            extension S: Decodable {
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
                }
            }

            extension S: Encodable {
                func encode(to encoder: any Encoder) throws {
                    var container = encoder.container(keyedBy: CodingKeys.self)

                    try container.encode(self.title, forKey: CodingKeys.title)
                }
            }

            extension S {
                enum CodingKeys: String, CodingKey {
                    case title = "user_title"
                }
            }

            """,
            macros: CodableMacroTestSupport.macros
        )
    }

    func test_codedAt_nestedContainer_usesNestedKeyedDecoding() throws {
        assertMacroExpansion(
            """
            @Codable
            struct Profile: Sendable {
                @CodedAt("detail", "bio")
                @Default("소개 없음")
                var biography: String
            }
            """,
            expandedSource: """
            struct Profile: Sendable {
                var biography: String
            }

            extension Profile: Decodable {
                init(from decoder: any Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)

                    let detail_container: KeyedDecodingContainer<CodingKeys>?
                    if (try? container.decodeNil(forKey: CodingKeys.detail)) == false {
                        detail_container = try? container.nestedContainer(keyedBy: CodingKeys.self, forKey: CodingKeys.detail)
                    } else {
                        detail_container = nil
                    }

                    if let detail_c = detail_container {
                        do {
                            self.biography = try detail_c.decodeIfPresent(String.self, forKey: CodingKeys.biography) ?? "소개 없음"
                        }
                        catch {
                            self.biography = "소개 없음"
                        }
                    }
                    else {
                        self.biography = "소개 없음"
                    }
                }
            }

            extension Profile: Encodable {
                func encode(to encoder: any Encoder) throws {
                    var container = encoder.container(keyedBy: CodingKeys.self)

                    var detail_container = container.nestedContainer(keyedBy: CodingKeys.self, forKey: CodingKeys.detail)
                    try detail_container.encode(self.biography, forKey: CodingKeys.biography)
                }
            }

            extension Profile {
                enum CodingKeys: String, CodingKey {
                    case biography = "bio"
                    case detail = "detail"
                }
            }

            """,
            macros: CodableMacroTestSupport.macros
        )
    }
}
