//
//  CachePolicy.swift
//  WhimUtils
//
//  Created by Do Duc on 14/05/2019.
//

import Foundation
import CoreLocation

public enum CachePolicy {

    /// Always return fresh data, no caching at all, this will by pass other conditions
    case nothing

    /// Fetch new data if the new location is more than constraint distance than last time it cached.
    /// Unit in meter
    case distance(CLLocationDistance)

    /// Fetch new data if the old data is expired.
    /// Unit in second
    case time(TimeInterval)
}
