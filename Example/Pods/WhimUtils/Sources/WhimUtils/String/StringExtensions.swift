//
//  StringExtensions.swift
//  whim-ios
//
//  Created by Do Duc on 08/08/16.
//  Copyright © 2016 maas. All rights reserved.
//

import Foundation
import MapKit
import CoreTelephony

// Whim's extension
public extension String {
    /// Detect vehogo code
    var isVehoGo: Bool {
        return self.hasPrefix("fi-veho")
    }
    
    var isTimeBasedPackage: Bool {
        return contains("pass")
    }
    
    func insufficientBalanceString() -> Bool {
        return self.hasPrefix("403: Insufficent balance")
    }
    
    func getInsufficientBalance() -> [String: Int] {
        let inputArray = self.split { $0 == " " }.map(String.init)
        
        guard let requiredIndex = inputArray.firstIndex(of: "(required:"), let actualIndex = inputArray.firstIndex(of: "actual:") else {
            return [:]
        }
        
        guard let required = Int(String(inputArray[requiredIndex+1].dropLast())), let actual = Int(String(inputArray[actualIndex+1].dropLast())) else {
            return [:]
        }
        
        return ["required": required, "actual": actual, "insufficient": required - actual]
    }
    
    func simplifyRentalCarName() -> String {
        guard let firstCommaIndex = self.index(of: ",") else {
            return self
        }
        
        return String(self[..<firstCommaIndex])
    }
    
    // Get svg ratio w/h
    func svgRatio() -> CGFloat {
        guard let svgFrame = self.svgFrame() else {
            return 375/130 // Default svg banner ratio
        }
        
        return svgFrame.width / svgFrame.height
    }
    
    // Get svg frame
    func svgFrame() -> CGRect? {
        guard let viewBoxRange = self.range(of: "viewBox=\"") else {
            return nil
        }
        
        let afterViewBoxString = self[viewBoxRange.upperBound...]
        
        guard let viewBoxContentRange = afterViewBoxString.range(of: "\"") else {
            return nil
        }
        
        let viewBoxContent = afterViewBoxString[..<viewBoxContentRange.upperBound].replacingOccurrences(of: "\"", with: "")
        
        let nums = viewBoxContent.components(separatedBy: " ").map { (str) -> CGFloat? in
            guard let doubleValue = Double(str) else {
                return nil
            }
            
            return CGFloat(doubleValue)
            }.compactMap({ $0 })
        
        guard nums.count == 4 else {
            return nil
        }
        
        return CGRect(x: nums[0], y: nums[1], width: nums[2], height: nums[3])
    }
    
    /// Latitude and Longitude value of string
    /// "20.32423,54.2138497" --> CLLocationCoordinate2D(latitude: 20.32423, longitude: 54.2138497)
    var coordinateValue: CLLocationCoordinate2D? {
        let array = self.trim().components(separatedBy: ",")
        guard array.count == 2 else { return nil }
        
        if let latValue = Double(array[0]), let lonValue = Double(array[1]) {
            return CLLocationCoordinate2D(latitude: latValue, longitude: lonValue)
        }
        
        return nil
    }
    
    /// Removed postal code for the time being
    func removedPostalCode() -> String {
        let strArr = self.split(separator: " ")
        
        var toRet: String = ""
        
        for s in strArr {
            var str: String = ""
            if s.last != "," {
                str = String(s)
            } else {/// Returns a random number in the range of [0, 1] (inclusive).
                str = String(s.dropLast())
            }
            
            guard str.isPostalCode else {
                toRet += "\(str) "
                continue
            }
        }
        
        return toRet
    }
    
    private var isPostalCode: Bool {
        if Int(String(self)) != nil, self.count > 3 {
            return true
        }
        
        return false
    }
    
