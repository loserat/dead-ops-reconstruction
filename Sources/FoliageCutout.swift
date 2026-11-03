import Foundation
import SceneKit
import CoreGraphics
import ImageIO

/// Pixel alpha for the same UV channel used by the production leaf material.
/// Transparent parts of a canopy must not trigger a player's occlusion silhouette.
final class FoliageOpacityMask {
    let width:Int,height:Int
    private let alpha:[UInt8]
    init?(_ image:CGImage) {
        let w=image.width,h=image.height
        guard w>0,h>0 else{return nil}
        var rgba=[UInt8](repeating:0,count:w*h*4)
        let drawn=rgba.withUnsafeMutableBytes { bytes -> Bool in
            guard let context=CGContext(data:bytes.baseAddress,width:w,height:h,bitsPerComponent:8,bytesPerRow:w*4,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGBitmapInfo.byteOrder32Big.rawValue|CGImageAlphaInfo.premultipliedLast.rawValue) else{return false}
            context.draw(image,in:CGRect(x:0,y:0,width:w,height:h));return true
        }
        guard drawn else{return nil}
        width=w;height=h;alpha=(0..<w*h).map{rgba[$0*4+3]}
    }
    func isOpaque(at uv:CGPoint)->Bool {
        guard uv.x.isFinite,uv.y.isFinite else{return false}
        let x=max(0,min(width-1,Int(min(1,max(0,uv.x))*CGFloat(width)))),y=max(0,min(height-1,Int(min(1,max(0,uv.y))*CGFloat(height))))
        return alpha[y*width+x]>=90
    }
}
extension ArcadeGame {
    func foliageMask(for material:SCNMaterial)->FoliageOpacityMask? {
        if let mask=foliageMasks[ObjectIdentifier(material)] {return mask}
        guard material.name=="foliage-cutout",let image=material.diffuse.contents as AnyObject? else{return nil}
        return foliageMasksByImage[ObjectIdentifier(image)]
    }
    func hitMaterial(_ hit:SCNHitTestResult)->SCNMaterial? {
        let materials=hit.node.geometry?.materials ?? []
        guard !materials.isEmpty else{return nil}
        return materials[max(0,hit.geometryIndex)%materials.count]
    }
    func foliageImage(_ name:String)->CGImage? {
        if let image=foliageImages[name] {return image}
        guard let url=Bundle.main.resourceURL?.appendingPathComponent("Assets/"+name),let source=CGImageSourceCreateWithURL(url as CFURL,nil),let image=CGImageSourceCreateImageAtIndex(source,0,nil) else{return nil}
        foliageImages[name]=image;return image
    }
    func configureFoliageCutout(_ material:SCNMaterial,image:CGImage) {
        material.name="foliage-cutout";material.diffuse.contents=image;material.transparent.contents=image
        material.isDoubleSided=true;material.writesToDepthBuffer=true;material.readsFromDepthBuffer=true
        material.blendMode = .replace
        material.shaderModifiers=[.surface:"#pragma opaque\n#pragma body\nif (_surface.diffuse.a < 0.35) discard_fragment();\n_surface.diffuse.a = 1.0;\n_surface.transparent = float4(1.0);"]
        for p in [material.diffuse,material.transparent] {p.minificationFilter = .linear;p.magnificationFilter = .linear;p.mipFilter = .linear;p.maxAnisotropy=4}
        let imageID=ObjectIdentifier(image)
        if foliageMasksByImage[imageID]==nil {foliageMasksByImage[imageID]=FoliageOpacityMask(image)}
        foliageMasks[ObjectIdentifier(material)]=foliageMasksByImage[imageID]
    }
}
