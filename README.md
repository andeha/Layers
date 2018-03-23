# Layers

On large-sized multitouch touchpads with haptic feedback, parallel computations and flat/touchbar-based user interfaces.

To enable the `Parall`, see the example code below:

    import MetalKit

    struct TiledStrokes {
        var beziers: [(Chronology, BezierPath2D, [BezierDraw2DArgument])]
    }

    class GPUServer {
        func compute(drawable: CAMetalDrawable?) {
            Parall.prefered.enque(entryPoint: "bezierDraw2D",
        in: { (encoder: MTLComputeCommandEncoder) -> Any? in
              self.drawable = drawable
              encoder.setTexture(drawable?.texture, at: 0)
              encoder.setBuffer(context, offset: 0, at: 0)
              return nil
          },
    assign: { (maxThreadsPerGroup: Int, threadWidth: Int, any: Any?) throws -> (MTLSize, MTLSize) in
            //let size = drawable.texture.height
            let threadsPerGroup = MTLSize(width: threadWidth, height: 1, depth: 1)
            let numThreadgroups = MTLSize(width: 16, height: 1, depth: 1)
            return (numThreadgroups, threadsPerGroup)
        },
     out: { (buffer: MTLCommandBuffer) in
            let bytesPerPixel = 4
    //            let bytesPerRow = bytesPerPixel * radiances.width
    //            let size = CGSize(width: radiances.width, height: radiances.height)
    //            let byteCount = Int(CGFloat(bytesPerPixel) * size.width * size.height)
    //            var bytes = [UInt8](repeating: 0, count: byteCount)
    //            radiances.getBytes(&imageBytes, bytesPerRow: Int(bytesPerRow),
    //                from: MTLRegionMake2D(0, 0, Int(size.width), Int(size.height)), mipmapLevel: 0)
    //            completion(bytes as? CAMetalDrawable)
        })
    }
    
    var delegate: GPUServerDelegate?
    var resolutions: [MTLSize] { return [] } // [😐]: Isn't that great <--.*
    var drawable: CAMetalDrawable?
    var context = Parall.prefered.buffer(initial: 4096)!
    
    // MARK: Public API for the Spatial Domain
    open func updateResolutions(includes: MTLSize, excludes: MTLSize) {}
    open func peek(entry: (Chronology, BezierPath2D, [BezierDraw2DArgument], inout Bool)->Void) {}
    open func seed(at: BezierPath2D) {}
    open func bezier(locus at: BezierPath2D, contemplative cp1: BezierPath2D, retrospective cp2: BezierPath2D, radius: BezierPath1D, intentional p3Color: BezierPath3D) {}
    open func stroke(beziers: TiledStrokes) {}
    open func commit(validTime finish: Chronology) {}
    open func rollback() {}
    }
    
    extension GPUServer {
    fileprivate func drawToBitmap(width: Int, height: Int, scale: CGFloat) -> NSBitmapImageRep? { // TODO: Use non-rectangular or mask.
        guard let bmpImageRep = NSBitmapImageRep(bitmapDataPlanes: nil,
            pixelsWide: Int(CGFloat(width) * scale), pixelsHigh: Int(CGFloat(height) * scale),
            bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false,
            colorSpaceName: NSCalibratedRGBColorSpace,
            bytesPerRow: 0, bitsPerPixel: 0)?.retagging(with: .sRGB) else { return nil }
        bmpImageRep.size = NSSize(width: width, height: height)
        let bitmapContext = NSGraphicsContext(bitmapImageRep: bmpImageRep)
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.setCurrent(bitmapContext)
        //bmpImageRep.setPixel(_ p: UnsafeMutablePointer<Int>!, atX x: Int, y: Int)
        let gpuServer = GPUServer()
        gpuServer.compute(bmpImageRep)
        NSGraphicsContext.restoreGraphicsState()
        return bmpImageRep
    }
    fileprivate func draw(layer: NSWindow) {
        let bounds = layer.bounds
        // Figure out the scale of pixels to points
        let scale = layer.convertToBacking(<#T##rect: NSRect##NSRect#>)
        CGFloat scale = [self convertSizeToBacking:CGSizeMake(1,1)].width;
        // Supply the user size (points)
        let alignOpts = NSAlignmentOptions.xxx
        alignedRect = self.backingAlignedRect
        let imageRep = self.drawToBitmapOfWidth(bounds.size.width, height: bounds.size.height, scale: scale)
        imageRep.drawInRect(bounds)
    }
    }
    
    protocol GPUServerDelegate {
    func willIncorporate(_ gpuServer: GPUServer, resolution: MTLSize)
    func didIncorporate(_ gpuServer: GPUServer, resolution: MTLSize) // 
    func didExclude(_ gpuServer: GPUServer, resolution: MTLSize)
    }
    
    class Doubler {
        var input = Parall.prefered.buffer(initial: 4096)!
        var output = Parall.prefered.buffer(initial: 4096)!
        init() { for i in 0..<input.length { input[i] = 12 } }
        func compute() {
            Parall.prefered.enque(entryPoint: "doubler",
      in: { (encoder: MTLComputeCommandEncoder) -> Any? in
            encoder.setBuffer(input, offset: 0, at: 0)
            encoder.setBuffer(output, offset: 0, at: 1)
            return input
        },
     assign: { (maxThreadsPerGroup: Int, threadWidth: Int, any: Any?) throws -> (MTLSize, MTLSize) in
            let threadsPerGroup = MTLSize(width: threadWidth, height: 1, depth: 1)
            let numThreadgroups = MTLSize(width: (self.input.length + threadWidth)/threadWidth, height: 1, depth: 1)
            return (numThreadgroups, threadsPerGroup)
        },
     out: { (buffer: MTLCommandBuffer) in
            for i in 0..<self.output.length { let x = self.output[i]; debugPrint("x: \(x!)") }
            })
        }
    }
