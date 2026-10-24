import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros

public struct OnceError: Error, CustomStringConvertible {
    public var description: String
    init(_ description: String) {
        self.description = description
    }
}

public struct OnceMacro: BodyMacro, PeerMacro {
    public static func expansion(
        of node: SwiftSyntax.AttributeSyntax,
        providingPeersOf declaration: some SwiftSyntax.DeclSyntaxProtocol,
        in context: some SwiftSyntaxMacros.MacroExpansionContext
    ) throws -> [SwiftSyntax.DeclSyntax] {
        let function = try functionDeclaration(from: declaration, context: context)
        let signature = function.signature
        let result = signature.returnClause?.type.trimmedDescription ?? "Void"
        let failure = signature.effectSpecifiers?.throwsClause == nil ? "Never" : "any Error"
        let propertyName = propertyName(from: function)
        let workName = Self.propertyName(from: function, prefix: "work")
        return [
            """
            private var \(raw: propertyName): Swift::Task<\(raw: result), \(raw: failure)>? = nil
            """,
            """
            private func \(raw: workName)() -> Swift::Task<\(raw: result), \(raw: failure)> {
                .init { [self] in
                    \(function.body!.statements.trimmed)
                }
            }
            """
        ]
    }

    public static func expansion(
        of node: SwiftSyntax.AttributeSyntax,
        providingBodyFor declaration: some SwiftSyntax.DeclSyntaxProtocol & SwiftSyntax.WithOptionalCodeBlockSyntax,
        in context: some SwiftSyntaxMacros.MacroExpansionContext
    ) throws -> [SwiftSyntax.CodeBlockItemSyntax] {
        let function = try functionDeclaration(from: declaration, context: context)
        let tryKeyword = function.signature.effectSpecifiers?.throwsClause == nil ? "" : "try "
        let propertyName = propertyName(from: function)
        let workName = Self.propertyName(from: function, prefix: "work")
        return[
        """
        let task = \(raw: propertyName) ?? \(raw: workName)()
        self.\(raw: propertyName) = task
        return \(raw: tryKeyword) await task.value
        """
        ]
    }

    static func propertyName(
        from declaration: FunctionDeclSyntax,
        prefix: String? = nil
    ) -> String {
        "_once_\(prefix.map { "\($0)_" } ?? "" )\(declaration.name.text.filter { $0 != "`" })"
    }

    static func functionDeclaration(
        from declaration: some SwiftSyntax.DeclSyntaxProtocol,
        context: some SwiftSyntaxMacros.MacroExpansionContext
    ) throws -> FunctionDeclSyntax {
        guard let function = declaration.as(FunctionDeclSyntax.self),
              function.body != nil else {
            throw OnceError("@Once must be attached to a non empty function")
        }
        guard function.signature.parameterClause.parameters.isEmpty,
              function.genericParameterClause == nil,
              function.genericWhereClause == nil else {
            throw OnceError("@Once requires a parameterless, non-generic method; argument-keyed memoization is a different policy")
        }
        let forbidden = ["static", "class", "nonisolated", "mutating", "override"]
        guard !function.modifiers.contains(where: { forbidden.contains($0.name.text) }) else {
            throw OnceError("@Once requires an isolated instance method")
        }
        if let throwsClause = function.signature.effectSpecifiers?.throwsClause,
           throwsClause.type != nil || throwsClause.throwsSpecifier.text == "rethrows" {
            throw OnceError("@Once supports untyped throws only")
        }
        guard let owner = context.lexicalContext.first(where: {
            $0.is(ActorDeclSyntax.self) || $0.is(ClassDeclSyntax.self) ||
            $0.is(StructDeclSyntax.self) || $0.is(ExtensionDeclSyntax.self) ||
            $0.is(FunctionDeclSyntax.self)
        }) else {
            throw OnceError("@Once must be declared directly inside an actor or @MainActor final class")
        }
        if !owner.is(ActorDeclSyntax.self) {
            guard let type = owner.as(ClassDeclSyntax.self),
                  type.modifiers.contains(where: { $0.name.text == "final" }),
                  type.attributes.contains(where: {
                      guard let attribute = $0.as(AttributeSyntax.self) else { return false }
                      return ["MainActor", "_Concurrency.MainActor"].contains(attribute.attributeName.trimmedDescription)
                  }) else {
                throw OnceError("@Once requires an actor or an explicitly @MainActor final class to serialize cache access")
            }
        }
        return function
    }
}

@main
struct OncePlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        OnceMacro.self,
    ]
}

