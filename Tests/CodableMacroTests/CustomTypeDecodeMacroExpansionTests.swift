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
            enum Kind: String, Codable { case a
            }

            extension S: Decodable {
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

            extension S: Encodable {
                func encode(to encoder: any Encoder) throws {
                    var container = encoder.container(keyedBy: CodingKeys.self)

                    try container.encode(self.kind, forKey: CodingKeys.kind)
                }
            }

            extension S {
                enum CodingKeys: String, CodingKey {
                    case kind = "kind"
                }
            }

            """,
            macros: CodableMacroTestSupport.macros
        )
    }

    func test_optionalEnum_tryDecodeIfPresent() throws {
        assertMacroExpansion(
            """
            @Codable
            struct S: Sendable {
                var kind: Kind?
            }
            enum Kind: String, Codable { case a, b }
            """,
            expandedSource: """
            struct S: Sendable {
                var kind: Kind?
            }
            enum Kind: String, Codable { case a, b 
            }

            extension S: Decodable {
                init(from decoder: any Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)

                    self.kind = try? container.decodeIfPresent(Kind.self, forKey: CodingKeys.kind)
                }
            }

            extension S: Encodable {
                func encode(to encoder: any Encoder) throws {
                    var container = encoder.container(keyedBy: CodingKeys.self)

                    try container.encodeIfPresent(self.kind, forKey: CodingKeys.kind)
                }
            }

            extension S {
                enum CodingKeys: String, CodingKey {
                    case kind = "kind"
                }
            }

            """,
            macros: CodableMacroTestSupport.macros
        )
    }

    func test_enumWithDefault_decodeIfPresentWithCatch() throws {
        assertMacroExpansion(
            """
            @Codable
            struct S: Sendable {
                @Default(Kind.a)
                var kind: Kind
            }
            enum Kind: String, Codable { case a, b }
            """,
            expandedSource: """
            struct S: Sendable {
                var kind: Kind
            }
            enum Kind: String, Codable { case a, b 
            }

            extension S: Decodable {
                init(from decoder: any Decoder) throws {
                    let container = try decoder.container(keyedBy: CodingKeys.self)

                    do {
                        self.kind = try container.decodeIfPresent(Kind.self, forKey: CodingKeys.kind) ?? Kind.a
                    }
                    catch {
                        self.kind = Kind.a
                    }
                }
            }

            extension S: Encodable {
                func encode(to encoder: any Encoder) throws {
                    var container = encoder.container(keyedBy: CodingKeys.self)

                    try container.encode(self.kind, forKey: CodingKeys.kind)
                }
            }

            extension S {
                enum CodingKeys: String, CodingKey {
                    case kind = "kind"
                }
            }

            """,
            macros: CodableMacroTestSupport.macros
        )
    }
}
