# Once

Example project for the [A Flock of Swifts](http://aflockofswifts.org) meetup on October 24, 2026.

This Swift package demonstrates `@Once`, a macro that memoizes work that should be done only once. The first call creates and stores a task; subsequent calls await that same task and reuse its result, including any thrown error.

## Before: cache the task manually

To load a profile only once per view model instance, store the task so repeated calls share the same work. These examples assume an existing `IUserService` with an asynchronous `fetchUserName()` method that returns a `String`.

```swift
@MainActor
final class ProfileViewModel {
    private(set) var userName = ""
    private let userService: any IUserService
    private var loadingTask: Task<Void, Never>? = nil

    init(userService: any IUserService) {
        self.userService = userService
    }

    func load() async {
        let task = loadingTask ?? Task {
            userName = await userService.fetchUserName()
        }
        loadingTask = task
        await task.value
    }
}
```

## After: let `@Once` manage the task

The macro generates the task storage and reuse logic, leaving the method focused on its work.

```swift
import Once

@MainActor
final class ProfileViewModel {
    private(set) var userName = ""
    private let userService: any IUserService

    init(userService: any IUserService) {
        self.userService = userService
    }

    @Once
    func load() async {
        userName = await userService.fetchUserName()
    }
}
```

In both versions, overlapping calls await the same task, and calls after completion reuse its result. The work runs once per view model instance.

The macro is designed for parameterless, non-generic instance methods declared directly in an actor or an explicitly `@MainActor` final class, which serializes access to the cached task.

The package includes the macro declaration in `Sources/Once`, its implementation in `Sources/OnceMacros`, an executable example in `Sources/OnceClient`, and tests in `Tests/OnceTests`. The executable calls a loader twice and prints `1`, demonstrating that the underlying work runs only once.
