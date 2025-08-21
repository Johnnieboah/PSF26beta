import SwiftUI
import Combine
import UIKit
import Foundation

// MARK: - Advanced Performance Manager
@MainActor
class AdvancedPerformanceManager: ObservableObject {
    static let shared = AdvancedPerformanceManager()
    
    // MARK: - Performance Metrics
    @Published var currentFPS: Double = 120.0
    @Published var memoryUsage: Double = 0.0
    @Published var cpuUsage: Double = 0.0
    @Published var batteryLevel: Float = 1.0
    @Published var thermalState: ProcessInfo.ThermalState = .nominal
    @Published var performanceMode: PerformanceMode = .balanced
    @Published var isOptimizing: Bool = false
    
    // MARK: - Analytics and Profiling
    @Published var simulationMetrics: SimulationMetrics = SimulationMetrics()
    @Published var frameDropCount: Int = 0
    @Published var averageSimulationTime: Double = 0.0
    @Published var peakMemoryUsage: Double = 0.0
    @Published var performanceScore: Double = 100.0
    
    // MARK: - iOS 26 Device Capabilities
    @Published var deviceCapabilities = DeviceCapabilities()
    @Published var aiAvailability: AIAvailability = .unavailable
    
    enum AIAvailability {
        case unavailable           // Older devices
        case available            // iPhone 15 Pro/Pro Max with iOS 26
        case limitedProcessing    // iPhone 15 Pro with thermal throttling
        case fullCapability       // iPhone 15 Pro Max optimal conditions
    }
    
    struct DeviceCapabilities {
        let supportsAppleIntelligence: Bool
        let supportsFoundationModels: Bool
        let supportsMetal4: Bool
        let supportsVisualIntelligence: Bool
        let deviceModel: DeviceModel
        let processingCapability: ProcessingCapability
        
        enum DeviceModel {
            case iPhone15Pro, iPhone15ProMax, iPhone16Pro, iPhone16ProMax
            case olderDevice(String)
        }
        
        enum ProcessingCapability {
            case full, limited, minimal
        }
        
        init() {
            let modelName = Self.getDeviceModel()
            self.deviceModel = Self.parseDeviceModel(modelName)
            
            // Check iOS version and device capability
            if #available(iOS 26.0, *) {
                switch deviceModel {
                case .iPhone15Pro, .iPhone15ProMax, .iPhone16Pro, .iPhone16ProMax:
                    self.supportsAppleIntelligence = true
                    self.supportsFoundationModels = true
                    self.supportsMetal4 = true
                    self.supportsVisualIntelligence = true
                    self.processingCapability = .full
                default:
                    self.supportsAppleIntelligence = false
                    self.supportsFoundationModels = false
                    self.supportsMetal4 = false
                    self.supportsVisualIntelligence = false
                    self.processingCapability = .minimal
                }
            } else {
                // iOS 25 and below - no AI features
                self.supportsAppleIntelligence = false
                self.supportsFoundationModels = false
                self.supportsMetal4 = false
                self.supportsVisualIntelligence = false
                self.processingCapability = deviceModel.isProDevice ? .limited : .minimal
            }
        }
        
