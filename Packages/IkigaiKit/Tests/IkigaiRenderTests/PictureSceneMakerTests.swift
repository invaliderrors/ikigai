import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers
@testable import IkigaiCore
@testable import IkigaiRender

struct PictureSceneMakerTests {
    @Test(arguments: PictureSceneMaker.Look.allCases)
    func everyLookIsAValidScene(_ look: PictureSceneMaker.Look) throws {
        for hasSubject in [true, false] {
            let scene = PictureSceneMaker.scene(look, hasSubject: hasSubject)
            #expect(scene.layers.count == (hasSubject ? 2 : 1))
            #expect(scene.layers.first?.image == "background.png")
            if hasSubject { #expect(scene.layers[1].depth > scene.layers[0].depth) }  // subject in front moves more
        }
    }

    @Test func aPictureWithoutASubjectBecomesOneScaledLayer() throws {
        // A plain gradient: nothing for Vision to lift out.
        let width = 6000, height = 3000
        let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.drawLinearGradient(CGGradient(colorsSpace: nil, colors: [CGColor(red: 0.9, green: 0.6, blue: 0.4, alpha: 1),
                                                                         CGColor(red: 0.2, green: 0.2, blue: 0.5, alpha: 1)] as CFArray,
                                              locations: [0, 1])!, start: .zero, end: CGPoint(x: 0, y: height), options: [])
        let source = FileManager.default.temporaryDirectory.appending(path: "Dusk \(UUID().uuidString).png")
        let destination = CGImageDestinationCreateWithURL(source as CFURL, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, context.makeImage()!, nil)
        #expect(CGImageDestinationFinalize(destination))
        defer { try? FileManager.default.removeItem(at: source) }

        let prepared = try PictureSceneMaker.prepare(source)
        defer { try? FileManager.default.removeItem(at: prepared.folder) }
        #expect(!prepared.hasSubject)
        let background = prepared.folder.appending(path: "background.png")
        let image = CGImageSourceCreateImageAtIndex(CGImageSourceCreateWithURL(background as CFURL, nil)!, 0, nil)!
        #expect(max(image.width, image.height) == Int(PictureSceneMaker.maxSide))
        // The scene for it resolves against the prepared folder.
        let scene = PictureSceneMaker.scene(.gentle, hasSubject: prepared.hasSubject)
        #expect(try SceneDocument.resolve(scene, folder: prepared.folder, package: prepared.folder).layers.count == 1)
    }
}
