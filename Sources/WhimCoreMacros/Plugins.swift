import SwiftCompilerPlugin
import SwiftSyntaxMacros

@main
struct WhimCoreMacrosPlugin: CompilerPlugin {
  let providingMacros: [any Macro.Type] = [
    ServiceMacro.self,
  ]
}
