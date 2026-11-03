import Foundation
import SceneKit
import CoreGraphics

extension ArcadeGame {
    func rebuildArena() {
        for n in decor.childNodes {n.removeFromParentNode()}
        fateDoorNodes=[:];fateDropNodes=[:];fateBootNodes=[:];fateLifeNodes=[:]
        trapNodes=[];rainNodes=[];forestSnowNodes=[];decor.eulerAngles=SCNVector3Zero
        artMaterials.removeValue(forKey:"water")
        builtArena=core.layout.kind;builtRevision=core.environmentRevision
        for n in corpseNodes {n.removeFromParentNode()};corpseNodes=[]
        switch core.layout.kind {case .island:buildDetailedIsland();case .courtyard:buildCourtyard();case .prison:buildPrison();case .cave:buildCave();case .marketplace:buildMarketplace();case .urban:buildUrban();case .street:buildStreet();case .facility:buildFacility();case .forest:buildForest();case .jungle:buildJungle()}
        buildEnemyEntranceArt()
        buildSideRoomDetails()
        let ring=SCNTorus(ringRadius:0.67,pipeRadius:0.035);ring.materials=[material(0x81bfda,glow:true)]
        exit.geometry=ring;exit.position=SCNVector3(core.layout.exit.x,core.layout.height(core.layout.exit)+0.14,core.layout.exit.y)
        exit.isHidden=true
        if exit.parent==nil {scene.rootNode.addChildNode(exit)}
    }
    func stoneBlock(_ x:Double,_ y:Double,_ z:Double,_ color:Int)->SCNNode {
        let n=box(CGFloat(x),CGFloat(y),CGFloat(z),color)
        n.geometry?.materials=[artMaterial((max(x,z)>3 || y>1.5 ? "plaster-":"stone-")+String(color),color)];return n
    }
    func openingWallBlock(_ x:Double,_ y:Double,_ z:Double,_ color:Int)->SCNNode {
        let n=box(CGFloat(x),CGFloat(y),CGFloat(z),color)
        let mat=openingStoneMaterial("wall-\(color)-\(x)-\(y)-\(z)",tint:color)
        mat.diffuse.contentsTransform=SCNMatrix4MakeScale(NodeFloat(max(x,z)/2.5),NodeFloat(max(0.25,y)/2.5),1)
        n.geometry?.materials=[mat];return n
    }
    func ruinedCourtyardWall(_ design:OpeningMapDesign.RuinedWall)->SCNNode {
        let plaster=artMaterial("plaster-courtyard73",0xb1ac96),stone=openingStoneMaterial("ruin73",tint:0xa3a18f)
        plaster.lightingModel = .lambert;plaster.specular.contents=rgb(0)
        var v=[SCNVector3](),norm=[SCNVector3](),uv=[CGPoint](),faces=[Int32](),masonry=[Int32]()
        func quad(_ a:SCNVector3,_ b:SCNVector3,_ c:SCNVector3,_ d:SCNVector3,_ normal:SCNVector3,_ exposed:Bool){
            let i=Int32(v.count);v += [a,b,c,d];norm+=Array(repeating:normal,count:4)
            for p in [a,b,c,d] {uv.append(CGPoint(x:Double(p.x+p.z)/2,y:Double(p.y)/2))}
            let indices=[i,i+1,i+2,i,i+2,i+3]
            if exposed {masonry+=indices}else{faces+=indices}
        }
        let top=design.top,d=design.depth/2,base=design.base,joint=base+design.height*0.25
        for i in 1..<top.count {
            let a=top[i-1],b=top[i],dx=b.x-a.x,dy=b.y-a.y,n=sqrt(dx*dx+dy*dy)
            for side in [-1.0,1.0] {
                let z=side*d,normal=SCNVector3(0,0,side)
                let lower=[SCNVector3(a.x,base,z),SCNVector3(b.x,base,z),SCNVector3(b.x,joint,z),SCNVector3(a.x,joint,z)]
                let upper=[SCNVector3(a.x,joint,z),SCNVector3(b.x,joint,z),SCNVector3(b.x,b.y,z),SCNVector3(a.x,a.y,z)]
                for (row,exposed) in [(lower,true),(upper,false)] {
                    if side>0 {quad(row[0],row[1],row[2],row[3],normal,exposed)}
                    else{quad(row[1],row[0],row[3],row[2],normal,exposed)}
                }
            }
            quad(SCNVector3(a.x,a.y,-d),SCNVector3(a.x,a.y,d),SCNVector3(b.x,b.y,d),SCNVector3(b.x,b.y,-d),SCNVector3(-dy/n,dx/n,0),true)
        }
        let first=top.first!,last=top.last!
        quad(SCNVector3(first.x,base,-d),SCNVector3(first.x,base,d),SCNVector3(first.x,first.y,d),SCNVector3(first.x,first.y,-d),SCNVector3(-1,0,0),true)
        quad(SCNVector3(last.x,base,d),SCNVector3(last.x,base,-d),SCNVector3(last.x,last.y,-d),SCNVector3(last.x,last.y,d),SCNVector3(1,0,0),true)
        let g=SCNGeometry(sources:[SCNGeometrySource(vertices:v),SCNGeometrySource(normals:norm),SCNGeometrySource(textureCoordinates:uv)],elements:[SCNGeometryElement(indices:faces,primitiveType:.triangles),SCNGeometryElement(indices:masonry,primitiveType:.triangles)])
        g.materials=[plaster,stone];return SCNNode(geometry:g)
    }
    func courtyardDoorLeaf()->SCNNode {
        let root=SCNNode(),wood=artMaterial("wood-courtyard-door73",0x665348),iron=material(0x41433a)
        func part(_ x:Double,_ y:Double,_ z:Double,_ p:SCNVector3,_ mat:SCNMaterial){
            let g=SCNBox(width:x,height:y,length:z,chamferRadius:0);g.materials=[mat]
            let n=SCNNode(geometry:g);n.position=p;root.addChildNode(n)
        }
        part(1.6,2.5,0.09,SCNVector3Zero,wood)
        for x in [-0.735,0.735] {part(0.13,2.5,0.15,SCNVector3(x,0,0),wood)}
        for y in [-1.18,0,1.18] {part(1.6,0.14,0.15,SCNVector3(0,y,0),wood)}
        for side in [-1.0,1.0] {
            for y in [-0.59,0.59] {part(1.2,0.98,0.015,SCNVector3(0,y,side*0.0525),wood)}
            for y in [-0.78,0.78] {part(1.36,0.06,0.012,SCNVector3(0,y,side*0.069),iron)}
        }
        return root.flattenedClone()
    }
    func buildCourtyard() {
        var rng=ArtRandom(seed:17067)
        let key="opening-courtyard-continuous80",groundMaterial:SCNMaterial
        if let cached=artMaterials[key] {groundMaterial=cached}
        else {
            let earth:Any=openingTextureImage("path-earth-v59.png") ?? rgb(0x9a977d)
            groundMaterial=CourtyardSurface.material(macro:openingTerrainMaterial(.courtyard),earth:earth)
            artMaterials[key]=groundMaterial
        }
        let floor=SCNNode(geometry:CourtyardSurface.geometry(material:groundMaterial))
        floor.name="opening-courtyard-ground";floor.castsShadow=false;decor.addChildNode(floor)
        let paving=SCNNode();paving.name="opening-courtyard-paving"
        // Cross, perimeter walk and fountain apron use one quiet set of batched stone materials.
        for ix in -20...20 {for iz in -13...13 {
            let p=V2(x:Double(ix)*OpeningMapDesign.Stone.spacing,y:Double(iz)*OpeningMapDesign.Stone.spacing)
            guard OpeningMapDesign.isCourtyardPath(p),p.length>1.58 else{continue}
            // Consume the same material draw even for an absent edge stone, preserving other art RNG.
            let mat=openingPavingMaterial(Int(rng.next()*5)),stone=OpeningMapDesign.courtyardStone(ix:ix,iz:iz)
            guard !stone.missing else{continue}
            let tile=courtyardStoneGeometry(stone,mat:mat)
            tile.position=SCNVector3(p.x,0.0025,p.y);paving.addChildNode(tile)
        }}
        // Low rubble stays beside the ruined perimeter; it does not imply a new solid barrier.
        for i in 0..<32 {
            let x=rng.range(-10.4,10.4),z=rng.range(-6.5,6.5)
            guard abs(x)>2.6,abs(z)>2.2,(abs(x)>8.5 || abs(z)>5.4) else{continue}
            let debris=SCNNode(geometry:SCNBox(width:rng.range(0.10,0.23),height:0.025,length:rng.range(0.10,0.22),chamferRadius:0.003))
            debris.geometry?.materials=[openingPavingMaterial(i%5)];debris.position=SCNVector3(x,0.0125,z);debris.eulerAngles.y=NodeFloat(rng.range(0,6));paving.addChildNode(debris)
        }
        let mergedPaving=paving.flattenedClone();mergedPaving.name=paving.name;decor.addChildNode(mergedPaving)
        let walls=SCNNode();walls.name="opening-courtyard-walls"
        // Broken plaster and exposed stone replace the regular fortress posts.
        // All new sections fit the old footprints and keep the four central mouths open.
        for sx in [-1.0,1] {
            for sz in [-1.0,1.0] {
                let wall=ruinedCourtyardWall(.init(length:6.3,depth:0.45,height:1.6,base:-0.15,seed:UInt64((sx<0 ? 10:20)+(sz<0 ? 1:2))))
                wall.position=SCNVector3(sx*12.05,0,sz*4.85);wall.eulerAngles.y=NodeFloat.pi/2;walls.addChildNode(wall)
            }
        }
        for sx in [-1.0,1] {
            let seed:UInt64=sx<0 ? 31:47
            let rear=ruinedCourtyardWall(.init(length:10.1,depth:0.55,height:2.2,base:-0.25,seed:seed));rear.position=SCNVector3(sx*7,0,-8.05);walls.addChildNode(rear)
            let front=ruinedCourtyardWall(.init(length:9.7,depth:0.6,height:0.5,base:-0.08,seed:seed+1));front.position=SCNVector3(sx*7,0,8.05);walls.addChildNode(front)
            let center=OpeningMapDesign.courtyardDoorCenters[sx<0 ? 0:1],door=courtyardDoorLeaf()
            door.position=SCNVector3(center.x,1,center.y);door.eulerAngles.y=NodeFloat(sx*0.48);walls.addChildNode(door)
            let cap=ruinedCourtyardWall(.init(length:0.5,depth:0.7,height:2.5,base:-0.25,seed:seed+2));cap.position=SCNVector3(sx*1.72,0,-8);walls.addChildNode(cap)
        }
        let mergedWalls=walls.flattenedClone();mergedWalls.name=walls.name;decor.addChildNode(mergedWalls)
        decor.addChildNode(courtyardFountain())
        let rainMaterial=material(0xaec2d4);rainMaterial.lightingModel = .constant;rainMaterial.transparency=0.22
        for _ in 0..<120 {
            let n=SCNNode(geometry:SCNBox(width:0.012,height:0.48,length:0.012,chamferRadius:0));n.geometry?.materials=[rainMaterial]
            n.position=SCNVector3(rng.range(-13,13),rng.range(0,10),rng.range(-9,9));n.eulerAngles.z = -0.16;n.castsShadow=false
            rainNodes.append(n);decor.addChildNode(n)
        }
    }
    func electricSpike(seed:UInt64)->SCNNode {
        let root=SCNNode(),base=cylinder(0.18,0.12,0x656a60);base.position.y=0.09;root.addChildNode(base)
        let shaft=cylinder(0.075,0.95,0x4c514a);shaft.position.y=0.56;root.addChildNode(shaft)
        for i in 0..<7 {let coil=cylinder(0.135,0.055,0x858f86);coil.position.y=NodeFloat(0.4+Double(i)*0.075);root.addChildNode(coil)}
        let cap=ball(0.105,0x54c94d,glow:true);cap.name="indicator";cap.position.y=1.13;root.addChildNode(cap)
        let arcs=SCNNode();arcs.name="arcs";root.addChildNode(arcs)
        var rng=ArtRandom(seed:seed)
        let electric=material(0xa4b2ff,glow:true);electric.lightingModel = .constant
        for i in 0..<9 {
            let a=Double(i)*Double.pi*2/9
            var last=SCNVector3(0,1.1,0)
            for j in 1...5 {
                let t=Double(j)/5,r=0.57*t,p=SCNVector3(cos(a)*r+rng.range(-0.13,0.13),1.1*(1-t)+rng.range(0.05,0.35),sin(a)*r+rng.range(-0.13,0.13))
                let arc=beam(last,p,radius:0.014,mat:electric);arc.castsShadow=false;arcs.addChildNode(arc);last=p
            }
        }
        let haloMat=combatEffectMaterial(0xff4130)
        let halo=SCNTorus(ringRadius:CGFloat(0.49),pipeRadius:0.015);halo.ringSegmentCount=40;halo.pipeSegmentCount=6;halo.materials=[haloMat]
        let footprint=SCNNode(geometry:halo);footprint.name="danger-ring";footprint.position.y=0.035;footprint.castsShadow=false;footprint.renderingOrder=22;root.addChildNode(footprint)
        arcs.isHidden=true;return root
    }
    func animateArena(_ now:Double,dt:Double) {
        for (i,n) in decor.childNodes.filter({$0.name=="cave-torch"}).enumerated() {
            n.childNode(withName:"flame",recursively:false)?.scale.y=NodeFloat(1.5+sin(core.elapsed*14+Double(i))*0.25)
        }
        let traps=core.layout.traps
        if trapNodes.count != traps.count || zip(trapNodes,traps).contains(where:{$0.name != "hazard-\($1.id)" || $0.parent !== decor}) {
            for n in trapNodes {n.removeFromParentNode()};trapNodes=[]
            for trap in traps {
                let n=electricSpike(seed:UInt64(trap.id));n.name="hazard-\(trap.id)";n.position=SCNVector3(trap.p.x,trap.elevation,trap.p.y);decor.addChildNode(n);trapNodes.append(n)
            }
        }
        for (i,n) in trapNodes.enumerated() {
            let state=traps[i].state(at:core.hazardClock)
            let color=state == .safe ? 0x54c94d:state == .warning ? 0xff4130:0xb5c5ff
            n.childNode(withName:"indicator",recursively:false)?.geometry?.firstMaterial?.diffuse.contents=rgb(color)
            n.childNode(withName:"indicator",recursively:false)?.geometry?.firstMaterial?.emission.contents=rgb(color)
            if let halo=n.childNode(withName:"danger-ring",recursively:false) {
                halo.isHidden=state == .safe;halo.opacity=state == .warning ? 0.45+0.3*sin(core.hazardClock*14):0.8
                halo.geometry?.firstMaterial?.diffuse.contents=rgb(color);halo.geometry?.firstMaterial?.emission.contents=rgb(color)
            }
            if let arcs=n.childNode(withName:"arcs",recursively:false) {
                arcs.isHidden=state != .active;arcs.opacity=Int(core.hazardClock*28)%3==0 ? 0.4:1
                arcs.eulerAngles.y=NodeFloat(Double(Int(core.hazardClock*12)%9)*0.7)
            }
        }
        for (i,n) in forestSnowNodes.enumerated() {
            n.isHidden=core.round != 36
            let y=(Double(i)*0.47-core.elapsed*1.25).truncatingRemainder(dividingBy:9)
            n.position.y=NodeFloat(y<0 ? y+9:y)
        }
        for (i,n) in rainNodes.enumerated() {
            n.isHidden=core.round != 8 && core.round != 16 && core.round != 40
            let y=(Double(i)*0.37-core.elapsed*13).truncatingRemainder(dividingBy:10)
            n.position.y=NodeFloat(y<0 ? y+10:y)
        }
    }
}

