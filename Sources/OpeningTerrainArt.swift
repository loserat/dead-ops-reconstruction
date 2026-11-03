import Foundation
import CoreGraphics
import ImageIO
import SceneKit

extension ArcadeGame {
    func courtyardStoneGeometry(_ stone:OpeningMapDesign.Stone,mat:SCNMaterial)->SCNNode {
        let polygon=stone.outline,n=polygon.count,half=OpeningMapDesign.Stone.half,height=OpeningMapDesign.Stone.thickness/2
        var vertices=[SCNVector3(0,height,0)],normals=[SCNVector3(0,1,0)],uv=[CGPoint(x:0.5,y:0.5)],indices=[Int32]()
        for p in polygon {
            vertices.append(SCNVector3(p.x,height,p.y));normals.append(SCNVector3(0,1,0))
            uv.append(CGPoint(x:(p.x+half)/(2*half),y:(p.y+half)/(2*half)))
        }
        for i in 0..<n {
            // A CCW x/z polygon needs reversed top indices for upward-facing triangles.
            indices += [0,Int32((i+1)%n+1),Int32(i+1)]
            let a=polygon[i],b=polygon[(i+1)%n],edge=(b-a).unit,offset=Int32(vertices.count)
            vertices += [SCNVector3(a.x,-height,a.y),SCNVector3(a.x,height,a.y),SCNVector3(b.x,height,b.y),SCNVector3(b.x,-height,b.y)]
            normals += Array(repeating:SCNVector3(edge.y,0,-edge.x),count:4)
            uv += [CGPoint(x:0,y:0),CGPoint(x:0,y:1),CGPoint(x:1,y:1),CGPoint(x:1,y:0)]
            indices += [offset,offset+1,offset+2,offset,offset+2,offset+3]
        }
        return mesh(vertices,indices,uv:uv,normals:normals,mat:mat)
    }
    /// One cached macro-colour image per opening arena: continuous paths, quiet grain, no animated shader.
    /// Repaint these world-space fields or replace the material later without changing gameplay.
    func openingTerrainMaterial(_ kind:ArenaKind)->SCNMaterial {
        let key=kind == .island ? "opening-island-terrain":"opening-courtyard-terrain"
        if let cached=artMaterials[key] {return cached}
        let file=Bundle.main.resourceURL?.appendingPathComponent("Assets/"+OpeningTerrainSurface.filename(kind))
        let image:CGImage
        if let file,let baked=OpeningTerrainSurface.readBaked(file,kind:kind) {
            image=baked;openingTerrainLoads+=1
        }else {
            image=OpeningTerrainSurface.render(kind,grass:openingTextureImage("ground-olive-v2.png"),earth:openingTextureImage("path-earth-v59.png"));openingTerrainBuilds+=1
        }
        let mat=material(0x69704b);mat.lightingModel = .lambert;mat.diffuse.contents=image
        mat.diffuse.wrapS = .clamp;mat.diffuse.wrapT = .clamp;mat.diffuse.minificationFilter = .linear;mat.diffuse.magnificationFilter = .linear;mat.diffuse.mipFilter = .linear;mat.diffuse.maxAnisotropy=4
        mat.specular.contents=rgb(0);artMaterials[key]=mat;return mat
    }
    func openingPavingMaterial(_ index:Int)->SCNMaterial {
        let key="opening-paver-\(index)"
        if let cached=artMaterials[key] {return cached}
        let mat=openingStoneMaterial("paver-\(index)",tint:[0xe2e1d5,0xd5d8cc,0xe9e5d8,0xcdd2c6,0xdcdfd0][index%5]).copy() as! SCNMaterial
        // Pale limestone keeps the existing grain readable against the courtyard lawn.
        mat.diffuse.intensity=1.25
        mat.diffuse.contentsTransform=SCNMatrix4MakeTranslation(NodeFloat(Double(index%3)*0.17),NodeFloat(Double(index/3)*0.23),0)
        artMaterials[key]=mat;return mat
    }
    func openingTextureImage(_ filename:String)->CGImage? {
        if let image=openingTextureImages[filename] {return image}
        guard let url=Bundle.main.resourceURL?.appendingPathComponent("Assets/"+filename),let source=CGImageSourceCreateWithURL(url as CFURL,nil),let image=CGImageSourceCreateImageAtIndex(source,0,nil) else{return nil}
        openingTextureImages[filename]=image;return image
    }
    func openingStoneMaterial(_ name:String,tint:Int)->SCNMaterial {
        let key="opening-stone-"+name
        if let cached=artMaterials[key] {return cached}
        let mat=material(tint);mat.lightingModel = .lambert;mat.diffuse.contents=openingTextureImage("paving-limestone-v59.png") ?? rgb(tint)
        mat.multiply.contents=rgb(tint);mat.specular.contents=rgb(0)
        mat.diffuse.wrapS = .mirror;mat.diffuse.wrapT = .mirror
        mat.diffuse.minificationFilter = .linear;mat.diffuse.magnificationFilter = .linear;mat.diffuse.mipFilter = .linear;mat.diffuse.maxAnisotropy=4
        artMaterials[key]=mat;return mat
    }
    func openingSandMaterial()->SCNMaterial {
        let key="opening-coastal-sand"
        if let cached=artMaterials[key] {return cached}
        let mat=material(0xe5e1d2);mat.lightingModel = .lambert;mat.diffuse.contents=openingTextureImage("path-earth-v59.png") ?? rgb(0xa79473)
        mat.multiply.contents=rgb(0xe5e1d2);mat.specular.contents=rgb(0)
        mat.diffuse.wrapS = .mirror;mat.diffuse.wrapT = .mirror;mat.diffuse.mipFilter = .linear;mat.diffuse.minificationFilter = .linear;mat.diffuse.maxAnisotropy=4
        artMaterials[key]=mat;return mat
    }
    func openingPier(_ design:OpeningMapDesign.Pier)->SCNNode {
        let root=SCNNode();root.name="opening-pier-\(design.entrance)"
        root.addChildNode(boardwalk(design.center,angle:design.angle,length:design.length))
        let a=design.hinge,b=design.landing,d=(b-a).unit,side=V2(x:-d.y,y:d.x)*(design.width/2)
        let vertices=[SCNVector3(a.x+side.x,design.deckHeight,a.y+side.y),SCNVector3(b.x+side.x,0,b.y+side.y),SCNVector3(b.x-side.x,0,b.y-side.y),SCNVector3(a.x-side.x,design.deckHeight,a.y-side.y)]
        let slope = -design.deckHeight/(b-a).length
        let ramp=mesh(vertices,[0,1,2,0,2,3],uv:[CGPoint(x:0,y:0),CGPoint(x:5,y:0),CGPoint(x:5,y:1),CGPoint(x:0,y:1)],normals:Array(repeating:SCNVector3(-d.x*slope,1,-d.y*slope),count:4),mat:artMaterial("wood-opening-ramp",0x85765a))
        ramp.name="pier-landing-ramp";root.addChildNode(ramp)
        // A short buried tongue crosses the exact terrain seam; a triangle edge is not a walk surface.
        let begin=b-d*0.06,end=b+d*0.12
        let tongue=mesh([SCNVector3(begin.x+side.x,0,begin.y+side.y),SCNVector3(end.x+side.x,0,end.y+side.y),SCNVector3(end.x-side.x,0,end.y-side.y),SCNVector3(begin.x-side.x,0,begin.y-side.y)],[0,1,2,0,2,3],normals:Array(repeating:SCNVector3(0,1,0),count:4),mat:artMaterial("wood-opening-ramp",0x85765a))
        tongue.name="pier-buried-landing-seam";root.addChildNode(tongue)
        return root
    }
}
