//
//  Touchbar.swift
//  Layers
//

import Cocoa

// MARK: - Touchbar

fileprivate extension NSTouchBarCustomizationIdentifier {
    static let paintBar = NSTouchBarCustomizationIdentifier("com.layers.paintbar")
    @available(OSX 10.12.2, *)
    static let defaultIdentifiers = [
        NSTouchBarItemIdentifier.label,
        NSTouchBarItemIdentifier.otherItemsProxy,
        NSTouchBarItemIdentifier.flexibleSpace,
        NSTouchBarItemIdentifier.appendExlusiveLayer,
        NSTouchBarItemIdentifier.undoAndRedoLatest,
        NSTouchBarItemIdentifier.selectPaintState
    ]
}

class WindowController: NSWindowController {
    @available(OSX 10.12.2, *)
    override func makeTouchBar() -> NSTouchBar? {
        let touchBar = NSTouchBar()
        touchBar.delegate = self
        touchBar.customizationIdentifier = .paintBar
        touchBar.defaultItemIdentifiers = NSTouchBarCustomizationIdentifier.defaultIdentifiers
        touchBar.principalItemIdentifier = NSTouchBarItemIdentifier.selectPaintState
        touchBar.escapeKeyReplacementItemIdentifier = .flexibleSpace // TODO: In another context, consider providing a cyclic escape button.
        return touchBar
    }
    override func awakeFromNib() {
        UserDefaults.standard.set(NSNumber(value: 0), forKey: "PaintState")
        principalController = self.contentViewController as? ViewController
    }
    override var undoManager: UndoManager? { get { return manager } }; private var manager = UndoManager()
    var principalController: ViewController?
    var sprouts = Dictionary<NSTouchBarItemIdentifier, NSView>()
}

