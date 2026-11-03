#if os(macOS)
import AppKit
import SceneKit
import Metal

/// Checks visible object pixels, with the ground halo/marker left in BOTH images.
/// A bright floor ring alone therefore cannot satisfy the object-readability check.
enum PickupReadabilityRenderVerification {
    static func run(_ output:URL,size:CGSize=CGSize(width:1600,height:900),suffix:String="",includeGalleries:Bool=true)throws->Int {
        let width=Int(size.width),height=Int(size.height)
        let game=ArcadeGame(view:GameView(frame:NSRect(origin:.zero,size:size)),defaults:nil)
        let renderer=SCNRenderer(device:MTLCreateSystemDefaultDevice(),options:nil)
        renderer.scene=game.scene;renderer.pointOfView=game.camera;renderer.overlaySKScene=game.hud
        let groups:[[PickupKind]]=[ [.life,.dash,.bomb,.boots,.orb,.chicken], [.spread,.ray,.rocket,.deathMachine,.grenade,.flamethrower], [.tank,.helicopter,.teddy,.barrelShield,.monkey,.turret] ]
        var images=0,probes=0,minimum=Int.max,maximumMeshes=0
        var observations=[[String:Any]]()
        func require(_ value:Bool,_ message:String)throws {
            if !value {throw NSError(domain:"PickupReadabilityProof",code:1,userInfo:[NSLocalizedDescriptionKey:message])}
        }
        func tick(){game.lastTime=ProcessInfo.processInfo.systemUptime+1;game.tick(players:[Controls()],devices:[],viewSize:size)}
        func capture(_ source:SCNRenderer)->CGImage {
            source.snapshot(atTime:42,with:size,antialiasingMode:.multisampling4X).cgImage(forProposedRect:nil,context:nil,hints:nil)!
        }
        func rgba(_ image:CGImage)->[UInt8] {
            var bytes=[UInt8](repeating:0,count:width*height*4)
            bytes.withUnsafeMutableBytes{raw in
                let c=CGContext(data:raw.baseAddress,width:width,height:height,bitsPerComponent:8,bytesPerRow:width*4,space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGBitmapInfo.byteOrder32Big.rawValue|CGImageAlphaInfo.premultipliedLast.rawValue)!
                c.draw(image,in:CGRect(origin:.zero,size:size))
            };return bytes
        }
        func save(_ name:String,_ image:CGImage)throws {
            let data=NSBitmapImageRep(cgImage:image).representation(using:.png,properties:[:])!
            try data.write(to:output.appendingPathComponent(name+suffix+".png"),options:.withoutOverwriting)
            images+=1;print("PASS pickup63 image \(name)")
        }
        func changedObjectPixels(_ node:SCNNode,_ foreground:[UInt8],_ background:[UInt8])->Int {
            let b=node.boundingBox
            let points=[b.min.x,b.max.x].flatMap{x in [b.min.y,b.max.y].flatMap{y in [b.min.z,b.max.z].map{z in
                NativeCameraProjection.project(node.convertPosition(SCNVector3(x,y,z),to:nil),camera:game.camera,size:size)
            }}}
            let x0=max(0,Int(floor(points.map{Double($0.x)}.min()!))-2),x1=min(width-1,Int(ceil(points.map{Double($0.x)}.max()!))+2)
            let y0=max(0,Int(floor(Double(height)-points.map{Double($0.y)}.max()!))-2),y1=min(height-1,Int(ceil(Double(height)-points.map{Double($0.y)}.min()!))+2)
            guard x0<=x1,y0<=y1 else{return 0}
            var changed=0
            for y in y0...y1 {for x in x0...x1 {let p=(y*width+x)*4
                if (0..<3).contains(where:{abs(Int(foreground[p+$0])-Int(background[p+$0]))>18}) {changed+=1}
            }};return changed
        }
        for round in [1,2,7,8] {
            for (group,kinds) in groups.enumerated() {
                game.core.reset();game.core.round=round;game.core.beginRound()
                game.core.foes=[];game.core.pickups=[];game.core.combatSpawningHeld=true
                game.core.hero=V2(x:0,y:-4.7);game.core.heroElevation=game.core.layout.height(game.core.hero);game.core.invulnerable=0
                game.settings.cameraMode = .overview;game.settings.zoom = .normal;game.core.messageTime=0
                for (i,kind) in kinds.enumerated() {
                    let p=game.core.layout.clamped(V2(x:Double(i%3-1)*3,y:i<3 ? -2.3:2.3))
                    game.core.pickups.append(Pickup(id:game.core.id(),p:p,kind:kind,ttl:50))
                }
                game.lastRound=0;tick()
                let ids=game.core.pickups.map(\.id)
                try require(ids.count==6 && game.pickupNodes.count==6,"Fixture physically collected or lost a staged fund")
                var roundMinimum=Int.max
                for angle in 0..<4 {
                    for id in ids {game.pickupNodes[id]!.childNode(withName:"pickup-icon",recursively:false)!.eulerAngles.y=NodeFloat(Double(angle)*Double.pi/4)}
                    let picture=capture(renderer),foreground=rgba(picture)
                    if angle==0 {try save("pickup63-map-\(round)-group-\(group)",picture)}
                    for (i,id) in ids.enumerated() {
                        let root=game.pickupNodes[id]!,icon=root.childNode(withName:"pickup-icon",recursively:false)!
                        if group==0 {try require(icon.childNode(withName:"utility-pickup-\(kinds[i].rawValue)",recursively:false) != nil,"Fixture reused a model from a different utility kind")}
                        if group==1 {try require(icon.childNode(withName:"pickup-weapon-\(kinds[i].rawValue)",recursively:false) != nil,"Fixture reused a model from a different weapon kind")}
                        try require(root.childNodes.filter{$0.name=="pickup-class-marker"}.count==1,"A physical pickup has coincident duplicate class markers")
                        icon.isHidden=true;let background=rgba(capture(renderer));icon.isHidden=false
                        let changed=changedObjectPixels(icon,foreground,background)
                        observations.append(["round":round,"kind":String(describing:kinds[i]),"angle":angle,"object_pixels":changed])
                        try require(changed>=40,"Fund body lost its visible pixels:round\(round),kind\(kinds[i]),angle\(angle),pixels\(changed)")
                        minimum=min(minimum,changed);roundMinimum=min(roundMinimum,changed);probes+=1
                        if group==0 {
                            var meshes=0;icon.enumerateChildNodes{n,_ in if n.geometry != nil{meshes+=1}}
                            maximumMeshes=max(maximumMeshes,meshes)
                            try require(meshes==1,"Immutable utility model escaped its one-node geometry batching")
                        }
                    }
                }
                print("PASS pickup63 actual map\(round)/group\(group):24object-only masks,min\(roundMinimum)pixels,halos unchanged,both source round orientations/lighting")
            }
        }
        if includeGalleries {
        // Two asset inspection sheets expose the actual solid side walls and weapon-independent shapes.
        let sheet=SCNScene();sheet.background.contents=rgb(0x1b2429)
        let camera=SCNNode();camera.camera=SCNCamera();camera.camera!.usesOrthographicProjection=true;camera.camera!.orthographicScale=2.1
        sheet.rootNode.addChildNode(camera)
        let light=SCNNode();light.light=SCNLight();light.light!.type = .directional;light.light!.intensity=1100;light.eulerAngles=SCNVector3(-0.8,-0.7,0);sheet.rootNode.addChildNode(light)
        let ambient=SCNNode();ambient.light=SCNLight();ambient.light!.type = .ambient;ambient.light!.intensity=400;sheet.rootNode.addChildNode(ambient)
        for (i,kind) in groups[0].enumerated() {
            let n=game.utilityPickupModel(kind);n.position=SCNVector3(Double(i%3-1)*1.5,0,Double(i/3)*1.6-0.8);n.eulerAngles.y=0.3;sheet.rootNode.addChildNode(n)
        }
        let inspection=SCNRenderer(device:MTLCreateSystemDefaultDevice(),options:nil);inspection.scene=sheet;inspection.pointOfView=camera
        for (index,p) in [SCNVector3(0,5,-5),SCNVector3(0,8,-2)].enumerated() {
            camera.position=p;camera.look(at:SCNVector3Zero)
            try save("pickup63-solid-gallery-\(index)",capture(inspection))
        }
        }
        try require(probes==288 && images==(includeGalleries ? 14:12) && maximumMeshes==1,"Incomplete readability gallery/probe coverage")
        try require(game.audio.voiceCount==0 && game.audio.playedCount==0 && game.music.playedCount==0,"Pickup proof attempted audio")
        print("PASS pickup63 readability:\(images)nativeimages,18fundkinds/4actualopeningrounds/4rotationangles,\(probes)object-onlypixelmasks,size\(width)x\(height),min\(minimum)pixels,onebatchedutilitynode,unchangedhalos,0audio/no window/controller;not human recognition or hardware FPS acceptance")
        let report:[String:Any]=["logical_size":[width,height],"minimum_object_pixels":minimum,"pixel_floor":40,"probes":observations,"limits":"Changed object pixels with identical floor markers in both images. A low-level visibility check,not human recognition,display resolution,or original-model acceptance."]
        try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]).write(to:output.appendingPathComponent("pickup-visibility"+suffix+".json"),options:.withoutOverwriting)
        return images
    }
}
#endif