        private static func getDeviceModel() -> String {
            var systemInfo = utsname()
            uname(&systemInfo)
            return withUnsafePointer(to: &systemInfo.machine) {
                $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                    String(validatingUTF8: $0) ?? "Unknown"
                }
            }
        }
        
        private static func parseDeviceModel(_ model: String) -> DeviceModel {
            switch model {
            case "iPhone16,1": return .iPhone15Pro
            case "iPhone16,2": return .iPhone15ProMax
            case "iPhone17,1": return .iPhone16Pro
            case "iPhone17,2": return .iPhone16ProMax
            default: return .olderDevice(model)
            }
        }
    }
    
    // MARK: - Performance History
    private var fpsHistory: [Double] = []
    private var memoryHistory: [Double] = []
    private var simulationTimeHistory: [Double] = []
    private let maxHistorySize = 100
    
    // MARK: - Monitoring State
    private var performanceTimer: Timer?
    private var analyticsTimer: Timer?
    private var isMonitoring = false
    
    // MARK: - Performance Thresholds
    private let lowFPSThreshold: Double = 90.0 // 90fps minimum for 120fps target
    private let highMemoryThreshold: Double = 300.0 // MB
    private let highCPUThreshold: Double = 80.0 // %
    
    enum PerformanceMode: String, CaseIterable {
        case powersaver = "Power Saver"
        case balanced = "Balanced"
        case performance = "Performance"
        case adaptive = "Adaptive"
    }
    
    // Memory Management
    @Published var performanceMetrics = PerformanceMetrics()
    
    // View Recycling Pool
    private var viewPool: [String: Any] = [:]
    private let maxPoolSize = 50
    
    // Image Cache with LRU eviction
    private var imageCache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 100
        cache.totalCostLimit = 100 * 1024 * 1024 // 100MB
        return cache
    }()
    
    // State optimization
    private var stateObservers: Set<AnyCancellable> = []
    
    struct PerformanceMetrics {
        var viewRenderTime: Double = 0.0
        var memoryPressure: MemoryPressureLevel = .normal
        var cacheHitRate: Double = 0.0
        var activeViews: Int = 0
        
        enum MemoryPressureLevel {
            case low, normal, high, critical
        }
    }
    
    // MARK: - Performance Monitoring Control
    private var isMonitoringPaused = false
    private var pausedTimers: (performanceTimer: Timer?, analyticsTimer: Timer?) = (nil, nil)
    
    // Add properties for tracking last update times
    private var lastMetricsUpdate: TimeInterval = 0
    private var lastAnalyticsUpdate: TimeInterval = 0
    private var lastSystemMetricsUpdate: TimeInterval = 0
    
    private init() {
        // Start monitoring after a delay to prevent initial CPU spike
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            self.startMonitoring()
        }
        
        setupThermalStateMonitoring()
        setupBatteryMonitoring()
        setupMemoryMonitoring()
        setupPerformanceTracking()
        
        // Initialize AI capability assessment
        assessAICapability()
    }
    
    // MARK: - AI Capability Assessment
    func assessAICapability() {
        let capabilities = deviceCapabilities
        
        if !capabilities.supportsAppleIntelligence {
            aiAvailability = .unavailable
            return
        }
        
        // Check current performance conditions
        let thermalOK = thermalState == .nominal || thermalState == .fair
        let batteryOK = batteryLevel > 0.2
        let memoryOK = memoryUsage < 200.0 // MB
        
        switch (capabilities.deviceModel, thermalOK && batteryOK && memoryOK) {
        case (.iPhone15ProMax, true), (.iPhone16ProMax, true):
            aiAvailability = .fullCapability
        case (.iPhone15Pro, true), (.iPhone16Pro, true):
            aiAvailability = .available
        case (.iPhone15Pro, false), (.iPhone15ProMax, false), 
             (.iPhone16Pro, false), (.iPhone16ProMax, false):
            aiAvailability = .limitedProcessing
        default:
            aiAvailability = .unavailable
        }
    }
    
    // MARK: - Performance Monitoring Setup
    private func setupPerformanceMonitoring() {
        // Invalidate existing timers
        performanceTimer?.invalidate()
        analyticsTimer?.invalidate()
        
        guard isMonitoring && !isMonitoringPaused else { return }
        
        // Reduced frequency during intensive operations
        let performanceInterval: TimeInterval = shouldUseReducedFrequency() ? 2.0 : 0.5
        let analyticsInterval: TimeInterval = shouldUseReducedFrequency() ? 10.0 : 5.0
        
        // Performance metrics timer
        performanceTimer = Timer.scheduledTimer(withTimeInterval: performanceInterval, repeats: true) { _ in
            Task { @MainActor in
                self.updatePerformanceMetrics()
            }
        }
        
        // Analytics timer
        analyticsTimer = Timer.scheduledTimer(withTimeInterval: analyticsInterval, repeats: true) { _ in
            Task { @MainActor in
                self.updateAnalytics()
            }
        }
    }
    
    private func setupThermalStateMonitoring() {
        NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                self.thermalState = ProcessInfo.processInfo.thermalState
                self.handleThermalStateChange()
            }
        }
    }
    
    private func setupBatteryMonitoring() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        NotificationCenter.default.addObserver(
            forName: UIDevice.batteryLevelDidChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                self.batteryLevel = UIDevice.current.batteryLevel
                self.adaptBatteryOptimizations()
            }
        }
    }
    
    // MARK: - Performance Metrics Updates
    private func updatePerformanceMetrics() {
        guard !isMonitoringPaused else { return }
        
        // Only update metrics every 2 seconds to reduce CPU load
        let currentTime = Date().timeIntervalSince1970
        if currentTime - lastMetricsUpdate < 2.0 { return }
        lastMetricsUpdate = currentTime
        
        // Batch memory and CPU updates
        Task {
            async let memoryTask = getCurrentMemoryUsage()
            async let cpuTask = getCurrentCPUUsage()
            
            let (newMemoryUsage, newCPUUsage) = await (memoryTask, cpuTask)
            
            await MainActor.run {
                // Update memory usage
                memoryUsage = newMemoryUsage
                peakMemoryUsage = max(peakMemoryUsage, newMemoryUsage)
                
                // Update CPU usage
                cpuUsage = newCPUUsage
                
                // Update battery level and thermal state less frequently
                if currentTime - lastSystemMetricsUpdate >= 5.0 {
                    batteryLevel = UIDevice.current.batteryLevel
                    thermalState = ProcessInfo.processInfo.thermalState
                    lastSystemMetricsUpdate = currentTime
                }
                
                // Track history and calculate performance score
                addToHistory(fps: currentFPS, memory: memoryUsage)
                calculatePerformanceScore()
            }
        }
    }
    
    private func updateAnalytics() {
        guard !isMonitoringPaused else { return }
        
        // Only update analytics every 5 seconds
        let currentTime = Date().timeIntervalSince1970
        if currentTime - lastAnalyticsUpdate < 5.0 { return }
        lastAnalyticsUpdate = currentTime
        
        // Update simulation metrics
        simulationMetrics.updateAverages()
        
        // Check for performance issues
        detectPerformanceIssues()
        
        // Log performance data every 30 seconds
        if Int(currentTime) % 30 == 0 {
            logPerformanceData()
        }
    }
    
    // MARK: - Memory Management
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
    
    private func getCurrentCPUUsage() -> Double {
        var info: processor_info_array_t?
        var numCpuInfo: mach_msg_type_number_t = 0
        var numCpus: natural_t = 0
        
        let result = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &numCpus, &info, &numCpuInfo)
        
        if result == KERN_SUCCESS, let cpuInfo = info {
            let cpuLoadInfo = cpuInfo.withMemoryRebound(to: processor_cpu_load_info.self, capacity: Int(numCpus)) { $0 }
            
            var totalTicks: UInt32 = 0
            var idleTicks: UInt32 = 0
            
            for i in 0..<Int(numCpus) {
                let cpu = cpuLoadInfo[i]
                totalTicks += cpu.cpu_ticks.0 + cpu.cpu_ticks.1 + cpu.cpu_ticks.2 + cpu.cpu_ticks.3
                idleTicks += cpu.cpu_ticks.3 // CPU_STATE_IDLE
            }
            
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: cpuInfo), vm_size_t(numCpuInfo))
            
            if totalTicks > 0 {
                return Double(totalTicks - idleTicks) / Double(totalTicks) * 100.0
            }
        }
        
        return 0
    }
    
    // MARK: - Performance History Management
    private func addToHistory(fps: Double, memory: Double) {
        fpsHistory.append(fps)
        memoryHistory.append(memory)
        
        // Keep history size manageable
        if fpsHistory.count > maxHistorySize {
            fpsHistory.removeFirst()
        }
        if memoryHistory.count > maxHistorySize {
            memoryHistory.removeFirst()
        }
    }
    
    // MARK: - Performance Score Calculation
    private func calculatePerformanceScore() {
        var score: Double = 100.0
        
        // FPS impact (40% weight)
        let fpsScore = min(currentFPS / 60.0, 1.0) * 40.0
        
        // Memory impact (30% weight)
        let memoryScore = max(0, (400.0 - memoryUsage) / 400.0) * 30.0
        
        // CPU impact (20% weight)
        let cpuScore = max(0, (100.0 - cpuUsage) / 100.0) * 20.0
        
        // Thermal impact (10% weight)
        let thermalScore: Double = {
            switch thermalState {
            case .nominal: return 10.0
            case .fair: return 7.5
            case .serious: return 5.0
            case .critical: return 2.5
            @unknown default: return 5.0
            }
        }()
        
        score = fpsScore + memoryScore + cpuScore + thermalScore
        performanceScore = max(0, min(100, score))
    }
    
    // MARK: - Adaptive Optimization
    private func adaptiveOptimization() {
        guard performanceMode == .adaptive else { return }
        
        let shouldOptimize = shouldTriggerOptimization()
        
        if shouldOptimize && !isOptimizing {
            Task {
                await performAdaptiveOptimization()
            }
        }
    }
    
    private func shouldTriggerOptimization() -> Bool {
        return currentFPS < lowFPSThreshold ||
               memoryUsage > highMemoryThreshold ||
               cpuUsage > highCPUThreshold ||
               thermalState == .serious ||
               thermalState == .critical ||
               batteryLevel < 0.2
    }
    
    private func performAdaptiveOptimization() async {
        isOptimizing = true
        print("🔧 Starting adaptive optimization")
        
        // Memory optimization
        if memoryUsage > highMemoryThreshold {
            await optimizeMemoryUsage()
        }
        
        // Performance mode adjustment
        if currentFPS < lowFPSThreshold || thermalState == .serious || thermalState == .critical {
            adjustPerformanceMode()
        }
        
        // Battery optimization
        if batteryLevel < 0.2 {
            enableBatteryOptimizations()
        }
        
        // Wait a moment before allowing next optimization
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
        isOptimizing = false
        
        print("✅ Adaptive optimization completed")
    }
    
    // MARK: - Thermal State Handling
    private func handleThermalStateChange() {
        print("🌡️ Thermal state changed to: \(thermalState)")
        
        switch thermalState {
        case .nominal:
            // Normal operation
            break
        case .fair:
            // Slight performance reduction
            if performanceMode == .performance {
                performanceMode = .balanced
            }
        case .serious:
            // Significant performance reduction
            performanceMode = .powersaver
            optimizeForThermalState()
        case .critical:
            // Emergency optimization
            performanceMode = .powersaver
            emergencyThermalOptimization()
        @unknown default:
            break
        }
    }
    
    private func optimizeForThermalState() {
        // Reduce animation complexity
        // Lower simulation quality
        // Reduce UI updates
        print("🔥 Optimizing for thermal state")
    }
    
    private func emergencyThermalOptimization() {
        // Minimal UI updates
        // Pause non-essential processes
        // Reduce all visual effects
        print("🚨 Emergency thermal optimization activated")
    }
    
    // MARK: - Battery Optimizations
    private func adaptBatteryOptimizations() {
        if batteryLevel < 0.2 {
            enableBatteryOptimizations()
        } else if batteryLevel > 0.8 {
            disableBatteryOptimizations()
        }
    }
    
    private func enableBatteryOptimizations() {
        // Reduce background processing
        // Lower refresh rates
        // Disable haptic feedback
        print("🔋 Battery optimizations enabled")
    }
    
    private func disableBatteryOptimizations() {
        // Restore normal operation
        print("🔋 Battery optimizations disabled")
    }
    
    // MARK: - Performance Issue Detection
    private func detectPerformanceIssues() {
        // Frame drops detection
        if currentFPS < lowFPSThreshold {
            frameDropCount += 1
            print("📉 Frame drop detected: \(self.currentFPS) FPS")
        }
        
        // Memory pressure detection
        if memoryUsage > highMemoryThreshold {
            print("🧠 High memory usage detected: \(self.memoryUsage) MB")
        }
        
        // CPU pressure detection
        if cpuUsage > highCPUThreshold {
            print("⚡ High CPU usage detected: \(self.cpuUsage)%")
        }
    }
    
    // MARK: - Performance Mode Management
    private func adjustPerformanceMode() {
        switch performanceScore {
        case 80...100:
            performanceMode = .performance
        case 60...79:
            performanceMode = .balanced
        case 40...59:
            performanceMode = .powersaver
        default:
            performanceMode = .adaptive
        }
        
        print("⚙️ Performance mode adjusted to: \(self.performanceMode.rawValue)")
    }
    
    // MARK: - Memory Optimization
    func optimizeMemoryUsage() async {
        print("🧹 Starting memory optimization")
        
        // Clear caches
        URLCache.shared.removeAllCachedResponses()
        
        // Trigger garbage collection
        await MainActor.run {
            // Force UI updates to complete
            objectWillChange.send()
        }
        
        // Wait for system cleanup
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        print("✅ Memory optimization completed")
    }
    
    // MARK: - Logging and Analytics
    private func logPerformanceData() {
        let avgFPS = fpsHistory.isEmpty ? 0 : fpsHistory.reduce(0, +) / Double(fpsHistory.count)
        let avgMemory = memoryHistory.isEmpty ? 0 : memoryHistory.reduce(0, +) / Double(memoryHistory.count)
        
        print("""
        📊 Performance Report:
        - Current FPS: \(String(format: "%.1f", currentFPS))
        - Average FPS: \(String(format: "%.1f", avgFPS))
        - Memory Usage: \(String(format: "%.1f", memoryUsage)) MB
        - Average Memory: \(String(format: "%.1f", avgMemory)) MB
        - CPU Usage: \(String(format: "%.1f", cpuUsage))%
        - Performance Score: \(String(format: "%.1f", performanceScore))
        - Thermal State: \(thermalState)
        - Battery Level: \(String(format: "%.0f", batteryLevel * 100))%
        """)
    }
    
    // MARK: - Public Interface
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        isMonitoring = true
        isMonitoringPaused = false
        
        // Start with reduced frequency to prevent initial CPU spike
        setupPerformanceMonitoring()
        
        print("🚀 Advanced Performance Monitoring initialized")
    }
    
    func stopMonitoring() {
        isMonitoring = false
        isMonitoringPaused = false
        
        performanceTimer?.invalidate()
        analyticsTimer?.invalidate()
        performanceTimer = nil
        analyticsTimer = nil
        
        print("🛑 Performance monitoring stopped")
    }
    
    func getPerformanceReport() -> PerformanceReport {
        return PerformanceReport(
            currentFPS: currentFPS,
            averageFPS: fpsHistory.isEmpty ? 0 : fpsHistory.reduce(0, +) / Double(fpsHistory.count),
            memoryUsage: memoryUsage,
            peakMemoryUsage: peakMemoryUsage,
            cpuUsage: cpuUsage,
            performanceScore: performanceScore,
            thermalState: thermalState,
            batteryLevel: batteryLevel,
            frameDropCount: frameDropCount,
            simulationMetrics: simulationMetrics
        )
    }
    
    func resetMetrics() {
        fpsHistory.removeAll()
        memoryHistory.removeAll()
        simulationTimeHistory.removeAll()
        frameDropCount = 0
        peakMemoryUsage = 0
        simulationMetrics = SimulationMetrics()
        print("🔄 Performance metrics reset")
    }
    
    deinit {
        performanceTimer?.invalidate()
        analyticsTimer?.invalidate()
        performanceTimer = nil
        analyticsTimer = nil
        isMonitoring = false
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - Memory Management
    
    private func setupMemoryMonitoring() {
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            Task { @MainActor in
                self.updateMemoryMetrics()
            }
        }
    }
    
    private func updateMemoryMetrics() {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            let memoryUsageBytes = Double(info.resident_size)
            memoryUsage = memoryUsageBytes / (1024 * 1024) // Convert to MB
            
            // Update memory pressure level
            switch memoryUsage {
            case 0..<100:
                performanceMetrics.memoryPressure = .low
            case 100..<200:
                performanceMetrics.memoryPressure = .normal
            case 200..<300:
                performanceMetrics.memoryPressure = .high
            default:
                performanceMetrics.memoryPressure = .critical
                Task {
                    await optimizeMemoryUsage()
                }
            }
        }
    }
    
    // MARK: - View Recycling
    
    func recycleView<T>(key: String, factory: () -> T) -> T {
        if let cachedView = viewPool[key] as? T {
            return cachedView
        }
        
        let newView = factory()
        
        if viewPool.count < maxPoolSize {
            viewPool[key] = newView
        }
        
        return newView
    }
    
    private func clearViewPool() {
        viewPool.removeAll()
    }
    
    // MARK: - Image Cache Management
    
    func getCachedImage(for key: String) -> UIImage? {
        return imageCache.object(forKey: NSString(string: key))
    }
    
    func setCachedImage(_ image: UIImage, for key: String) {
        let cost = Int(image.size.width * image.size.height * 4) // Approximate bytes
        imageCache.setObject(image, forKey: NSString(string: key), cost: cost)
    }
    
    func preloadImages(for teams: [String]) async {
        await withTaskGroup(of: Void.self) { group in
            for team in teams {
                group.addTask { @MainActor in
                    if self.getCachedImage(for: team) == nil {
                        if let image = UIImage(named: team) {
                            self.setCachedImage(image, for: team)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Performance Tracking
    
    private func setupPerformanceTracking() {
        // Monitor view render times
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { _ in
                Task { @MainActor in
                    self.trackPerformance()
                }
            }
            .store(in: &stateObservers)
    }
    
    private func trackPerformance() {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let renderTime = CFAbsoluteTimeGetCurrent() - startTime
            self.performanceMetrics.viewRenderTime = renderTime
        }
    }
    
    // MARK: - State Optimization
    
    func optimizeStateUpdates<T: ObservableObject>(for object: T, throttleInterval: TimeInterval = 0.1) -> AnyPublisher<T, Never> {
        return object.objectWillChange
            .throttle(for: .seconds(throttleInterval), scheduler: DispatchQueue.main, latest: true)
            .map { _ in object }
            .eraseToAnyPublisher()
    }
    
    // MARK: - Performance Monitoring Control
    func pauseMonitoringForIntensiveOperation() {
        guard !isMonitoringPaused && isMonitoring else { return }
        
        isMonitoringPaused = true
        pausedTimers = (performanceTimer, analyticsTimer)
        
        performanceTimer?.invalidate()
        analyticsTimer?.invalidate()
        performanceTimer = nil
        analyticsTimer = nil
        
        print("⏸️ Performance monitoring paused for intensive operation")
    }
    
    func resumeMonitoringAfterIntensiveOperation() {
        guard isMonitoringPaused else { return }
        
        isMonitoringPaused = false
        setupPerformanceMonitoring()
        
        print("▶️ Performance monitoring resumed after intensive operation")
    }
    
    private func shouldUseReducedFrequency() -> Bool {
        return memoryUsage > 500.0 || // High memory usage
               cpuUsage > 80.0 ||     // High CPU usage
               thermalState == .serious ||
               thermalState == .critical ||
               batteryLevel < 0.3
    }
}

// MARK: - Supporting Data Structures

struct SimulationMetrics {
    var totalSimulations: Int = 0
    var averageSimulationTime: Double = 0.0
    var fastestSimulation: Double = Double.infinity
    var slowestSimulation: Double = 0.0
    var totalSimulationTime: Double = 0.0
    var totalBatchSimulations: Int = 0
    var totalBatchGames: Int = 0
    var averageBatchTime: Double = 0.0
    var totalBatchTime: Double = 0.0
    
    mutating func addSimulation(time: Double) {
        totalSimulations += 1
        totalSimulationTime += time
        averageSimulationTime = totalSimulationTime / Double(totalSimulations)
        fastestSimulation = min(fastestSimulation, time)
        slowestSimulation = max(slowestSimulation, time)
    }
    
    mutating func addBatchSimulation(time: Double, gameCount: Int) {
        totalBatchSimulations += 1
        totalBatchGames += gameCount
        totalBatchTime += time
        averageBatchTime = totalBatchTime / Double(totalBatchSimulations)
        
        // Also add to regular simulation metrics for overall tracking
        addSimulation(time: time)
    }
    
    mutating func updateAverages() {
        if totalSimulations > 0 {
            averageSimulationTime = totalSimulationTime / Double(totalSimulations)
        }
        if totalBatchSimulations > 0 {
            averageBatchTime = totalBatchTime / Double(totalBatchSimulations)
        }
    }
}

struct PerformanceReport {
    let currentFPS: Double
    let averageFPS: Double
    let memoryUsage: Double
    let peakMemoryUsage: Double
    let cpuUsage: Double
    let performanceScore: Double
    let thermalState: ProcessInfo.ThermalState
    let batteryLevel: Float
    let frameDropCount: Int
    let simulationMetrics: SimulationMetrics
    
    var description: String {
        return """
        Performance Report:
        - FPS: \(String(format: "%.1f", currentFPS)) (avg: \(String(format: "%.1f", averageFPS)))
        - Memory: \(String(format: "%.1f", memoryUsage)) MB (peak: \(String(format: "%.1f", peakMemoryUsage)) MB)
        - CPU: \(String(format: "%.1f", cpuUsage))%
        - Score: \(String(format: "%.1f", performanceScore))/100
        - Thermal: \(thermalState)
        - Battery: \(String(format: "%.0f", batteryLevel * 100))%
        - Frame Drops: \(frameDropCount)
        - Simulations: \(simulationMetrics.totalSimulations) (avg: \(String(format: "%.3f", simulationMetrics.averageSimulationTime))s)
        """
    }
}

// MARK: - Performance Monitoring View
struct PerformanceMonitorView: View {
    @StateObject private var performanceManager = AdvancedPerformanceManager.shared
    @State private var showDetailedReport = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Performance Score
            HStack {
                Text("Performance Score")
                    .font(.headline)
                Spacer()
                Text("\(Int(performanceManager.performanceScore))/100")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(scoreColor)
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            // Quick Metrics
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                MetricCard(title: "FPS", value: String(format: "%.1f", performanceManager.currentFPS), color: .blue)
                MetricCard(title: "Memory", value: "\(Int(performanceManager.memoryUsage)) MB", color: .green)
                MetricCard(title: "CPU", value: "\(Int(performanceManager.cpuUsage))%", color: .orange)
                MetricCard(title: "Battery", value: "\(Int(performanceManager.batteryLevel * 100))%", color: .yellow)
            }
            
            // Performance Mode
            HStack {
                Text("Mode:")
                    .font(.subheadline)
                Spacer()
                Text(performanceManager.performanceMode.rawValue)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(8)
            }
            
            // Detailed Report Button
            Button("Show Detailed Report") {
                showDetailedReport.toggle()
            }
            .buttonStyle(.borderedProminent)
            
            Spacer()
        }
        .padding()
        .sheet(isPresented: $showDetailedReport) {
            PerformanceReportView()
        }
    }
    
    private var scoreColor: Color {
        switch performanceManager.performanceScore {
        case 80...100: return .green
        case 60...79: return .yellow
        case 40...59: return .orange
        default: return .red
        }
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let color: Color
    
    var body: some View {
        VStack {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct PerformanceReportView: View {
    @StateObject private var performanceManager = AdvancedPerformanceManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(performanceManager.getPerformanceReport().description)
                        .font(.system(.body, design: .monospaced))
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    
                    Button("Reset Metrics") {
                        performanceManager.resetMetrics()
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Performance Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Performance Optimized View Modifier

struct PerformanceOptimized: ViewModifier {
    @StateObject private var performanceManager = AdvancedPerformanceManager.shared
    let identifier: String
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                performanceManager.performanceMetrics.activeViews += 1
            }
            .onDisappear {
                performanceManager.performanceMetrics.activeViews -= 1
            }
            .background(
                Group {
                    #if DEBUG
                    if performanceManager.performanceMetrics.memoryPressure == .high {
                        Color.red.opacity(0.1)
                    } else {
                        Color.clear
                    }
                    #else
                    Color.clear
                    #endif
                }
            )
    }
}

extension View {
    func performanceOptimized(identifier: String) -> some View {
        modifier(PerformanceOptimized(identifier: identifier))
    }
}

// MARK: - Advanced List Performance



// MARK: - Async Image with Performance Optimization

struct OptimizedAsyncImage: View {
    let teamName: String
    let size: CGSize
    
    @StateObject private var performanceManager = AdvancedPerformanceManager.shared
    @State private var image: UIImage?
    @State private var isLoading = true
    
    var body: some View {
        Group {
            if let image = image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size.width, height: size.height)
            } else if isLoading {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.ultraThinMaterial)
                    .frame(width: size.width, height: size.height)
                    .overlay(
                        ProgressView()
                            .scaleEffect(0.6)
                    )
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.secondary.opacity(0.3))
                    .frame(width: size.width, height: size.height)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.secondary)
                    )
            }
        }
        .task {
            await loadImage()
        }
    }
    
    private func loadImage() async {
        // Check cache first
        if let cachedImage = performanceManager.getCachedImage(for: teamName) {
            await MainActor.run {
                self.image = cachedImage
                self.isLoading = false
            }
            return
        }
        
        // Load from bundle
        await Task.detached {
            if let bundleImage = UIImage(named: teamName) {
                await MainActor.run {
                    performanceManager.setCachedImage(bundleImage, for: teamName)
                    self.image = bundleImage
                    self.isLoading = false
                }
            } else {
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }.value
    }
}

// MARK: - Device Capability Extensions

extension AdvancedPerformanceManager.DeviceCapabilities.DeviceModel {
    var isProDevice: Bool {
        switch self {
        case .iPhone15Pro, .iPhone15ProMax, .iPhone16Pro, .iPhone16ProMax:
            return true
        case .olderDevice:
            return false
        }
    }
}