extension WindowController: NSTouchBarDelegate {
    @available(OSX 10.12.2, *)
    func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItemIdentifier) -> NSTouchBarItem? {
        switch identifier {
        case NSTouchBarItemIdentifier.label:
            let custom = NSCustomTouchBarItem(identifier: identifier)
            custom.view = NSTextField(labelWithString: "Layers")
            return custom
        case NSTouchBarItemIdentifier.appendExlusiveLayer:
            let custom = NSCustomTouchBarItem(identifier: identifier)
            let button = NSButton(image: NSImage(named: "NSTouchBarAddTemplate")!, target: self, action: #selector(appendExlusiveLayerPicked(_:)))
            button.isBordered = false
            custom.view = button
            custom.customizationLabel = "Add Exclusive Layer"
            return custom
        case NSTouchBarItemIdentifier.undoAndRedoLatest:
            let custom = NSCustomTouchBarItem(identifier: identifier)
            let undo = NSImage(named: "NSTouchBarGoBackTemplate")!
            let redo = NSImage(named: "NSTouchBarGoForwardTemplate")!
            let segmentedControl = NSSegmentedControl(images: [ undo, redo ],
                trackingMode: .momentary, target: self, action: #selector(undoOrRedoLatestPicked(_:)))
            segmentedControl.segmentStyle = .separated
            segmentedControl.setWidth(127/2.0, forSegment: 1)
            custom.view = segmentedControl
            custom.customizationLabel = "Undo and Redo Latest"
            return custom
        case NSTouchBarItemIdentifier.selectTubeLater: // TODO: Move to default
            guard let view = sprouts[identifier] else { return nil }
           // let item = NSPopoverTouchBarItem(identifier: identifier)
         //   item.collapsedRepresentation = view
          //  let branch = NSTouchBar()
           // branch.delegate = self
            let colorPicker = NSColorPickerTouchBarItem.strokeColorPicker(withIdentifier: NSTouchBarItemIdentifier.colorPicker)
         //   colorPicker.target = self
            colorPicker.action = #selector(colorPicked(_:))
            return colorPicker
           // branch.defaultItemIdentifiers = [ NSTouchBarItemIdentifier.colorPicker, NSTouchBarItemIdentifier.otherItemsProxy ]
            //item.popoverTouchBar = branch
            //return item
        case NSTouchBarItemIdentifier.reverseInvokation:
            let custom = NSCustomTouchBarItem(identifier: identifier)
            let button = NSButton(image: NSImage(named: "NSTouchBarDeleteTemplate")!, target: self, action: #selector(reverseInvokationCherryPicked(_:)))
            button.isBordered = false
            custom.view = button
            custom.customizationLabel = "Reverse Invokation"
            return custom
        case NSTouchBarItemIdentifier.selectPaintState:
            let custom = NSCustomTouchBarItem(identifier: identifier)
            let segmentedControl = TemporalSegmentedControl(labels: [ "Drawing", "Palette", "Kerning", "History", "Canvas" ],
                trackingMode: .selectOne, target: self, action: #selector(selectPaintStatePicked(_:)))
            segmentedControl.bind(NSSelectedIndexBinding, to: NSUserDefaultsController.shared(),
                                 withKeyPath: "values.PaintState", options:
                [ NSContinuouslyUpdatesValueBindingOption: NSNumber(value: true) ])
            custom.view = segmentedControl
            custom.customizationLabel = "Select Paint State"
            return custom
        default: return nil
        }
    }
}

// MARK: Conclusions. Touchbar Features.

extension NSTouchBarItemIdentifier {
    // Statics
    static let label = NSTouchBarItemIdentifier("com.layers.brandlabel")
    static let selectPaintState = NSTouchBarItemIdentifier("com.layers.selectPaintState")
    // Canvas
    static let appendExlusiveLayer = NSTouchBarItemIdentifier("com.layers.appendExlusiveLayer")
    static let undoAndRedoLatest = NSTouchBarItemIdentifier("com.layers.undoAndRedoLatest")
    // Viscosity and Colors. I.e the palette.
    static let selectTubeLater = NSTouchBarItemIdentifier("com.layers.selectTubeLater")
    static let colorPicker = NSTouchBarItemIdentifier("com.layers.colorPicker")
    //static let tag = NSTouchBarItemIdentifier("com.layers.tag")
    //static let exposeTimeline = NSTouchBarItemIdentifier("com.layers.exposeTimeline")
    //static let timeline = NSTouchBarItemIdentifier("com.layers.timeline") // TODO: Consider close button.
    // Kerning and Control Points
    static let cycleShowRaster = NSTouchBarItemIdentifier("com.layers.cycleShowRaster")
    // History (May be developed on top of kerning)
    static let reverseInvokation = NSTouchBarItemIdentifier("com.layers.reverseInvokation")
}

extension WindowController {
    /* @undoable */ func appendExlusiveLayerPicked(_ sender: Any?) {
        if let layers = (contentViewController as? Layers) {
            registerForUndo(appendExclusiveLayer: layers)
            layers.appendLayer(exclusive: true)
        }
    }
    func undoOrRedoLatestPicked(_ sender: Any?) {
        if let segmentedControl = sender as? NSSegmentedControl, let undo = undoManager {
            switch segmentedControl.selectedSegment {
            case 0: undo.undo(); case 1: undo.redo()
            default: debugPrint("undoOrRedoLatestPicked: Error")
            }
        }
    }
    func selectTubePicked(_ sender: Any?) {
        if let button = sender as? NSButton {
        }
    }
    /* @undoable */ func colorPicked(_ sender: Any?) {
        if let segmented = sender as? TemporalSegmentedControl {
            let previousColor = NSColor.black // segmented.previous
            let currentColor = NSColor.white // segmented.current
            registerForUndo(action: "Select Clot", selector: #selector(selectClot(color:)), previously: previousColor)
            selectClot(color: currentColor)
        }
    }
    func reverseInvokationCherryPicked(_ sender: Any?) {}
    func rollbackPicked(_ sender: Any?) {}
    func commitCanvasAndSwitchToDrawingPicked(_ sender: Any?) {}
    @available(OSX 10.12.2, *)
    /* @undoable */ func selectPaintStatePicked(_ sender: Any?) {
        if let segmentedControl = sender as? NSSegmentedControl {
            // registerForUndo(selectPaintState: segmentedControl)
            updateController(inAccordanceWith: segmentedControl)
            sampleController()
         }
    }
}

extension WindowController { // MARK: Undoables.
    func remove(layer: CALayer) {}
    // func forcePaintState(selectedSegment: Int) {}
    func reverseKerningAndCommit(layer: CALayer) {}
    func reverseBezierModificationAndCommit(uuid: UUID) {}
    func setCanvas(frame: NSRect) {}
    func restorePalette(t: TimeInterval) {}
    func forceRasterType(value: Raster.Type) {}
    func restoreGalleyProof(t: TimeInterval) {}
    // MARK: Undo
    func registerForUndo(appendExclusiveLayer layers: Layers) {
        if let undo = self.undoManager, let `self` = undo.prepare(withInvocationTarget: self) as? WindowController {
            if undo.isUndoRegistrationEnabled {}
            undo.beginUndoGrouping()
            undo.endUndoGrouping()
            // `self`.principalController.removeLayer(sender)
            undo.setActionName("Append Exclusive Layer")
        }
    }
    /* undoable */ func registerForUndo(action name: String, selector: Selector, previously: Any?) {
        guard let undo = self.undoManager else { return }
        undo.registerUndo(withTarget: self, selector: selector, object: previously)
        undo.setActionName(name)
    }
    func registerForUndo(selectPaintState segmentedControl: NSSegmentedControl) {
        if let undo = undoManager, let `self` = undo.prepare(withInvocationTarget: self) as? WindowController {
            if #available(OSX 10.12.2, *) {
             //   `self`.updateController(inAccordanceWith: segmentedControl)
            } else {
                // Fallback on earlier versions
            }
            undo.setActionName("Paint State Changed")
        }
    }
}

extension WindowController { // MARK: ModelAlterers
    func selectClot(color: NSColor) {
        debugPrint("selectClot")
    }
}

var AssociatedObjectKey: UInt8 = 0
class TemporalSegmentedControl: NSSegmentedControl {
    var previous: NSNumber {
        get {
            return objc_getAssociatedObject(self, &AssociatedObjectKey) as! NSNumber
        }
    }
    var current: NSNumber {
        get {
            return NSNumber(integerLiteral: selectedSegment)
        }
        set {
            let oldValue = NSNumber(integerLiteral: self.selectedSegment)
            objc_setAssociatedObject(self, &AssociatedObjectKey, oldValue, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            selectedSegment = newValue.intValue
        }
    }
}

//extension WindowController { // MARK: Context and back to drawing.
//    func flipToShoebox(_ sender: Any?) {
//        let storyboard = NSStoryboard(name: "Layers", bundle: nil)
//        let dest = storyboard.instantiateController(withIdentifier: "Shoebox") as! NSViewController
//        if let current = contentViewController {
//            let segue = ReplaceSegue(identifier: "SegueToShoebox", source: current, destination: dest)
//            self.prepare(for: segue, sender: sender)
//            segue.perform()
//        }
//    }
//    func userDidIndicateInterest(_ sender: Any?) {
//        // sender contains url or uuid to artwork.
//        //performChangePaintState(sender, selectedSegment: 0)
//        //segueToPrincipal()
//    }
//}

extension WindowController {
    @available(OSX 10.12.2, *)
    func updateController(inAccordanceWith stem: Any?) {
        guard let segmented = stem as? NSSegmentedControl else { return }
        let selectedSegment = segmented.selectedSegment
        switch selectedSegment { // TODO: Consider composition, typesetting post on Fender jazzmaster.
        case 0: // Drawing
            segueToPrincipal(stem: segmented)
        case 1: // Palette
            let storyboard = NSStoryboard(name: "Layers", bundle: nil)
            let dest = storyboard.instantiateController(withIdentifier: "Palette") as! NSViewController
            if let current = contentViewController {
                let segue = ReplaceSegue(identifier: "SegueToPalette", source: current, destination: dest)
                self.prepare(for: segue, sender: segmented)
                guard let image = NSImage(named: "NSTouchBarColorPickerStrokeTemplate") else { return }
                let button = NSButton(image: image, target: self, action: #selector(selectTubePicked(_:)))
                segue.perform() {
                    self.sprout(knot: NSTouchBarItemIdentifier.selectTubeLater, tip: button)
                    { (stem: inout NSTouchBar, knot: NSTouchBarItemIdentifier) -> [NSTouchBarItemIdentifier] in
                        return [ NSTouchBarItemIdentifier.appendExlusiveLayer, NSTouchBarItemIdentifier.undoAndRedoLatest ]
                    }
                }
            }
        case 2: // Kerning (Enabled below)
            segueToPrincipal(stem: segmented) {
                guard let image = NSImage(named: "NSTouchBarColorRefreshTemplate") else { return }
                let button = NSButton(image: image, target: self, action: #selector(self.rollbackPicked(_:)))
                self.sprout(knot: NSTouchBarItemIdentifier.reverseInvokation, tip: button)
                    { (stem: inout NSTouchBar, knot: NSTouchBarItemIdentifier) -> [NSTouchBarItemIdentifier] in
                        return [ NSTouchBarItemIdentifier.appendExlusiveLayer, NSTouchBarItemIdentifier.undoAndRedoLatest ]
                    }
            }
        case 3: // History
            let storyboard = NSStoryboard(name: "Layers", bundle: nil)
            let dest = storyboard.instantiateController(withIdentifier: "History") as! NSViewController
            if let controller = contentViewController {
                let segue = ReplaceSegue(identifier: "SegueToHistory", source: controller, destination: dest)
                self.prepare(for: segue, sender: segmented)
                guard let image = NSImage(named: "NSTouchBarColorPickerStrokeTemplate") else { return }
                let button = NSButton(image: image, target: self, action: #selector(reverseInvokationCherryPicked(_:)))
                segue.perform() {
                    self.sprout(knot: NSTouchBarItemIdentifier.reverseInvokation, tip: button)
                    { (stem: inout NSTouchBar, knot: NSTouchBarItemIdentifier) -> [NSTouchBarItemIdentifier] in
                        return [ NSTouchBarItemIdentifier.appendExlusiveLayer, NSTouchBarItemIdentifier.undoAndRedoLatest ]
                    }
                }
            }
        case 4: // Canvas (Enabled below)
            guard let image = NSImage(named: "NSTouchBarComposeTemplate") else { return }
            let button = NSButton(image: image, target: self, action: #selector(commitCanvasAndSwitchToDrawingPicked(_:)))
            segueToPrincipal(stem: segmented) {
                self.sprout(knot: NSTouchBarItemIdentifier.reverseInvokation, tip: button)
                { (stem: inout NSTouchBar, knot: NSTouchBarItemIdentifier) -> [NSTouchBarItemIdentifier] in
                    return [ NSTouchBarItemIdentifier.appendExlusiveLayer, NSTouchBarItemIdentifier.undoAndRedoLatest ]
                }
            }
        default:
            debugPrint("Unknown paint state")
        }
        if let controller = principalController {
            controller.holistic = selectedSegment == 2
            controller.canvasIsAdjustable = selectedSegment == 4
        }
    }
    private func segueToPrincipal(stem: Any?, `while`: @escaping ()->Void = {}) {
        if let current = contentViewController,
            let principal = principalController {
            let segue = ReplaceSegue(identifier: "SegueToPrincipal", source: current, destination: principal)
            self.prepare(for: segue, sender: stem)
            segue.perform() { `while`() }
        }
    }
    @available(OSX 10.12.2, *)
    private func sprout(knot identifier: NSTouchBarItemIdentifier, tip: NSControl, in prepare: (inout NSTouchBar, NSTouchBarItemIdentifier)->[NSTouchBarItemIdentifier]) {
        sprouts[identifier] = tip
        if var bar = touchBar {
            var branches = Array<NSTouchBarItemIdentifier>()
            branches.append(contentsOf: bar.itemIdentifiers)
            let stemIndex = bar.itemIdentifiers.count - 1
            branches.insert(identifier, at: stemIndex)
            let prunes = prepare(&bar, identifier)
            for collar in prunes {
                if let index = branches.index(of: collar) { branches.remove(at: index) }
            }
            bar.defaultItemIdentifiers = branches
        }
    }
    @available(OSX 10.12.2, *)
    func sampleController() {
        touchBar = makeTouchBar()
        if let bar = touchBar, let item = bar.item(forIdentifier: .undoAndRedoLatest) { // 😐: Small children towards Christmas?
            if let undoSegmented = item.view as? NSSegmentedControl, let undo = undoManager {
                undoSegmented.setEnabled(undo.canUndo, forSegment: 0)
                undoSegmented.setEnabled(undo.canRedo, forSegment: 1)
            }
        }
    }
}

