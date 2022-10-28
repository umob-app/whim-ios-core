//
//  Cachable.swift
//  WhimUtils
//
//  Created by Do Duc on 14/05/2019.
//

import Foundation
import CoreLocation

public struct Cache: Cacheable {
    public var policies: [CachePolicy]
    public var lastTimestamp: Date?
    public var lastLocation: CLLocation?

    public init(policies: [CachePolicy]) {
        self.policies = policies
    }
}

public protocol Cacheable {
    var policies: [CachePolicy] { get }
    var lastTimestamp: Date? { get set }
    var lastLocation: CLLocation? { get set }
}

extension Cacheable {

    /// Check if data need to be updated from API, update new location and timestamp if return true
    mutating public func isUpdateRequired(newLocation: CLLocation?) -> Bool {
        if policies.first(where: { !checkValidity(policy: $0, newLocation: newLocation) }) != nil {
            updateCacheProperties(newLocation: newLocation)
            return true
        }

        return false
    }

    /// Return false if update is needed
    private func checkValidity(policy: CachePolicy, newLocation: CLLocation?) -> Bool {
        switch policy {
        case .nothing:
            return false
        case let .distance(cooldownDistance):
            guard let lastLocation = lastLocation, let newLocation = newLocation else {
                return false
            }
            
            return lastLocation.distance(from: newLocation) <= cooldownDistance
        case let .time(cooldownTime):
            guard let lastTimestamp = lastTimestamp else {
                return false
            }

            return Date().timeInterval(since: lastTimestamp) <= cooldownTime
        }
    }

    mutating private func updateCacheProperties(newLocation: CLLocation?) {
        self.lastLocation = newLocation
        self.lastTimestamp = Date()
    }
}
