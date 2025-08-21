import SwiftUI
import UIKit
import QuartzCore
import Combine

// MARK: - ProMotion Display Manager
@MainActor
class ProMotionDisplayManager: ObservableObject {
    static let shared = ProMotionDisplayManager()
    
    // MARK: - Display Properties
    @Published var supportsProMotion: Bool = false
    @Published var currentRefreshRate: Double = 60.0
    @Published var targetRefreshRate: Double = 120.0
    @Published var isHighRefreshRateEnabled: Bool = true
    @Published var adaptiveRefreshRate: Bool = true
    
    // MARK: - Performance Monitoring
    @Published var actualFPS: Double = 60.0
    @Published var frameDrops: Int = 0
    @Published var displayLinkActive: Bool = false
    
    // MARK: - Display Link
    private var displayLink: CADisplayLink?
    private var frameCount: Int = 0
    private var lastTimestamp: CFTimeInterval = 0
    private var fpsUpdateTimer: Timer?
    
    // MARK: - Performance Thresholds
    private let batteryThreshold: Float = 0.2 // 20% battery
    private let thermalThreshold: ProcessInfo.ThermalState = .serious
    private let cpuThreshold: Double = 85.0 // 85% CPU usage
    
    private init() {
        detectProMotionSupport()
        setupDisplayLink()
        startPerformanceMonitoring()
    }
    
