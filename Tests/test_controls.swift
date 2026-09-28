import Foundation

@main
struct ControlsTests {
    static func main() {
        let activities = FactorioControlsView.activities
        assert(activities.count == 6 && Set(activities.map(\.title)).count == activities.count)
        assert(activities.allSatisfy { !$0.controls.isEmpty })
        let controls = activities.flatMap(\.controls)
        assert(controls.allSatisfy { !$0.action.isEmpty && !$0.buttons.isEmpty })
        assert(Set(controls.map(\.action)).count == controls.count, "Each action must appear once")
        assert(!controls.contains { $0.action == "Select second-row slots, if visible" })
        let expected = [
            "Select quickbars 1 / 2 / 3 / 4": "LB + D-pad",
            "Clear slot assignment": "RB + D-pad ↑",
            "Toggle inventory slot filter": "RB + D-pad ↑",
            "Select next weapon": "RB + D-pad →",
            "Shoot the selected target": "LB + Y",
            "Copy machine settings": "LB + LT",
            "Paste machine settings": "LB + RT",
            "Cycle blueprints in a held book": "LB + stick clicks",
            "Select deconstruction planner": "RB + D-pad ↓",
            "Select upgrade planner": "RB + D-pad ←",
            "Transfer selected stack": "LB + RT",
            "Transfer half of selected stack": "LB + LT",
            "Transfer all of selected item": "RB + RT",
            "Transfer half of selected item": "RB + LT",
            "Copy an area": "RB + B", "Cut an area": "LB + RB + B",
            "Undo": "LB + RB + X", "Redo": "LB + RB + Y"
        ]
        for (action, buttons) in expected {
            assert(controls.contains { $0.action == action && $0.buttons == buttons }, "Wrong binding for \(action)")
        }
        print("Factorio controller guide tests passed.")
    }
}
