import Foundation

public typealias WhimSortDescriptor<Value> = (Value, Value) -> Bool

public func combine<Value>(sortDescriptors: [WhimSortDescriptor<Value>]) -> WhimSortDescriptor<Value> {
    return { lhs, rhs in
        for descriptor in sortDescriptors {
            if descriptor(lhs, rhs) { return true }
            if descriptor(rhs, lhs) { return false }
        }
        return false
    }
}
