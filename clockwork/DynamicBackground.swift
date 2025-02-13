import SwiftUI

struct Blob: Identifiable {
    let id = UUID()
    var position: CGPoint
    var size: CGFloat
    var color: Color
    var velocity: CGPoint
    
    mutating func move(in bounds: CGRect) {
        position.x += velocity.x
        position.y += velocity.y
        
        if position.x - size < bounds.minX || position.x + size > bounds.maxX {
            velocity.x *= -1
        }
        if position.y - size < bounds.minY || position.y + size > bounds.maxY {
            velocity.y *= -1
        }
    }
}

class BlobState: ObservableObject {
    @Published var blobs: [Blob] = []
    private var timer: Timer?
    
    init() {
        generateBlobs()
        startAnimation()
    }
    
    func generateBlobs() {
        let screenWidth = NSScreen.main?.frame.width ?? 800
        let screenHeight = NSScreen.main?.frame.height ?? 600
        
        blobs = (0..<12).map { _ in
            Blob(
                position: CGPoint(
                    x: CGFloat.random(in: 0...screenWidth),
                    y: CGFloat.random(in: 0...screenHeight)
                ),
                size: CGFloat.random(in: 200...400),
                color: Color(
                    hue: Double.random(in: 0...1),
                    saturation: 0.8,
                    brightness: 0.55
                ),
                velocity: CGPoint(
                    x: CGFloat.random(in: -1.5...1.5),
                    y: CGFloat.random(in: -1.5...1.5)
                )
            )
        }
    }
    
    private func startAnimation() {
        timer = Timer.scheduledTimer(withTimeInterval: 1/60, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            let bounds = CGRect(x: 0, y: 0, width: NSScreen.main?.frame.width ?? 800, height: NSScreen.main?.frame.height ?? 600)
            for i in self.blobs.indices {
                self.blobs[i].move(in: bounds)
            }
        }
    }
    
    deinit {
        timer?.invalidate()
    }
}

struct DynamicBackground: View {
    @StateObject private var state = BlobState()
    
    var body: some View {
        ZStack {
            Color.black
            
            ForEach(state.blobs) { blob in
                Circle()
                    .fill(blob.color)
                    .frame(width: blob.size, height: blob.size)
                    .position(blob.position)
                    .blur(radius: blob.size * 0.5)
            }
        }
        .ignoresSafeArea()
    }
    
    func refresh() {
        state.generateBlobs()
    }
} 