import SwiftUI
import UIKit
import Foundation
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

    deinit {
        offsetObs?.invalidate()
        displayLink?.invalidate()
    }

    func attach(_ sv: UIScrollView) {
        if scrollView === sv { return }
        scrollView = sv

        // ✅ Swift 6-safe: don't unwrap or touch `self` outside the MainActor task
        offsetObs = sv.observe(\.contentOffset, options: [.initial, .new]) { [weak self] sv, _ in
            Task { @MainActor in
                guard let self else { return }
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

    func updateOffsetY(_ y: CGFloat) {
        offsetY = y
    }

    func stop() {
        active = false
        velocity = 0
        killDisplayLink()
    }

    private func recomputeVelocity() {
        guard viewportHeight > 1 else { velocity = 0; return }

        let start = config.edgeThreshold
        let stop  = config.edgeThreshold + config.hysteresis
        let maxSpeed = config.maxSpeed

        let topDist = dragYInViewport
        let bottomDist = viewportHeight - dragYInViewport

        func ramp(_ dist: CGFloat, threshold: CGFloat) -> CGFloat {
            guard threshold > 0 else { return 0 }
            let t = max(0, min(1, 1 - (dist / threshold)))
            return t * t
        }

        // 1) Enter scrolling aggressively when inside `start`
        if topDist <= start {
            velocity = -maxSpeed * ramp(topDist, threshold: start)
            return
        }
        if bottomDist <= start {
            velocity =  maxSpeed * ramp(bottomDist, threshold: start)
            return
        }

        // 2) Hysteresis: if we were already scrolling, keep it alive until `stop`,
        //    and fade it out smoothly across the [start, stop] band.
        if velocity < 0, topDist <= stop {
            velocity = -maxSpeed * ramp(topDist, threshold: stop)
            return
        }
        if velocity > 0, bottomDist <= stop {
            velocity =  maxSpeed * ramp(bottomDist, threshold: stop)
            return
        }

        // 3) Fully out of both zones -> stop
        velocity = 0
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
