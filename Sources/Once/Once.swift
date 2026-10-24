@attached(body)
@attached(peer, names: prefixed(_once_), prefixed(_once_work_))
public macro Once() = #externalMacro(module: "OnceMacros", type: "OnceMacro")
