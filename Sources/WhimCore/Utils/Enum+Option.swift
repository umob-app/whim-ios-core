/// Allows enums to behave like OptionSet.
///
/// Main motivation for this is that it has `allCases` out of the box
/// and it's much easier to pick random case.
///
/// It has no impact on existing OptionSet usage.
///
/// Inspired by: [NSHipster OptionSet-Option](https://nshipster.com/optionset/#a-fresh-take-on-an-old-classic)
public protocol Option: RawRepresentable, Hashable, CaseIterable {}

extension Set where Element: Option {
    public static var all: Set<Element> {
        Set(Element.allCases)
    }
}
