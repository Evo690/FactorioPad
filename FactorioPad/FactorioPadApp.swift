import SwiftUI

@main
final class FactorioPadApp: UIResponder, UIApplicationDelegate {
    override init() {
        super.init()
        // Discard unused transfer data from earlier development builds.
        UserDefaults.standard.removeObject(forKey: "FactorioAccountSourceBookmark")
        try? FileManager.default.removeItem(at: FileManager.default.temporaryDirectory.appending(path: "factorio-account.json"))
    }

    func application(_ application: UIApplication, configurationForConnecting session: UISceneSession,
        options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: session.role)
        configuration.delegateClass = FactorioSceneDelegate.self
        return configuration
    }
}

final class FactorioSceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession,
        options: UIScene.ConnectionOptions) {
        guard let scene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: scene)
        window.rootViewController = FactorioRootController(rootView: FactorioLaunchView())
        window.makeKeyAndVisible()
        self.window = window
    }
}

final class FactorioRootController: UIHostingController<FactorioLaunchView> {
    weak var gameController: FactorioViewController?

    override var prefersPointerLocked: Bool { gameController?.prefersPointerLocked ?? false }
    override var prefersHomeIndicatorAutoHidden: Bool { true }
    override var preferredScreenEdgesDeferringSystemGestures: UIRectEdge { [.bottom, .right] }
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
