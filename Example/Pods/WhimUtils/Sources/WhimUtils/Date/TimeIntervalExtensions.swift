//
//  TimeInterval+Extensions.swift
//  whim-ios
//
//  Created by Anton Zvonkov on 06/06/16.
//  Copyright © 2016 maas. All rights reserved.
//

import Foundation

func rounding(_ value: Double, toNearest: Double) -> Double {
    return round(value / toNearest) * toNearest
}

extension TimeInterval {

    init(days: Int) {
        self = Double(days * 86400)
    }

    init(hours: Int) {
        self = Double(hours * 3600)
    }

    init(minutes: Int) {
        self = Double(minutes * 60)
    }
    
    public var months: String? {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        formatter.zeroFormattingBehavior = .default
        
        formatter.allowedUnits = [.month]
        return formatter.string(from: self)
    }

    /// 5 days
    public var days: String? {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .full
        formatter.zeroFormattingBehavior = .default

        formatter.allowedUnits = [.day]
        let roundedValue = rounding(self, toNearest: TimeInterval(days: 1))
        return formatter.string(from: roundedValue)
    }

    /// 3h 52min
    public var hoursMin: String? {
        return format(to: .short)
    }

    /// 99 mins
    public var mins: String? {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .short
        formatter.zeroFormattingBehavior = .default

        formatter.allowedUnits = [.minute]
        return formatter.string(from: self)
    }

    /// .full -> 3 hours 53 minutes, .short -> 3h 53min
    public func format(to unitStyle: DateComponentsFormatter.UnitsStyle, allowedUnits: NSCalendar.Unit = [.day, .hour, .minute], maximumUnitCount: Int = 0) -> String? {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = unitStyle
        formatter.zeroFormattingBehavior = .default
        formatter.maximumUnitCount = maximumUnitCount

        formatter.allowedUnits = allowedUnits
        return formatter.string(from: self)?.replacingOccurrences(of: ",", with: "")
    }

    public var validString: String? {
        if self > 3.days.timeInterval {
            return days
        }

        if self > 90.minutes.timeInterval {
            return format(to: .short)
        }

        return mins
    }

    /// Less or equal than 24 hours -> 8h, 10 hours 30 mins, 24 hours
    /// More than that, days would be displayed ->  2days
    public var packageValidity: String? {
        if self > 1.days.timeInterval {
            return format(to: .short)
        }

        if self > 90.minutes.timeInterval {
            return format(to: .short, allowedUnits: [.hour, .minute])
        }

        return mins
    }
}
