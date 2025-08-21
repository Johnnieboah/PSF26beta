import SwiftUI
import UIKit

// MARK: - High Performance Scroll Components
// Optimized for 120fps ProMotion displays

// MARK: - Smooth ScrollView
struct SmoothScrollView<Content: View>: UIViewRepresentable {
    let content: Content
    let showsIndicators: Bool
    let bounces: Bool
    
    init(showsIndicators: Bool = true, bounces: Bool = true, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.showsIndicators = showsIndicators
        self.bounces = bounces
    }
    
    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = HighPerformanceScrollView()
        
        // Configure for maximum smoothness
        scrollView.showsVerticalScrollIndicator = showsIndicators
        scrollView.showsHorizontalScrollIndicator = showsIndicators
        scrollView.bounces = bounces
        scrollView.alwaysBounceVertical = bounces
        
        // Enable smooth scrolling optimizations
        if #available(iOS 15.0, *) {
            scrollView.automaticallyAdjustsScrollIndicatorInsets = true
        }
        
        // Configure for 120fps
        scrollView.decelerationRate = .fast // Smoother deceleration
        scrollView.contentInsetAdjustmentBehavior = .automatic
        
        // Add SwiftUI content
        let hostingController = UIHostingController(rootView: content)
        hostingController.view.backgroundColor = .clear
        scrollView.addSubview(hostingController.view)
        
        // Setup constraints
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: scrollView.topAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
            hostingController.view.widthAnchor.constraint(equalTo: scrollView.widthAnchor)
        ])
        
        return scrollView
    }
    
    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        // Update content if needed
    }
}

// MARK: - Custom High Performance ScrollView
class HighPerformanceScrollView: UIScrollView {
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupOptimizations()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupOptimizations()
    }
    
    private func setupOptimizations() {
        // Enable maximum performance
        layer.shouldRasterize = false // Disable rasterization for smooth scrolling
        clipsToBounds = true
        
        // Optimize for ProMotion
        if #available(iOS 15.0, *) {
            // ProMotion optimization disabled - APIs not available in iOS 26.0
            // Future: Implement using iOS 26.0 compatible APIs when available
        }
        
        // Configure content offset animations
        layer.allowsEdgeAntialiasing = true
        layer.drawsAsynchronously = true
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // Optimize layout for high refresh rates
        // Use window scene screen instead of deprecated UIScreen.main
        if let windowScene = window?.windowScene {
            layer.contentsScale = windowScene.screen.scale
        } else {
            // Fallback for when window is not available
            layer.contentsScale = 3.0 // Default to 3x for modern devices
        }
    }
}

// MARK: - High Performance List
struct HighPerformanceList<Data: RandomAccessCollection, Content: View>: View where Data.Element: Identifiable {
    let data: Data
    let content: (Data.Element) -> Content
    let showsIndicators: Bool
    
    init(_ data: Data, showsIndicators: Bool = true, @ViewBuilder content: @escaping (Data.Element) -> Content) {
        self.data = data
        self.content = content
        self.showsIndicators = showsIndicators
    }
    
    var body: some View {
        SmoothScrollView(showsIndicators: showsIndicators) {
            LazyVStack(spacing: 0) {
                ForEach(data, id: \.id) { item in
                    content(item)
                        .optimizedForHighRefreshRate()
                }
            }
        }
        .highRefreshRate()
    }
}

// MARK: - Optimized LazyVGrid for 120fps
struct HighPerformanceLazyVGrid<Data: RandomAccessCollection, Content: View>: View where Data.Element: Identifiable {
    let data: Data
    let columns: [GridItem]
    let spacing: CGFloat?
    let pinnedViews: PinnedScrollableViews
    let content: (Data.Element) -> Content
    
    init(
        _ data: Data,
        columns: [GridItem],
        spacing: CGFloat? = nil,
        pinnedViews: PinnedScrollableViews = [],
        @ViewBuilder content: @escaping (Data.Element) -> Content
    ) {
        self.data = data
        self.columns = columns
        self.spacing = spacing
        self.pinnedViews = pinnedViews
        self.content = content
    }
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: spacing, pinnedViews: pinnedViews) {
                ForEach(data, id: \.id) { item in
                    content(item)
                        .optimizedForHighRefreshRate()
                }
            }
        }
        .highRefreshRate()
        .scrollContentBackground(.hidden) // Reduce rendering overhead
    }
}

// MARK: - View Modifiers for High Refresh Rate Optimization
struct HighRefreshRateOptimizationModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .drawingGroup(opaque: false, colorMode: .nonLinear) // Optimize rendering
            .compositingGroup() // Reduce overdraw
            .clipped() // Optimize clipping
    }
}

