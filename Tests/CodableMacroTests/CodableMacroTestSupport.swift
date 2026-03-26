import SwiftSyntaxMacros
import CodableMacroImpl

/// 모든 매크로 확장 테스트에서 공유하는 매크로 등록입니다.
enum CodableMacroTestSupport {
    static let macros: [String: Macro.Type] = [
        "Codable": CodableMacro.self,
        "Default": DefaultMacro.self,
        "CodedAt": CodedAtMacro.self,
        "CodedAs": CodedAsMacro.self,
        "Ignore": IgnoreMacro.self,
        "CodedIn": CodedInMacro.self,
    ]
}
