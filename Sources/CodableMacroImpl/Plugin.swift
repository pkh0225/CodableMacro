import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct CodableMacroPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        CodableMacro.self,
        CodedAtMacro.self,
        CodedAsMacro.self,
        DefaultMacro.self,
        IgnoreMacro.self,
        CodedInMacro.self,
    ]
}
