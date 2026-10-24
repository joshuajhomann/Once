import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacrosTestSupport
import Testing

// Macro implementations build for the host, so the corresponding module is not available when cross-compiling. Cross-compiled tests may still make use of the macro itself in end-to-end tests.
#if canImport(OnceMacros)
import OnceMacros
import Once
actor Storage {
    var count = 0
    func increment() {
        count += 1
    }
}

actor Loader {
    var storage: Storage
    init(storage: Storage) {
        self.storage = storage
    }
    @Once
    func load() async {
        await storage.increment()
    }
}
#endif

@Test("Work executes once", arguments: 1...3)
func workExecutesOnce(count: Int) async {
    let storage = Storage()
    let loader = Loader(storage: storage)
    for _ in 0..<count  {
        await loader.load()
    }
    let count = await storage.count
    #expect(count == 1)
}

