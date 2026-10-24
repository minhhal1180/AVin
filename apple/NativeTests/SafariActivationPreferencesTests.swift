import XCTest
@testable import VNAnviaApp

final class SafariActivationPreferencesTests:XCTestCase {
 func testNewInstallOffersHelpAndLaterLaunchDoesNotRepeatIt()throws {
  let suite="VNAnvia.SafariActivationTests."+UUID().uuidString
  let defaults=try XCTUnwrap(UserDefaults(suiteName:suite))
  defer{defaults.removePersistentDomain(forName:suite)}
  let preferences=SafariActivationPreferences(defaults:defaults)
  XCTAssertTrue(preferences.shouldPresentHelp)
  preferences.markHelpSeen()
  let relaunched=SafariActivationPreferences(defaults:defaults)
  XCTAssertFalse(relaunched.shouldPresentHelp)
 }
 func testHelpPreferenceStoresOnlySeenFlagAndDoesNotClaimPermission()throws {
  let suite="VNAnvia.SafariActivationTests."+UUID().uuidString
  let defaults=try XCTUnwrap(UserDefaults(suiteName:suite))
  defer{defaults.removePersistentDomain(forName:suite)}
  let preferences=SafariActivationPreferences(defaults:defaults)
  preferences.markHelpSeen()
  let saved=try XCTUnwrap(defaults.persistentDomain(forName:suite))
  XCTAssertEqual(Set(saved.keys),[SafariActivationPreferences.seenKey])
  XCTAssertEqual(saved[SafariActivationPreferences.seenKey] as? Bool,true)
 }
}
