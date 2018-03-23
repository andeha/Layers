//
//  Graphics.swift
//  Layers
//

import Cocoa
import SceneKit

class Anfang: Creation {
    let layer = CAShapeLayer()
    init(text: String, font: NSFont, frame: NSRect) {
        super.init(layer: layer)
        layer.path = NSBezierPath(anfang: text, font: font, rect: frame).cgPath
    }
}

class Pdf: Creation, FriendOrFoe, CALayerDelegate {
    let layer = CALayer()

    fileprivate var image: NSImage?
    fileprivate var page: CGPDFPage?

    init?(originalUrl: URL /* securityToken: (String)->Void 😐: Don't allow. */) {
        super.init(layer: layer)
        guard let pdf = CGPDFDocument(originalUrl as CFURL) else { return nil }
        guard let page = pdf.page(at: 1) else { return nil }
        self.page = page
        layer.delegate = self
        // TODO: Lets move the crop box.
    }
    
    func images(completion: (NSImage)) {
        if let p = page {
            let contentStream = CGPDFContentStreamCreateWithPage(p)
            // public func CGPDFContentStreamCreateWithStream(_ stream: CGPDFStreamRef, _ streamResources: CGPDFDictionaryRef, _ parent: CGPDFContentStreamRef) -> CGPDFContentStreamRef
            // public func CGPDFContentStreamGetStreams(_ cs: CGPDFContentStreamRef) -> CFArray?
            // public func CGPDFContentStreamGetResource(_ cs: CGPDFContentStreamRef, _ category: UnsafePointer<Int8>, _ name: UnsafePointer<Int8>) -> CGPDFObjectRef?
            let csp = PDFContentStreamProcessor(contentStream: contentStream)
            csp.scan(initialCTM: CGAffineTransform(a: 1, b: 0, c: 0, d: 1, tx: 0, ty: 0))
        }
    }
    
    // MARK: CALayerDelegate
            
    func draw(_ layer: CALayer, in context: CGContext) {
        if let p = page {
            let size = PDFPageRenderer.render(page: p, context: context)
            debugPrint("Size is \(size)")
        }
    }
    
    // FriendOrFoe
    
    func tuck() {}
    func incorporate() {}
    
    // MARK: Miscellaneous
    
    override var description: String {
        get {
            guard let p = page else { return "Unable to interpret .pdf file" }
            let trimRect = p.getBoxRect(CGPDFBox.trimBox)
            let artRect = p.getBoxRect(CGPDFBox.artBox)
            let angle = p.rotationAngle
            return "Trimbox is \(trimRect). Artbox is \(artRect). Angle is \(angle)."
        }
    }
}

protocol FriendOrFoe { func tuck(); func incorporate() }

class Surface: Creation {
    var layer = CAMetalLayer() // Defaults to 8 bytes for Blue, Green, Red, and Alpha, in that order — with normalized values between 0 and 1.
    var gpuServer = GPUServer()
    var displayLink: CVDisplayLink?
    var source = DispatchSource.makeUserDataAddSource()
    var commandQueue: MTLCommandQueue?
    let cinematicOrManualRendering = DispatchQueue(label: "Cinematic or manual surface rendering")
    var isPaused = true {
        didSet {
            guard let link = displayLink else { return }
            if isPaused { CVDisplayLinkStop(link); source.cancel() } else { CVDisplayLinkStart(link) }
        }
    }
    var now: CVTimeStamp? {
        get {
            let timestamp = UnsafeMutablePointer<CVTimeStamp>.allocate(capacity: 1)
            guard let link = displayLink, CVDisplayLinkGetCurrentTime(link, timestamp) == kCVReturnSuccess else { return nil }
            return timestamp.pointee
        }
    }
    init() {
        super.init(layer: layer)
        source.setEventHandler() { self.loop() }; source.resume()
    }
    var callback: CVDisplayLinkOutputCallback = { (displayLink: CVDisplayLink, inTime: UnsafePointer<CVTimeStamp>, outTime: UnsafePointer<CVTimeStamp>, c: CVOptionFlags, d: UnsafeMutablePointer<CVOptionFlags>, displayLinkContext: UnsafeMutableRawPointer?) -> CVReturn in
        let me = unsafeBitCast(displayLinkContext, to: UnsafeMutablePointer<Surface>.self).pointee
        if me.linkAndDisplayTime != nil {
            debugPrint("CGDirectDisplay device refresh rate indicates rendering affects frame rate")
            me.isLateAndHasSkipped.0 = true
        }
        me.linkAndDisplayTime = (inTime.pointee, outTime.pointee)
        // if let t1 = me.linkAndDisplayTime?.0, let t2 = me.linkAndDisplayTime?.1 { debugPrint("Display link  \(t1), \(t2)") }
        me.source.add(data: 1)
        return kCVReturnSuccess
    }
    func setup() {}; func draw(encoder: MTLRenderCommandEncoder) {}
    func sample(descriptor: MTLRenderPassDescriptor, current drawable: CAMetalDrawable, displayTime: CVTimeStamp?) {
        // Fills the layer with one color.
        descriptor.colorAttachments[0].loadAction  = .clear
        descriptor.colorAttachments[0].storeAction = .store
        descriptor.colorAttachments[0].clearColor  = MTLClearColorMake(1.0, 0.0, 0.0, 1.0)
        descriptor.colorAttachments[0].texture     = drawable.texture
    }
    func render(displayTime: CVTimeStamp?) {
        if let queue = commandQueue, let drawable = layer.nextDrawable() {
            let descriptor = MTLRenderPassDescriptor()
            sample(descriptor: descriptor, current: drawable, displayTime: displayTime)
            let buffer = queue.makeCommandBuffer()
            let encoder = buffer.makeRenderCommandEncoder(descriptor: descriptor)
            draw(encoder: encoder)
            encoder.endEncoding()
            buffer.present(drawable)
            //buffer.present(drawable, atTime: targetTime)
            //presentationDelay = drawable.presentedTime - targetTime
            //// Examine presentationDelay and adjust future frame timing
            buffer.commit()
        }
    }
    var linkAndDisplayTime: (CVTimeStamp, CVTimeStamp)?
    var isLateAndHasSkipped = (false, false) // Indicates correspondance with display refresh rate. 
}

