import Foundation

/// This flag records that the app has shown help, never that Safari granted access.
/// Only the containing app includes this file; Share and Safari targets do not prompt.
struct SafariActivationPreferences {
 static let seenKey="safariActivationHelpSeen.v1"
 private let defaults:UserDefaults
 init(defaults:UserDefaults = .standard){self.defaults=defaults}
 var shouldPresentHelp:Bool{!defaults.bool(forKey:Self.seenKey)}
 func markHelpSeen(){defaults.set(true,forKey:Self.seenKey)}
}
