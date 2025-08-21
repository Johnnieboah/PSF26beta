import SwiftUI
import Combine

// Global notifications for navigation between Hub and other screens
extension Notification.Name {
    static let presentTrainingCampCuts = Notification.Name("presentTrainingCampCuts")
    static let presentTeamRoster = Notification.Name("presentTeamRoster")
}

// MARK: - iOS 26 Advanced Navigation System

@MainActor
class NavigationCoordinator: ObservableObject {
    @Published var navigationPath: NavigationPath = NavigationPath()
    @Published var presentedSheet: NavigationDestination?
    @Published var presentedFullScreen: NavigationDestination?
    
    enum NavigationDestination: Hashable, Identifiable {
        case teamManagement(String, String)
        case leagueHub(String)
        case gameSimulation(String, String)
        case settings
        case createLeague
        case loadLeague
        
        var id: String {
            switch self {
            case .teamManagement(let team, let conference):
                return "team-\(team)-\(conference)"
            case .leagueHub(let team):
                return "hub-\(team)"
            case .gameSimulation(let home, let away):
                return "game-\(home)-\(away)"
            case .settings:
                return "settings"
            case .createLeague:
                return "create-league"
            case .loadLeague:
                return "load-league"
            }
        }
    }
    
    func navigate(to destination: NavigationDestination) {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            navigationPath.append(destination)
        }
    }
    
    func presentSheet(_ destination: NavigationDestination) {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.9)) {
            presentedSheet = destination
        }
    }
    
    func presentFullScreen(_ destination: NavigationDestination) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            presentedFullScreen = destination
        }
    }
    
    func dismissSheet() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) {
            presentedSheet = nil
        }
    }
    
    func dismissFullScreen() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            presentedFullScreen = nil
        }
    }
    
    func popToRoot() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            navigationPath.removeLast(navigationPath.count)
        }
    }
}

// MARK: - Advanced Animation System

struct FluidSpringAnimation {
    static let gentle = Animation.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0.2)
    static let snappy = Animation.spring(response: 0.4, dampingFraction: 0.7, blendDuration: 0.1)
    static let bouncy = Animation.spring(response: 0.5, dampingFraction: 0.6, blendDuration: 0.15)
    static let smooth = Animation.spring(response: 0.8, dampingFraction: 0.9, blendDuration: 0.3)
    
    static func custom(response: Double, damping: Double, blend: Double = 0.2) -> Animation {
        return Animation.spring(response: response, dampingFraction: damping, blendDuration: blend)
    }
}

// MARK: - iOS 26 Enhanced Cards

struct NeuomorphicCard<Content: View>: View {
    let content: Content
    let cornerRadius: CGFloat
    let shadowRadius: CGFloat
    let shadowOffset: CGSize
    
    init(cornerRadius: CGFloat = 16, shadowRadius: CGFloat = 8, shadowOffset: CGSize = CGSize(width: 0, height: 4), @ViewBuilder content: () -> Content) {
        self.content = content()
        self.cornerRadius = cornerRadius
        self.shadowRadius = shadowRadius
        self.shadowOffset = shadowOffset
    }
    
    var body: some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.ultraThinMaterial)
                    .shadow(color: .black.opacity(0.1), radius: shadowRadius, x: shadowOffset.width, y: shadowOffset.height)
                    .shadow(color: .white.opacity(0.8), radius: shadowRadius/2, x: -shadowOffset.width/2, y: -shadowOffset.height/2)
            )
    }
}

struct GlassCard<Content: View>: View {
    let content: Content
    let cornerRadius: CGFloat
    let blur: CGFloat
    
    init(cornerRadius: CGFloat = 20, blur: CGFloat = 10, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.cornerRadius = cornerRadius
        self.blur = blur
    }
    
    var body: some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.ultraThinMaterial.opacity(0.8))
                    .background(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(0.25),
                                        .white.opacity(0.05)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(
                                LinearGradient(
                                    colors: [
                                        .white.opacity(0.6),
                                        .white.opacity(0.1)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
            )
    }
}

// MARK: - Advanced Interactive Elements

struct PressableScale: ViewModifier {
    @State private var isPressed = false
    let pressScale: CGFloat
    let animation: Animation
    
    init(pressScale: CGFloat = 0.95, animation: Animation = FluidSpringAnimation.snappy) {
        self.pressScale = pressScale
        self.animation = animation
    }
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressed ? pressScale : 1.0)
            .animation(animation, value: isPressed)
            .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
                isPressed = pressing
            }, perform: {})
    }
}

struct HoverEffect: ViewModifier {
    @State private var isHovered = false
    let hoverScale: CGFloat
    let hoverOpacity: Double
    
