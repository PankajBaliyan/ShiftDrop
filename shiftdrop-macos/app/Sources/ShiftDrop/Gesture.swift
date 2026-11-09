import AppKit
import CoreGraphics

/// Watches the system for "a file drag is in progress and Shift is down".
///
/// Method (no private API): a listen-only CGEventTap sees every mouse and modifier event. On the first
/// left-button drag after a mouse-down, the drag pasteboard (NSPasteboard.Name.drag) is checked: its change
/// count moves when a drag session starts, and it holds file URLs for a Finder drag. That is the same way
/// Dropzone and Yoink notice drags. Shift while that is true shows the probe.
///
/// Needs Input Monitoring permission (listen-only tap). It never changes or blocks events.
final class Gesture {
    var onShow: ((NSPoint) -> Void)?
    var onMouseUp: (() -> Void)?
    var onScroll: ((Int) -> Void)?
    var onSelectRing: ((Int) -> Void)?
    var onCancel: (() -> Void)?
    var isWheelShown: () -> Bool = { false }

    private var tap: CFMachPort?
    private var pbCount = 0
    private(set) var fileDragActive = false
    private var shown = false
    private var scrollAccum = 0.0
    private var lastScrollTime: CFTimeInterval = 0
    private(set) var eventCount = 0
    private(set) var dragCount = 0

    var log: (String) -> Void = { print($0) }

    /// False when the tap could not be created (permission missing).
    func start() -> Bool {
        let types: [CGEventType] = [.leftMouseDown, .leftMouseUp, .leftMouseDragged, .flagsChanged, .scrollWheel, .keyDown]
        let mask = types.reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << $1.rawValue) }
        let callback: CGEventTapCallBack = { _, type, event, refcon in
            guard let refcon else { return Unmanaged.passUnretained(event) }
            Unmanaged<Gesture>.fromOpaque(refcon).takeUnretainedValue().handle(type, event)
            return Unmanaged.passUnretained(event)
        }
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .listenOnly,
                                          eventsOfInterest: mask, callback: callback, userInfo: Unmanaged.passUnretained(self).toOpaque()) else {
            return false
        }
        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func markHidden() { shown = false }

    private func hasFiles(_ pb: NSPasteboard) -> Bool {
        pb.canReadObject(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true])
    }

    fileprivate func handle(_ type: CGEventType, _ event: CGEvent) {
        eventCount += 1
        if type == .leftMouseDragged { dragCount += 1 }
        switch type {
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
        case .leftMouseDown:
            pbCount = NSPasteboard(name: .drag).changeCount
            fileDragActive = false
        case .leftMouseDragged:
            if !fileDragActive {
                let pb = NSPasteboard(name: .drag)
                if pb.changeCount != pbCount && hasFiles(pb) {
                    fileDragActive = true
                    log("file drag detected")
                }
            }
            considerShowing(shift: event.flags.contains(.maskShift))
        case .flagsChanged:
            considerShowing(shift: event.flags.contains(.maskShift))
        case .leftMouseUp:
            fileDragActive = false
            if shown { onMouseUp?() }
        case .scrollWheel:
            guard isWheelShown() else { break }
            let continuous = event.getIntegerValueField(.scrollWheelEventIsContinuous) != 0
            let momentum = event.getIntegerValueField(.scrollWheelEventMomentumPhase)
            // Ignore momentum (coasting after fingers lifted) so one swipe changes exactly one slide
            if continuous && momentum != 0 { break }

            let phase = event.getIntegerValueField(.scrollWheelEventScrollPhase)
            if phase == 4 || phase == 8 { // Ended or Cancelled
                scrollAccum = 0
                break
            }

            let dy = continuous ? event.getDoubleValueField(.scrollWheelEventPointDeltaAxis1) : event.getDoubleValueField(.scrollWheelEventDeltaAxis1)
            let dx = continuous ? event.getDoubleValueField(.scrollWheelEventPointDeltaAxis2) : event.getDoubleValueField(.scrollWheelEventDeltaAxis2)

            // Support horizontal trackpad swipe (dx) as well as vertical scroll (dy)
            let delta = abs(dx) > abs(dy) ? dx : dy
            guard abs(delta) > 0.001 else { break }

            scrollAccum += delta
            let threshold = continuous ? 25.0 : 1.0
            let now = CACurrentMediaTime()
            log("scroll delta=\(delta) continuous=\(continuous) accum=\(scrollAccum)")
            if abs(scrollAccum) >= threshold && (now - lastScrollTime) > 0.20 {
                onScroll?(scrollAccum > 0 ? -1 : 1)
                scrollAccum = 0
                lastScrollTime = now
            }
        case .keyDown:
            // Allow keyboard navigation while wheel is shown (with or without Shift)
            guard isWheelShown() else { break }
            let code = Int(event.getIntegerValueField(.keyboardEventKeycode))
            // Direct ring selection 1..9 (Carbon keycodes: 18, 19, 20, 21, 23, 22, 26, 28, 25)
            let directKeys: [Int: Int] = [
                18: 0, 19: 1, 20: 2, 21: 3, 23: 4, 22: 5, 26: 6, 28: 7, 25: 8
            ]
            if let ring = directKeys[code] {
                onSelectRing?(ring)
                break
            }
            // Step navigation forward: Tab (48), Right Arrow (124), Down Arrow (125), Right Bracket ']' (30)
            if code == 48 || code == 124 || code == 125 || code == 30 {
                onScroll?(1)
                break
            }
            // Step navigation backward: Left Arrow (123), Up Arrow (126), Left Bracket '[' (33), Grave/Tilde '`' (50)
            if code == 123 || code == 126 || code == 33 || code == 50 {
                onScroll?(-1)
                break
            }
            // Escape (53): cancel / hide the wheel
            if code == 53 {
                onCancel?()
                break
            }
        default: break
        }
    }

    private func considerShowing(shift: Bool) {
        guard fileDragActive, shift, !shown else { return }
        shown = true
        log("shift during file drag: probe shown")
        onShow?(NSEvent.mouseLocation)
    }
}
