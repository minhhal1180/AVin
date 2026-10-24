import SwiftUI
@main struct VNAnviaApp:App {
 @State private var checkedSafariSetup=false
 @State private var showingSafariSetup=false
 private let safariSetup=SafariActivationPreferences()
 var body:some Scene {
  WindowGroup {
   AnalysisScreen()
    .task {
     guard !checkedSafariSetup else{return}
     checkedSafariSetup=true
     showingSafariSetup=safariSetup.shouldPresentHelp
    }
    .sheet(isPresented:$showingSafariSetup,onDismiss:{safariSetup.markHelpSeen()}) {
     SafariHelp(firstRun:true)
    }
  }
 }
}