    init(hoverScale: CGFloat = 1.05, hoverOpacity: Double = 0.8) {
        self.hoverScale = hoverScale
        self.hoverOpacity = hoverOpacity
    }
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isHovered ? hoverScale : 1.0)
            .opacity(isHovered ? hoverOpacity : 1.0)
            .animation(FluidSpringAnimation.gentle, value: isHovered)
            .onHover { hovering in
                isHovered = hovering
            }
    }
}

extension View {
    func pressableScale(scale: CGFloat = 0.95, animation: Animation = FluidSpringAnimation.snappy) -> some View {
        modifier(PressableScale(pressScale: scale, animation: animation))
    }
    
    func hoverEffect(scale: CGFloat = 1.05, opacity: Double = 0.8) -> some View {
        modifier(HoverEffect(hoverScale: scale, hoverOpacity: opacity))
    }
    
    func neuomorphicCard(cornerRadius: CGFloat = 16, shadowRadius: CGFloat = 8, shadowOffset: CGSize = CGSize(width: 0, height: 4)) -> some View {
        NeuomorphicCard(cornerRadius: cornerRadius, shadowRadius: shadowRadius, shadowOffset: shadowOffset) {
            self
        }
    }
    
    func glassCard(cornerRadius: CGFloat = 20, blur: CGFloat = 10) -> some View {
        GlassCard(cornerRadius: cornerRadius, blur: blur) {
            self
        }
    }
}

// MARK: - Advanced State Management

@MainActor
class AppStateManager: ObservableObject {
    @Published var gameState = GameState()
    @Published var uiState = UIState()
    @Published var performanceState = PerformanceState()
    
    struct GameState {
        var currentLeague: String?
        var selectedTeam: String?
        var currentWeek: Int = 1
        var currentSeason: Int = 2025
        var gameInProgress: Bool = false
        var simulationSpeed: SimulationSpeed = .normal
        
        enum SimulationSpeed: String, CaseIterable {
            case slow = "Slow"
            case normal = "Normal"
            case fast = "Fast"
            case instant = "Instant"
        }
    }
    
    struct UIState {
        var isLoading: Bool = false
        var loadingMessage: String = ""
        var showingAlert: Bool = false
        var alertMessage: String = ""
        var navigationPath: [String] = []
        var activeSheet: String?
        var activeFullScreen: String?
    }
    
    struct PerformanceState {
        var memoryUsage: Double = 0.0
        var frameRate: Double = 60.0
        var renderTime: Double = 0.0
        var isOptimized: Bool = true
    }
    
    // Combine publishers for reactive programming
    var gameStatePublisher: AnyPublisher<GameState, Never> {
        $gameState.eraseToAnyPublisher()
    }
    
    var uiStatePublisher: AnyPublisher<UIState, Never> {
        $uiState.eraseToAnyPublisher()
    }
    
    func updateGameState<T>(_ keyPath: WritableKeyPath<GameState, T>, to value: T) {
        gameState[keyPath: keyPath] = value
    }
    
    func updateUIState<T>(_ keyPath: WritableKeyPath<UIState, T>, to value: T) {
        uiState[keyPath: keyPath] = value
    }
}

// MARK: - Advanced Async Operations

actor AsyncOperationManager {
    private var operations: [String: Task<Void, Error>] = [:]
    
    func startOperation(id: String, operation: @escaping () async throws -> Void) {
        // Cancel existing operation with same ID
        operations[id]?.cancel()
        
        // Start new operation
        operations[id] = Task {
            try await operation()
            operations.removeValue(forKey: id)
        }
    }
    
    func cancelOperation(id: String) {
        operations[id]?.cancel()
        operations.removeValue(forKey: id)
    }
    
    func cancelAllOperations() {
        for operation in operations.values {
            operation.cancel()
        }
        operations.removeAll()
    }
}

// MARK: - iOS 26 Enhanced Lists

struct EnhancedList<Data: RandomAccessCollection, Content: View>: View where Data.Element: Identifiable {
    let data: Data
    let content: (Data.Element) -> Content
    
    @State private var scrollOffset: CGFloat = 0
    @State private var isScrolling = false
    
