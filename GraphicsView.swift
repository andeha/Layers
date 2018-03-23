//
//  GraphicsView.swift
//  Layers
//

import Cocoa

@IBDesignable
class GraphicsView: NSView {
    var delegate: GraphicsViewDelegate?
    override func awakeFromNib() {
        super.awakeFromNib()
        pressureConfiguration = NSPressureConfiguration(pressureBehavior: .primaryGeneric) // Removes the default primaryDeepClick.
        register(forDraggedTypes: [ NSFilenamesPboardType ])
    }
}

extension GraphicsView { // MARK: NSDraggingDestination
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        return NSDragOperation.link
    }
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        return NSDragOperation.link
    }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        var result = false
        let pboard: NSPasteboard = sender.draggingPasteboard()
        if let data = pboard.data(forType: NSFilenamesPboardType) {
            let loc = sender.draggingLocation()
            place(data: data, location: loc, &result)
        }
        return result
    }
    private func place(data: Data, location loc: NSPoint, _ result: inout Bool) { do {
        if let filepaths = try PropertyListSerialization.propertyList(from: data,
                options: PropertyListSerialization.MutabilityOptions(rawValue: 0), format: nil) as? NSArray {
            for filepath in filepaths {
                let url = URL(fileURLWithFileSystemRepresentation: filepath as! String, isDirectory: false, relativeTo: nil)
                if let partialResult = delegate?.didDropFile(self, location: loc, originalUrl: url) {
                    result = partialResult || result
                }
            }
        }
    } catch { debugPrint("Unable to embed or use dropped files: \(error)") } }
}

protocol GraphicsViewDelegate {
    func didDropFile(_ graphicsView: GraphicsView, location: NSPoint, originalUrl: URL) -> Bool
}
