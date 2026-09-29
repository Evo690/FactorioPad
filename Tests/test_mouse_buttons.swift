import Foundation

@main struct MouseButtonTests {
    static func main() {
        var buttons = FactorioMouseButtonSources()
        let firstMouse = NSObject()
        let secondMouse = NSObject()
        let first = ObjectIdentifier(firstMouse)
        let second = ObjectIdentifier(secondMouse)
        let left = 1
        let right = 2

        assert(buttons.set(left, pressed: true, for: first) == left)
        assert(buttons.set(left, pressed: true, for: second) == left)
        assert(buttons.set(left, pressed: false, for: first) == left)
        assert(buttons.set(left, pressed: true, for: first) == left)
        assert(buttons.remove(first) == left)
        assert(buttons.set(left, pressed: false, for: second) == 0)
        assert(buttons.set(right, pressed: true, for: first) == right)
        assert(buttons.set(left, pressed: true, for: second) == left | right)
        assert(buttons.remove(first) == left)
        assert(buttons.remove(second) == 0)
        print("Factorio mouse button tests passed.")
    }
}
