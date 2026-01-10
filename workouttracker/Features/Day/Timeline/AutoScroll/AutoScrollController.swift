import SwiftUI
import UIKit
import Combine

@MainActor
final class AutoScrollController: ObservableObject {
    @Published private(set) var offsetY: CGFloat = 0

    var config: AutoScrollConfig

    private weak var scrollView: UIScrollView?
    private var offsetObs: NSKeyValueObservation?

    private var displayLink: CADisplayLink?
    private var lastTS: CFTimeInterval = 0

    private var viewportHeight: CGFloat = 0
    private var dragYInViewport: CGFloat = 0
    private var velocity: CGFloat = 0
    private var active: Bool = false

    init(config: AutoScrollConfig = .default) {
        self.config = config
    }

    func attach(_ sv: UIScrollView) {
        if scrollView === sv { return }
        scrollView = sv

        offsetObs = sv.observe(\.contentOffset, options: [.initial, .new]) { [weak self] sv, _ in
            guard let self else { return }
            Task { @MainActor in
                self.offsetY = sv.contentOffset.y
            }
        }
    }

    func updateDrag(yInViewport: CGFloat, viewportHeight: CGFloat) {
        active = true
        dragYInViewport = yInViewport
        self.viewportHeight = viewportHeight
        recomputeVelocity()
        ensureDisplayLink()
    }

    func stop() {
        active = false
        velocity = 0
        killDisplayLink()
    }

    private func recomputeVelocity() {
        guard viewportHeight > 1 else { velocity = 0; return }

        let edgeThreshold = config.edgeThreshold
        let maxSpeed = config.maxSpeed
        let hysteresis = config.hysteresis

        let topDist = dragYInViewport
        let bottomDist = viewportHeight - dragYInViewport

        let start = edgeThreshold
        let stop = edgeThreshold + hysteresis

        func ramp(_ dist: CGFloat) -> CGFloat {
            let t = max(0, min(1, 1 - (dist / start)))
            return t * t
        }

        if topDist <= start {
            velocity = -maxSpeed * ramp(topDist)
        } else if bottomDist <= start {
            velocity =  maxSpeed * ramp(bottomDist)
        } else if abs(velocity) > 0, (topDist >= stop && bottomDist >= stop) {
            velocity = 0
        } else {
            velocity = 0
        }
    }

    private func ensureDisplayLink() {
        guard displayLink == nil else { return }
        lastTS = 0
        let dl = CADisplayLink(target: self, selector: #selector(tick(_:)))
        dl.add(to: .main, forMode: .common)
        displayLink = dl
    }

    private func killDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
        lastTS = 0
    }

    @objc private func tick(_ link: CADisplayLink) {
        guard active, let sv = scrollView, abs(velocity) > 0.01 else {
            if !active || abs(velocity) <= 0.01 { killDisplayLink() }
            return
        }

        if lastTS == 0 { lastTS = link.timestamp; return }
        let dt = link.timestamp - lastTS
        lastTS = link.timestamp

        let maxOffset = max(0, sv.contentSize.height - sv.bounds.height)
        var next = sv.contentOffset.y + velocity * CGFloat(dt)
        next = min(max(0, next), maxOffset)

        if abs(next - sv.contentOffset.y) > 0.5 {
            sv.setContentOffset(CGPoint(x: sv.contentOffset.x, y: next), animated: false)
        }

        recomputeVelocity()

        if next <= 0.1 || next >= maxOffset - 0.1 {
            velocity = 0
            killDisplayLink()
        }
    }
}
