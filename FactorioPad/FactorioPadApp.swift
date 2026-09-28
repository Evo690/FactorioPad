import SwiftUI

@main
struct FactorioPadApp: App {
    init() {
        // Discard unused transfer data from earlier development builds.
        UserDefaults.standard.removeObject(forKey: "FactorioAccountSourceBookmark")
        try? FileManager.default.removeItem(at: FileManager.default.temporaryDirectory.appending(path: "factorio-account.json"))
    }
    var body: some Scene {
        WindowGroup {
            FactorioLaunchView()
        }
    }
}

extension Notification.Name {
    static let factorioStopped = Notification.Name("FactorioStopped")
    static let factorioControlsRequested = Notification.Name("FactorioControlsRequested")
}

struct FactorioLaunchView: View {
    @State private var showsControls = false
    @State private var message: String?

    var body: some View {
        FactorioMetalView(inputEnabled: !showsControls && message == nil)
        .accessibilityHidden(showsControls)
        .ignoresSafeArea()
        .persistentSystemOverlays(.hidden)
        .statusBarHidden(true)
        .defersSystemGestures(on: [.bottom, .trailing])
        .onReceive(NotificationCenter.default.publisher(for: .factorioControlsRequested)) { _ in
            showsControls = true
        }
        .overlay {
            if showsControls {
                FactorioControlsView(onClose: { showsControls = false })
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .factorioStopped)) { notification in
            message = notification.userInfo?["message"] as? String
        }
        .alert("Factorio", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button("OK") { message = nil }
        } message: { Text(message ?? "") }
    }
}
