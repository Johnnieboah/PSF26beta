import SwiftUI
import UIKit

// MARK: - iOS 26 Full-Screen Swipe Back Gesture Modifier
struct iOS26SwipeBackGesture: ViewModifier {
    @Environment(\.dismiss) private var dismiss
    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    
    func body(content: Content) -> some View {
        content
            .offset(x: dragOffset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        // Only allow rightward swipes
                        if value.translation.width > 0 {
                            isDragging = true
                            // Apply resistance - make it harder to drag as you go further
                            let resistance = min(value.translation.width / UIScreen.main.bounds.width, 0.4)
                            dragOffset = value.translation.width * resistance
                        }
                    }
                    .onEnded { value in
                        let translation = value.translation.width
                        let velocity = value.velocity.width
                        let screenWidth = UIScreen.main.bounds.width
                        
                        // Determine if we should dismiss based on translation distance or velocity
                        let shouldDismiss = translation > screenWidth * 0.25 || velocity > 800
                        
                        if shouldDismiss && translation > 0 {
                            // Animate to dismiss
                            withAnimation(.easeOut(duration: 0.3)) {
                                dragOffset = screenWidth
                            }
                            
                            // Dismiss after animation
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                dismiss()
                            }
                        } else {
                            // Animate back to original position
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                                dragOffset = 0
                            }
                        }
                        
                        isDragging = false
                    }
            )
            .animation(.interactiveSpring(), value: dragOffset)
    }
}

// MARK: - SwiftUI Extension
extension View {
    /// Enables iOS 26 style full-screen swipe back gesture from anywhere on the screen
    func enableiOS26SwipeBack() -> some View {
        modifier(iOS26SwipeBackGesture())
    }
}
