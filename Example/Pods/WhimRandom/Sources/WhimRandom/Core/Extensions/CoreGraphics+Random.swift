import CoreGraphics

extension CGPoint: Random {
    public static func random<G: RandomNumberGenerator>(using generator: inout G) -> CGPoint {
        CGPoint(
            x: CGFloat.random(in: 0.0 ... .greatestFiniteMagnitude, using: &generator),
            y: CGFloat.random(in: 0.0 ... .greatestFiniteMagnitude, using: &generator)
        )
    }
}

extension CGFloat: Random {
    public static func random<G: RandomNumberGenerator>(using generator: inout G) -> CGFloat {
        return .random(in: .leastNormalMagnitude ... .greatestFiniteMagnitude, using: &generator)
    }
}

extension CGLineCap: CaseIterable, Random {
    public typealias AllCases = [CGLineCap]

    public static var allCases: AllCases {
        [.butt, .round, .square]
    }

    public static func random<G: RandomNumberGenerator>(using generator: inout G) -> CGLineCap {
        allCases.randomElement(using: &generator)!
    }
}

extension CGLineJoin: CaseIterable, Random {
    public typealias AllCases = [CGLineJoin]

    public static var allCases: AllCases {
        [.miter, .round, .bevel]
    }

    public static func random<G: RandomNumberGenerator>(using generator: inout G) -> CGLineJoin {
        allCases.randomElement(using: &generator)!
    }
}
