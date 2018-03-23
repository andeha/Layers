//
//  NP with Friends.swift
//  Layers
//

import Metal

class Parall {
    static var prefered = Parall()
    func enque(entryPoint: String, in: (MTLComputeCommandEncoder)->Any?, assign: (Int, Int, Any?) throws -> (MTLSize, MTLSize), out: @escaping (MTLCommandBuffer)->Void) {
        guard let device = MTLCreateSystemDefaultDevice() else { return }
        guard let library = device.newDefaultLibrary(), let main = library.makeFunction(name: entryPoint) else { return }
        let queue = device.makeCommandQueue(); let buffer = queue.makeCommandBuffer(); let encoder = buffer.makeComputeCommandEncoder()
        do {
            let state = try device.makeComputePipelineState(function: main)
            let any = `in`(encoder)
            let threadWidth = state.threadExecutionWidth
            let maxThreadsPerGroup = state.maxTotalThreadsPerThreadgroup
            debugPrint("threadWidth: \(threadWidth) and maxThreadsPerGroup \(maxThreadsPerGroup)")
            let (numThreadgroups, threadsPerGroup) = try `assign`(maxThreadsPerGroup, threadWidth, any)
            // Execute the compute function in a single instruction, multiple data (SIMD) fashion on the device.
            encoder.setComputePipelineState(state)            
            encoder.dispatchThreadgroups(numThreadgroups, threadsPerThreadgroup: threadsPerGroup)
            encoder.endEncoding()
            buffer.addCompletedHandler(out)
            buffer.commit()
        } catch {
            debugPrint("Error when assigning task to parall: \(error)")
        }
    }
    // enum Ring: Int { case unavailable, read, write, fullaccess }
    // typealias Access = (initialRing: Ring, maxRing: Ring)
    // func field(access: Access = (.read, .read), windowOffset: UInt64 = 0) -> Data {}
    func buffer(initial length: Int) -> MTLBuffer? {
        guard let buffer = MTLCreateSystemDefaultDevice()?.makeBuffer(length: length) else { return nil }
        return buffer
    }
    
    static func info(device: MTLDevice) {
        guard let name = device.name else { return }
        let isLowPower = device.isLowPower; let maxThreads = device.maxThreadsPerThreadgroup; let memSize = device.recommendedMaxWorkingSetSize
        debugPrint("Name: \(name)"); debugPrint("Low-power: \(isLowPower)")
        debugPrint("MaxThreads: \(maxThreads) and MemSize \(memSize)")
    }
}

extension Parall {  // 😐: MARK: 😐|😐😐
    static func ceiledNthRoot(degree n: Int, base: Int) -> Int {
        var x: Int = 1
        var y = nthRootStep(n: n, base: base, fixpoint: x)
        repeat {
            x = y
            y = nthRootStep(n: n, base: base, fixpoint: x)
        } while y < x
        return x
    }
    static func ceiledTwoRaisedTo(_ value: Int) -> Int { return Int(CeiledPowerOfTwo(Int64(value), 1)) }
}

extension Parall {
    fileprivate static func nthRootStep(n: Int, base: Int, fixpoint x: Int) -> Int { return ((n-1)*x + base/x^(n-1))/n }
}

//enum ParallError: Error { case generalError(description: String) }

extension MTLBuffer {
    subscript(index: Int) -> UInt8? {
        get {
            guard index < self.length else { return nil }
            let pointer = self.contents().assumingMemoryBound(to: UInt8.self).advanced(by: index)
            return pointer.pointee
        }
        set (replacement) {
            guard index < self.length, let r = replacement else { return }
            let pointer = self.contents().assumingMemoryBound(to: UInt8.self).advanced(by: index)
            pointer.pointee = r
        }
    }
}