extension Surface {
    func loop() {
        cinematicOrManualRendering.async {
            if let displayTime = self.linkAndDisplayTime?.1 {
                //if let n = self.now { debugPrint("Start rendering \(n)") }
                self.render(displayTime: displayTime)
                self.linkAndDisplayTime = nil
            }
        }
    }
    func refresh() { cinematicOrManualRendering.async { self.render(displayTime: nil) } }
    func start() {
        layer.device = MTLCreateSystemDefaultDevice()
        if displayLink == nil {
            CVDisplayLinkCreateWithActiveCGDisplays(&displayLink)
            if let link = displayLink {
                let context = UnsafeMutablePointer<Surface>.allocate(capacity: 1)
                context.pointee = self
                CVDisplayLinkSetOutputCallback(link, callback, context)
                CVDisplayLinkSetCurrentCGDisplay(link, CGMainDisplayID()) // TODO: Investigate CGGetDisplaysWithPoint
                commandQueue = layer.device?.makeCommandQueue()
                setup()
            }
        }
        isPaused = false
    }
    func stop() {
        isPaused = true
        layer.device = nil 
    }
}

class Sediment: Surface {
    var blender = Blender() // Presence
    var turtle = Axiom(device: device)
    override func render(displayTime: CVTimeStamp?) {
        preApply(displayTime: displayTime)
        lead(displayTime: displayTime)
        super.render(displayTime: displayTime)
        process(displayTime: displayTime)
        follow(displayTime: displayTime)
        postApply(displayTime: displayTime)
    }
    override func sample(descriptor: MTLRenderPassDescriptor, current drawable: CAMetalDrawable, displayTime: CVTimeStamp?) { // cone: ...
        descriptor.colorAttachments[0].loadAction  = .clear
        descriptor.colorAttachments[0].storeAction = .store
        descriptor.colorAttachments[0].clearColor  = MTLClearColorMake(1.0, 1.0, 0.0, 1.0)
        descriptor.colorAttachments[0].texture     = drawable.texture
    }
    static let device = MTLCreateSystemDefaultDevice()
}

extension Sediment { // MARK: Sediment Rendering
    func preApply(displayTime: CVTimeStamp? /* to: buffer, sources: [], destinations: [] */ ) {
        // Physics I
    }
    func lead(displayTime: CVTimeStamp? /* initial camera: Int, transgress: (_ x: Double, _ y: Double, _ z: Double, [_ r: Double, _ 𝜃: Double, _ 𝜑: Double, _ weight: Double])->[], consecutive camera: Int, completion: (Int, Int)->Void */) {
        // x, y, z, rho, [focalx, focaly]
        // TODO: Consider tilt-pressure.
    }
    func process(displayTime: CVTimeStamp?) {
        // Kodak.
        // perspectives.lookAt(eye: float3, center: float3, up: float3) -> float4x4 but in GPU.
    }
    func follow(displayTime: CVTimeStamp? /* x: Double, y: Double, z: Double, 𝜃: Double, 𝜑: Double */) {
        // TODO: Scene continues.
    }
    func postApply(displayTime: CVTimeStamp? /* to: buffer, sources: [], destinations: [] */) {
        // Physics II
    }
}

extension Sediment { // MARK: - macOS
    func viewWillAppear() { start() }
    func viewWillDisappear() { stop() }
}