/// One opaque ground plane. The baked arena field and repeating earth meet in the
/// same fragment/material, rather than at an exposed geometry/material boundary.
enum CourtyardSurface {
 static func material(macro:SCNMaterial,earth:Any)->SCNMaterial {
  let material=macro.copy() as! SCNMaterial;material.name="opening-courtyard-continuous80";material.lightingModel = .lambert
  material.diffuse.wrapS = .clamp;material.diffuse.wrapT = .clamp
  material.multiply.contents=earth;material.multiply.mappingChannel=1;material.multiply.wrapS = .mirror;material.multiply.wrapT = .mirror
  material.roughness.contents=0.95
  for p in [material.diffuse,material.multiply] {p.minificationFilter = .linear;p.magnificationFilter = .linear;p.mipFilter = .linear;p.maxAnisotropy=4}
  // Built-in diffuse/multiply samplers retain SceneKit's colour handling and mipmaps.
  // The multiply sample is used as a second albedo, then reset before final lighting.
  material.shaderModifiers=[.surface:"""
  #pragma opaque
  #pragma body
  float2 world = float2(_surface.diffuseTexcoord.x * 33.0 - 16.5,
                        _surface.diffuseTexcoord.y * 23.0 - 11.5);
  float margin = min(16.5 - abs(world.x), 11.5 - abs(world.y));
  float interior = smoothstep(0.0, 1.75, margin);
  float3 exterior = _surface.multiply.rgb * float3(0.70, 0.70, 0.64);
  _surface.diffuse = float4(mix(exterior, _surface.diffuse.rgb, interior), 1.0);
  _surface.multiply = float4(1.0);
  """]
  return material
 }
 static func geometry(macro:SCNMaterial,earth:Any)->SCNGeometry {geometry(material:material(macro:macro,earth:earth))}
 static func geometry(material:SCNMaterial)->SCNGeometry {
  var vertices=[SCNVector3](),macroUV=[CGPoint](),earthUV=[CGPoint]()
  for (x,z) in [(-120.0,-120.0),(-120.0,120.0),(120.0,120.0),(120.0,-120.0)] {
   vertices.append(SCNVector3(x,0,z))
   // Raw SceneKit source UVs; ModelIO flips V during conversion and is not used here.
   macroUV.append(CGPoint(x:(x+16.5)/33,y:(z+11.5)/23));earthUV.append(CGPoint(x:x/2,y:z/2))
  }
  let sources=[SCNGeometrySource(vertices:vertices),SCNGeometrySource(normals:Array(repeating:SCNVector3(0,1,0),count:4)),SCNGeometrySource(textureCoordinates:macroUV),SCNGeometrySource(textureCoordinates:earthUV)]
  let geometry=SCNGeometry(sources:sources,elements:[SCNGeometryElement(indices:[Int32(0),1,2,0,2,3],primitiveType:.triangles)]);geometry.materials=[material];return geometry
 }
}
