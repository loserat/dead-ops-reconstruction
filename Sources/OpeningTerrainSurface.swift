import Foundation
import CoreGraphics
import ImageIO

/// Offline-baked world-space material fields. Original bitmap inputs stay untouched.
/// The same renderer is a safe fallback after editing map anchors without rebaking.
enum OpeningTerrainSurface {
    static func filename(_ kind:ArenaKind)->String {kind == .island ? "opening-island-v59.png":"opening-courtyard-v59.png"}
    static func dimensions(_ kind:ArenaKind)->(Int,Int) {kind == .island ? (1536,1024):(2048,1536)}
    static func extent(_ kind:ArenaKind)->V2 {kind == .island ? V2(x:IslandLayout.width*1.025,y:IslandLayout.depth*1.025):V2(x:16.5,y:11.5)}
    static func signature(_ kind:ArenaKind)->String {
        var parts=["terrain59-v1",String(kind.rawValue),String(extent(kind).x.bitPattern),String(extent(kind).y.bitPattern)]
        if kind == .island {
            parts += [String(OpeningMapDesign.boat.p.x.bitPattern),String(OpeningMapDesign.boat.p.y.bitPattern)]
            for path in OpeningMapDesign.islandPaths {
                parts.append(String(path.width.bitPattern))
                for p in path.points {parts += [String(p.x.bitPattern),String(p.y.bitPattern)]}
            }
        }else {parts.append(String(OpeningMapDesign.fountainRadius.bitPattern))}
        var hash:UInt64=14695981039346656037
        for byte in parts.joined(separator:"|").utf8 {hash=(hash ^ UInt64(byte)) &* 1099511628211}
        return "deadops-terrain59-"+String(hash,radix:16)
    }
    static func readBaked(_ url:URL,kind:ArenaKind)->CGImage? {
        guard let source=CGImageSourceCreateWithURL(url as CFURL,nil),
              let properties=CGImageSourceCopyPropertiesAtIndex(source,0,nil) as? [CFString:Any],
              let png=properties[kCGImagePropertyPNGDictionary] as? [CFString:Any],
              png[kCGImagePropertyPNGDescription] as? String == signature(kind) else{return nil}
        guard let image=CGImageSourceCreateImageAtIndex(source,0,nil) else{return nil}
        let (width,height)=dimensions(kind)
        return image.width==width && image.height==height ? image:nil
    }
    static func writeBaked(_ image:CGImage,to url:URL,kind:ArenaKind)throws {
        guard let target=CGImageDestinationCreateWithURL(url as CFURL,"public.png" as CFString,1,nil) else{throw NSError(domain:"TerrainBake",code:1)}
        CGImageDestinationAddImage(target,image,[kCGImagePropertyPNGDictionary:[kCGImagePropertyPNGDescription:signature(kind)]] as CFDictionary)
        guard CGImageDestinationFinalize(target) else{throw NSError(domain:"TerrainBake",code:2)}
    }
    private struct Pixels {
        let side=512
        var bytes=[UInt8](repeating:128,count:512*512*4)
        init(_ image:CGImage?) {
            guard let image else{return}
            let side=self.side
            bytes.withUnsafeMutableBytes {raw in
                let context=CGContext(data:raw.baseAddress,width:side,height:side,bitsPerComponent:8,bytesPerRow:side*4,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
                context.interpolationQuality = .high;context.draw(image,in:CGRect(x:0,y:0,width:side,height:side))
            }
        }
        func sample(_ u:Double,_ v:Double)->(Double,Double,Double) {
            // Mirrored material repeats meet continuously even if a source image has a small edge mismatch.
            func mirror(_ n:Double)->Double {let t=n-floor(n/2)*2;return t<=1 ? t:2-t}
            let x=mirror(u)*Double(side-1),y=mirror(v)*Double(side-1),ix=Int(x),iy=Int(y),fx=x-Double(ix),fy=y-Double(iy)
            let x1=min(side-1,ix+1),y1=min(side-1,iy+1)
            func channel(_ c:Int)->Double {
                let a=Double(bytes[(iy*side+ix)*4+c]),b=Double(bytes[(iy*side+x1)*4+c]),d=Double(bytes[(y1*side+ix)*4+c]),e=Double(bytes[(y1*side+x1)*4+c])
                return (a*(1-fx)+b*fx)*(1-fy)+(d*(1-fx)+e*fx)*fy
            }
            return (channel(0),channel(1),channel(2))
        }
    }
    static func render(_ kind:ArenaKind,grass:CGImage?,earth:CGImage?)->CGImage {
        let (width,height)=dimensions(kind),extent=extent(kind),island=kind == .island
        let grass=Pixels(grass),earth=Pixels(earth)
        var bytes=[UInt8](repeating:255,count:width*height*4)
        func smooth(_ n:Double)->Double {let t=max(0,min(1,n));return t*t*(3-2*t)}
        for row in 0..<height {for col in 0..<width {
            let p=V2(x:(Double(col)/Double(width-1)*2-1)*extent.x,y:(Double(row)/Double(height-1)*2-1)*extent.y)
            let broad=sin(p.x*0.47+p.y*0.22)*cos(p.y*0.59-p.x*0.16)
            let g=grass.sample(p.x*0.13+sin(p.y*0.21)*0.045,p.y*0.13+sin(p.x*0.23)*0.04)
            let soil=earth.sample(p.x*0.17+p.y*0.011+0.37,p.y*0.17-0.21)
            var red=g.0*0.64+32+broad*7,green=g.1*0.72+44+broad*8,blue=g.2*0.62+21+broad*4
            var wear=max(0,(g.0+g.1+g.2)/3-75)/120
            wear=min(0.15,wear)
            if island {
                var path=0.0
                let edgeNoise=sin(p.x*3.2+p.y*1.7)*sin(p.y*2.4)*0.05
                for trail in OpeningMapDesign.islandPaths {path=max(path,smooth((trail.width*0.75-trail.distance(p)+edgeNoise)/(trail.width*0.45)))}
                path=max(path,smooth((1.8-p.length)/1.1)*0.72)
                let rho=pow(pow(abs(p.x)/IslandLayout.width,4)+pow(abs(p.y)/IslandLayout.depth,4),0.25)
                let bank=smooth((rho-0.80)/0.23)*0.65
                let boat=OpeningMapDesign.boat,local=p-boat.p
                let boatWear=smooth((1.2-hypot(local.x,local.y*0.42))/0.6)*0.25
                wear=max(wear,path,bank,boatWear)
            }else {
                let edge=smooth((max(abs(p.x)/11.6,abs(p.y)/7.6)-0.94)*7)
                let apron=smooth((OpeningMapDesign.fountainRadius+0.85-p.length)/0.7)*0.28
                wear=max(wear,edge*0.8,apron)
                let moss=smooth((broad+0.2)*0.5)*0.15
                red*=1-moss;green*=1-moss*0.5;blue*=1-moss
            }
            red=red*(1-wear)+(soil.0*0.67+16+broad*3)*wear
            green=green*(1-wear)+(soil.1*0.69+14+broad*3)*wear
            blue=blue*(1-wear)+(soil.2*0.66+13+broad*2)*wear
            let i=(row*width+col)*4
            bytes[i]=UInt8(max(0,min(255,red)));bytes[i+1]=UInt8(max(0,min(255,green)));bytes[i+2]=UInt8(max(0,min(255,blue)))
        }}
        return CGImage(width:width,height:height,bitsPerComponent:8,bitsPerPixel:32,bytesPerRow:width*4,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGBitmapInfo(rawValue:CGImageAlphaInfo.last.rawValue),provider:CGDataProvider(data:Data(bytes) as CFData)!,decode:nil,shouldInterpolate:true,intent:.defaultIntent)!
    }
}
