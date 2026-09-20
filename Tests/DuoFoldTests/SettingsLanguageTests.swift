import Foundation
import Testing
@testable import DuoFold

struct SettingsLanguageTests {
    /// SwiftPM with Xcode 26.4 writes a flat bundle with `zh-hans.lproj`.
    /// Xcode 26.6 writes `Contents/Resources/zh-Hans.lproj`. The published
    /// build showed English for Chinese because only one spelling was tried.
    @Test(arguments: ["zh-hans.lproj", "Contents/Resources/zh-Hans.lproj"])
    func testFindsTheChineseTableInBothBundleLayouts(lprojPath: String) throws {
        let root = try makeBundle(lprojPath: lprojPath)
        defer { try? FileManager.default.removeItem(at: root) }
        let resources = try #require(Bundle(url: root))

        let lproj = try #require(SettingsLanguage.lprojBundle(for: "zh-Hans", in: resources))
        #expect(lproj.localizedString(forKey: "Start angle", value: "Start angle", table: nil) == "起始角度")
    }

    @Test
    func testMissingLanguageReturnsNil() throws {
        let root = try makeBundle(lprojPath: "en.lproj")
        defer { try? FileManager.default.removeItem(at: root) }
        let resources = try #require(Bundle(url: root))

        #expect(SettingsLanguage.lprojBundle(for: "zh-Hans", in: resources) == nil)
    }

    @Test
    func testEveryCaseIsDeclaredInInfoPlist() throws {
        // `preferredLocalizations` ignores languages the app does not declare,
        // so the System option can only pick languages listed here.
        let plistURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Resources/Info.plist")
        let plist = try #require(NSDictionary(contentsOf: plistURL) as? [String: Any])
        let declared = try #require(plist["CFBundleLocalizations"] as? [String])
        for language in SettingsLanguage.allCases {
            #expect(declared.contains(language.rawValue), "\(language.rawValue) is missing from CFBundleLocalizations")
        }
    }

    /// A resource bundle in a temporary directory with one strings table.
    private func makeBundle(lprojPath: String) throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SettingsLanguageTests-\(UUID().uuidString)")
        let lproj = root.appendingPathComponent(lprojPath)
        try FileManager.default.createDirectory(at: lproj, withIntermediateDirectories: true)
        let strings = "\"Start angle\" = \"起始角度\";\n"
        try strings.write(to: lproj.appendingPathComponent("Localizable.strings"), atomically: true, encoding: .utf8)
        return root
    }
}
