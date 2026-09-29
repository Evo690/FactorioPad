struct FactorioMouseButtonSources {
    private var held: [ObjectIdentifier: Int] = [:]

    var combined: Int { held.values.reduce(0, |) }

    mutating func set(_ button: Int, pressed: Bool, for device: ObjectIdentifier) -> Int {
        let current = held[device] ?? 0
        let next = pressed ? current | button : current & ~button
        held[device] = next == 0 ? nil : next
        return combined
    }

    mutating func remove(_ device: ObjectIdentifier) -> Int {
        held.removeValue(forKey: device)
        return combined
    }

    mutating func removeAll() { held.removeAll() }
}