//class Abstraction {
//  let layer = CATiledLayer() // CAScrollLayer, CATextLayer, QTMovieLayer
//}

class Scene: Creation {
    var layer = SCNLayer()
    init() {
        super.init(layer: layer)
        layer.scene = SCNScene(named: "")
        layer.frame = NSRect(x: 10, y: 10, width: 200, height: 200)
    }
}

class Image: Creation {
    let layer = CALayer()
    init(image: NSImage) {
        super.init(layer: layer)
        layer.bounds = NSRectToCGRect(NSRect(x: 0.0, y: 0.0, width: image.size.width, height: image.size.height))
        layer.contents = image
        // layer.contentsGravity = kCAGravityCenter
        // layer.anchorPoint = NSMakePoint(0.5, 0.5)
    }
}

class Creation: NSObject {
    var eventMonitor: Any?
    init(layer: CALayer) {
        layer.setValue(NSNumber(value: 10.0), forKey: Attributes.nudgeDelta) // TODO: Change nudgeDelta to 1.0 for pixel perfection.
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: NSEventMask.keyDown)
        { (event: NSEvent) -> NSEvent? in
            guard let selected = layer.value(forKey: Attributes.isSelected) as? NSNumber else { return event }
            guard let nudgeDelta = layer.value(forKey: Attributes.nudgeDelta) as? NSNumber else { return event }
            guard selected.boolValue else { return event }
            switch event.keyCode {
            case 123: // Left
                layer.position = CGPoint(x: layer.position.x - CGFloat(nudgeDelta.doubleValue), y: layer.position.y)
            case 124: // Right
                layer.position = CGPoint(x: layer.position.x + CGFloat(nudgeDelta.doubleValue), y: layer.position.y)
            case 125: // Down
                layer.position = CGPoint(x: layer.position.x, y: layer.position.y - CGFloat(nudgeDelta.doubleValue))
            case 126: // Up
                layer.position = CGPoint(x: layer.position.x, y: layer.position.y + CGFloat(nudgeDelta.doubleValue))
            default: break
            }
            return event
        }
    }
}

class Grid {
    let layer = CAShapeLayer()
    
    var gridPath: NSBezierPath {
        get {
            let path = NSBezierPath()
            var x = layer.bounds.origin.x + (layer.bounds.size.width + increment)/2
            while x < NSMaxX(layer.bounds) {
                path.move(to: NSPoint(x: x, y: NSMinY(layer.bounds)))
                path.line(to: NSPoint(x: x, y: NSMaxY(layer.bounds)))
                x += increment
            }
            x = layer.bounds.origin.x + (layer.bounds.size.width - increment)/2
            while x > NSMinX(layer.bounds) {
                path.move(to: NSPoint(x: x, y: NSMinY(layer.bounds)))
                path.line(to: NSPoint(x: x, y: NSMaxY(layer.bounds)))
                x -= increment
            }
            var y = layer.bounds.origin.y + (layer.bounds.size.height + increment)/2
            while y < NSMaxY(layer.bounds) {
                path.move(to: NSPoint(x: NSMinX(layer.bounds), y: y))
                path.line(to: NSPoint(x: NSMaxX(layer.bounds), y: y))
                y += increment
            }
            y = layer.bounds.origin.y + (layer.bounds.size.height - increment)/2
            while y > NSMinY(layer.bounds) {
                path.move(to: NSPoint(x: NSMinX(layer.bounds), y: y))
                path.line(to: NSPoint(x: NSMaxX(layer.bounds), y: y))
                y -= increment
            }
            return path
        }
    }
    
    var increment: CGFloat = 20.0
    
    init() {
        layer.strokeColor = Colors.fineGrid.cgColor
        layer.lineWidth = 0.5
    }
    
    func viewWillAppear() { enfoil(layer: layer, margins: [ 4.0, 4.0, 4.0, 4.0 ]) }
    func repaint() { layer.path = gridPath.cgPath }
}

class GalleyProof {
    let layer = CATextLayer()
    
    init() {
        layer.string = "A"
        layer.font = "Zapfino" as CFTypeRef
        layer.fontSize = 137.0
        layer.alignmentMode = kCAAlignmentCenter
        layer.foregroundColor = NSColor.black.cgColor
        layer.isWrapped = false
        layer.actions = [ "position" : NSNull() ]
    }
    
    func viewWillAppear() { bullseye(layer: layer) }
}

class CropMarks {
    let layer = CAShapeLayer()
    
    var length: CGFloat = 20.0
    var ext: CGFloat = 10.0
    
