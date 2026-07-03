import Foundation

// 单个调试节点快照。
public struct DebugNodeSnapshot: Codable, Identifiable, Sendable {
    public let id: String
    public let parentID: String?
    public let role: String
    public let label: String
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double
    public let isVisible: Bool
    public let actions: [String]

    public init(
        id: String,
        parentID: String? = nil,
        role: String,
        label: String,
        x: Double,
        y: Double,
        width: Double,
        height: Double,
        isVisible: Bool,
        actions: [String]
    ) {
        self.id = id
        self.parentID = parentID
        self.role = role
        self.label = label
        self.x = x
        self.y = y
        self.width = width
        self.height = height
        self.isVisible = isVisible
        self.actions = actions
    }
}

// bridge 运行时上下文。
public struct DebugBridgeContext: Sendable {
    public let appName: String
    public let consoleTitle: String?
    public let screenName: String
    public let serverTime: String

    public init(
        appName: String,
        consoleTitle: String? = nil,
        screenName: String,
        serverTime: String = debugTimestampString()
    ) {
        self.appName = appName
        self.consoleTitle = consoleTitle
        self.screenName = screenName
        self.serverTime = serverTime
    }
}

// action query。
public struct DebugActionCatalogQuery: Sendable {
    public let targetId: String?
    public let action: String?
    public let screen: String?

    public init(
        targetId: String? = nil,
        action: String? = nil,
        screen: String? = nil
    ) {
        self.targetId = targetId
        self.action = action
        self.screen = screen
    }

    public var hasFilters: Bool {
        targetId != nil || action != nil || screen != nil
    }
}

// logs query。
public struct DebugLogsQuery: Sendable {
    public let isQueryRequest: Bool
    public let event: String?
    public let level: String?
    public let source: String?
    public let targetId: String?
    public let screen: String?
    public let from: String?
    public let to: String?
    public let limit: Int
    public let keyword: String?

    public init(
        isQueryRequest: Bool = false,
        event: String? = nil,
        level: String? = nil,
        source: String? = nil,
        targetId: String? = nil,
        screen: String? = nil,
        from: String? = nil,
        to: String? = nil,
        limit: Int = 20,
        keyword: String? = nil
    ) {
        self.isQueryRequest = isQueryRequest
        self.event = event
        self.level = level
        self.source = source
        self.targetId = targetId
        self.screen = screen
        self.from = from
        self.to = to
        self.limit = limit
        self.keyword = keyword
    }

    public var hasFilters: Bool {
        isQueryRequest
            || event != nil
            || level != nil
            || source != nil
            || targetId != nil
            || screen != nil
            || from != nil
            || to != nil
            || keyword != nil
    }
}

// state query。
public struct DebugStateQuery: Sendable {
    public let isQueryRequest: Bool
    public let keys: [String]
    public let targetId: String?
    public let scope: String?

    public init(
        isQueryRequest: Bool = false,
        keys: [String] = [],
        targetId: String? = nil,
        scope: String? = nil
    ) {
        self.isQueryRequest = isQueryRequest
        self.keys = keys
        self.targetId = targetId
        self.scope = scope
    }

    public var hasFilters: Bool {
        isQueryRequest || !keys.isEmpty || targetId != nil || scope != nil
    }
}

// snapshot query。
public struct DebugSnapshotQuery: Sendable {
    public let isQueryRequest: Bool
    public let targetId: String?
    public let scope: String?
    public let depth: Int?
    public let types: [String]
    public let textKeyword: String?
    public let visible: Bool?
    public let enabled: Bool?
    public let clickable: Bool?
    public let fields: [String]
    public let limit: Int

    public init(
        isQueryRequest: Bool = false,
        targetId: String? = nil,
        scope: String? = nil,
        depth: Int? = nil,
        types: [String] = [],
        textKeyword: String? = nil,
        visible: Bool? = nil,
        enabled: Bool? = nil,
        clickable: Bool? = nil,
        fields: [String] = [],
        limit: Int = 20
    ) {
        self.isQueryRequest = isQueryRequest
        self.targetId = targetId
        self.scope = scope
        self.depth = depth
        self.types = types
        self.textKeyword = textKeyword
        self.visible = visible
        self.enabled = enabled
        self.clickable = clickable
        self.fields = fields
        self.limit = limit
    }

    public var hasFilters: Bool {
        isQueryRequest
            || targetId != nil
            || scope != nil
            || depth != nil
            || !types.isEmpty
            || textKeyword != nil
            || visible != nil
            || enabled != nil
            || clickable != nil
            || !fields.isEmpty
    }
}

public func debugTimestampString(_ date: Date = Date()) -> String {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = .current
    formatter.dateFormat = "yyyyMMdd-HHmmss"
    return formatter.string(from: date)
}

public func debugBundleBuildVersion(bundle: Bundle = .main) -> Int {
    if let number = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? NSNumber {
        return number.intValue
    }

    if let string = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String {
        let normalized = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if let value = Int(normalized) {
            return value
        }
        if let head = normalized.split(separator: ".").first, let value = Int(head) {
            return value
        }
    }

    return 0
}
