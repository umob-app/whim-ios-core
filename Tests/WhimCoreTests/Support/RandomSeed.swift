import Foundation
import WhimRandom

// We need randomizer in tests not to bother and waste time creating values for tests.
// But the bigger idea is to be able to always run tests with different data so we can find corner cases we didn't think of before.
// It's not yet Property-based testing, but it's great for starters.

public var R = Xoroshiro()

// The second thing we need is seed that was used to start-off Randomizer.
// We can use this information to replay test suit with given seed again and again to reproduce tests cases.

// This class is called before whole tests suite
// in order to give clear understanding of seed which is used for creating randomizer.
// Set in `WhimCore-Unit-Tests-Info.plist` by `Principal Class` key,
// and is re-set automatically with every `pod install` because it's described in `WhimCore.podspec` for `Tests` test-spec.

@objc
final class RandomSeed: NSObject {
    private let seedMessage = { (seed: String) in #"""

    ************************************************************************************************************************
                                         ____                         __
                    ____                /\  _`\                      /\ \
                   /\' .\    _____      \ \ \L\ \     __      ___    \_\ \    ___     ___ ___
                  /: \___\  / .  /\      \ \ ,  /   /'__`\  /' _ `\  /'_` \  / __`\ /' __` __`\
                  \' / . / /____/..\      \ \ \\ \ /\ \L\.\_/\ \/\ \/\ \L\ \/\ \L\ \/\ \/\ \/\ \
                   \/___/  \'  '\  /       \ \_\ \_\ \__/.\_\ \_\ \_\ \___,_\ \____/\ \_\ \_\ \_\
                            \'__'\/         \/_/\/ /\/__/\/_/\/_/\/_/\/__,_ /\/___/  \/_/\/_/\/_/

    To replay tests suite with the same RNG sequence, go to 'Support/Random.swift' and create randomizer with this seed:

    `public var R = Xoroshiro(seed: \#(seed))`

    ************************************************************************************************************************

    """#
    }

    override init() {
        super.init()

        let seed = "\(R.state)"
        print(seedMessage(seed))
    }
}
