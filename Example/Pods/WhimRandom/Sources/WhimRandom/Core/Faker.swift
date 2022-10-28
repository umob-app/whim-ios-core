// Borrowed from Fakery: https://github.com/vadymmarkov/Fakery

import Foundation

public final class Faker {
    public static let data: [String: Any] = {
        let bundle = Bundle(for: Faker.self)
        guard let path = bundle.path(forResource: "fakes", ofType: "json", inDirectory: "Resources.bundle"),
              let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let parsedData = try? JSONSerialization.jsonObject(with: data, options: .allowFragments),
              let json = parsedData as? [String: Any]
        else {
            return [:]
        }
        return json
    }()

    private static let parser: Parser = {
        Parser(data: data)
    }()

    public static func value<G: RandomNumberGenerator>(by key: String, using generator: inout G) -> String? {
        do {
            return try parser.fetchValue(by: key, using: &generator)
        } catch {
            print("🥸❌: \(error)")
        }
        return nil
    }
}

extension Faker {
    public enum Constants: Equatable {
        public static let lowercaseLetters = "abcdefghijklmnopqrstuvwxyz"
        public static let uppercaseLetters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        public static let letters = lowercaseLetters + uppercaseLetters
        public static let numbers = "0123456789"
        public static let alphaNumeric = letters + numbers
    }

    public enum Domain: Equatable {
        case address(Address)
        case bank(Bank)
        case car(Car)
        case company(Company)
        case creditCard(CreditCard)
        case internet(Internet)
        case name(Name)
        case phone(Phone)
        case text(Text)
        case vehicle(Vehicle)

        public enum Address: Equatable {
            case full, country, countryCode, state, stateShort, county, city, streetName, streetAddress, buildingNumber, postCode, timeZone, formatted
        }

        public enum Bank: Equatable {
            case name, iban, bban, swiftBic
        }

        public enum Car: Equatable {
            case brand
        }

        public enum Company: Equatable {
            case name, suffix
        }

        public enum CreditCard: Equatable {
            case number, type, expiry
        }

        public enum Internet: Equatable {
            case username, email, domain, hashtag, url, password(minLength: UInt, maxLength: UInt), image(width: UInt, height: UInt)

            public static var password: Internet {
                .password(minLength: 8, maxLength: 16)
            }

            public static var image: Internet {
                .image(width: 200, height: 300)
            }
        }

        public enum Name: Equatable {
            case first, last, full, prefix, suffix, title
        }

        public enum Phone: Equatable {
            case number, cell
        }

        public enum Text: Equatable {
            case words(UInt), sentences(UInt), paragraphs(UInt)

            public static var word: Text {
                .words(1)
            }

            public static var sentence: Text {
                .sentences(1)
            }

            public static var paragraph: Text {
                .paragraphs(1)
            }
        }

        public enum Vehicle: Equatable {
            case manufacture, make
        }
    }

    static func numerify<G: RandomNumberGenerator>(_ string: String, using generator: inout G) -> String {
        let numbers = Array(Constants.numbers)
        let count = UInt32(numbers.count)
        return String(string.enumerated().map { (index, item) in
            let numberIndex = index == 0
                ? UInt32.random(in: 0 ..< (count - 1), using: &generator)
                : UInt32.random(in: 0 ..< count, using: &generator)
            let char = numbers[Int(numberIndex)]
            return String(item) == "#" ? char : item
        })
    }

    static func letterify<G: RandomNumberGenerator>(_ string: String, using generator: inout G) -> String {
        return String(string.map { item in
            let char = Constants.lowercaseLetters.randomElement(using: &generator)!
            return String(item) == "?" ? char : item
        })
    }

    static func bothify<G: RandomNumberGenerator>(_ string: String, using generator: inout G) -> String {
        return letterify(numerify(string, using: &generator), using: &generator)
    }

    static func alphaNumerify(_ string: String) -> String {
        return string.replacingOccurrences(
            of: "[^A-Za-z0-9_]",
            with: "",
            options: .regularExpression,
            range: nil
        )
    }
}

