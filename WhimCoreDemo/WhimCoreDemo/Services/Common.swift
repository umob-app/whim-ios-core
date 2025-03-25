/// iso 3166-1-alpha-2 code
typealias CountryCode = String
typealias CountryName = String
typealias CountryRegion = String
typealias Continent = String

func countryFlag(from code: CountryCode) -> String {
    let baseFlagScalar: UInt32 = 127397
    var flagString = ""
    for scalarValue in code.uppercased().unicodeScalars {
        guard let scalar = UnicodeScalar(baseFlagScalar + scalarValue.value) else {
            continue
        }
        flagString.unicodeScalars.append(scalar)
    }
    return flagString
}
