//
//  Date+Extensions.swift
//  
//
//  Created by Anton Zvonkov on 04/04/16.
//
//

import Foundation
import CoreGraphics
import SwiftDate

public extension Date {
	var apiFormat: Int64 {
		return Int64(self.timeIntervalSince1970*1000)
	}

	static var yesterday: Date {
		return Calendar.current.date(byAdding: .day, value: -1, to: Date().noon)!
	}

	var noon: Date {
		return Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: self)!
	}

	func dayMonthYearFormat() -> String {
		return DateFormatterHelper.shared.formatMediumDateStyleString(from: self)
	}

	func setTime(hour: Int, mins: Int) -> Date {
		let calendar = Calendar.current

		let dateComponents = calendar.dateComponents([.year, .month, .day], from: self)

		var mergedComponents = DateComponents()
		mergedComponents.year = dateComponents.year
		mergedComponents.month = dateComponents.month
		mergedComponents.day = dateComponents.day
		mergedComponents.hour = hour
		mergedComponents.minute = mins
		mergedComponents.second = 0

		return calendar.date(from: mergedComponents)!
	}

	/// Today or Tomorrow or 11/06/2019
	var dayAndYearFormat: String {
		return DateFormatterHelper.shared.formatRelativeShortDateStyleString(from: self)
	}

	/// 11 Jun 2019
	var dayAndYearFormatLong: String {
		return DateFormatterHelper.shared.formatDayMonthYearString(from: self)
	}

	static var birthdayFormatter: DateFormatter {
		let dateFormatter = DateFormatter()
		dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
		dateFormatter.setLocalizedDateFormatFromTemplate("dd.MM.yyyy")
		return dateFormatter
	}

	/// 11 July 2018 in your time locale
	var birthdayFormat: String {
		return Date.birthdayFormatter.string(from: self)
	}

	/// Time in format HH:mm
	func hourMinuteFormat() -> String {
		return DateFormatterHelper.shared.formatHourMinuteString(from: self)
	}

	/// Weekday as a single char, example - M
	var weekdayFormat: String {
		return DateFormatterHelper.shared.formatWeekdayOneCharString(from: self)
	}

	/// February 2022
	var monthYearFormat: String {
		return DateFormatterHelper.shared.formatMonthYearString(from: self)
	}

	func roundToNextMin(_ min: Int) -> Date? {
		let calendar = Calendar.current
		let minutes = calendar.component(.minute, from: self)

		let minuteUnit = Int(ceil(Double(minutes)/Double(min))) * min
		if minuteUnit == 60 {
			let hours = calendar.component(.hour, from: self) + 1
			return calendar.date(bySettingHour: hours, minute: 0, second: 0, of: self)
		}

		return calendar.date(bySetting: .minute, value: minuteUnit, of: self)
	}

	func minDiffence(_ toDate: Date) -> Int? {
		let calendar = Calendar.current

		let components = calendar.dateComponents([.minute], from: self, to: toDate)

		return components.minute
	}

	/// More than 3 days --> show nothing, More than 90 min --> xx hour xx min, More than 90 min --> xx hour xx min, Less than 90 mins --> xx mins
	var validForString: String {
		let timeDiff = timeIntervalSinceNow

		// More than 3 days --> show nothing
		if timeDiff >= 3.days.timeInterval {
			return ""
		}

		// More than 90 min --> xx hour xx min
		if timeDiff >= 90.minutes.timeInterval {
			return timeDiff.hoursMin ?? "n/a"
		}

		// --> xx min
		return timeDiff.mins ?? "n/a"
	}

	/// More than 30 days --> xx months, More than 24 hours --> xx days, More than 90 min --> xx hour xx min, Less than 90 mins --> xx mins
    var validForStringWithMonths: String {
        let timeDiff = timeIntervalSinceNow
        
        // More than 32 days --> xx months
        if timeDiff >= 32.days.timeInterval {
            return timeDiff.months ?? "n/a"
        }
        
        // More than 24 hours --> xx days
        if timeDiff >= 24.hours.timeInterval {
            return timeDiff.days ?? "n/a"
        }
        
        // More than 90 min --> xx hour xx min
        if timeDiff >= 90.minutes.timeInterval {
            return timeDiff.hoursMin ?? "n/a"
        }
        
        // --> xx min
        return timeDiff.mins ?? "n/a"
    }

	func dayDiffence(toDate: Date = Date()) -> Int {
		return difference(unit: 1.days.timeInterval, toDate: toDate)
	}

	func hoursDiffence(toDate: Date = Date()) -> Int {
		return difference(unit: 1.hours.timeInterval, toDate: toDate)
	}

	func minutesDifference(toDate: Date = Date()) -> Int {
		difference(unit: 1.minutes.timeInterval, toDate: toDate)
	}

	func progress(total: TimeInterval) -> CGFloat {
		if total == 0 {
			return 0
		}
		return CGFloat(self.timeIntervalSinceNow/total)
	}

	func dateDayFormat() -> String? {
		return DateFormatterHelper.shared.formatLongWeekDateString(from: self)
	}

	func shortDateDayFormat() -> String? {
		return DateFormatterHelper.shared.formatDayShortMonthString(from: self)
	}

	// Date - Day - Month format
	func dateValidityTimeFormat(to: Date? = nil) -> String? {
		guard let fromText = self.dateDayFormat() else { return nil }

		var toRet = fromText

		if let toText = to?.dateDayFormat() {
			toRet += " - \(toText)"
		}

		return toRet
	}

	// Day - Month format
	func shortDateValidityTimeFormat(to: Date? = nil) -> String? {
		guard let fromText = self.shortDateDayFormat() else { return nil }

		var toRet = fromText

		if let toText = to?.shortDateDayFormat() {
			toRet += " - \(toText)"
		}

		return toRet
	}

	// Wed 21 May, 19:55 format
	func dateFullFormat() -> String? {
		guard let dayPart = dateValidityTimeFormat() else {
			return nil
		}

		return dayPart + " " + hourMinuteFormat()
	}

	// 21 May, 19:55 format
	func dateShortFormat() -> String? {
		guard let dayPart = shortDateValidityTimeFormat() else {
			return nil
		}

		return dayPart + " " + hourMinuteFormat()
	}

	// Expired in 2 days || Expired 2 days ago
	func expiredIn() -> String {
		// This property is now only used in an internal feature, no need to localise
		let timeDiff = abs(self.timeIntervalSinceNow)
		let timeDiffString: String? = timeDiff.toClock()

		if isInFuture {
			return "Expires in \(timeDiffString ?? "n/a")"
		}

		return "Expired \(timeDiffString ?? "n/a") ago"
	}

	func add(minutes: Int) -> Date {
		return self.add(minutes, .minute)
	}

	func add(hours: Int) -> Date {
		return self.add(hours, .hour)
	}

	func add(months: Int) -> Date {
		return add(months, .month)
	}

	func add(days: Int) -> Date {
		return add(days, .day)
	}

	func add(_ count: Int, _ component: Calendar.Component) -> Date {
		return dateByAdding(count, component).date
	}

	func isInSameDayOf(date: Date?) -> Bool {
		guard let date = date else {
			return false
		}

		return self.compare(DateComparisonType.isSameDay(date))
	}

	var isMorning: Bool {
		return self.compare(.isMorning)
	}

	var isAfternoon: Bool {
		return self.compare(.isAfternoon)
	}

	func roundedDuration(to: Date, floorMinute: Bool = true) -> TimeInterval {
		let mode: RoundDateMode = floorMinute ? .toFloorMins(1) : .toMins(1)
		return self.dateRoundedAt(at: mode).timeIntervalSince(to.dateRoundedAt(at: mode))
	}

	func timeInterval(since date: Date) -> TimeInterval {
		return (self.date - date).timeInterval
	}

	func subtract(with offset: DateComponents) -> Date {
		return self - offset
	}

	func add(with offset: DateComponents) -> Date {
		return self + offset
	}

	func isEarlier(date: Date, orEqual: Bool) -> Bool {
		if orEqual, self == date {
			return true
		}

		return self.earlierDate(date) == self
	}

	func isAfter(date: Date, orEqual: Bool) -> Bool {
		if orEqual, self == date {
			return true
		}
		
		return self.laterDate(date) == self
	}

	func isBetween(_ date1: Date, and date2: Date) -> Bool {
		return (min(date1, date2) ... max(date1, date2)).contains(self)
	}

	/// MARK: Private methods
	private func difference(unit: TimeInterval, toDate: Date = Date()) -> Int {
		let difference = Int(ceil(abs(toDate.timeIntervalSince(self)) / unit))
		return difference
	}
}
