import Foundation

enum MXCertificateInfo {
    static func expirationDate() -> Date? {
        guard let profileURL = Bundle.main.url(forResource: "embedded", withExtension: "mobileprovision"),
              let data = try? Data(contentsOf: profileURL),
              let plistData = embeddedPlist(in: data),
              let object = try? PropertyListSerialization.propertyList(from: plistData, options: [], format: nil),
              let dictionary = object as? [String: Any],
              let expiration = dictionary["ExpirationDate"] as? Date else {
            return nil
        }
        return expiration
    }

    private static func embeddedPlist(in data: Data) -> Data? {
        let xmlStart = Data("<?xml".utf8)
        let plistEnd = Data("</plist>".utf8)

        guard let startRange = data.range(of: xmlStart),
              let endRange = data.range(of: plistEnd, options: [], in: startRange.lowerBound..<data.endIndex) else {
            return nil
        }

        return data.subdata(in: startRange.lowerBound..<endRange.upperBound)
    }
}