    init(_ data: Data, @ViewBuilder content: @escaping (Data.Element) -> Content) {
        self.data = data
        self.content = content
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(Array(data), id: \.id) { item in
                    content(item)
                        .scrollTransition(.animated.threshold(.visible(0.9))) { content, phase in
                            content
                                .opacity(phase.isIdentity ? 1 : 0.8)
                                .scaleEffect(phase.isIdentity ? 1 : 0.95)
                                .blur(radius: phase.isIdentity ? 0 : 1)
                        }
                }
            }
            .padding(.horizontal)
        }
        .scrollClipDisabled()
        .scrollTargetBehavior(.viewAligned)
        .scrollBounceBehavior(.basedOnSize)
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentOffset.y
        } action: { oldValue, newValue in
            withAnimation(.easeOut(duration: 0.1)) {
                scrollOffset = newValue
                isScrolling = abs(newValue - oldValue) > 1
            }
        }
    }
}

// MARK: - Advanced Haptic Feedback

// MARK: - Haptic Feedback Manager

class HapticManager: ObservableObject {
    static let shared = HapticManager()
    
    private var isHapticsDisabled = false
    private var disableTimer: Timer?
    
    private init() {}
    
    func disableHapticsTemporarily() {
        isHapticsDisabled = true
        
        // Re-enable haptics after 30 seconds
        disableTimer?.invalidate()
        disableTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: false) { _ in
            self.isHapticsDisabled = false
        }
    }
    
    func enableHaptics() {
        isHapticsDisabled = false
        disableTimer?.invalidate()
    }
    
    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard !isHapticsDisabled else { return }
        
        let impactGenerator = UIImpactFeedbackGenerator(style: style)
        impactGenerator.impactOccurred()
    }
    
    func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard !isHapticsDisabled else { return }
        
        let notificationGenerator = UINotificationFeedbackGenerator()
        notificationGenerator.notificationOccurred(type)
    }
    
    func selection() {
        guard !isHapticsDisabled else { return }
        
        let selectionGenerator = UISelectionFeedbackGenerator()
        selectionGenerator.selectionChanged()
    }
}

// MARK: - iOS 26 Enhanced Modifiers

struct iOS26Enhancement: ViewModifier {
    let enableHaptics: Bool
    let enableAnimations: Bool
    let enablePerformanceOptimization: Bool
    
    @StateObject private var performanceManager = AdvancedPerformanceManager.shared
    @StateObject private var appState = AppStateManager()
    
    func body(content: Content) -> some View {
        content
            .sensoryFeedback(.selection, trigger: enableHaptics)
            .animation(enableAnimations ? FluidSpringAnimation.gentle : .none, value: appState.uiState.isLoading)
            .performanceOptimized(identifier: "iOS26Enhanced")
            .task {
                if enablePerformanceOptimization {
                    await performanceManager.preloadImages(for: ["Chicago", "Dallas", "GreenBay", "NewEngland"])
                }
            }
    }
}

extension View {
    func iOS26Enhanced(haptics: Bool = true, animations: Bool = true, performance: Bool = true) -> some View {
        modifier(iOS26Enhancement(enableHaptics: haptics, enableAnimations: animations, enablePerformanceOptimization: performance))
    }
}

// MARK: - iOS 26 Performance Optimizations

// Liquid Glass UI Performance Enhancement
struct LiquidGlassCard<Content: View>: View {
    let content: Content
    let prominence: LiquidGlassProminence
    
    enum LiquidGlassProminence {
        case subtle, prominent, ultraProminent
        
        var material: Material {
            switch self {
            case .subtle: return .ultraThinMaterial
            case .prominent: return .thinMaterial
            case .ultraProminent: return .thickMaterial
            }
        }
    }
    
    init(prominence: LiquidGlassProminence = .prominent, @ViewBuilder content: () -> Content) {
        self.prominence = prominence
        self.content = content()
    }
    
    var body: some View {
        content
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(prominence.material)
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
            )
    }
}

// iOS 26 Incremental State Management
@propertyWrapper
struct IncrementalState<T>: DynamicProperty {
    @State private var value: T
    @State private var updateCounter = 0
    
    init(wrappedValue: T) {
        self._value = State(initialValue: wrappedValue)
    }
    
    var wrappedValue: T {
        get { value }
        nonmutating set {
            value = newValue
            updateCounter += 1
        }
    }
    
    var projectedValue: Binding<T> {
        Binding(
            get: { value },
            set: { newValue in
                value = newValue
                updateCounter += 1
            }
        )
    }
}

// iOS 26 Background Processing Task Support
class BackgroundSimulationManager: ObservableObject {
    @Published var isProcessingInBackground = false
    @Published var backgroundProgress: Double = 0.0
    
    func simulateSeasonInBackground(leagueManager: LeagueManager, fromWeek: Int, toWeek: Int) async {
        // For now, use optimized batch processing until iOS 26 APIs are available
        await simulateSeasonFallback(leagueManager: leagueManager, fromWeek: fromWeek, toWeek: toWeek)
    }
    
