import AVFAudio
import GameController
import SwiftUI
import UIKit

final class FactorioHostUIView: UIView {
    var inputEnabled = true {
        didSet { setInputActive(window != nil && UIApplication.shared.applicationState == .active) }
    }
    private static var factorioStarted = false
    private var primaryTouch: UITouch?
    private var lifecycleObservers: [NSObjectProtocol] = []
    private var inputActive = true
    private var cursorDisplayLink: CADisplayLink?
    private let controllerCursor = FactorioControllerCursorView(frame: CGRect(x: 0, y: 0, width: 18, height: 23))
    private let onScreenKeyboard = FactorioOnScreenKeyboardView()
    private let keyboardButton = FactorioTouchOnlyButton(type: .system)

    override class var layerClass: AnyClass { FactorioMetalLayer.self }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        isOpaque = true
        isMultipleTouchEnabled = true
        onScreenKeyboard.isHidden = true
        onScreenKeyboard.onClose = { [weak self] in
            self?.onScreenKeyboard.isHidden = true
            self?.keyboardButton.isHidden = false
            self?.keyboardButton.accessibilityLabel = "Show keyboard"
        }
        addSubview(controllerCursor)
        addSubview(onScreenKeyboard)
        keyboardButton.setImage(UIImage(systemName: "keyboard"), for: .normal)
        keyboardButton.tintColor = .white
        keyboardButton.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        keyboardButton.layer.cornerRadius = 22
        keyboardButton.accessibilityLabel = "Show keyboard"
        keyboardButton.accessibilityHint = "Touch and hold for controller controls."
        keyboardButton.accessibilityCustomActions = [UIAccessibilityCustomAction(
            name: "Show controller controls", target: self, selector: #selector(showControlsWithAccessibility))]
        keyboardButton.addTarget(self, action: #selector(toggleKeyboard), for: .touchUpInside)
        let controlsPress = UILongPressGestureRecognizer(target: self, action: #selector(showControls))
        controlsPress.minimumPressDuration = 0.5
        keyboardButton.addGestureRecognizer(controlsPress)
        addSubview(keyboardButton)

        let center = NotificationCenter.default
        lifecycleObservers.append(center.addObserver(forName: UIApplication.willResignActiveNotification,
            object: nil, queue: .main) { [weak self] _ in self?.setInputActive(false) })
        lifecycleObservers.append(center.addObserver(forName: UIApplication.didBecomeActiveNotification,
            object: nil, queue: .main) { [weak self] _ in self?.setInputActive(true) })
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    deinit {
        for observer in lifecycleObservers { NotificationCenter.default.removeObserver(observer) }
    }

    func detach() {
        cursorDisplayLink?.invalidate()
        cursorDisplayLink = nil
        setInputActive(false)
    }

    private func setInputActive(_ applicationActive: Bool) {
        let active = applicationActive && inputEnabled
        inputActive = active
        primaryTouch = nil
        cursorDisplayLink?.isPaused = !active
        FactorioControllerBridgeSetActive(active)
        if !active {
            FactorioTouchCancel()
            onScreenKeyboard.reset()
        }
        // Keep the game rendering under help sheets. Suspend only for app lifecycle events.
        FactorioMetalLayer.setApplicationActive(applicationActive)
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard window != nil else { detach(); return }
        FactorioMetalHost.setHostView(self)
        if cursorDisplayLink == nil {
            let displayLink = CADisplayLink(target: self, selector: #selector(updateControllerCursor))
            displayLink.add(to: .main, forMode: .common)
            cursorDisplayLink = displayLink
        }
        setInputActive(UIApplication.shared.applicationState == .active)
        // Startup waits for a nonzero layout instead of assuming an iPad model.
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        guard window != nil, bounds.width > 0, bounds.height > 0 else { return }
        FactorioMetalHost.setHostView(self)
        // Use equal proportional edge gaps, not the side inset reserved for the iPhone notch.
        let buttonInset = max(8, min(bounds.width, bounds.height) * 0.016)
        keyboardButton.frame = CGRect(x: bounds.maxX - buttonInset - 44,
            y: bounds.maxY - buttonInset - 44, width: 44, height: 44)
        let keyboardHeight = min(280, bounds.height)
        onScreenKeyboard.frame = CGRect(x: 0, y: bounds.maxY - keyboardHeight,
            width: bounds.width, height: keyboardHeight)

        if !Self.factorioStarted {
            Self.factorioStarted = true
            configureAudioSession()
            FactorioLoader.start(withWindowSize: bounds.size)
        }
        FactorioControllerBridgeSetViewportSize(bounds.width, bounds.height)
        FactorioTouchUpdateWindowSize()
    }

    @objc private func updateControllerCursor() {
        controllerCursor.isHidden = !inputActive || !GCController.controllers().contains { $0.extendedGamepad != nil }
        controllerCursor.frame.origin = FactorioControllerBridgeGetCursorPosition()
    }

    @objc private func toggleKeyboard() {
        onScreenKeyboard.isHidden.toggle()
        keyboardButton.isHidden = !onScreenKeyboard.isHidden
        keyboardButton.accessibilityLabel = onScreenKeyboard.isHidden ? "Show keyboard" : "Hide keyboard"
    }

    @objc private func showControls(_ gesture: UILongPressGestureRecognizer) {
        switch gesture.state {
        case .began:
            keyboardButton.isHighlighted = false
            requestControls()
        case .ended, .cancelled, .failed:
            keyboardButton.isHighlighted = false
        default:
            break
        }
    }

    @objc private func showControlsWithAccessibility() -> Bool {
        requestControls()
        return true
    }

    private func requestControls() {
        onScreenKeyboard.isHidden = true
        keyboardButton.isHidden = false
        keyboardButton.accessibilityLabel = "Show keyboard"
        NotificationCenter.default.post(name: .factorioControlsRequested, object: nil)
    }

    private func updateTouch(_ touch: UITouch, send: (CGFloat, CGFloat) -> Void) {
        let point = touch.location(in: self)
        FactorioControllerBridgeSetCursorPosition(point.x, point.y)
        send(point.x, point.y)
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        guard inputActive, primaryTouch == nil, let touch = touches.first else { return }
        primaryTouch = touch
        updateTouch(touch, send: FactorioTouchBegin)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesMoved(touches, with: event)
        guard inputActive, let primaryTouch, touches.contains(primaryTouch) else { return }
        for touch in event?.coalescedTouches(for: primaryTouch) ?? [primaryTouch] {
            updateTouch(touch, send: FactorioTouchMove)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        guard inputActive, let primaryTouch, touches.contains(primaryTouch) else { return }
        updateTouch(primaryTouch, send: FactorioTouchEnd)
        self.primaryTouch = nil
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        guard let primaryTouch, touches.contains(primaryTouch) else { return }
        FactorioTouchCancel()
        self.primaryTouch = nil
    }

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default)
            try session.setActive(true)
        } catch { NSLog("[FactorioPad] Audio session failed: %@", error.localizedDescription) }
    }
}

final class FactorioViewController: UIViewController {
    let gameView = FactorioHostUIView(frame: .zero)
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .landscape }
    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation { .landscapeRight }
    override var prefersInterfaceOrientationLocked: Bool { true }
    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }

    override func loadView() {
        view = UIView()
        view.backgroundColor = .black
        view.addSubview(gameView)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        setNeedsUpdateOfSupportedInterfaceOrientations()
        setNeedsUpdateOfPrefersInterfaceOrientationLocked()
        setNeedsStatusBarAppearanceUpdate()
        setNeedsUpdateOfHomeIndicatorAutoHidden()
        view.window?.windowScene?.requestGeometryUpdate(.iOS(interfaceOrientations: .landscape)) { error in
            NSLog("[FactorioPad] Landscape request: %@", error.localizedDescription)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // iPadOS can supply a tall multitasking window despite orientation preferences.
        // Keep the game landscape-shaped, with black bars outside the game viewport.
        let height = min(view.bounds.height, view.bounds.width * 0.75)
        gameView.frame = CGRect(x: 0, y: (view.bounds.height - height) / 2,
            width: view.bounds.width, height: height)
    }
}

struct FactorioMetalView: UIViewControllerRepresentable {
    var inputEnabled = true
    func makeUIViewController(context: Context) -> FactorioViewController { FactorioViewController() }
    func updateUIViewController(_ controller: FactorioViewController, context: Context) {
        if controller.gameView.inputEnabled != inputEnabled {
            controller.gameView.inputEnabled = inputEnabled
        }
    }
    static func dismantleUIViewController(_ controller: FactorioViewController, coordinator: ()) {
        controller.gameView.detach()
    }
}