struct SmoothAnimationModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.8, blendDuration: 0.1), value: UUID())
    }
}

struct ProMotionOptimizedModifier: ViewModifier {
    @StateObject private var proMotionManager = ProMotionDisplayManager.shared
    
    func body(content: Content) -> some View {
        content
            .preferredColorScheme(nil) // Let system handle color scheme changes smoothly
            .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
                // Ensure smooth orientation changes at 120fps
                proMotionManager.enableHighRefreshRate(true)
            }
    }
}

// MARK: - SwiftUI Extensions
extension View {
    /// Optimizes view for high refresh rate displays (120fps)
    func optimizedForHighRefreshRate() -> some View {
        modifier(HighRefreshRateOptimizationModifier())
    }
    
    /// Adds smooth animations optimized for ProMotion
    func smoothAnimations() -> some View {
        modifier(SmoothAnimationModifier())
    }
    
    /// Applies comprehensive ProMotion optimizations
    func proMotionOptimized() -> some View {
        modifier(ProMotionOptimizedModifier())
    }
}

// MARK: - High Performance Table View (for complex lists)
struct HighPerformanceTableView<Data: RandomAccessCollection, Content: View>: UIViewControllerRepresentable where Data.Element: Identifiable {
    let data: Data
    let content: (Data.Element) -> Content
    let estimatedRowHeight: CGFloat
    
    init(_ data: Data, estimatedRowHeight: CGFloat = 44, @ViewBuilder content: @escaping (Data.Element) -> Content) {
        self.data = data
        self.content = content
        self.estimatedRowHeight = estimatedRowHeight
    }
    
    func makeUIViewController(context: Context) -> HighPerformanceTableViewController<Data, Content> {
        HighPerformanceTableViewController(data: data, content: content, estimatedRowHeight: estimatedRowHeight)
    }
    
    func updateUIViewController(_ uiViewController: HighPerformanceTableViewController<Data, Content>, context: Context) {
        uiViewController.updateData(data)
    }
}

class HighPerformanceTableViewController<Data: RandomAccessCollection, Content: View>: UITableViewController where Data.Element: Identifiable {
    private var data: Data
    private let content: (Data.Element) -> Content
    private let estimatedRowHeight: CGFloat
    private var hostingControllers: [String: UIHostingController<Content>] = [:]
    
    init(data: Data, content: @escaping (Data.Element) -> Content, estimatedRowHeight: CGFloat) {
        self.data = data
        self.content = content
        self.estimatedRowHeight = estimatedRowHeight
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Configure table view for maximum performance
        tableView.estimatedRowHeight = estimatedRowHeight
        tableView.rowHeight = UITableView.automaticDimension
        tableView.separatorStyle = .none
        tableView.showsVerticalScrollIndicator = true
        tableView.backgroundColor = .systemBackground
        
        // Enable smooth scrolling
        tableView.decelerationRate = .fast
        
        // Register cell
        tableView.register(HighPerformanceTableViewCell.self, forCellReuseIdentifier: "Cell")
    }
    
    func updateData(_ newData: Data) {
        data = newData
        tableView.reloadData()
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return data.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as! HighPerformanceTableViewCell
        
        let item = data[data.index(data.startIndex, offsetBy: indexPath.row)]
        let itemView = content(item)
        
        // Reuse hosting controller if possible
        let itemId = String(describing: item.id)
        if let existingController = hostingControllers[itemId] {
            existingController.rootView = itemView
            cell.configure(with: existingController)
        } else {
            let hostingController = UIHostingController(rootView: itemView)
            hostingController.view.backgroundColor = .clear
            hostingControllers[itemId] = hostingController
            cell.configure(with: hostingController)
        }
        
        return cell
    }
}

class HighPerformanceTableViewCell: UITableViewCell {
    private var hostingController: UIHostingController<AnyView>?
    
    func configure<Content: View>(with hostingController: UIHostingController<Content>) {
        // Remove previous hosting controller
        self.hostingController?.view.removeFromSuperview()
        
        // Add new hosting controller
        let anyHostingController = UIHostingController(rootView: AnyView(hostingController.rootView))
        anyHostingController.view.backgroundColor = .clear
        anyHostingController.view.translatesAutoresizingMaskIntoConstraints = false
        
        contentView.addSubview(anyHostingController.view)
        
        NSLayoutConstraint.activate([
            anyHostingController.view.topAnchor.constraint(equalTo: contentView.topAnchor),
            anyHostingController.view.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            anyHostingController.view.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            anyHostingController.view.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
        
        self.hostingController = anyHostingController
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        hostingController?.view.removeFromSuperview()
        hostingController = nil
    }
}
