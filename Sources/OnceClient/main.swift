import Once

actor Storage {
    var count = 0
    func load() {
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
        await storage.load()
    }
}

let storage = Storage()
let loader = Loader(storage: storage)
await loader.load()
await loader.load()
let count = await storage.count
print(count)
