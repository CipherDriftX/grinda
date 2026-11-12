import Foundation

/// Where someone lives, as the server checks it before money goes in:
/// an ISO 3166 country code ("DE") and, where rules differ by state, an
/// ISO 3166-2 region ("US-AZ"). The lists of blocked places and higher ages
/// live on the server, so they change without an app update.
enum Place {
    /// Countries whose rules differ by state; the server asks for a state there.
    static let needsRegion: Set<String> = ["US", "CA", "AU"]

    struct Option: Hashable, Identifiable {
        let code: String
        let name: String
        var id: String { code }
    }

    /// Every country, named in the phone's language, sorted by name.
    static let countries: [Option] = Locale.Region.isoRegions
        .map(\.identifier)
        .filter { $0.count == 2 && $0.allSatisfy(\.isLetter) }
        .compactMap { code in Locale.current.localizedString(forRegionCode: code).map { Option(code: code, name: $0) } }
        .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }

    /// The phone's country, if it is one.
    static var phoneCountry: String? {
        guard let c = Locale.current.region?.identifier, c.count == 2, c.allSatisfy(\.isLetter) else { return nil }
        return c
    }

    static func countryName(_ code: String) -> String {
        Locale.current.localizedString(forRegionCode: code) ?? code
    }

    /// States, provinces and territories, by the part after the dash in ISO 3166-2.
    static func regions(of country: String) -> [Option] {
        let list: [(String, String)]
        switch country {
        case "US": list = usStates
        case "CA": list = [("AB", "Alberta"), ("BC", "British Columbia"), ("MB", "Manitoba"), ("NB", "New Brunswick"),
                           ("NL", "Newfoundland and Labrador"), ("NS", "Nova Scotia"), ("NT", "Northwest Territories"),
                           ("NU", "Nunavut"), ("ON", "Ontario"), ("PE", "Prince Edward Island"), ("QC", "Quebec"),
                           ("SK", "Saskatchewan"), ("YT", "Yukon")]
        case "AU": list = [("ACT", "Australian Capital Territory"), ("NSW", "New South Wales"), ("NT", "Northern Territory"),
                           ("QLD", "Queensland"), ("SA", "South Australia"), ("TAS", "Tasmania"), ("VIC", "Victoria"),
                           ("WA", "Western Australia")]
        default: list = []
        }
        return list.map { Option(code: $0.0, name: $0.1) }
    }

    static func regionName(_ region: String) -> String {
        let parts = region.split(separator: "-", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return region }
        return regions(of: parts[0]).first { $0.code == parts[1] }?.name ?? region
    }

    private static let usStates: [(String, String)] = [
        ("AL", "Alabama"), ("AK", "Alaska"), ("AZ", "Arizona"), ("AR", "Arkansas"), ("CA", "California"),
        ("CO", "Colorado"), ("CT", "Connecticut"), ("DE", "Delaware"), ("DC", "District of Columbia"),
        ("FL", "Florida"), ("GA", "Georgia"), ("HI", "Hawaii"), ("ID", "Idaho"), ("IL", "Illinois"),
        ("IN", "Indiana"), ("IA", "Iowa"), ("KS", "Kansas"), ("KY", "Kentucky"), ("LA", "Louisiana"),
        ("ME", "Maine"), ("MD", "Maryland"), ("MA", "Massachusetts"), ("MI", "Michigan"), ("MN", "Minnesota"),
        ("MS", "Mississippi"), ("MO", "Missouri"), ("MT", "Montana"), ("NE", "Nebraska"), ("NV", "Nevada"),
        ("NH", "New Hampshire"), ("NJ", "New Jersey"), ("NM", "New Mexico"), ("NY", "New York"),
        ("NC", "North Carolina"), ("ND", "North Dakota"), ("OH", "Ohio"), ("OK", "Oklahoma"), ("OR", "Oregon"),
        ("PA", "Pennsylvania"), ("RI", "Rhode Island"), ("SC", "South Carolina"), ("SD", "South Dakota"),
        ("TN", "Tennessee"), ("TX", "Texas"), ("UT", "Utah"), ("VT", "Vermont"), ("VA", "Virginia"),
        ("WA", "Washington"), ("WV", "West Virginia"), ("WI", "Wisconsin"), ("WY", "Wyoming"),
    ]
}
