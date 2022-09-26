// original: https://github.com/apple/swift-package-manager/blob/master/swift-tools-support-core/Tests/TSCBasicTests/OrderedSetTests.swift

/*
 This source file is part of the Swift.org open source project

 Copyright 2016 Apple Inc. and the Swift project authors
 Licensed under Apache License v2.0 with Runtime Library Exception

 See http://swift.org/LICENSE.txt for license information
 See http://swift.org/CONTRIBUTORS.txt for Swift project authors
*/

import XCTest
@testable import WhimCore

class OrderedSetTests: XCTestCase {
    func testBasics() {
        // Create an empty set.
        var set = OrderedSet<String>()
        XCTAssertTrue(set.isEmpty)
        XCTAssertEqual(set.contents, [])

        // Create a new set with some strings.
        set = OrderedSet(["one", "two", "three"])
        XCTAssertFalse(set.isEmpty)
        XCTAssertEqual(set.count, 3)
        XCTAssertEqual(set[0], "one")
        XCTAssertEqual(set[1], "two")
        XCTAssertEqual(set[2], "three")
        XCTAssertEqual(set.contents, ["one", "two", "three"])

        // Try adding the same item again - the set should be unchanged.
        XCTAssertEqual(set.append("two"), false)
        XCTAssertEqual(set.count, 3)
        XCTAssertEqual(set[0], "one")
        XCTAssertEqual(set[1], "two")
        XCTAssertEqual(set[2], "three")

        // Remove the last element.
        let three = set.removeLast()
        XCTAssertEqual(set.count, 2)
        XCTAssertEqual(set[0], "one")
        XCTAssertEqual(set[1], "two")
        XCTAssertEqual(three, "three")

        // Remove all the objects.
        set.removeAll(keepingCapacity: true)
        XCTAssertEqual(set.count, 0)
        XCTAssertTrue(set.isEmpty)
        XCTAssertEqual(set.contents, [])

        set.append("Hello")
        XCTAssertEqual(set.remove("Hello"), "Hello")
        XCTAssertEqual(set.remove("Hello"), nil)
        XCTAssertEqual(set.remove("cool"), nil)
    }

    func testUpdate() {
        var set = OrderedSet<S>([S(x: 0, y: "a"), S(x: 1, y: "b"), S(x: 2, y: "c")])
        set.update(with: S(x: 1, y: "1"))

        XCTAssertEqual(set.count, 3)
        XCTAssertEqual(set[1].y, "1")

        set.update(with: S(x: 3, y: "d"))
        XCTAssertEqual(set.count, 4)
        XCTAssertEqual(set[3].y, "d")
    }
}

private struct S: Equatable, Hashable {
    let x: Int
    let y: String

    static func == (lhs: S, rhs: S) -> Bool {
        lhs.x == rhs.x
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(x)
    }
}
