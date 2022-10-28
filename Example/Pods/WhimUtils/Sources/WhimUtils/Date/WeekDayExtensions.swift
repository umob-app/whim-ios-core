//
//  WeekDay.swift
//  whim-ios
//
//  Created by Do Duc on 14/03/2017.
//  Copyright © 2017 maas. All rights reserved.
//

import Foundation
import SwiftDate

extension WeekDay {
    init?(stringValue: String) {
        switch stringValue {
            case "sunday": self = .sunday
            case "monday": self = .monday
            case "tuesday": self = .tuesday
            case "wednesday": self = .wednesday
            case "thursday": self = .thursday
            case "friday": self = .friday
            case "saturday": self = .saturday
            default: return nil
        }
    }
}

public enum RelativeDay: String {
    case today
    case tomorrow
}

public extension Date {

    /// Return a day base on weekday/today/tomorrow with start hour default value 9am
    /// If relative date is weekday, and is the same day as today, return next week result
    static func dateFromString(relativeStartTime: String?, startTimeAtHour: String?) -> Date? {
        guard let relativeStartTime = relativeStartTime else {
            return nil
        }

        let startHour = startTimeAtHour?.intValue ?? 9

        if let weekday = WeekDay(stringValue: relativeStartTime) {
            let nextWeekDay = Date.next(weekday: weekday, hour: startHour)
            if nextWeekDay?.isInSameDayOf(date: Date()) == true {
                return Date.next(weekday: weekday, hour: startHour, startFrom: 1.days.fromNow)
            }

            return nextWeekDay
        }

        switch RelativeDay(rawValue: relativeStartTime) {
            case .today:
                return Date.today(at: startHour)
            case .tomorrow:
                return Date.tomorrow(at: startHour)
            default:
                return nil
        }
    }

    static func next(weekday: WeekDay, hour: Int = 0, startFrom: Date = Date()) -> Date? {
        // Get the next day matching this weekday
        let components = DateComponents(hour: hour, weekday: weekday.rawValue)

        return Calendar.current.nextDate(after: startFrom, matching: components, matchingPolicy: .nextTime)
    }

    static func today(at hour: Int) -> Date? {
        return Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: Date())
    }

    static func tomorrow(at hour: Int) -> Date? {
        guard let today = today(at: hour) else {
            return nil
        }

        return Calendar.current.date(byAdding: .day, value: 1, to: today)
    }
    
    static var weekendStart: Date {
        return next(weekday: .friday, hour: 15, startFrom: Date())!
    }
    
    static var weekendEnd: Date {
        return next(weekday: .monday, hour: 9, startFrom: weekendStart)!
    }
        
    func next(days: Int = 1, atHour: Int) -> Date? {
        if let nextDay = Calendar.current.date(byAdding: .day, value: days, to: self) {
            var components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: nextDay)
            components.setValue(0, for: .minute)
            
            components.setValue(atHour, for: .hour)
            
            return Calendar.current.date(from: components)
        }
        
        return nil
    }
    
    static func datesWithinExtendedWeekend(_ optionalDates: [Date?], startingOnFridayAt startHour: Int = 15, endingOnMondayAt endHour: Int = 14) -> Bool {
        // Check if dates are within any weekends (fri klo 15 -> mon klo 14)
        let dates = optionalDates.compactMap({ $0 })
        guard let firstDate = dates.first else { return false}
        let calendar = Calendar.current
        
        func datesOnWeekend(_ weekend: DateInterval) -> Bool {
            let weekendStart = weekend.start.subtract(with: (24-startHour).hours)
            let weekendEnd = weekend.end.add(with: endHour.hours)
            return dates.filter({ !$0.isBetween(weekendStart, and: weekendEnd) }).isEmpty
        }
        
        if let weekend = calendar.dateIntervalOfWeekend(containing: firstDate), datesOnWeekend(weekend) {
            return true
        } else if let weekend = calendar.nextWeekend(startingAfter: firstDate, direction: .forward), datesOnWeekend(weekend) {
            return true
        } else if let weekend = calendar.nextWeekend(startingAfter: firstDate, direction: .backward), datesOnWeekend(weekend) {
            return true
        }
        
        return false
    }
}