extension Faker {
    public enum Failure: Error, Equatable {
        case absentData
        case emptyValue(key: String)
        case emptyDataArray(key: String)
        case wrongDataFormat(key: String)
        case invalidPath(key: String)
        case absentPath(key: String)
        case incompletePath(key: String)
        case other(NSError)
    }

    final class Parser {
        enum KeyData {
            case value(String)
            case array([String])
            case object([String: Any])
        }

        private let data: [String: Any]

        init(data: [String: Any]) {
            self.data = data
        }

        func fetchValue<G: RandomNumberGenerator>(by key: String, using generator: inout G) throws -> String {
            let keyData = try fetchData(by: key)
            let parsed: String
            switch keyData {
            case let .value(value):
                parsed = value
            case let .array(array):
                guard let value = array.randomElement(using: &generator) else {
                    throw Failure.emptyDataArray(key: key)
                }
                parsed = value
            case .object:
                throw Failure.incompletePath(key: key)
            }
            let result = parsed.range(of: "#{") != nil
                ? try parse(parsed, forSubject: try getSubject(key), using: &generator)
                : parsed

            if result.isEmpty {
                throw Failure.emptyValue(key: key)
            }
            return result
        }

        func parse<G: RandomNumberGenerator>(_ template: String, forSubject subject: String, using generator: inout G) throws -> String {
            var text = ""
            let string = NSString(string: template)
            do {
                let regex = try NSRegularExpression(
                    pattern: "(\\(?)#\\{([A-Za-z]+\\.)?([^\\}]+)\\}([^#]+)?",
                    options: .caseInsensitive
                )
                let matches = regex.matches(
                    in: template,
                    options: .reportCompletion,
                    range: NSRange(location: 0, length: string.length)
                )
                guard !matches.isEmpty else {
                    return template
                }
                for match in matches {
                    if match.numberOfRanges < 4 {
                        continue
                    }
                    let prefixRange = match.range(at: 1)
                    if prefixRange.length > 0 {
                        text += string.substring(with: prefixRange)
                    }
                    let subjectRange = match.range(at: 2)
                    var subjectWithDot = subject + "."
                    if subjectRange.length > 0 {
                        subjectWithDot = string.substring(with: subjectRange)
                    }
                    let methodRange = match.range(at: 3)
                    if methodRange.length > 0 {
                        let key = subjectWithDot.lowercased() + string.substring(with: methodRange)
                        text += try fetchValue(by: key, using: &generator)
                    }
                    let otherRange = match.range(at: 4)
                    if otherRange.length > 0 {
                        text += string.substring(with: otherRange)
                    }
                }
            } catch let error as Failure {
                throw error
            } catch {
                throw Failure.other(error as NSError)
            }
            return text
        }

        private func fetchData(by key: String) throws -> KeyData {
            let keyParts = key.components(separatedBy: ".")
            guard !keyParts.isEmpty else {
                throw Failure.invalidPath(key: key)
            }
            guard var dataPart = data["faker"] as? [String: Any] else {
                throw Failure.absentData
            }
            var keyData: Any?
            for keyPart in keyParts {
                guard let foundPart = dataPart[keyPart] else {
                    throw Failure.absentPath(key: key)
                }
                guard let foundPart = foundPart as? [String: Any] else {
                    keyData = dataPart[keyPart]
                    continue
                }
                dataPart = foundPart
                keyData = foundPart
            }
            if let object = keyData as? [String: Any] {
                return .object(object)
            } else if let array = keyData as? [String] {
                return .array(array)
            } else if let value = keyData as? String {
                return .value(value)
            } else {
                throw Failure.wrongDataFormat(key: key)
            }
        }

        private func getSubject(_ key: String) throws -> String {
            let parts = key.components(separatedBy: ".")
            guard let subject = parts.first else {
                throw Failure.invalidPath(key: key)
            }
            return subject
        }
    }
}