    var gridPath: NSBezierPath {
        get {
            let path = NSBezierPath()
            guard let rect = layer.value(forKey: Attributes.cropRect) as? NSRect else { return path }
            path.move(to: NSMakePoint(NSMinX(rect) - ext, NSMinY(rect)))
            path.relativeLine(to: NSMakePoint(length + ext, 0))
            path.move(to: NSMakePoint(NSMinX(rect), NSMinY(rect) - ext))
            path.relativeLine(to: NSMakePoint(0, length + ext))
            path.move(to: NSMakePoint(NSMaxX(rect) + ext, NSMinY(rect)))
            path.relativeLine(to: NSMakePoint(-(length + ext), 0))
            path.move(to: NSMakePoint(NSMaxX(rect), NSMinY(rect) - ext))
            path.relativeLine(to: NSMakePoint(0, length + ext))
            path.move(to: NSMakePoint(NSMinX(rect) - ext, NSMaxY(rect)))
            path.relativeLine(to: NSMakePoint(length + ext, 0))
            path.move(to: NSMakePoint(NSMinX(rect), NSMaxY(rect) + ext))
            path.relativeLine(to: NSMakePoint(0, -(length + ext)))
            path.move(to: NSMakePoint(NSMaxX(rect) + ext, NSMaxY(rect)))
            path.relativeLine(to: NSMakePoint(-(length + ext), 0))
            path.move(to: NSMakePoint(NSMaxX(rect), NSMaxY(rect) + ext))
            path.relativeLine(to: NSMakePoint(0, -(length + ext)))
            guard let selected = layer.value(forKey: Attributes.isSelected) as? NSNumber else { return path }
            if selected.boolValue {
                path.appendOval(in: NSRect(x: NSMinX(rect) - ext/2, y: NSMinY(rect) - ext/2, width: ext, height: ext))
            }
            return path
        }
    }

    init() {
        layer.strokeColor = Colors.cropmarks.cgColor
        layer.lineWidth = 0.5
        layer.setValue(NSNumber(value: false), forKey: Attributes.isSelected)
        layer.setValue(CropMarks.defaultCropRect, forKey: Attributes.cropRect)
        let redisplay = { self.layer.path = self.gridPath.cgPath }
        layer.setValue(redisplay, forKey: Attributes.repaint)
        layer.name = NamedLayers.cropmarks
    }
    
    private static var defaultCropRect: NSRect {
        // Set Cropmarks
        let paperSize = NSPrintInfo.shared().paperSize
        let bottomMargin = NSPrintInfo.shared().bottomMargin
        let leftMargin = NSPrintInfo.shared().leftMargin
        return NSRect(origin: NSMakePoint(leftMargin, bottomMargin), size: paperSize)
    }

    func repaint() {
        guard let repaint = layer.value(forKey: Attributes.repaint) as? ()->Void else { return }
        repaint() // 😐: And someone might not limit the stack!
    }
}

// MARK: Constraints

func bullseye(layer: CALayer) {
    layer.addConstraint(CAConstraint(attribute: .midX,
        relativeTo: "superlayer", attribute: .midX))
    layer.addConstraint(CAConstraint(attribute: .midY,
        relativeTo: "superlayer", attribute: .midY)) // scale: 1.0
}

func enfoil(layer: CALayer, margins: [CGFloat]) {
    layer.autoresizingMask = [ .layerHeightSizable, .layerWidthSizable ]
    layer.contentsGravity = kCAGravityResizeAspect
    layer.addConstraint(CAConstraint(attribute: .minX,
        relativeTo: "superlayer", attribute: .minX, offset:  margins[0]))
    layer.addConstraint(CAConstraint(attribute: .maxY,
        relativeTo: "superlayer", attribute: .maxY, offset: -margins[1]))
    layer.addConstraint(CAConstraint(attribute: .maxX,
        relativeTo: "superlayer", attribute: .maxX, offset: -margins[2]))
    layer.addConstraint(CAConstraint(attribute: .minY,
        relativeTo: "superlayer", attribute: .minY, offset:  margins[3]))
}

extension CALayer {
    // Both setter and getter in `selected` below cycles infinitely and exhausts 
    // the stack. When used from Swift, the resulting code bloats for a good 
    // reason.
    
//    var selected: Bool {
//        get {
//            guard let number = value(forKey: Attributes.selected) as? NSNumber else { return true }
//            return number.boolValue
//        }
//        set {
//            setValue(NSNumber(value: newValue), forKey: Attributes.selected)
//        }
//    }
    
//    func isoA0PaperSize(portrait: Bool) -> NSSize {
//        // A0 is defined as a sheet 1 m^2 in area with sides of ratio 1:sqrt(2) which gives 841 x 1189 mm
//        var a0 = NSZeroSize
//        if portrait {
//            a0.width = 841.0 * 2.83465
//            a0.height = 1189.0 * 2.83465
//        } else {
//            a0.width = 1189.0 * 2.83465
//            a0.height = 841.0 * 2.83465
//        }
//        return a0
//    }
}
