/// Basically wrapping a function into an object to give it an identity (conform to Equatable).
public final class FunctionObject<Input, Output>: Hashable {
    private let execute: (Input) -> Output

    public init(_ execute: @escaping (Input) -> Output) {
        self.execute = execute
    }

    public convenience init(_ output: Output) {
        self.init { _ in output } 
    }

    public func callAsFunction(_ arg: Input) -> Output {
        return execute(arg)
    }

    public static func == (lhs: FunctionObject, rhs: FunctionObject) -> Bool {
        return ObjectIdentifier(lhs) == ObjectIdentifier(rhs)
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(ObjectIdentifier(self))
    }
}
