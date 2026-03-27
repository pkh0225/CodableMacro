import SwiftSyntaxMacrosTestSupport
import XCTest

/// ValueCoder 분기 — Double / Bool (Int·String은 다른 파일·기본 테스트와 중복 최소화)
final class ValueCoderMacroExpansionTests: XCTestCase {

    func test_valueCoder_double_coercesFromStringAndInt() throws {
        assertMacroExpansion(
            """
            @Codable
            struct S: Sendable {
                var score: Double
            }
            """,
            expandedSource: """
            struct S: Sendable {
                var score: Double
            }

            extension S: Decodable {
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
                }
            }

            extension S: Encodable {
                func encode(to encoder: any Encoder) throws {
                    var container = encoder.container(keyedBy: CodingKeys.self)

                    try container.encode(self.score, forKey: CodingKeys.score)
                }
            }

            extension S {
                enum CodingKeys: String, CodingKey {
                    case score = "score"
                }
            }

            """,
            macros: CodableMacroTestSupport.macros
        )
    }

    func test_valueCoder_bool_coercesFromIntAndString() throws {
        assertMacroExpansion(
            """
            @Codable
            struct S: Sendable {
                var flag: Bool
            }
            """,
            expandedSource: """
            struct S: Sendable {
                var flag: Bool
            }

            extension S: Decodable {
                init(from decoder: any Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)

                    if let v = try? container.decodeIfPresent(Bool.self, forKey: CodingKeys.flag) {
                        self.flag = v
                    } else if let v = try? container.decodeIfPresent(Int.self, forKey: CodingKeys.flag) {
                        self.flag = v != 0
                    } else if let s = try? container.decodeIfPresent(String.self, forKey: CodingKeys.flag) {
                        self.flag = s.lowercased() == "true" || s == "1" || s.lowercased() == "yes" || s.lowercased() == "y"
                    } else {
                        self.flag = false
                    }
                }
            }

            extension S: Encodable {
                func encode(to encoder: any Encoder) throws {
                    var container = encoder.container(keyedBy: CodingKeys.self)

                    try container.encode(self.flag, forKey: CodingKeys.flag)
                }
            }

            extension S {
                enum CodingKeys: String, CodingKey {
                    case flag = "flag"
                }
            }

            """,
            macros: CodableMacroTestSupport.macros
        )
    }
}
