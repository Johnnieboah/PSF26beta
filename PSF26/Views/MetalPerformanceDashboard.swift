import SwiftUI
import Metal
import Combine

// MARK: - Metal Performance Dashboard
struct MetalPerformanceDashboard: View {
    @StateObject private var metalManager = MetalOptimizationManager.shared
    @StateObject private var performanceManager = AdvancedPerformanceManager.shared
    @State private var showingDetailedMetrics = false
    @State private var refreshTimer: Timer?
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    headerSection
                    
                    // Metal Status Card
                    metalStatusCard
                    
                    // Performance Metrics
                    performanceMetricsSection
                    
                    // Optimization Level Control
                    optimizationLevelSection
                    
                    // Real-time Monitoring
                    if metalManager.isMetalAvailable {
                        realTimeMonitoringSection
                    }
                    
                    // Device Capabilities
                    deviceCapabilitiesSection
                    
                    // Performance Tips
                    performanceTipsSection
                    
                    Spacer(minLength: 50)
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
            }
            .metalOptimized()
            .metalGradientBackground(
                colors: [
                    Color(.systemBackground),
                    Color(.systemGray6).opacity(0.5),
                    Color(.systemBlue).opacity(0.1)
                ],
                animated: metalManager.optimizationLevel == .maximum
            )
            .navigationTitle("Metal Performance")
            .navigationBarTitleDisplayMode(NavigationBarItem.TitleDisplayMode.large)
            .onAppear {
                startPerformanceMonitoring()
            }
            .onDisappear {
                stopPerformanceMonitoring()
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "gpu")
                    .font(.title)
                    .foregroundColor(.blue)
                    .metalSmoothRotation(angle: .degrees(360), isActive: metalManager.optimizationLevel == .maximum)
                
                VStack(alignment: .leading) {
                    Text("Metal Performance")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("iOS 26 GPU Acceleration")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // Overall Performance Score
            HStack {
                Text("Overall Score")
                    .font(.headline)
                
                Spacer()
                
                Text("\(Int(performanceManager.performanceScore))/100")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(performanceScoreColor)
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(12)
        }
        .standardCard(.ultraThin16)
    }
    
    // MARK: - Metal Status Card
    private var metalStatusCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Image(systemName: metalManager.isMetalAvailable ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .foregroundColor(metalManager.isMetalAvailable ? .green : .red)
                    .font(.title2)
                
                Text(metalManager.isMetalAvailable ? "Metal Available" : "Metal Unavailable")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text(metalManager.optimizationLevel.description)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(optimizationLevelColor.opacity(0.2))
                    .foregroundColor(optimizationLevelColor)
                    .cornerRadius(8)
            }
            
            if metalManager.isMetalAvailable {
                VStack(alignment: .leading, spacing: 8) {
                    MetricRow(
                        title: "Active Views",
                        value: "\(metalManager.activeMetalViews)",
                        icon: "rectangle.3.group"
                    )
                    
                    MetricRow(
                        title: "Render Time",
                        value: "\(String(format: "%.2f", metalManager.metalRenderTime))ms",
                        icon: "timer"
                    )
                    
                    MetricRow(
                        title: "Memory Usage",
                        value: "\(String(format: "%.1f", metalManager.metalMemoryUsage))MB",
                        icon: "memorychip"
                    )
                }
            } else {
                Text("Metal GPU acceleration is not available on this device. The app will use standard rendering.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }
    
    // MARK: - Performance Metrics Section
    private var performanceMetricsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Performance Metrics")
                .font(.headline)
                .fontWeight(.semibold)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 12) {
                PerformanceMetricCard(
                    title: "FPS",
                    value: String(format: "%.1f", performanceManager.currentFPS),
                    target: "60.0",
                    color: .blue,
                    icon: "speedometer"
                )
                
                PerformanceMetricCard(
                    title: "Memory",
                    value: "\(Int(performanceManager.memoryUsage))",
                    target: "<200",
                    color: .green,
                    icon: "memorychip"
                )
                
                PerformanceMetricCard(
                    title: "CPU",
                    value: "\(Int(performanceManager.cpuUsage))",
                    target: "<60",
                    color: .orange,
                    icon: "cpu"
                )
                
                PerformanceMetricCard(
                    title: "Battery",
                    value: "\(Int(performanceManager.batteryLevel * 100))",
                    target: ">20",
                    color: .yellow,
                    icon: "battery.100"
                )
            }
        }
        .standardCard(.ultraThin16)
    }
    
    // MARK: - Optimization Level Section
    private var optimizationLevelSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Optimization Level")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                OptimizationLevelRow(
                    level: .disabled,
                    title: "Disabled",
                    description: "No Metal optimizations",
                    isActive: metalManager.optimizationLevel == .disabled
                )
                
                OptimizationLevelRow(
                    level: .basic,
                    title: "Basic",
                    description: "Standard Metal rendering",
                    isActive: metalManager.optimizationLevel == .basic
                )
                
                OptimizationLevelRow(
                    level: .enhanced,
                    title: "Enhanced",
                    description: "Advanced Metal features",
                    isActive: metalManager.optimizationLevel == .enhanced
                )
                
                OptimizationLevelRow(
                    level: .maximum,
                    title: "Maximum",
                    description: "Full Metal 4 capabilities",
                    isActive: metalManager.optimizationLevel == .maximum
                )
            }
        }
        .standardCard(.ultraThin16)
    }
    
    // MARK: - Real-time Monitoring Section
    private var realTimeMonitoringSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Real-time Monitoring")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Details") {
                    showingDetailedMetrics.toggle()
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }
            
            // Live performance graph placeholder
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
                .frame(height: 120)
                .overlay(
                    VStack {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.title2)
                            .foregroundColor(.secondary)
                        
                        Text("Live Performance Graph")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("Coming in future update")
                            .font(.caption)
                            .foregroundColor(Color.secondary.opacity(0.7))
                    }
                )
        }
        .standardCard(.ultraThin16)
        .sheet(isPresented: $showingDetailedMetrics) {
            DetailedMetricsView()
        }
    }
    
    // MARK: - Device Capabilities Section
    private var deviceCapabilitiesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Device Capabilities")
                .font(.headline)
                .fontWeight(.semibold)
            
            let capabilities = performanceManager.deviceCapabilities
            
            VStack(spacing: 8) {
                CapabilityRow(
                    title: "Metal 4 Support",
                    isSupported: capabilities.supportsMetal4,
                    description: "Advanced GPU features"
                )
                
                CapabilityRow(
                    title: "Apple Intelligence",
                    isSupported: capabilities.supportsAppleIntelligence,
                    description: "On-device AI processing"
                )
                
                CapabilityRow(
                    title: "Foundation Models",
                    isSupported: capabilities.supportsFoundationModels,
                    description: "Large language models"
                )
                
                CapabilityRow(
                    title: "Visual Intelligence",
                    isSupported: capabilities.supportsVisualIntelligence,
                    description: "Computer vision features"
                )
            }
        }
        .standardCard(.ultraThin16)
    }
    
    // MARK: - Performance Tips Section
    private var performanceTipsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Performance Tips")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 12) {
                PerformanceTip(
                    icon: "thermometer",
                    title: "Keep Device Cool",
                    description: "High temperatures reduce Metal performance"
                )
                
                PerformanceTip(
                    icon: "battery.100",
                    title: "Maintain Battery Level",
                    description: "Low battery triggers power saving mode"
                )
                
                PerformanceTip(
                    icon: "memorychip",
                    title: "Close Background Apps",
                    description: "Free up memory for better performance"
                )
                
                PerformanceTip(
                    icon: "arrow.clockwise",
                    title: "Restart Occasionally",
                    description: "Clears caches and optimizes performance"
                )
            }
        }
        .standardCard(.ultraThin16)
    }
    
    // MARK: - Helper Properties
    private var performanceScoreColor: Color {
        let score = performanceManager.performanceScore
        switch score {
        case 80...100: return .green
        case 60..<80: return .orange
        case 40..<60: return .red
        default: return .red
        }
    }
    
    private var optimizationLevelColor: Color {
        switch metalManager.optimizationLevel {
        case .disabled: return .gray
        case .basic: return .blue
        case .enhanced: return .green
        case .maximum: return .purple
        case .proMotion120fps: return .orange
        }
    }
    
    // MARK: - Performance Monitoring
    private func startPerformanceMonitoring() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            // The UI will automatically update when @StateObject properties change
            // No manual refresh needed
        }
    }
    
    private func stopPerformanceMonitoring() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }
}