    func separateAddress() -> (title: String, description: String) {
        let stringArray = self.split(separator: ",")
        
        var toRetTitle = ""
        var toRetDesc = ""
        for chars in stringArray {
            if toRetTitle.count >= 5 {
                toRetDesc.append("\(String(chars)),")
            } else {
                toRetTitle.append(String(chars))
            }
        }
        if toRetDesc.hasSuffix(",") {
            toRetDesc.remove(at: toRetDesc.index(before: toRetDesc.endIndex))
        }
        toRetDesc = toRetDesc.trim()
        return (title: toRetTitle, description: toRetDesc)
    }
    
    func handlerFirebaseString() -> String {
        return firstCharacters(number: 100)
    }
    
    /// Remove plus sign in area code
    func removePlusSign() -> String {
        return self.replacingOccurrences(of: "+", with: "").removeSpaces()
    }
    
    /// Addplus sign for are code
    func addPlusSign() -> String {
        guard !self.hasPrefix("+") else {
            return self.removeSpaces()
        }
        
        return "+\(self.removeSpaces())"
    }

    var isAddressComponents: Bool {
        if !self.isEmpty && self.contains("|") {
            return true
        }
        
        return false
    }
    
    /// Get String with more than 5 chars from `self`
    ///
    /// - Example:
    ///   1) "Runberginkatu, 2, Kiev, Ukraint, 111111111111111, 22, 33333, 4567890-098765456789".handleFavouriteName" - > "Runberginkatu"
    ///   2) "AA, 34, Finland" -> "AA 34"
    ///   3) "AA,34,Finland" -> "AA34Finland"
    ///   4) "AA,34 ,Finland" -> "AA34 "
    var handleFavouriteName: String {
        let stringArray = self.split(separator: ",")
        
        var resultString = ""
        for chars in stringArray {
            guard resultString.count < 5 else { continue }
            
            resultString.append(String(chars))
        }
        
        return resultString
    }
    
    var webView: String {
        guard self.contains("<html") || self.hasPrefix("<meta") else {
            return String(format: "<html><head><meta name=\"viewport\" content=\"height=device-height, initial-scale=1.0, maximum-scale=1.0, user-scalable=no\" /></head><body style=\"margin:0; padding:0\">%@</body></html>", self)
        }
        
        return self
    }

    var firstCapitalized: String {
        return prefix(1).capitalized + dropFirst()
    }

    var stringifyingNewLineCharacters: String {
        replacingOccurrences(of: "\\n", with: "\n")
    }
}

/// Based on QvikSwift extensions
/// https://github.com/qvik/qvik-swift-ios
public extension String {
    /// Double value from string, if possible
    var doubleValue: Double? {
        return NumberFormatter().number(from: self)?.doubleValue
    }

    /// Integer value from string, if possible
    var intValue: Int? {
        return NumberFormatter().number(from: self)?.intValue
    }

    /**
     Returns a substring of this string from a given index up the given length.
     
     - parameter startIndex: index of the first character to include in the substring
     - parameter length: number of characters to include in the substring
     - returns: the substring
     */
    func substring(startIndex: Int, length: Int) -> String {
        guard self.count > (startIndex + length) else { return self }
        let start = self.index(self.startIndex, offsetBy: startIndex)
        let end = self.index(self.startIndex, offsetBy: startIndex + length)
        
        return String(self[start..<end])
    }
    
    /**
     Returns a substring of this string from a given index to the end of the string.
     
     - parameter startIndex: index of the first character to include in the substring
     - returns: the substring from startIndex to the end of this string
     */
    func substring(startIndex: Int) -> String {
        let start = self.index(self.startIndex, offsetBy: startIndex)
        return String(self[start..<self.endIndex])
    }
    
    func index(from: Int) -> Index {
        return self.index(startIndex, offsetBy: from)
    }
    
    /// Cut string from index
    func substring(from: Int) -> String {
        let fromIndex = index(from: from)
        return String(self[fromIndex...])
    }
    
    /// Cut string to index
    func substring(to: Int) -> String {
        let toIndex = index(from: to)
        return String(self[..<toIndex])
    }
    
