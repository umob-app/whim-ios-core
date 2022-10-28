//
//  URL+Extensions.swift
//  tallink-ios
//
//  Created by Anton Zvonkov on 08/02/16.
//  Copyright © 2016 Maas. All rights reserved.
//

import Foundation

enum URLScheme {
    static let email: String = "mailto"
    static let tel: String = "tel"
}

private func < <T: Comparable>(lhs: T?, rhs: T?) -> Bool {
    switch (lhs, rhs) {
    case let (l?, r?):
        return l < r
    case (nil, _?):
        return true
    default:
        return false
    }
}

private func > <T: Comparable>(lhs: T?, rhs: T?) -> Bool {
    switch (lhs, rhs) {
    case let (l?, r?):
        return l > r
    default:
        return rhs < lhs
    }
}

public extension URL {
    var parameters: [String: String]? {
        guard let queryItems = URLComponents(url: self, resolvingAgainstBaseURL: true)?.queryItems else { return nil }
        let items = queryItems.compactMap { item -> (String, String)? in
            guard let value = item.value else { return nil }
            return (item.name, value)
        }
        return Dictionary(items, uniquingKeysWith: { (first, _) in first })
    }
    
    var email: String? {
        return scheme == URLScheme.email ? URLComponents(url: self, resolvingAgainstBaseURL: false)?.path : nil
    }
    
    var tel: String? {
        return scheme == URLScheme.tel ? URLComponents(url: self, resolvingAgainstBaseURL: false)?.path : nil
    }
    
    /// Path to document directory
    static var documentDirectory: URL? {
        return directory(.documentDirectory)
    }

    static var applicationSupportDirectory: URL? {
        return directory(.applicationSupportDirectory)
    }

    static func directory(_ directory: FileManager.SearchPathDirectory) -> URL? {
        return FileManager.default.urls(for: directory, in: .userDomainMask).first
    }
}
