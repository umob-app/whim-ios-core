//
//  DateFormatterHelper.swift
//  WhimUtils
//
//  Created by Do Duc on 5.11.2020.
//

/*
 All credits go to William Boles
 https://williamboles.me/sneaky-date-formatters-exposing-more-than-you-think/
 */

import Foundation

private protocol DateFormatterType {
    func string(from date: Date) -> String
    func date(from string: String) -> Date?
}

extension DateFormatter: DateFormatterType { }

public final class DateFormatterHelper {
    public static let shared = DateFormatterHelper()

    // MARK: - Formatters
    private static func formatter(withFormat dateFormat: String, localeId: String? = nil) -> DateFormatter {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = dateFormat
        if let localeId = localeId {
            dateFormatter.locale = Locale(identifier: localeId)
        }
        return dateFormatter
    }
    
    private static func formatter(withTemplate template: String) -> DateFormatter {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = DateFormatter.dateFormat(fromTemplate: template, options: 0, locale: Locale.current)
        return dateFormatter
    }

    private let weekdayFormatter: DateFormatterType = {
        return DateFormatterHelper.formatter(withFormat: "EEEEE")
    }()

    private let dayMonthUKLocaleFormatter: DateFormatterType = {
        return DateFormatterHelper.formatter(withFormat: "dd MMM", localeId: "en_GB")
    }()

    private let hourMinuteFormatter: DateFormatterType = {
        return DateFormatterHelper.formatter(withFormat: "HH:mm")
    }()

    private let hourMinuteSecondFormatter: DateFormatterType = {
        return DateFormatterHelper.formatter(withFormat: "HH:mm:ss")
    }()

    private let fullTimeFormatter: DateFormatterType = {
        return DateFormatterHelper.formatter(withFormat: "yyyy-MM-dd HH:mm:ss.SSS")
    }()

    private let monthYearFormatter: DateFormatterType = {
        return DateFormatterHelper.formatter(withTemplate: "MMMM yyyy")
    }()

    private let shortMonthYearFormatter: DateFormatterType = {
        return DateFormatterHelper.formatter(withTemplate: "MMMYYYY")
    }()

    private let dayShortMonthFormatter: DateFormatterType = {
        return DateFormatterHelper.formatter(withTemplate: "dd MMM")
    }()

    private let longWeekDateFormatter: DateFormatterType = {
        return DateFormatterHelper.formatter(withTemplate: "EEEdMMM")
    }()

    private let shortWeekDateFormatter: DateFormatterType = {
        return DateFormatterHelper.formatter(withFormat: "EEE dd.MM")
    }()

    private let shortWeekDateHourMinuteFormatter: DateFormatterType = {
        return DateFormatterHelper.formatter(withFormat: "EEE dd.MM HH:mm")
    }()

    private let shortWeekFullDateFormatter: DateFormatterType = {
        return DateFormatterHelper.formatter(withFormat: "EEE MMM d, yyyy")
    }()

    private let shortWeekShortDateFormatter: DateFormatterType = {
        return DateFormatterHelper.formatter(withFormat: "EEE MMM d")
    }()
    
    private let fullWeekFullDateFormatter: DateFormatterType = {
        return DateFormatterHelper.formatter(withFormat: "EEEE, MMM d, yyyy")
    }()

    private let fullWeekDateHourMinuteFormatter: DateFormatterType = {
        return DateFormatterHelper.formatter(withFormat: "EEEE, MMM d, yyyy HH:mm")
    }()

    private let shortWeekMediumDateHourMinuteFormatter: DateFormatterType = {
        return DateFormatterHelper.formatter(withFormat: "E, d.MM.yyyy, HH:mm")
    }()

    private let cardExpiredDateFormatter: DateFormatterType = {
        return DateFormatterHelper.formatter(withFormat: "MM/yy")
    }()
    
    private let shortDayMonthYearHoursMinutes: DateFormatterType = {
        return DateFormatterHelper.formatter(withTemplate: "dd MMM yyyy, HH:mm")
    }()

