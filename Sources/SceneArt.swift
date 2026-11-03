import Foundation
import SceneKit
import CoreGraphics
import ImageIO
#if os(macOS)
import AppKit
#else
import UIKit
#endif

struct ArtRandom {
    var seed:UInt64=72191
    mutating func next()->Double {seed=seed&*6364136223846793005&+1442695040888963407;return Double(seed>>11)/Double(UInt64.max>>11)}
    mutating func range(_ a:Double,_ b:Double)->Double{a+(b-a)*next()}
}

extension ArcadeGame {
    func artMaterial(_ name:String,_ color:Int)->SCNMaterial {
        let personal=name=="cloth-player" || name=="player-vehicle-badge",key=personal ? ownerMaterialKey(name):name
        if key != name,artMaterials[key]==nil,let original=artMaterials[name],let copy=original.copy() as? SCNMaterial {artMaterials[key]=copy}
        if let m=artMaterials[key]{return m}
        let m=material(color);m.lightingModel = .blinn;m.specular.contents=rgb(0x11120e);m.shininess=8
        if key == "ground",let url=Bundle.main.resourceURL?.appendingPathComponent("Assets/ground-olive-v2.png") {
            #if os(macOS)
            m.diffuse.contents=NSImage(contentsOf:url) ?? rgb(color)
            #else
            m.diffuse.contents=UIImage(contentsOfFile:url.path) ?? rgb(color)
            #endif
        } else if key.hasPrefix("stone"),let url=Bundle.main.resourceURL?.appendingPathComponent("Assets/courtyard-stone-v03.png") {
            #if os(macOS)
            m.diffuse.contents=NSImage(contentsOf:url) ?? rgb(color)
            #else
            m.diffuse.contents=UIImage(contentsOfFile:url.path) ?? rgb(color)
            #endif
            let r=min(255,Int(Double((color>>16)&255)*1.4)),g=min(255,Int(Double((color>>8)&255)*1.4)),b=min(255,Int(Double(color&255)*1.4))
            let tone=min(255,Int(Double(r+g+b)/3*1.24))
            m.multiply.contents=rgb((tone<<16)|(tone<<8)|tone)
        } else if key.hasPrefix("cloth"),let texture=characterClothTexture() {
            m.diffuse.contents=texture;m.diffuse.intensity=1.0;m.diffuse.mipFilter = .linear
            m.multiply.contents=rgb(color);m.shininess=3
        } else if key == "sand" || key.hasPrefix("rock") || key.hasPrefix("wood") || key == "bark" || key.hasPrefix("cloth") || key.hasPrefix("stone") || key.hasPrefix("plaster") {
            m.diffuse.contents=detailTexture(kind:key,base:color)
        }
        for property in [m.diffuse,m.normal,m.roughness,m.transparent] {property.minificationFilter = .linear;property.magnificationFilter = .linear;property.mipFilter = .linear;property.maxAnisotropy=4}
        m.diffuse.wrapS = .repeat;m.diffuse.wrapT = .repeat
        artMaterials[key]=m;return m
    }
    func characterClothTexture()->CGImage? {
        if let image=clothTexture {return image}
        guard let url=Bundle.main.resourceURL?.appendingPathComponent("Assets/cloth-canvas-v37.png"),
              let source=CGImageSourceCreateWithURL(url as CFURL,nil),let image=CGImageSourceCreateImageAtIndex(source,0,nil) else{return nil}
        clothTexture=image;return image
    }
    func detailTexture(kind:String,base:Int)->CGImage? {
        let side=512
        let ctx=CGContext(data:nil,width:side,height:side,bitsPerComponent:8,bytesPerRow:side*4,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
        let red=Double((base>>16)&255)/255,green=Double((base>>8)&255)/255,blue=Double(base&255)/255
        var rng=ArtRandom(seed:1219)
        ctx.setFillColor(CGColor(red:red,green:green,blue:blue,alpha:1));ctx.fill(CGRect(x:0,y:0,width:side,height:side))
        for _ in 0..<28000 {
            let gray=rng.next()>0.45 ? 0.95:0.02
            ctx.setFillColor(CGColor(gray:gray,alpha:rng.range(0.025,0.15)))
            let x=rng.range(0,512),y=rng.range(0,512),s=rng.range(0.3,2.2)
            ctx.fillEllipse(in:CGRect(x:x,y:y,width:s,height:s))
        }
        if kind.hasPrefix("wood") || kind == "bark" {
            for _ in 0..<400 {
                let x=rng.range(0,512),y=rng.range(-70,500)
                ctx.setStrokeColor(CGColor(gray:rng.next()>0.3 ? 0.06:0.85,alpha:rng.range(0.05,0.22)))
                ctx.setLineWidth(rng.range(0.3,1.8));ctx.move(to:CGPoint(x:x,y:y))
                ctx.addCurve(to:CGPoint(x:x+rng.range(-5,5),y:y+rng.range(15,230)),control1:CGPoint(x:x+4,y:y+15),control2:CGPoint(x:x-3,y:y+65));ctx.strokePath()
            }
        }
        if kind.hasPrefix("wood-boat-painted72") {
            // Broad, static paint loss, baked once with the existing wood grain. No animated noise.
            for _ in 0..<145 {
                let x=rng.range(0,512),y=rng.range(0,512)
                ctx.setFillColor(CGColor(red:0.25,green:0.24,blue:0.18,alpha:rng.range(0.14,0.40)))
                ctx.fill(CGRect(x:x,y:y,width:rng.range(1,4),height:rng.range(3,20)))
            }
        }
        if kind.hasPrefix("cloth") {
            for _ in 0..<150 {ctx.setFillColor(CGColor(gray:rng.next()>0.5 ? 0.03:0.6,alpha:0.18));ctx.fillEllipse(in:CGRect(x:rng.range(0,512),y:rng.range(0,512),width:rng.range(8,50),height:rng.range(5,25)))}
        }
        return ctx.makeImage()
    }
    func mesh(_ vertices:[SCNVector3],_ indices:[Int32],uv:[CGPoint]?=nil,normals:[SCNVector3]?=nil,secondaryUV:[CGPoint]?=nil,mat:SCNMaterial)->SCNNode {
        var sources=[SCNGeometrySource(vertices:vertices)]
        if let uv {sources.append(SCNGeometrySource(textureCoordinates:uv))}
        if let normals {sources.append(SCNGeometrySource(normals:normals))}
        if let secondaryUV {sources.append(SCNGeometrySource(textureCoordinates:secondaryUV))}
        let geo=SCNGeometry(sources:sources,elements:[SCNGeometryElement(indices:indices,primitiveType:.triangles)]);geo.materials=[mat]
        return SCNNode(geometry:geo)
    }
    func detailedIslandLayer(scale:Double,height:Double,mat sourceMaterial:SCNMaterial,grain:Double)->SCNNode {
        let mat=sourceMaterial.copy() as! SCNMaterial
        let segments=128,rings=18
        var vertices=[SCNVector3(0,height,0)],coords=[scale<1.1 ? CGPoint(x:0.5,y:0.5):CGPoint.zero],normals=[SCNVector3(0,1,0)]
        var colours:[Float]=[1,1,1,1]
        for ring in 1...rings {
            let fraction=Double(ring)/Double(rings)
            for i in 0..<segments {
                let a=Double(i)*Double.pi*2/Double(segments)
                let bank=OpeningMapDesign.coastalBank(angle:a,fraction:fraction),sand=scale>1.1
                let p=IslandLayout.edge(angle:a,scale:scale*fraction*(sand ? bank.radius:1))
                vertices.append(SCNVector3(p.x,sand ? bank.height:height,p.y));coords.append(scale<1.1 ? CGPoint(x:p.x/(IslandLayout.width*scale*2)+0.5,y:p.y/(IslandLayout.depth*scale*2)+0.5):CGPoint(x:p.x/grain,y:p.y/grain));normals.append(SCNVector3(0,1,0))
                let wet=sand ? bank.wetness:0
                colours += [Float(1-0.40*wet),Float(1-0.32*wet),Float(1-0.27*wet),1]
            }
        }
        var maskUVs:[CGPoint]?=nil
        if scale<1.1 {
            maskUVs=vertices.map{CGPoint(x:Double($0.x)/(IslandLayout.width*scale*2)+0.5,y:Double($0.z)/(IslandLayout.depth*scale*2)+0.5)}
            mat.transparent.contents=shoreMask();mat.transparent.mappingChannel=1
            mat.transparencyMode = .aOne;mat.writesToDepthBuffer=false;mat.blendMode = .alpha
            mat.transparent.minificationFilter = .linear;mat.transparent.mipFilter = .linear
        }
        var indices:[Int32]=[]
        for i in 0..<segments {indices += [0,Int32(1+(i+1)%segments),Int32(1+i)]}
        for ring in 1..<rings {
            let inner=1+(ring-1)*segments,outer=1+ring*segments
            for i in 0..<segments {let j=(i+1)%segments;indices += [Int32(inner+i),Int32(inner+j),Int32(outer+i),Int32(inner+j),Int32(outer+j),Int32(outer+i)]}
        }
        let layer=mesh(vertices,indices,uv:coords,normals:normals,secondaryUV:maskUVs,mat:mat)
        if scale>1.1 {
            let data=colours.withUnsafeBytes{Data($0)}
            let colourSource=SCNGeometrySource(data:data,semantic:.color,vectorCount:vertices.count,usesFloatComponents:true,componentsPerVector:4,bytesPerComponent:MemoryLayout<Float>.size,dataOffset:0,dataStride:MemoryLayout<Float>.size*4)
            layer.geometry=SCNGeometry(sources:layer.geometry!.sources+[colourSource],elements:layer.geometry!.elements)
            layer.geometry!.materials=[mat]
        }
        layer.name=scale<1.1 ? "island-grass-surface":"island-sand-surface"
        layer.renderingOrder=scale<1.1 ? 2:1
        layer.castsShadow=false;return layer
    }
    func jaggedRock(seed:UInt64,radius:Double)->SCNNode {
        var rng=ArtRandom(seed:seed)
        let rows=7,cols=11
        var v:[SCNVector3]=[],uv:[CGPoint]=[],norm:[SCNVector3]=[]
        for row in 0...rows {
            let phi=Double(row)/Double(rows)*Double.pi
            for col in 0...cols {
                let a=Double(col)/Double(cols)*2*Double.pi,rough=rng.range(0.82,1.14)
                let x=sin(phi)*cos(a)*rough,y=cos(phi)*rough,z=sin(phi)*sin(a)*rough
                v.append(SCNVector3(x*radius,y*radius*0.72,z*radius*0.82));uv.append(CGPoint(x:Double(col)/Double(cols),y:Double(row)/Double(rows)));norm.append(SCNVector3(x,y/0.72,z/0.82))
            }
        }
        var ind:[Int32]=[]
        for row in 0..<rows {for col in 0..<cols {let a=Int32(row*(cols+1)+col),b=a+Int32(cols+1);ind += [a,a+1,b,a+1,b+1,b]}}
        let n=mesh(v,ind,uv:uv,normals:norm,mat:artMaterial("rock",0x69665b));n.eulerAngles.y=NodeFloat(rng.range(0,6));return n
    }
    func beam(_ a:SCNVector3,_ b:SCNVector3,radius:CGFloat,mat:SCNMaterial)->SCNNode {
        let dx=Double(b.x-a.x),dy=Double(b.y-a.y),dz=Double(b.z-a.z),length=sqrt(dx*dx+dy*dy+dz*dz)
        let g=SCNCylinder(radius:radius,height:CGFloat(length));g.radialSegmentCount=8;g.materials=[mat]
        let n=SCNNode(geometry:g);n.position=SCNVector3((Double(a.x)+Double(b.x))/2,(Double(a.y)+Double(b.y))/2,(Double(a.z)+Double(b.z))/2)
        n.look(at:b,up:SCNVector3(0,0,1),localFront:SCNVector3(0,1,0));return n
    }
    func palm(seed:UInt64,height:Double)->SCNNode {
        let tree=SCNNode(),trunkParts=SCNNode();var rng=ArtRandom(seed:seed)
        let bend=rng.range(-0.65,0.65),lean=rng.range(-0.3,0.5)
        func trunk(_ f:Double)->SCNVector3 {SCNVector3(bend*f*f,height*f,lean*f*f)}
        for i in 0..<12 {
            let f=Double(i)/12
            trunkParts.addChildNode(beam(trunk(f),trunk(f+1.0/12),radius:CGFloat(0.13-f*0.045),mat:artMaterial("bark",0x766247)))
            let band=cylinder(CGFloat(0.137-f*0.047),0.023,0x443e2e);band.position=trunk(f);trunkParts.addChildNode(band)
        }
        tree.addChildNode(trunkParts.flattenedClone())
        let top=trunk(1)
        if let canopy=texturedPalmCrown(at:top) {tree.addChildNode(canopy);return tree}
        var vertices:[SCNVector3]=[],indices:[Int32]=[],normals:[SCNVector3]=[]
        for frond in 0..<11 {
            let angle=Double(frond)*Double.pi*2/11+rng.range(-0.14,0.14),length=rng.range(2.5,3.7),lift=rng.range(0.2,0.9)
            func center(_ t:Double)->V2 {V2(x:lift*sin(t*Double.pi*0.85)-1.15*t*t,y:length*t)}
            func vertex(_ x:Double,_ y:Double,_ z:Double)->SCNVector3 {
                SCNVector3(Double(top.x)+x*cos(angle)+z*sin(angle),Double(top.y)+y,Double(top.z)-x*sin(angle)+z*cos(angle))
            }
            for i in 1..<25 {
                let t=Double(i)/25,p=center(t),spread=0.65*sin(Double.pi*t)*pow(1-t,0.25)+0.04
                for side in [-1.0,1.0] {
                    let base=Int32(vertices.count)
                    vertices += [vertex(0,p.x,p.y),vertex(side*spread,p.x-0.14-spread*0.20,p.y-0.22),vertex(0,p.x-0.012,p.y+0.12)]
                    indices += side>0 ? [base,base+2,base+1]:[base,base+1,base+2]
                    normals += [SCNVector3(0,1,0),SCNVector3(0,1,0),SCNVector3(0,1,0)]
                }
            }
        }
        let leafMat=artMaterial("palm-crown",0x4b5a34);leafMat.isDoubleSided=true;leafMat.cullMode = .back
        tree.addChildNode(mesh(vertices,indices,normals:normals,mat:leafMat))
        for i in 0..<4 {let fruit=ball(0.11,0x62523b);fruit.position=SCNVector3(Double(top.x)+cos(Double(i)*1.6)*0.15,Double(top.y)-0.16,Double(top.z)+sin(Double(i)*1.6)*0.15);tree.addChildNode(fruit)}
        return tree
    }
    func boardwalk(_ at:V2,angle:Double,length:Double=5.0)->SCNNode {
        let pier=SCNNode();pier.position=SCNVector3(at.x,0.17,at.y);pier.eulerAngles.y=NodeFloat(angle)
        var rng=ArtRandom(seed:982)
        let underlay=box(CGFloat(length),0.10,2.05,0x71634e);underlay.position.y = -0.025;underlay.geometry?.materials=[artMaterial("wood-opening-underlay",0x71634e)];pier.addChildNode(underlay)
        let wood=artMaterial("wood",0x82765e)
        let count=Int(length/0.27)
        for i in 0..<count {
            let plank=box(0.24,0.10,2.05,0x82765e);plank.geometry?.materials=[wood]
            plank.position=SCNVector3(Double(i)*0.27-length/2+0.135,0,0);plank.eulerAngles.y=NodeFloat(rng.range(-0.02,0.02));pier.addChildNode(plank)
            for side in [-0.8,0.8] {
                let g=SCNBox(width:0.032,height:0.006,length:0.032,chamferRadius:0)
                let nailMaterial=artMaterial("pier-nail72",0x393b34);nailMaterial.name="pier-nail72";g.materials=[nailMaterial]
                let nail=SCNNode(geometry:g);nail.position=SCNVector3(Double(plank.position.x),0.054,side);nail.castsShadow=false;pier.addChildNode(nail)
            }
        }
        for side in [-1.02,1.02] {
            for x in [-length/2+0.2,0,length/2-0.2] {
                let post=box(0.12,1.45,0.12,0x6e624a);post.geometry?.materials=[wood];post.position=SCNVector3(x,0.23,side);pier.addChildNode(post)
            }
            let rail=box(CGFloat(length),0.08,0.08,0x6e624a);rail.geometry?.materials=[wood];rail.position=SCNVector3(0,0.9,side);pier.addChildNode(rail)
            let rail2=box(CGFloat(length),0.045,0.045,0x6e624a);rail2.geometry?.materials=[wood];rail2.position=SCNVector3(0,0.42,side);pier.addChildNode(rail2)
        }
        let bounds=pier.boundingBox,merged=pier.flattenedClone();merged.boundingBox=bounds;return merged
    }
    func beachHut()->SCNNode {
        let hut=SCNNode(),wood=artMaterial("wood",0x74664e)
        for x in [-1.5,1.5] {for z in [-1.5,1.5] {let post=box(0.17,2.8,0.17,0x625843);post.position=SCNVector3(x,1.1,z);post.geometry?.materials=[wood];hut.addChildNode(post)}}
        for i in 0..<12 {
            let plank=box(0.245,1.8,0.13,0x625843);plank.position=SCNVector3(Double(i)*0.26-1.45,0.85,-1.5);plank.geometry?.materials=[wood];hut.addChildNode(plank)
            let roof=box(0.3,0.085,3.75,i%2==0 ? 0x625b47:0x706752);roof.position=SCNVector3(Double(i)*0.30-1.65,2.6,0);roof.eulerAngles.z=0.08;hut.addChildNode(roof)
        }
        let floor=box(3.4,0.15,3.4,0x746650);floor.geometry?.materials=[wood];floor.position.y=0.1;hut.addChildNode(floor)
        return hut.flattenedClone()
    }
    func buildDetailedIsland() {
        let seaGeometry=SCNPlane(width:240,height:240)
        let seaMat=material(0x476e78);seaMat.lightingModel = .blinn;seaMat.specular.contents=rgb(0x7a9394);seaMat.shininess=45
        seaMat.normal.contents=waterNormals();seaMat.normal.wrapS = .repeat;seaMat.normal.wrapT = .repeat
        seaMat.normal.contentsTransform=waterNormalTransform(now:0);artMaterials["water"]=seaMat
        seaGeometry.materials=[seaMat];let sea=SCNNode(geometry:seaGeometry);sea.eulerAngles.x = -NodeFloat.pi/2;sea.position.y = -0.24;decor.addChildNode(sea)
        decor.addChildNode(detailedIslandLayer(scale:1.19,height:0.005,mat:openingSandMaterial(),grain:2.4))
        decor.addChildNode(detailedIslandLayer(scale:1.025,height:0.055,mat:openingTerrainMaterial(.island),grain:5.2))
        var rng=ArtRandom(seed:68291)
        // Broken coastline clusters replace the evenly spaced ring of stones.
        for (cluster,angle) in [(-0.8,0.18),(0.5,0.18),(2.7,0.2),(4.1,0.15)] {
            for i in 0..<10 {
                let a=cluster+rng.range(-angle,angle),p=IslandLayout.edge(angle:a,scale:rng.range(1.17,1.27))
                let rock=jaggedRock(seed:UInt64(i)+UInt64(abs(cluster)*100),radius:rng.range(0.5,1.4));rock.geometry?.materials=[openingStoneMaterial("coast-\(i%3)",tint:[0x77776c,0x7d7c70,0x707368][i%3])];rock.position=SCNVector3(p.x,-0.05,p.y);decor.addChildNode(rock)
            }
        }
        let hut=beachHut();hut.name="opening-island-hut";hut.position=SCNVector3(OpeningMapDesign.hut.x,0,OpeningMapDesign.hut.y);hut.eulerAngles.y = -0.16;decor.addChildNode(hut)
        for (i,pos) in [V2(x:-10.8,y:-5.8),V2(x:9.0,y:-6.8),V2(x:-12.1,y:3.3),V2(x:11.8,y:5.9)].enumerated() {
            let n=palm(seed:UInt64(200+i*51),height:i==1 ? 4.8:4.0);n.position=SCNVector3(pos.x,0,pos.y);decor.addChildNode(n)
        }
        for design in OpeningMapDesign.piers {decor.addChildNode(openingPier(design))}
        let boat=abandonedBoat();boat.name="opening-island-boat";boat.position=SCNVector3(OpeningMapDesign.boat.p.x,0.08,OpeningMapDesign.boat.p.y);boat.eulerAngles.y=NodeFloat(OpeningMapDesign.boat.angle);decor.addChildNode(boat)
        for (x,z) in [(8.4,-5.6),(9.2,-5.4)] {let crate=box(0.8,0.8,0.8,0x6b6048);crate.geometry?.materials=[artMaterial("wood",0x82765e)];crate.position=SCNVector3(x+1.6,0.45,z-2.0);crate.eulerAngles.y=0.22;decor.addChildNode(crate)
            for h in [0.18,0.67] {let strap=box(0.84,0.06,0.84,0x373e37);strap.position.y=NodeFloat(h-0.4);crate.addChildNode(strap)}}
        // Sparse upright blades soften the border while preserving the open combat area.
        var blades:[SCNVector3]=[],ind:[Int32]=[],norm:[SCNVector3]=[]
        for _ in 0..<700 {
            let a=rng.range(0,Double.pi*2),p=IslandLayout.edge(angle:a,scale:rng.range(0.91,1.025))
            let h=rng.range(0.09,0.27),w=rng.range(0.03,0.06),base=Int32(blades.count)
            blades += [SCNVector3(p.x-w,0.09,p.y),SCNVector3(p.x+w,0.09,p.y),SCNVector3(p.x+rng.range(-0.07,0.07),h,p.y+0.035)]
            ind += [base,base+1,base+2];norm += [SCNVector3(0,1,0),SCNVector3(0,1,0),SCNVector3(0,1,0)]
        }
        let grass=artMaterial("grass-blades",0x626348);grass.isDoubleSided=true
        let edgeGrass=mesh(blades,ind,normals:norm,mat:grass);edgeGrass.name="shoreline-grass";edgeGrass.castsShadow=false;decor.addChildNode(edgeGrass)
    }
    /// Four immutable appearances cover all current bullets; position/opacity belong to each shot.
    func projectileNode(_ kind:PickupKind?)->SCNNode {
        let key=kind == .grenade ? 3:kind == .rocket ? 2:kind == .ray ? 1:0
        if let geometry=projectileGeometries[key] {return SCNNode(geometry:geometry)}
        let node=kind == .grenade ? ball(0.10,0xd7b868):box(0.050,0.050,kind == .rocket ? 0.5:0.8,kind == .ray ? 0x91ff55:0xffdf94)
        node.geometry!.firstMaterial!.emission.contents=rgb(kind == .ray ? 0x91ff55:0xffc565)
        projectileGeometries[key]=node.geometry!
        return node
    }
    func detailedCharacter(player:Bool,variant:Int=0,prisoner:Bool=false)->SCNNode {
        if player {return humanCharacter(player:true,variant:variant,prisoner:prisoner)}
        let key=variant%3+(prisoner ? 3:0)
        if let template=enemyCharacterTemplates[key],let skin=enemySkinGeometries[key] {
            let model=template.clone();skin.install(on:model,replacingRigidBody:false);return model
        }
        let template=humanCharacter(player:false,variant:variant,prisoner:prisoner)
        let skin=EnemySkinGeometry(model:template)
        skin.install(on:template)
        enemyCharacterTemplates[key]=template;enemySkinGeometries[key]=skin
        let model=template.clone();skin.install(on:model,replacingRigidBody:false);return model
    }
    func prepareEnemySkinTemplates(){
        // Finish lazy SceneKit geometry before rendering starts, never during a spawn callback.
        for prisoner in [false,true] {for variant in 0..<3 {
            _=detailedCharacter(player:false,variant:variant,prisoner:prisoner)
        }}
    }
    func rebindEnemySkin(on model:SCNNode){
        guard let geometry=model.childNode(withName:"human-skinned-mesh",recursively:false)?.geometry,
              let skin=enemySkinGeometries.values.first(where:{$0.geometry === geometry}) else{return}
        // Fallen figures keep their own posed joints; engineer/burn attachments remain present.
        skin.install(on:model,replacingRigidBody:false)
    }

}

extension ArcadeGame {
    func detailedPickup(_ kind:PickupKind,loot:LootAppearance?=nil,gemUnits:Int?=nil)->SCNNode {
        let root=SCNNode(),icon=SCNNode();icon.name="pickup-icon";root.addChildNode(icon)
        switch kind {
        case .treasure:
            icon.addChildNode(treasureModel(loot ?? .treasure(index:2)))
        case .gem:
            icon.addChildNode(treasureModel(loot ?? .gem(.blue,.medium),gemUnits:gemUnits))
        case .life,.bomb,.dash,.boots,.orb,.chicken:
            icon.addChildNode(utilityPickupModel(kind))
        case .spread,.ray,.rocket,.deathMachine,.grenade,.flamethrower:
            icon.addChildNode(pickupWeaponModel(kind))
        case .teddy:
            let model=teddyModel();model.scale=SCNVector3(0.58,0.58,0.58);icon.addChildNode(model)
        case .monkey:
            let model=monkeyModel();model.scale=SCNVector3(0.70,0.70,0.70);icon.addChildNode(model)
        case .turret:
            let model=sentryModel();model.scale=SCNVector3(0.46,0.46,0.46);icon.addChildNode(model)
        case .barrelShield:
            for x in [-0.14,0.14] {let model=shieldBarrelModel();model.scale=SCNVector3(0.40,0.40,0.40);model.position.x=NodeFloat(x);icon.addChildNode(model)}
        case .tank,.helicopter:
            let model=kind == .tank ? tankModel():helicopterModel();model.scale=SCNVector3(0.27,0.27,0.27);model.eulerAngles.y = -0.5;icon.addChildNode(model)
        }
        // Keep equipment bodies readable at the supported960x540minimum window.
        // Currency retains its density;collection radii and the floor halo stay unchanged.
        let iconSize=kind == .treasure || kind == .gem ? 1.3:1.6
        icon.scale=SCNVector3(iconSize,iconSize,iconSize);icon.position.y=kind == .treasure ? 0.08:kind == .gem ? 0.18:0.28;icon.eulerAngles.y = -0.3
        if kind != .treasure {
            let tint=kind == .gem ? (loot?.gemColor?.tint ?? 0x80c9ff):PickupPresentation.forKind(kind).tint
            if kind != .gem {root.addChildNode(pickupClassMarker(kind))}
            let key="pickup-halo-\(tint)"
            let mat:SCNMaterial
            if let cached=artMaterials[key]{mat=cached}else{
                mat=SCNMaterial();mat.lightingModel = .constant;mat.isDoubleSided=true;mat.writesToDepthBuffer=false
                let ctx=CGContext(data:nil,width:64,height:64,bitsPerComponent:8,bytesPerRow:256,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
                let red=CGFloat((tint>>16)&255)/255,green=CGFloat((tint>>8)&255)/255,blue=CGFloat(tint&255)/255
                let colors=[CGColor(red:red,green:green,blue:blue,alpha:0.62),CGColor(red:red,green:green,blue:blue,alpha:0)] as CFArray
                let gradient=CGGradient(colorsSpace:CGColorSpaceCreateDeviceRGB(),colors:colors,locations:[0,1])!
                ctx.drawRadialGradient(gradient,startCenter:CGPoint(x:32,y:32),startRadius:2,endCenter:CGPoint(x:32,y:32),endRadius:31,options:[])
                mat.diffuse.contents=ctx.makeImage();artMaterials[key]=mat
            }
            let g=SCNPlane(width:1.3,height:1.3);g.materials=[mat];let glow=SCNNode(geometry:g);glow.eulerAngles.x = -NodeFloat.pi/2;glow.position.y=0.065;glow.castsShadow=false;glow.renderingOrder=19;root.addChildNode(glow)
        }
        return root
    }
}

extension ArcadeGame {
    /// Same world-space wave size as the former75x55plane;the larger plane
    /// fills the whole-map camera without adding vertices or a second water layer.
    func waterNormalTransform(now:Double)->SCNMatrix4 {
        SCNMatrix4Mult(SCNMatrix4MakeScale(7.0*240/75,7.0*240/55,1),
            SCNMatrix4MakeTranslation(NodeFloat((now*0.003).truncatingRemainder(dividingBy:1)),NodeFloat((now*0.0015).truncatingRemainder(dividingBy:1)),0))
    }
    func waterNormals()->CGImage? {
        let side=256;var bytes=[UInt8](repeating:255,count:side*side*4)
        for y in 0..<side {for x in 0..<side {
            let a=Double(x)*Double.pi*2/Double(side),b=Double(y)*Double.pi*2/Double(side)
            let nx=0.13*sin(b*12+a*3)+0.025*cos(b*25-a*7),ny=0.06*cos(a*7-b*3)+0.04*sin(a*15+b*18)
            let i=(y*side+x)*4;bytes[i]=UInt8((0.5+nx)*255);bytes[i+1]=UInt8((0.5+ny)*255);bytes[i+2]=250
        }}
        let data=Data(bytes) as CFData
        return CGImage(width:side,height:side,bitsPerComponent:8,bitsPerPixel:32,bytesPerRow:side*4,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGBitmapInfo(rawValue:CGImageAlphaInfo.premultipliedLast.rawValue),provider:CGDataProvider(data:data)!,decode:nil,shouldInterpolate:true,intent:.defaultIntent)
    }
}

extension ArcadeGame {
    func texturedPalmCrown(at top:SCNVector3)->SCNNode? {
        guard let image=foliageImage("palm-crown-v2.png") else{return nil}
        let key="textured-palm-crown"
        let mat:SCNMaterial
        if let cached=artMaterials[key]{mat=cached}else{
            mat=SCNMaterial();mat.diffuse.contents=image;mat.isDoubleSided=true
            mat.lightingModel = .lambert;mat.transparencyMode = .aOne;mat.transparent.contents=image;mat.writesToDepthBuffer=true
            mat.diffuse.minificationFilter = .linear;mat.diffuse.magnificationFilter = .linear
            mat.diffuse.mipFilter = .linear;mat.diffuse.maxAnisotropy=4
            mat.name="foliage-cutout";mat.blendMode = .replace
            configureFoliageCutout(mat,image:image)
            artMaterials[key]=mat
        }
        let count=12,size=6.9
        var verts:[SCNVector3]=[],norm:[SCNVector3]=[],uv:[CGPoint]=[],indices:[Int32]=[]
        for row in 0...count {for col in 0...count {
            let u=Double(col)/Double(count),v=Double(row)/Double(count),x=(u-0.5)*size,z=(v-0.5)*size
            let drop=min(1,(x*x+z*z)/12)*0.75
            verts.append(SCNVector3(Double(top.x)+x,Double(top.y)+0.10-drop,Double(top.z)+z))
            norm.append(SCNVector3(x*0.08,1,z*0.08));uv.append(CGPoint(x:u,y:v))
        }}
        for row in 0..<count {for col in 0..<count {let a=Int32(row*(count+1)+col),b=a+Int32(count+1);indices += [a,b,a+1,a+1,b,b+1]}}
        let canopy=mesh(verts,indices,uv:uv,normals:norm,mat:mat)
        canopy.name="palm-leaf-canopy";canopy.castsShadow=false
        return canopy
    }
}

extension ArcadeGame {
    func shoreMask()->CGImage? {
        let side=512;var bytes=[UInt8](repeating:255,count:side*side*4)
        for y in 0..<side {for x in 0..<side {
            let u=abs(Double(x)/Double(side-1)*2-1),v=abs(Double(y)/Double(side-1)*2-1)
            let radius=pow(pow(u,IslandLayout.exponent)+pow(v,IslandLayout.exponent),1/IslandLayout.exponent)
            let ragged=sin(Double(x)*0.21)*cos(Double(y)*0.16)*0.010
            let alpha=min(1,max(0,(1-radius+ragged)/0.12))
            bytes[(y*side+x)*4+3]=UInt8(alpha*255)
        }}
        return CGImage(width:side,height:side,bitsPerComponent:8,bitsPerPixel:32,bytesPerRow:side*4,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGBitmapInfo(rawValue:CGImageAlphaInfo.last.rawValue),provider:CGDataProvider(data:Data(bytes) as CFData)!,decode:nil,shouldInterpolate:true,intent:.defaultIntent)
    }
}
