/// Loading status consisting of multiple steps.
///
/// - Idle: Passive initial state, doesn't contain any value.
///
/// - Loading: Optional type that represents two cases:
///   * nil means we're in a loading state without any successfully preceding case:
///
///     `idle -> loading(nil)`
///
///   * value means we're in a loading state with previous successfully loaded value:
///
///     `idle -> loading(nil) -> loaded(value) -> loading(value)`
///
/// - Loaded: Always contains currently loaded value.
///
///     `idle -> loading(nil) -> loaded(value)`
///
/// - Failed: Optional type that represents two cases:
///
///   * nil means we're in a failed state without any successfully preceding case:
///
///     `idle -> loading(nil) -> failed(nil, err)`
///
///   * value means we're in a failed state with previous successfully loaded value:
///
///     `idle -> loading(nil) -> loaded(value) -> loading(value) -> failed(value, err)`
///
enum LoadingStatus<Value, Failure: Error> {
    case idle
    case loading(Value?)
    case loaded(Value)
    case failed(Value?, Failure)

    static var initial: LoadingStatus { .idle }
}

extension LoadingStatus {
    var isIdle: Bool {
        guard case .idle = self else { return false }
        return true
    }

    var isLoading: Bool {
        guard case .loading = self else { return false }
        return true
    }

    var isLoaded: Bool {
        guard case .loaded = self else { return false }
        return true
    }

    var isFailed: Bool {
        guard case .failed = self else { return false }
        return true
    }

    var loadingValue: Value? {
        guard case let .loading(value) = self else { return nil }
        return value
    }

    var loadedValue: Value? {
        guard case let .loaded(value) = self else { return nil }
        return value
    }

    var failedValue: Value? {
        guard case let .failed(value, _) = self else { return nil }
        return value
    }

    var error: Failure? {
        guard case let .failed(_, error) = self else { return nil }
        return error
    }
}

extension LoadingStatus {
    var isStarted: Bool {
        return !isIdle
    }

    var isFinished: Bool {
        return isLoaded || isFailed
    }

    var finishedResult: Result<Value, Failure>? {
        return switch self {
        case .idle, .loading: nil
        case let .loaded(value): .success(value)
        case let .failed(_, error): .failure(error)
        }
    }

    var value: Value? {
        return switch self {
        case .idle: nil
        case let .loaded(value): value
        case let .loading(value), let .failed(value, _): value
        }
    }
}

extension LoadingStatus {
    @discardableResult
    mutating func startLoading(keepingValue: Bool = true) -> Bool {
        guard !isLoading else { return false }
        self = .loading(keepingValue ? value : nil)
        return true
    }

    @discardableResult
    mutating func finish(with result: Result<Value, Failure>, keepValueIfFailed: Bool = true, force: Bool = false) -> Bool {
        guard isLoading || force else { return false }
        self = switch result {
        case let .success(value): .loaded(value)
        case let .failure(error): .failed(keepValueIfFailed ? value : nil, error)
        }
        return true
    }
}

extension LoadingStatus {
    func map<U>(_ transform: (Value) -> U) -> LoadingStatus<U, Failure> {
        return switch self {
        case .idle: .idle
        case let .loading(value): .loading(value.map(transform))
        case let .loaded(value): .loaded(transform(value))
        case let .failed(value, error): .failed(value.map(transform), error)
        }
    }

    func compactMap<U>(_ transform: (Value) -> U?) -> LoadingStatus<U, Failure>? {
        switch self {
        case .idle:
            return .idle
        case let .loading(value):
            guard let value = value else { return .loading(nil) }
            return transform(value).map { .loading($0) }
        case let .loaded(value):
            return transform(value).map { .loaded($0) }
        case let .failed(value, error):
            guard let value = value else { return .failed(nil, error) }
            return transform(value).map { .failed($0, error) }
        }
    }
}

extension LoadingStatus: Equatable where Value: Equatable, Failure: Equatable {}
extension LoadingStatus: Hashable where Value: Hashable, Failure: Hashable {}

typealias DemoLoadingStatus<Value> = LoadingStatus<Value, DemoError>