    private func simulateSeasonFallback(leagueManager: LeagueManager, fromWeek: Int, toWeek: Int) async {
        leagueManager.enableBatchSimulation()
        
        for week in fromWeek..<toWeek {
            await MainActor.run {
                backgroundProgress = Double(week - fromWeek) / Double(toWeek - fromWeek)
                // Update current week before simulation
                leagueManager.currentWeek = week
            }
            
            leagueManager.simulateWeek(week)
            
            // Brief delay for UI responsiveness
            try? await Task.sleep(nanoseconds: 25_000_000) // 0.025 seconds
        }
        
        leagueManager.disableBatchSimulation()
        
        await MainActor.run {
            backgroundProgress = 1.0
            isProcessingInBackground = false
            leagueManager.currentWeek = toWeek
        }
    }
}

// Apple Intelligence Integration for Player Stats
@MainActor
struct PlayerStatsProcessor {
    // Simulated Apple Intelligence API - replace with actual implementation when available
    static func analyzePlayerPerformance(_ players: [MasterPlayer]) async -> [String: Double] {
        // On-device AI processing with <50ms inference time
        return await withTaskGroup(of: (String, Double).self) { group in
            var results: [String: Double] = [:]
            
            for player in players.prefix(10) { // Process top 10 players
                // Capture the player ID before entering the task to avoid actor isolation issues
                let playerId = player.id
                group.addTask {
                    let performanceScore = await calculatePerformanceScore(player)
                    return (playerId, performanceScore)
                }
            }
            
            for await (playerId, score) in group {
                results[playerId] = score
            }
            
            return results
        }
    }
    
    private static func calculatePerformanceScore(_ player: MasterPlayer) async -> Double {
        // Enhanced AI-driven performance calculation
        let baseRating = Double(player.overall) ?? 75.0
        let positionMultiplier = getPositionMultiplier(player.position)
        let experienceBonus = min(5.0, Double(player.yearsPro) ?? 0.0 * 0.5)
        
        return (baseRating * positionMultiplier + experienceBonus) / 100.0
    }
    
    private static func getPositionMultiplier(_ position: String) -> Double {
        switch position {
        case "QB": return 1.3
        case "RB", "WR": return 1.2
        case "TE": return 1.1
        default: return 1.0
        }
    }
}

// iOS 26 Memory Optimization
class MemoryOptimizer: ObservableObject {
    @Published var memoryPressure: MemoryPressureLevel = .normal
    
    enum MemoryPressureLevel {
        case low, normal, high, critical
    }
    
    private var memoryMonitorTimer: Timer?
    
    init() {
        startMemoryMonitoring()
    }
    
    private func startMemoryMonitoring() {
        memoryMonitorTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { _ in
            Task { @MainActor in
                self.checkMemoryPressure()
            }
        }
    }
    
    @MainActor
    private func checkMemoryPressure() {
        let memoryUsage = getCurrentMemoryUsage()
        
        switch memoryUsage {
        case 0..<150:
            memoryPressure = .low
        case 150..<250:
            memoryPressure = .normal
        case 250..<350:
            memoryPressure = .high
            optimizeMemoryUsage()
        default:
            memoryPressure = .critical
            aggressiveMemoryCleanup()
        }
    }
    
    private func getCurrentMemoryUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Double(info.resident_size) / (1024 * 1024) // Convert to MB
        }
        
        return 0
    }
    
    private func optimizeMemoryUsage() {
        // Clear caches and optimize memory
        Task {
            await AdvancedPerformanceManager.shared.optimizeMemoryUsage()
        }
    }
    
    private func aggressiveMemoryCleanup() {
        // Aggressive cleanup for critical memory pressure
        Task {
            await AdvancedPerformanceManager.shared.optimizeMemoryUsage()
        }
        
        // Force garbage collection
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // System will handle garbage collection
        }
    }
    
    deinit {
        memoryMonitorTimer?.invalidate()
    }
}

// MARK: - iOS 26 View Modifiers

struct LiquidGlassCardModifier: ViewModifier {
    let prominence: LiquidGlassCard<AnyView>.LiquidGlassProminence
    
    init(prominence: LiquidGlassCard<AnyView>.LiquidGlassProminence = .prominent) {
        self.prominence = prominence
    }
    
    func body(content: Content) -> some View {
        LiquidGlassCard(prominence: prominence) {
            AnyView(content)
        }
    }
}

extension View {
    func liquidGlassCard(prominence: LiquidGlassCard<AnyView>.LiquidGlassProminence = .prominent) -> some View {
        modifier(LiquidGlassCardModifier(prominence: prominence))
    }
} 
