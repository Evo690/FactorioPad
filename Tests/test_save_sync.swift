import Foundation

@main
struct SaveSyncTests {
    static func main() throws {
        let manager = FileManager.default
        let root = manager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? manager.removeItem(at: root) }
        let local = root.appendingPathComponent("iPad")
        let shared = root.appendingPathComponent("Mac")
        try manager.createDirectory(at: local, withIntermediateDirectories: true)
        try manager.createDirectory(at: shared, withIntermediateDirectories: true)
        let localSave = local.appendingPathComponent("world.zip")
        let sharedSave = shared.appendingPathComponent("world.zip")

        try Data("ipad v1".utf8).write(to: localSave)
        try FactorioSaveSync.synchronize(local: local, shared: shared)
        try Data("ipad v2".utf8).write(to: localSave)
        try FactorioSaveSync.synchronize(local: local, shared: shared)
        let ipadUpdate = try Data(contentsOf: sharedSave)
        assert(ipadUpdate == Data("ipad v2".utf8))
        let firstNames = try manager.contentsOfDirectory(atPath: shared.path)
        assert(firstNames.count == 1)

        try Data("mac v3".utf8).write(to: sharedSave)
        try FactorioSaveSync.synchronize(local: local, shared: shared)
        let macUpdate = try Data(contentsOf: localSave)
        assert(macUpdate == Data("mac v3".utf8))
        let secondNames = try manager.contentsOfDirectory(atPath: local.path)
        assert(secondNames.count == 1)

        try Data("ipad v4".utf8).write(to: localSave)
        try Data("mac v5".utf8).write(to: sharedSave)
        try manager.setAttributes([.modificationDate: Date(timeIntervalSince1970: 100)], ofItemAtPath: localSave.path)
        try manager.setAttributes([.modificationDate: Date(timeIntervalSince1970: 200)], ofItemAtPath: sharedSave.path)
        try FactorioSaveSync.synchronize(local: local, shared: shared)
        let current = try Data(contentsOf: localSave)
        let conflicts = try manager.contentsOfDirectory(atPath: local.path)
            .filter { $0.contains("iPad conflict") && $0.hasSuffix(".zip") }
        assert(current == Data("mac v5".utf8) && conflicts.count == 1)
        let conflict = try Data(contentsOf: local.appendingPathComponent(conflicts[0]))
        assert(conflict == Data("ipad v4".utf8))

        try FactorioSaveSync.synchronize(local: local, shared: shared)
        let localNames = try manager.contentsOfDirectory(atPath: local.path)
        let sharedNames = try manager.contentsOfDirectory(atPath: shared.path)
        assert(localNames.count == 2 && sharedNames.count == 2)
    }
}
