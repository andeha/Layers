//
//  Flat.swift
//  Layers
//

import Cocoa

protocol Flat {
    var monitors: [String: Any?] { get set }
    func addMonitors()
    func removeAllMonitors()
}

class FlatController: NSViewController, Flat {
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.wantsLayer = true
    }
    override func viewDidAppear() {
        super.viewDidAppear()
        addMonitors()
    }
    func addMonitorsForLaptop() {
        monitors["cursorEnteringMonitor"] = NSEvent.addLocalMonitorForEvents(matching: NSEventMask.mouseEntered)
            { (event: NSEvent) -> NSEvent? in
                //self.hapticFeedback()
                self.inside = true
                return event
            }
        monitors["cursorExitingMonitor"] = NSEvent.addLocalMonitorForEvents(matching: NSEventMask.mouseExited)
            { (event: NSEvent) -> NSEvent? in
                self.inside = false
                return event
            }
        monitors["trackpadMovementMonitor"] = NSEvent.addLocalMonitorForEvents(matching: NSEventMask.mouseMoved)
            { (event: NSEvent) -> NSEvent? in
                let locationInWindow = event.locationInWindow
                let locationInView = self.view.convert(locationInWindow, from: nil)
                self.anchor = locationInView
                self.trackpadChanged(anchor: locationInView, transient: CGPoint.zero, relative: 0.0)
                return event
        }
        monitors["pressureMonitor"] = NSEvent.addLocalMonitorForEvents(matching: NSEventMask.pressure)
            { (event: NSEvent) -> NSEvent? in
                let locationInWindow = event.locationInWindow
                let locationInView = self.view.convert(locationInWindow, from: nil)
                let pressure = event.pressure
                self.trackpadChanged(anchor: self.anchor, transient: locationInView, relative: pressure)
                return event
        }
        monitors["flagsChanged"] = NSEvent.addLocalMonitorForEvents(matching: NSEventMask.flagsChanged)
        { (event: NSEvent) -> NSEvent? in
            self.flagsChanged(event: event)
            return event
        }
    }
    override func viewDidDisappear() {
        super.viewDidDisappear()
        removeAllMonitors()
    }
    dynamic func addMonitors() { debugPrint("addMonitors") }
    dynamic func trackpadChanged(anchor insideView: CGPoint, transient forView: CGPoint, relative pressure: Float) { debugPrint("trackpadChanged") }
    func touchEnters(insideView: CGPoint) { debugPrint("touchEnters") }
    func touchExits(insideView: CGPoint)  { debugPrint("touchExits")  }
    func touchMoves(insideView: CGPoint)  { debugPrint("touchMoves")  }
    func removeAllMonitors() { let _ = monitors.map { NSEvent.removeMonitor($1!) } }
    // MARK: - Cache
    var optionHold = false
    var commandHold = false
    var anchor = CGPoint.zero
    var inside = true
    let feedbackFilter = NSAlignmentFeedbackFilter()
    var monitors = [String: Any?]()
}

extension FlatController {
    func flagsChanged(event: NSEvent) {
        if BranchSelect(l: event.modifierFlags.contains(.option), r: event.modifierFlags.contains(.command),
 leftWon: { optionHold = true  ; commandHold = false },
rightWon: { optionHold = false ; commandHold = true  },
      or: {  /* refreshTouchbar ( )   */             },
    both: { optionHold = true  ; commandHold = true  }
        ) {
            optionHold = false ; commandHold = false
        }
    }
    func hapticFeedback() {
        var preparedAlignments = [NSAlignmentFeedbackToken]()
        if let token = self.feedbackFilter.alignmentFeedbackTokenForHorizontalMovement(in: self.view,
                previousX: 0.0, alignedX: 1.0, defaultX: 2.0) {
            preparedAlignments += [token]
        }
        self.feedbackFilter.performFeedback(preparedAlignments, performanceTime: .now)
    }
}

extension CALayer {
    func traverse(completion: (CALayer)->Void) {
        completion(self)
        guard let children = self.sublayers else { return }
        for l in children { l.traverse(completion: completion) }
    }
}

class ReplaceSegue: NSStoryboardSegue {
    override func perform() {
        if let src = self.sourceController as? NSViewController,
            let dest = self.destinationController as? NSViewController,
            let window = src.view.window {
            dest.view.frame = src.view.frame
            // This updates the content and adjusts window size
            window.contentViewController = dest
        }
    }
}

extension NSStoryboardSegue {
    func perform(`while`: @escaping ()->Void = {}) {
        DispatchQueue.main.async { `while`() }
        perform()
    }
}