    /// Cut string with a range
    func substring(with r: Range<Int>) -> String {
        let startIndex = index(from: r.lowerBound)
        let endIndex = index(from: r.upperBound)
        return String(self[startIndex..<endIndex])
    }
    
    // let substring = String(string[0..<34])
    subscript (bounds: CountableClosedRange<Int>) -> String {
        let start = index(startIndex, offsetBy: bounds.lowerBound)
        let end = index(startIndex, offsetBy: bounds.upperBound)
        return String(self[start...end])
    }
    
    // let substring = String(string[0..<34])
    subscript (bounds: CountableRange<Int>) -> String {
        let start = index(startIndex, offsetBy: bounds.lowerBound)
        let end = index(startIndex, offsetBy: bounds.upperBound)
        return String(self[start..<end])
    }
    
    /// Index of string
    func index(of string: String, options: CompareOptions = .literal) -> Index? {
        return range(of: string, options: options)?.lowerBound
    }
    
    /// End-Index of string
    func endIndex(of string: String, options: CompareOptions = .literal) -> Index? {
        return range(of: string, options: options)?.upperBound
    }
    
    /// Return a coordinate string with format "lat,lon"
    static func coordinateToString(_ lat: Double, lon: Double) -> String {
        return "\(lat),\(lon)"
    }
    
    /// Check if is integer
    var isInteger: Bool {
        if !self.isEmpty {
            return Int(self) != nil
        }
        return false
    }
    
    // Create random string with optional length
    static func random(length: Int = 20) -> String {
        let base = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        var randomString: String = ""
        
        for _ in 0..<length {
            let randomValue = arc4random_uniform(UInt32(base.count))
            randomString += "\(base[base.index(base.startIndex, offsetBy: Int(randomValue))])"
        }
        return randomString
    }
    
    /// formated masked number 
    func maskedNumber() -> String {
        let toRet = self.trimmingCharacters(in: CharacterSet.decimalDigits.inverted)
        
        if !toRet.isEmpty {
            return "•••• \(toRet)"
        }
        
        return "•••• ••••"
    }
    
    /// Trim all spaces and new line in the end of strings
    func trim() -> String {
        return self.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    func trimEndsAndExtraNewlines() -> String {
        let result = self.trim().replacingOccurrences(of: "\\n{3,}", with: "\n\n", options: .regularExpression)
        return result
    }
    
    /// Remove all space in string
    func removeSpaces() -> String {
        return self.replacingOccurrences(of: " ", with: "")
    }
    
    func removeInitialZeros() -> String {
        guard let number = UInt64(self) else { return "" }
        
        return "\(number)"
    }
    
    func droplast(length: Int = 0) -> String {
        let end = self.index(self.endIndex, offsetBy: -length)
        return String(self[end..<self.endIndex])
    }
    
    func firstCharacters(number: Int) -> String {
        if self.count > number {
            let end = self.index(self.startIndex, offsetBy: number)
            return String(self[startIndex..<end])
        }
        
        return self
    }
    
    var url: URL? {
        return URL(string: self)
    }

    // TODO: remove this one, using url instead so fetching and passing data won't block main thread
    var toImage: UIImage? {
        guard let url = url else {
            return nil
        }

        guard let data = try? Data(contentsOf: url) else {
            return nil
        }

        return UIImage(data: data)
    }

    func match(regex: String) -> [String]? {
        do {
            let regex = try NSRegularExpression(pattern: regex)
            let nsString = self as NSString
            let results = regex.matches(in: self, range: NSRange(location: 0, length: count))
            return results.map { nsString.substring(with: $0.range)}
        } catch let error {
            print("invalid regex: \(error.localizedDescription)")
            return nil
        }
    }

    func containsJapaneseOrChineseCharacter() -> Bool {
        return matches(pattern: "[\u{3040}-\u{30ff}\u{3400}-\u{4dbf}\u{4e00}-\u{9fff}\u{f900}-\u{faff}\u{ff66}-\u{ff9f}]")
    }
    
    func matches(pattern: String) -> Bool {
        do {
            let regex = try NSRegularExpression(pattern: pattern, options: NSRegularExpression.Options.caseInsensitive)
            let range = NSRange(location: 0, length: self.count)
            return regex.firstMatch(in: self, options: [], range: range) != nil
        } catch {
            return false
        }
    }
    
    /**
     Returns the bounding rectangle that drawing required for drawing this string using
     the given font. By default the string is drawn on a single line, but it can be
     constrained to a specific width with the optional parameter constrainedToSize.
     
     - parameter font: font used
     - parameter constrainedToSize: the constraints for drawing
     - returns: the bounding rectangle required to draw the string
     */
    func boundingRectWithFont(_ font: UIFont, constrainedToSize size: CGSize = CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)) -> CGRect {
        let attributedString = NSAttributedString(string: self, attributes: [.font: font])
        return attributedString.boundingRect(with: size, options: [.usesLineFragmentOrigin, .usesFontLeading], context: nil)
    }