    private let dayMonthHourMinuteFormatter: DateFormatterType = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("dd MMM HH:mm")
        return formatter
    }()

    private let ssnDateFormatter: DateFormatterType = {
        return DateFormatterHelper.formatter(withFormat: "ddMMyyyy")
    }()
    
    private let dayMonthYearHoursMinutesFormatter: DateFormatterType = {
        return DateFormatterHelper.formatter(withFormat: "dd.MM.yyyy HH:mm")
    }()

    private let dayMonthYearFormatter: DateFormatterType = {
        return DateFormatterHelper.formatter(withFormat: "dd MMM yyyy")
    }()

    private let shortTimeStyleFormatter: DateFormatterType = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    private let relativeShortDateStyleFormatter: DateFormatterType = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        formatter.doesRelativeDateFormatting = true
        return formatter
    }()

    private let shortDateStyleShortTimeStyleFormatter: DateFormatterType = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()

    private let relativeShortDateStyleShortTimeStyleFormatter: DateFormatterType = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        formatter.doesRelativeDateFormatting = true
        return formatter
    }()

    private let mediumDateStyleFormatter: DateFormatterType = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    private let mediumDateStyleShortTimeStyleFormatter: DateFormatterType = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    private let relativeMediumDateStyleShortTimeStyleFormatter: DateFormatterType = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.doesRelativeDateFormatting = true
        return formatter
    }()

    // MARK: - Output string from date for each format
    /// Format: "dd MMM", locale: "en_GB"
    public func formatDayMonthUKLocaleString(from date: Date) -> String {
        return dayMonthUKLocaleFormatter.string(from: date)
    }

    /// Format: "HH:mm"
    public func formatHourMinuteString(from date: Date) -> String {
        return hourMinuteFormatter.string(from: date)
    }

    /// Format: "HH:mm:ss"
    public func formatHourMinuteSecondString(from date: Date) -> String {
        return hourMinuteSecondFormatter.string(from: date)
    }

    /// Format: "yyyy-MM-dd HH:mm:ss.SSS"
    public func formatFullTimeString(from date: Date) -> String {
        return fullTimeFormatter.string(from: date)
    }

    /// Template: "MMMM yyyy"
    public func formatMonthYearString(from date: Date) -> String {
        return monthYearFormatter.string(from: date)
    }

    /// Template: "MMMYYYY"
    public func formatShortMonthYearString(from date: Date) -> String {
        return shortMonthYearFormatter.string(from: date)
    }

    /// Format: "dd MMM"
    public func formatDayShortMonthString(from date: Date) -> String {
        return dayShortMonthFormatter.string(from: date)
    }

    /// Template: "EEEdMMM"
    public func formatLongWeekDateString(from date: Date) -> String {
        return longWeekDateFormatter.string(from: date)
    }

    /// Format: "EEE dd.MM"
    public func formatShortWeekDateString(from date: Date) -> String {
        return shortWeekDateFormatter.string(from: date)
    }

    /// Format: "EEE dd.MM HH:mm"
    public func formatShortWeekDateHourMinuteString(from date: Date) -> String {
        return shortWeekDateHourMinuteFormatter.string(from: date)
    }

    /// Format: EEE MMM d, yyyy
    public func formatShortWeekFullDateString(from date: Date) -> String {
        return shortWeekFullDateFormatter.string(from: date)
    }
    
    /// Format: EEE MMM d
    public func formatShortWeekShortDateString(from date: Date) -> String {
        return shortWeekShortDateFormatter.string(from: date)
    }

    /// Format: "EEEE, MMM d, yyyy"
    public func formatFullWeekDateString(from date: Date) -> String {
        return fullWeekFullDateFormatter.string(from: date)
    }

    /// Format: "EEEE, MMM d, yyyy HH:mm"
    public func formatFullWeekDateTimeString(from date: Date) -> String {
        return fullWeekDateHourMinuteFormatter.string(from: date)
    }

    /// Format: "E, d.MM.yyyy, HH:mm"
    public func shortWeekMediumDateHourMinuteString(from date: Date) -> String {
        return shortWeekMediumDateHourMinuteFormatter.string(from: date)
    }

    /// Format: "MM/yy"
    public func formatCardExpiredDateString(from date: Date) -> String {
        return cardExpiredDateFormatter.string(from: date)
    }

    /// Format: "dd.mm.yyyy hh:mm"
    public func formatDayMonthYearHoursMinutesString(from date: Date) -> String {
        return dayMonthYearHoursMinutesFormatter.string(from: date)
    }

	/// Format: "dd mm yyyy"
	public func formatDayMonthYearString(from date: Date) -> String {
		return dayMonthYearFormatter.string(from: date)
	}

    /// Template localised "dd MMM HH:mm"
    public func formatDayMonthHourMinuteString(from date: Date) -> String {
        return dayMonthHourMinuteFormatter.string(from: date)
    }
    

    public func formatShortTimeStyleString(from date: Date) -> String {
        return shortTimeStyleFormatter.string(from: date)
    }

    public func formatRelativeShortDateStyleString(from date: Date) -> String {
        return relativeShortDateStyleFormatter.string(from: date)
    }

    public func formatShortDateStyleShortTimeStyleString(from date: Date) -> String {
        return shortDateStyleShortTimeStyleFormatter.string(from: date)
    }

    public func formatRelativeShortDateStyleShortTimeStyleString(from date: Date) -> String {
        return relativeShortDateStyleShortTimeStyleFormatter.string(from: date)
    }

    public func formatMediumDateStyleString(from date: Date) -> String {
        return mediumDateStyleFormatter.string(from: date)
    }

    public func formatMediumDateStyleShortTimeStyleString(from date: Date) -> String {
        return mediumDateStyleShortTimeStyleFormatter.string(from: date)
    }

    public func formatRelativeMediumDateStyleShortTimeStyleString(from date: Date) -> String {
        return relativeMediumDateStyleShortTimeStyleFormatter.string(from: date)
    }

    public func formatWeekdayOneCharString(from date: Date) -> String {
        return weekdayFormatter.string(from: date)
    }
    
    public func formatShortDayMonthYearHoursMinutes(from date: Date) -> String {
        return shortDayMonthYearHoursMinutes.string(from: date)
    }

    // MARK: - Output date from string for each format
    public func formatSSNDate(from string: String) -> Date? {
        return ssnDateFormatter.date(from: string)
    }

    public func formatCardDate(from string: String) -> Date? {
        return ssnDateFormatter.date(from: string)
    }

    public func formatHourMinuteSecondDate(from string: String) -> Date? {
        return hourMinuteSecondFormatter.date(from: string)
    }
}
