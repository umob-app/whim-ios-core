//
//  CLAuthorizationStatusExtensions.swift
//  WhimUtils
//
//  Created by Do Duc on 26/06/2019.
//

import CoreLocation

public extension CLAuthorizationStatus {
    var isAuthorized: Bool {
        return self.rawValue > CLAuthorizationStatus.denied.rawValue
    }
}
