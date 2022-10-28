extension String {
    public static func random<G: RandomNumberGenerator>(_ domain: Faker.Domain, using generator: inout G) -> String {
        switch domain {
        case let .address(address):
            return randomAddress(address, using: &generator)
        case let .bank(bank):
            return randomBank(bank, using: &generator)
        case let .car(car):
            return randomCar(car, using: &generator)
        case let .company(company):
            return randomCompany(company, using: &generator)
        case let .creditCard(creditCard):
            return randomCreditCard(creditCard, using: &generator)
        case let .internet(internet):
            return randomInternet(internet, using: &generator)
        case let .name(name):
            return randomName(name, using: &generator)
        case let .phone(phone):
            return randomPhone(phone, using: &generator)
        case let .text(text):
            return randomText(text, using: &generator)
        case let .vehicle(vehicle):
            return randomVehicle(vehicle, using: &generator)
        }
    }

    static func generate<G: RandomNumberGenerator>(_ key: String, using generator: inout G) -> String {
        return Faker.value(by: key, using: &generator)
            ?? random(ofLength: 5, from: Faker.Constants.alphaNumeric, using: &generator)
    }
}

// MARK: - Address

extension String {
    static func randomAddress<G: RandomNumberGenerator>(_ address: Faker.Domain.Address, using generator: inout G) -> String {
        switch address {
        case .full:
            return [
                randomAddress(.country, using: &generator),
                randomAddress(.city, using: &generator),
                randomAddress(.postCode, using: &generator),
                randomAddress(.streetName, using: &generator),
                randomAddress(.buildingNumber, using: &generator),
            ].joined(separator: ", ")
        case .formatted:
            return [
                "country:" + randomAddress(.country, using: &generator),
                "city:" + randomAddress(.city, using: &generator),
                "zipCode:" + randomAddress(.postCode, using: &generator),
                "streetName:" + randomAddress(.streetName, using: &generator),
                "streetNumber:" + randomAddress(.buildingNumber, using: &generator),

                randomOptional("state:" + randomAddress(.state, using: &generator), using: &generator),
                randomOptional("district:" + randomAddress(.county, using: &generator), using: &generator),
                randomOptional("ward:" + randomAddress(.stateShort, using: &generator), using: &generator),
            ].compactMap { $0 }.joined(separator: "|")
        case .country:
            return generate("address.country", using: &generator)
        case .countryCode:
            return generate("address.country_code", using: &generator)
        case .state:
            return generate("address.state", using: &generator)
        case .stateShort:
            return generate("address.state_abbr", using: &generator)
        case .county:
            return generate("address.county", using: &generator)
        case .city:
            return generate("address.city", using: &generator)
        case .streetName:
            return generate("address.street_name", using: &generator)
        case .streetAddress:
            return Faker.numerify(generate("address.street_address", using: &generator), using: &generator)
        case .buildingNumber:
            return Faker.bothify(generate("address.building_number", using: &generator), using: &generator)
        case .postCode:
            return Faker.bothify(generate("address.postcode", using: &generator), using: &generator)
        case .timeZone:
            return generate("address.time_zone", using: &generator)
        }
    }
}

// MARK: - Bank

extension String {
    static func randomBank<G: RandomNumberGenerator>(_ bank: Faker.Domain.Bank, using generator: inout G) -> String {
        switch bank {
        case .name:
            return generate("bank.name", using: &generator)

        case .iban:
            return generate("bank.ibanDetails.bankCountryCode", using: &generator)
                + random(ofLength: 2, from: Faker.Constants.numbers, using: &generator)
                + Faker.letterify(generate("bank.ibanDetails.ibanLetterCode", using: &generator), using: &generator)
                + Faker.numerify(generate("bank.ibanDetails.ibanDigits", using: &generator), using: &generator)

        case .bban:
            return Faker.letterify(generate("bank.ibanDetails.ibanLetterCode", using: &generator), using: &generator)
                + Faker.numerify(generate("bank.ibanDetails.ibanDigits", using: &generator), using: &generator)

        case .swiftBic:
            return generate("bank.swiftBic", using: &generator)
        }
    }
}

// MARK: - Car

extension String {
    static func randomCar<G: RandomNumberGenerator>(_ car: Faker.Domain.Car, using generator: inout G) -> String {
        switch car {
        case .brand:
            return generate("car.brand", using: &generator)
        }
    }
}

// MARK: - Company

extension String {
    static func randomCompany<G: RandomNumberGenerator>(_ company: Faker.Domain.Company, using generator: inout G) -> String {
        switch company {
        case .name:
            return generate("company.name", using: &generator)

        case .suffix:
            return generate("company.suffix", using: &generator)
        }
    }
}

// MARK: - CreditCard