    func width(with constrainedHeight: CGFloat, font: UIFont) -> CGFloat {
        return ceil(boundingRectWithFont(font, constrainedToSize: CGSize(width: .greatestFiniteMagnitude, height: constrainedHeight)).width)
    }

    func height(with constraintWidth: CGFloat, font: UIFont) -> CGFloat {
        return ceil(boundingRectWithFont(font, constrainedToSize: CGSize(width: constraintWidth, height: .greatestFiniteMagnitude)).height)
    }
}

/// Data processing
public extension String {
    /// Encode url
    func encodeURL() -> String? {
        return self.addingPercentEncoding(withAllowedCharacters: CharacterSet.rfc3986Unreserved)
    }
    
    /// Convert String to data
    func toData(encoding: String.Encoding = .utf8) -> Data? {
        guard let value = self.data(using: encoding) else {
            Log.error("Cannot convert string to data")
            
            return nil
        }
        
        return value
    }

    /// Convert String to URL and add percent encoding characterSet if needed
    /// i.e: input string: https://staticfiles.maas.global/dev/icons/products folder/hsl-zone-ab.png
    /// output url URL(string: "https://staticfiles.maas.global/dev/icons/products%20folder/hsl-zone-ab.png")

    func toURL(withAllowedCharacters characterSet: CharacterSet?) -> URL? {
        var processedString = self

        if let characterSet = characterSet, let newValue = self.addingPercentEncoding(withAllowedCharacters: characterSet) {
            processedString = newValue
        }

        return URL(string: processedString)
    }
}

// MARK: - String Element Extension
//
/// Used in CommonLocation
public extension String.Element {
    // Check if is integer
    var isInteger: Bool {
        let s = String(self)
        guard Int(s) != nil else {
            return false
        }
        
        return true
    }
}

extension CharacterSet {
    static let rfc3986Unreserved = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
}

// MARK: - TextStyle
//
/// Used for script generated textStyles in app theme
public struct TextStyle {
    var color: UIColor
    var font: UIFont
    var alignment: NSTextAlignment = .left
    var kerning: CGFloat = 0
    var paragraphSpacing: CGFloat
    var lineHeight: CGFloat?
    
    public init(color: UIColor, font: UIFont, alignment: NSTextAlignment, kerning: CGFloat, paragraphSpacing: CGFloat, lineHeight: CGFloat?) {
        self.color = color
        self.font = font
        self.alignment = alignment
        self.kerning = kerning
        self.paragraphSpacing = paragraphSpacing
        self.lineHeight = lineHeight
    }
    
    public func attributedString(withString string: String) -> NSAttributedString {
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.alignment = alignment
        if let lineHeight = lineHeight {
            paragraphStyle.minimumLineHeight = lineHeight
            paragraphStyle.maximumLineHeight = lineHeight
        }
        
        let attributes: [NSAttributedString.Key: Any] = [.foregroundColor: color,
                                                        .font: font,
                                                        .kern: kerning,
                                                        .paragraphStyle: paragraphStyle]
        
        return NSAttributedString(string: string, attributes: attributes)
    }
}
