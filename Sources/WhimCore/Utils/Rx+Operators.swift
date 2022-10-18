import RxSwift

public extension ObservableType {
    /// Groups the elements of the source observable into tuples of the previous and current elements.
    ///
    /// - Parameter seed: Optional initial value.
    /// - Returns: The resulting observable which:
    ///   - if given a seed, starts emiting values once the source observable emits at least 1 element;
    ///   - if not given a seed, does not emit anything until the source observable emits at least 2 elements;
    ///   - emits a tuple for every element after that, consisting of the previous and the current item;
    ///   - forwards any error or completed events.
    ///
    /// - Example:
    /// ```
    /// --(1)---(2)---(3)------(4)-------(5)------->
    ///  |
    ///  | pairwise(seed: 0)
    ///  v
    /// --(0,1)-(1,2)-(2,3)----(3,4)-----(4,5)----->
    /// ```
    ///
    /// ```
    /// --(1)--(2)---(3)------(4)-------(5)------->
    ///  |
    ///  | pairwise()
    ///  v
    /// -------(1,2)-(2,3)----(3,4)-----(4,5)----->
    /// ```
    func pairwise(seed: Element? = nil) -> Observable<(Element, Element)> {
        return self
            .scan(into: (seed, seed), accumulator: { acc, value in
                acc = (acc.1, value)
            })
            .skip(1)
            .compactMap(WhimCore.zip)
    }
}
