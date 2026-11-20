import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation

let code = FileHandle.standardInput.readDataToEndOfFile()
let filter = CIFilter.qrCodeGenerator()
filter.message = code
filter.correctionLevel = "M"

if let image = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 8, y: 8)),
   let png = CIContext(options: [.useSoftwareRenderer: true]).pngRepresentation(
       of: image, format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB()
   ) {
    print(png.base64EncodedString())
} else {
    exit(EXIT_FAILURE)
}