    // MARK: - ProMotion Detection
    private func detectProMotionSupport() {
        // Use modern screen detection that completely avoids deprecated UIScreen.main
        let supportsHighRefreshRate: Bool
        
        if #available(iOS 26.0, *) {
            // For iOS 26+, use window scene approach
            if let windowScene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive }) {
                supportsHighRefreshRate = windowScene.screen.maximumFramesPerSecond >= 120
            } else {
                // If no active window scene, assume modern device capabilities
                // Most devices from iPhone 13 Pro onwards support ProMotion
                supportsHighRefreshRate = true
            }
        } else {
            // For iOS < 26, use the non-deprecated approach
            if let windowScene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first {
                supportsHighRefreshRate = windowScene.screen.maximumFramesPerSecond >= 120
            } else {
                // Fallback: assume ProMotion support on modern iOS versions
                supportsHighRefreshRate = true
            }
        }
        
        // Check for ProMotion support (120Hz capability)
        supportsProMotion = supportsHighRefreshRate
        
        // Get refresh rate from window scene if available
        let maxFramesPerSecond: Int
        if let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first {
            maxFramesPerSecond = windowScene.screen.maximumFramesPerSecond
        } else {
            maxFramesPerSecond = supportsProMotion ? 120 : 60
        }
        
        currentRefreshRate = Double(maxFramesPerSecond)
        
        print("🖥️ Display Info:")
        print("   Max FPS: \(maxFramesPerSecond)")
        print("   ProMotion Support: \(supportsProMotion)")
        print("   Current Refresh Rate: \(currentRefreshRate)Hz")
        
        // Set target based on capabilities
        if supportsProMotion {
            targetRefreshRate = 120.0
            print("   🚀 Target: 120Hz (ProMotion)")
        } else {
            targetRefreshRate = 60.0
            print("   📱 Target: 60Hz (Standard)")
        }
    }
    
    // MARK: - Display Link Configuration
    private func setupDisplayLink() {
        displayLink = CADisplayLink(target: self, selector: #selector(displayLinkFired(_:)))
        
        if supportsProMotion && isHighRefreshRateEnabled {
            // Enable maximum refresh rate for ProMotion devices
            if #available(iOS 15.0, *) {
                displayLink?.preferredFrameRateRange = CAFrameRateRange(
                    minimum: 80,
                    maximum: 120,
                    preferred: 120
                )
            } else {
                displayLink?.preferredFramesPerSecond = 120
            }
            print("🔥 Display Link configured for 120Hz")
        } else {
            displayLink?.preferredFramesPerSecond = 60
            print("📺 Display Link configured for 60Hz")
        }
        
        displayLink?.add(to: .main, forMode: .common)
        displayLinkActive = true
    }
    
    @objc private func displayLinkFired(_ displayLink: CADisplayLink) {
        frameCount += 1
        
        // Calculate FPS every second
        let currentTime = displayLink.timestamp
        if lastTimestamp == 0 {
            lastTimestamp = currentTime
        }
        
        let deltaTime = currentTime - lastTimestamp
        if deltaTime >= 1.0 {
            actualFPS = Double(frameCount) / deltaTime
            frameCount = 0
            lastTimestamp = currentTime
            
            // Update published properties on main queue
            Task { @MainActor in
                self.objectWillChange.send()
            }
        }
    }
    
    // MARK: - Performance Monitoring
    private func startPerformanceMonitoring() {
        fpsUpdateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updatePerformanceMetrics()
            }
        }
    }
    
    private func updatePerformanceMetrics() {
        // Check if we should adapt refresh rate based on system conditions
        if adaptiveRefreshRate {
            adaptRefreshRateBasedOnConditions()
        }
        
        // Monitor frame drops
        if actualFPS < targetRefreshRate * 0.9 {
            frameDrops += 1
        }
    }
    
    private func adaptRefreshRateBasedOnConditions() {
        let batteryLevel = UIDevice.current.batteryLevel
        let thermalState = ProcessInfo.processInfo.thermalState
        
        var shouldUseHighRefreshRate = isHighRefreshRateEnabled && supportsProMotion
        
        // Reduce refresh rate on low battery
        if batteryLevel > 0 && batteryLevel < batteryThreshold {
            shouldUseHighRefreshRate = false
            print("🔋 Low battery: Reducing to 60Hz")
        }
        
        // Reduce refresh rate on thermal throttling
        if thermalState.rawValue >= thermalThreshold.rawValue {
            shouldUseHighRefreshRate = false
            print("🌡️ Thermal throttling: Reducing to 60Hz")
        }
        
        updateDisplayLinkRefreshRate(highRefreshRate: shouldUseHighRefreshRate)
    }
    
    private func updateDisplayLinkRefreshRate(highRefreshRate: Bool) {
        guard let displayLink = displayLink else { return }
        
        if highRefreshRate && supportsProMotion {
            if #available(iOS 15.0, *) {
                displayLink.preferredFrameRateRange = CAFrameRateRange(
                    minimum: 80,
                    maximum: 120,
                    preferred: 120
                )
            } else {
                displayLink.preferredFramesPerSecond = 120
            }
            targetRefreshRate = 120.0
        } else {
            displayLink.preferredFramesPerSecond = 60
            targetRefreshRate = 60.0
        }
    }
    
    // MARK: - Public Methods
    func enableHighRefreshRate(_ enabled: Bool) {
        isHighRefreshRateEnabled = enabled
        updateDisplayLinkRefreshRate(highRefreshRate: enabled && supportsProMotion)
        print("🎮 High refresh rate \(enabled ? "enabled" : "disabled")")
    }
    
    func setAdaptiveRefreshRate(_ enabled: Bool) {
        adaptiveRefreshRate = enabled
        print("⚡ Adaptive refresh rate \(enabled ? "enabled" : "disabled")")
    }
    
    func forceRefreshRate(_ fps: Double) {
        guard let displayLink = displayLink else { return }
        
        let targetFPS = min(fps, supportsProMotion ? 120.0 : 60.0)
        displayLink.preferredFramesPerSecond = Int(targetFPS)
        targetRefreshRate = targetFPS
        print("🎯 Forced refresh rate to \(targetFPS)Hz")
    }
    
    // MARK: - Cleanup
    deinit {
        displayLink?.invalidate()
        fpsUpdateTimer?.invalidate()
    }
}

// MARK: - SwiftUI View Modifiers
struct HighRefreshRateModifier: ViewModifier {
    @StateObject private var proMotionManager = ProMotionDisplayManager.shared
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                proMotionManager.enableHighRefreshRate(true)
            }
            .onDisappear {
                // Keep high refresh rate for smooth transitions
            }
    }
}

struct AdaptiveRefreshRateModifier: ViewModifier {
    @StateObject private var proMotionManager = ProMotionDisplayManager.shared
    let enableHighRefreshRate: Bool
    
    func body(content: Content) -> some View {
        content
            .onAppear {
                proMotionManager.enableHighRefreshRate(enableHighRefreshRate)
            }
    }
}

// MARK: - SwiftUI Extensions
extension View {
    /// Enables maximum refresh rate (120Hz on ProMotion devices)
    func highRefreshRate() -> some View {
        modifier(HighRefreshRateModifier())
    }
    
    /// Enables adaptive refresh rate based on content and system conditions
    func adaptiveRefreshRate(enabled: Bool = true) -> some View {
        modifier(AdaptiveRefreshRateModifier(enableHighRefreshRate: enabled))
    }
}