extension String {
    static func randomCreditCard<G: RandomNumberGenerator>(_ creditCard: Faker.Domain.CreditCard, using generator: inout G) -> String {
        switch creditCard {
        case .number:
            return generate("business.credit_card_numbers", using: &generator)

        case .type:
            return generate("business.credit_card_types", using: &generator)

        case .expiry:
            return generate("business.credit_card_expiry_dates", using: &generator)
        }
    }
}

// MARK: - Internet

extension String {
    static func randomInternet<G: RandomNumberGenerator>(_ internet: Faker.Domain.Internet, using generator: inout G) -> String {
        switch internet {
        case .username:
            let components = [
                generate("name.first_name", using: &generator),
                generate("name.last_name", using: &generator),
                "\(Int.random(in: 0..<10000, using: &generator))"
            ]
            return components
                .shuffled(using: &generator)
                .joined(separator: "")
                .replacingOccurrences(of: "'", with: "")
                .lowercased()

        case .email:
            return [random(.internet(.username), using: &generator), random(.internet(.domain), using: &generator)]
                .joined(separator: "@")

        case .domain:
            let domain = generate("company.name", using: &generator).components(separatedBy: " ").first?.lowercased()
                ?? random(ofLength: 5, from: Faker.Constants.lowercaseLetters, using: &generator)
            return domain + generate("internet.domain_suffix", using: &generator)

        case .hashtag:
            return generate("internet.hashtag", using: &generator)

        case .url:
            return "https://\(random(.internet(.domain), using: &generator))/\(random(.internet(.username), using: &generator))"

        case let .password(minLength, maxLength):
            var temp = random(ofLength: minLength, from: Faker.Constants.alphaNumeric, using: &generator)
            let diffLength = maxLength - minLength
            if diffLength > 0 {
                let diffRandom = UInt.random(in: 0 ... diffLength, using: &generator)
                temp += random(ofLength: diffRandom, from: Faker.Constants.alphaNumeric, using: &generator)
            }
            return temp

        case let .image(width, height):
            return "https://picsum.photos/\(width)/\(height)/?image=\(UInt.random(in: 1...1000, using: &generator))"
        }
    }
}

// MARK: - Name

extension String {
    static func randomName<G: RandomNumberGenerator>(_ name: Faker.Domain.Name, using generator: inout G) -> String {
        switch name {
        case .first:
            return generate("name.first_name", using: &generator)

        case .last:
            return generate("name.last_name", using: &generator)

        case .full:
            return generate("name.name", using: &generator)

        case .prefix:
            return generate("name.prefix", using: &generator)

        case .suffix:
            return generate("name.suffix", using: &generator)

        case .title:
            return [
                generate("name.title.descriptor", using: &generator),
                generate("name.title.level", using: &generator),
                generate("name.title.job", using: &generator)
            ].joined(separator: " ")
        }
    }
}

// MARK: - Phone

extension String {
    static func randomPhone<G: RandomNumberGenerator>(_ phone: Faker.Domain.Phone, using generator: inout G) -> String {
        switch phone {
        case .number:
            return Faker.numerify(generate("phone_number.formats", using: &generator), using: &generator)

        case .cell:
            return Faker.numerify(generate("cell_phone.formats", using: &generator), using: &generator)
        }
    }
}

// MARK: - Text

extension String {
    static func randomText<G: RandomNumberGenerator>(_ text: Faker.Domain.Text, using generator: inout G) -> String {
        switch text {
        case let .words(number):
            var words = [String]()
            for _ in 0 ..< number {
                words.append(generate("lorem.words", using: &generator))
            }
            return words.joined(separator: " ")

        case let .sentences(number):
            var sentences = [String]()
            for _ in 0 ..< number {
                var sentence = random(.text(.words(.random(in: 0 ..< 10, using: &generator))), using: &generator) + "."
                sentence.replaceSubrange(
                    sentence.startIndex...sentence.startIndex,
                    with: String(sentence[sentence.startIndex]).capitalized
                )
                sentences.append(sentence)
            }
            return sentences.joined(separator: " ")

        case let .paragraphs(number):
            var paragraphs = [String]()
            for _ in 0 ..< number {
                let paragraph = random(.text(.sentences(.random(in: 0 ..< 10, using: &generator))), using: &generator)
                paragraphs.append(paragraph)
            }
            return paragraphs.joined(separator: "\n")
        }
    }
}

// MARK: - Vehicle

extension String {
    static func randomVehicle<G: RandomNumberGenerator>(_ vehicle: Faker.Domain.Vehicle, using generator: inout G) -> String {
        switch vehicle {
        case .manufacture:
            return generate("vehicle.manufacture", using: &generator)

        case .make:
            return generate("vehicle.makes", using: &generator)
        }
    }
}