// MARK: - Supporting Views

struct MetricRow: View {
    let title: String
    let value: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            Text(title)
                .font(.subheadline)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
    }
}

struct PerformanceMetricCard: View {
    let title: String
    let value: String
    let target: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(value)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("Target: \(target)")
                    .font(.caption2)
                    .foregroundColor(Color.secondary.opacity(0.7))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }
}

struct OptimizationLevelRow: View {
    let level: MetalOptimizationManager.OptimizationLevel
    let title: String
    let description: String
    let isActive: Bool
    
    var body: some View {
        HStack {
            Image(systemName: isActive ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isActive ? .green : .secondary)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if isActive {
                Text("Active")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.green.opacity(0.2))
                    .foregroundColor(.green)
                    .cornerRadius(8)
            }
        }
        .padding(.vertical, 4)
    }
}

struct CapabilityRow: View {
    let title: String
    let isSupported: Bool
    let description: String
    
    var body: some View {
        HStack {
            Image(systemName: isSupported ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(isSupported ? .green : .red)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct PerformanceTip: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Detailed Metrics View
struct DetailedMetricsView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var metalManager = MetalOptimizationManager.shared
    @StateObject private var performanceManager = AdvancedPerformanceManager.shared
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Real-time performance data
                    Text("Detailed performance metrics coming soon...")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding()
                    
                    // Placeholder for detailed metrics
                    MetalPerformanceMonitor()
                }
                .padding()
            }
            .navigationTitle("Detailed Metrics")
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