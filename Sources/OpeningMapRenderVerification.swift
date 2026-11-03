#if os(macOS)
import AppKit
import SceneKit
import SceneKit.ModelIO
import ModelIO
import Metal

/// Actual opening map geometry and texture checks; never opens a window, polls input or emits audio.
enum OpeningMapRenderVerification {
    static func run(_ output:URL)throws {
        setbuf(stdout,nil);try FileManager.default.createDirectory(at:output,withIntermediateDirectories:true)
        let begin=ProcessInfo.processInfo.systemUptime
        let game=ArcadeGame(view:GameView(frame:NSRect(x:0,y:0,width:1600,height:900)),defaults:nil)
        let buildMS=(ProcessInfo.processInfo.systemUptime-begin)*1000
        let renderer=SCNRenderer(device:MTLCreateSystemDefaultDevice(),options:nil);renderer.scene=game.scene;renderer.pointOfView=game.camera;renderer.overlaySKScene=game.hud
        var images=0,surfaceSamples=0
        let size=CGSize(width:1600,height:900)
        func require(_ value:Bool,_ text:String)throws {if !value{throw NSError(domain:"OpeningMapProof",code:1,userInfo:[NSLocalizedDescriptionKey:text])}}
        func tick(){game.lastTime=ProcessInfo.processInfo.systemUptime;game.tick(controls:Controls(),viewSize:size)}
        func capture()->CGImage {renderer.snapshot(atTime:42,with:size,antialiasingMode:.multisampling4X).cgImage(forProposedRect:nil,context:nil,hints:nil)!}
        func save(_ name:String)throws->CGImage {
            let image=capture(),bytes=NSBitmapImageRep(cgImage:image).representation(using:.png,properties:[:])!
            try bytes.write(to:output.appendingPathComponent(name+".png"),options:.withoutOverwriting);images+=1;print("PASS opening image \(name)");return image
        }
        func fixture(_ round:Int){
            game.core.reset();game.core.round=round;game.core.beginRound();game.core.foes=[];game.core.pickups=[];game.core.combatSpawningHeld=true;game.core.invulnerable=999
            game.settings.cameraMode = .overview;game.core.messageTime=0;game.lastRound=0;tick()
        }
        for round in 1...8 {
            fixture(round)
            for entry in 0..<game.core.layout.enemyEntranceCount {
                game.core.foes.append(game.core.arrivingFoe(kind:.zombie,hp:999,speed:2.1,entrance:entry,lane:Double(entry%3-1)))
            }
            game.core.step(2,inputs:[]);tick();_=try save("opening-round-\(round)")
        }
        fixture(5);_=capture()
        let fountain=game.decor.childNode(withName:"opening-courtyard-fountain",recursively:false)!
        var fountainCorners=0,fountainFlats=0
        for i in 0..<16 {
            let a=Double(i)*Double.pi/8,p=V2(x:cos(a)*1.60,y:sin(a)*1.60)
            let hits=fountain.hitTestWithSegment(from:SCNVector3(p.x,2,p.y),to:SCNVector3(p.x,-0.1,p.y),options:[SCNHitTestOption.backFaceCulling.rawValue:false])
            if i%2==0 {try require(!hits.isEmpty,"Octagonal basin corner has a missing physical surface");fountainCorners+=1}
            else{try require(hits.isEmpty,"Fountain still has a round outer silhouette instead of octagonal flats");fountainFlats+=1}
        }
        let walls=game.decor.childNode(withName:"opening-courtyard-walls",recursively:false)!
        var wallVertices=0,wallIndices=0
        func countWalls(_ node:SCNNode){
            if let g=node.geometry {let m=MDLMesh(scnGeometry:g);wallVertices+=m.vertexCount;wallIndices+=(m.submeshes as? [MDLSubmesh] ?? []).map(\.indexCount).reduce(0,+)}
            for child in node.childNodes {countWalls(child)}
        };countWalls(walls)
        try require(wallVertices>100 && wallVertices<10000 && wallIndices<30000,"Ruined courtyard facade missed its merged geometry budget")
        var courtyardFloorSamples=0
        for ix in -58...58 {for iz in -38...38 {
            let p=V2(x:Double(ix)*0.2,y:Double(iz)*0.2)
            guard game.core.layout.walkable(p,clearance:0) else{continue}
            let hits=walls.hitTestWithSegment(from:SCNVector3(p.x,4,p.y),to:SCNVector3(p.x,-1,p.y),options:[SCNHitTestOption.backFaceCulling.rawValue:false,SCNHitTestOption.searchMode.rawValue:SCNHitTestSearchMode.all.rawValue])
            try require(hits.isEmpty,"Visible courtyard facade or open door intrudes into walkable ground at\(p)")
            courtyardFloorSamples+=1
        }}
        var wallSightlines=0
        for round in 5...8 {for p in [V2(x:11.30,y:0),V2(x:-11.30,y:0),V2(x:0,y:7.30),V2(x:0,y:-7.30),V2(x:10.8,y:7),V2(x:-10.8,y:-7)] {
            fixture(round);game.settings.cameraMode = .following;game.core.hero=p;game.core.heroElevation=0;game.lastRound=0;tick();_=capture()
            let wall=game.decor.childNode(withName:"opening-courtyard-walls",recursively:false)!
            let hits=wall.hitTestWithSegment(from:game.camera.position,to:SCNVector3(p.x,0.95,p.y),options:[SCNHitTestOption.backFaceCulling.rawValue:false])
            try require(hits.isEmpty,"Courtyard perimeter obscures the real player's upper body at\(p),round\(round)")
            wallSightlines+=1
        }}
        fixture(5);_=capture()
        for entry in 0..<4 {for (stage,fraction) in [("outside",0.25),("approach",0.65),("landed",1.0)] {
            let route=game.core.layout.enemyArrival(index:entry),total=zip(route.points,route.points.dropFirst()).map{($1.p-$0.p).length}.reduce(0,+)
            var arrival=route,p=route.start.p,h=route.start.height
            _=arrival.advance(position:&p,height:&h,distance:total*fraction)
            game.core.foes=[Foe(id:840000+entry,p:p,hp:999,speed:0,gait:0,elevation:h,arrival:fraction<1 ? arrival:nil)]
            game.core.hero=route.end.p+(route.end.p-route.start.p).unit*1.4;game.core.heroElevation=0;game.settings.cameraMode = .following;game.lastRound=0;tick()
            _=try save("opening-courtyard-entry-\(entry)-\(stage)")
        }}
        print("PASS courtyard73:\(wallVertices)wallvertices/\(wallIndices)indices,\(courtyardFloorSamples)actual walkable-groundrays,\(wallSightlines)upperbodysightlines,\(fountainCorners)actualbasincorners/\(fountainFlats)flats,4physical doorway approaches;ModelIOcounts,not GPU counters")
        fixture(5);_=capture()
        let paving=game.decor.childNode(withName:"opening-courtyard-paving",recursively:false)!,soil=game.decor.childNode(withName:"opening-courtyard-ground",recursively:false)!
        var pavingVertices=0,pavingIndices=0
        func countMesh(_ node:SCNNode){
            if let g=node.geometry {
                let converted=MDLMesh(scnGeometry:g);pavingVertices+=converted.vertexCount
                pavingIndices+=(converted.submeshes as? [MDLSubmesh] ?? []).map(\.indexCount).reduce(0,+)
            };for child in node.childNodes {countMesh(child)}
        }
        countMesh(paving)
        try require(pavingVertices>1000 && pavingVertices<100000 && pavingIndices>3000,"Actual merged courtyard paving missed the explicit low-poly budget or is empty")
        var stoneHeights=0,gapHeights=0
        for ix in -20...20 {for iz in -13...13 {
            let p=V2(x:Double(ix)*OpeningMapDesign.Stone.spacing,y:Double(iz)*OpeningMapDesign.Stone.spacing)
            guard OpeningMapDesign.isCourtyardPath(p),p.length>1.58,game.core.layout.walkable(p,clearance:0.29) else{continue}
            let stone=OpeningMapDesign.courtyardStone(ix:ix,iz:iz)
            guard stone.missing || stoneHeights<24 else{continue}
            let node=stone.missing ? soil:paving
            let hits=node.hitTestWithSegment(from:SCNVector3(p.x,2,p.y),to:SCNVector3(p.x,-1,p.y),options:[SCNHitTestOption.backFaceCulling.rawValue:true,SCNHitTestOption.searchMode.rawValue:SCNHitTestSearchMode.all.rawValue])
            let top=hits.map{Double($0.worldCoordinates.y)}.max()
            try require(top != nil && abs(top!-(stone.missing ? 0:0.02))<0.003,"Chipped paving top is back-facing or a missing boundary stone became a physical floor hole")
            if stone.missing {gapHeights+=1}else{stoneHeights+=1}
        }}
        try require(stoneHeights==24 && gapHeights>0,"Paving proof did not sample both actual stone tops and the continuous soil under gaps")
        try require(game.rainNodes.count==120 && game.rainNodes.allSatisfy{($0.geometry as? SCNBox)?.chamferRadius==0},"Rain streaks still carry unnecessary rounded-box geometry")
        let tiny=box(0.15,0.20,0.20,0x777777).geometry!,convertedTiny=MDLMesh(scnGeometry:tiny)
        let tinyIndices=(convertedTiny.submeshes as? [MDLSubmesh] ?? []).map(\.indexCount).reduce(0,+)
        try require(convertedTiny.vertexCount>0 && convertedTiny.vertexCount<=216 && tinyIndices<=324,"Shared tiny-box helper exceeded the native-converted216vertex108triangle budget")
        print("PASS chipped paving71:\(pavingVertices)native-converted vertices/\(pavingIndices)indices,\(stoneHeights)up-facingstoneheights/\(gapHeights)continuoussoilgapheights,120unroundedrainstreaks;actual ModelIO representation,not a GPU primitive counter")
        fixture(1)
        let cachedTerrain=game.artMaterials["opening-island-terrain"]!
        _=capture() // Commit freshly flattened static meshes before querying their actual native surfaces.
        let sand=game.decor.childNode(withName:"island-sand-surface",recursively:false)!
        try require(sand.geometry!.sources(for:.color).first?.vectorCount==2305,"Wet bank is missing its bounded per-vertex colour field")
        func pixels(_ image:CGImage)->[UInt8]{
            var bytes=[UInt8](repeating:0,count:1600*900*4)
            bytes.withUnsafeMutableBytes {raw in
                let context=CGContext(data:raw.baseAddress,width:1600,height:900,bitsPerComponent:8,bytesPerRow:1600*4,space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGBitmapInfo.byteOrder32Big.rawValue|CGImageAlphaInfo.premultipliedLast.rawValue)!
                context.draw(image,in:CGRect(x:0,y:0,width:1600,height:900))
            };return bytes
        }
        let wetGeometry=sand.geometry!,wetPixels=pixels(capture())
        let dryGeometry=SCNGeometry(sources:wetGeometry.sources.filter{$0.semantic != .color},elements:wetGeometry.elements)
        dryGeometry.materials=wetGeometry.materials;sand.geometry=dryGeometry
        let dryPixels=pixels(capture());sand.geometry=wetGeometry
        var wetChangedPixels=0
        for i in stride(from:0,to:wetPixels.count,by:4) {
            let difference=(0..<3).map{Int(dryPixels[i+$0])-Int(wetPixels[i+$0])}.reduce(0,+)
            if difference>12 {wetChangedPixels+=1}
        }
        try require(wetChangedPixels>1500,"Native wet-bank colour source does not visibly darken the actual production shore")
        var pierVertices=0,pierIndices=0,nailTriangles=0
        func inspectPier(_ node:SCNNode){
            if let g=node.geometry {
                let converted=MDLMesh(scnGeometry:g);pierVertices+=converted.vertexCount
                pierIndices+=(converted.submeshes as? [MDLSubmesh] ?? []).map(\.indexCount).reduce(0,+)
                for (i,e) in g.elements.enumerated() where !g.materials.isEmpty && g.materials[i%g.materials.count].name=="pier-nail72" {nailTriangles+=e.primitiveCount}
            };for child in node.childNodes {inspectPier(child)}
        }
        for design in OpeningMapDesign.piers {inspectPier(game.decor.childNode(withName:"opening-pier-\(design.entrance)",recursively:false)!)}
        try require(nailTriangles==840,"Actual merged pier nails still use spherical geometry or lost their visible heads")
        print("PASS island72 native:2305wet-bankcolours,\(wetChangedPixels)actualdarkenedpixels,\(pierVertices)piervertices/\(pierIndices)indices,\(nailTriangles)nailtriangles;ModelIOcounts,not GPU counters")
        for design in OpeningMapDesign.piers {
            guard let node=game.decor.childNode(withName:"opening-pier-\(design.entrance)",recursively:false) else{throw NSError(domain:"OpeningMapProof",code:2)}
            let delta=design.landing-design.outside,cross=abs(delta.x)>abs(delta.y) ? V2(x:0,y:1):V2(x:1,y:0)
            for lane in [-0.32,0,0.32] {for i in 0...40 {
                let p=design.outside+delta*(Double(i)/40)+cross*lane
                let hits=node.hitTestWithSegment(from:SCNVector3(p.x,4,p.y),to:SCNVector3(p.x,-1,p.y),options:[SCNHitTestOption.backFaceCulling.rawValue:false,SCNHitTestOption.searchMode.rawValue:SCNHitTestSearchMode.all.rawValue])
                let height=hits.map{Double($0.worldCoordinates.y)}.max()
                try require(height != nil && abs(height!-design.surfaceHeight(p))<0.035,"Rendered pier/ramp misses real approach foot height:entry\(design.entrance),lane\(lane),p\(p),hit\(String(describing:height))")
                surfaceSamples+=1
            }}
            for (name,fraction) in [("outside",0.08),("ramp",0.86),("landed",1.0)] {
                let route=design.route(lane:0),total=(route.points[1].p-route.start.p).length+(route.end.p-route.points[1].p).length
                var arrival=route,p=route.start.p,h=route.start.height
                _=arrival.advance(position:&p,height:&h,distance:total*fraction)
                game.core.foes=[Foe(id:820000+design.entrance,p:p,hp:999,speed:0,gait:0,elevation:h,arrival:fraction<1 ? arrival:nil)]
                game.core.hero=design.landing+(design.landing-design.hinge).unit*2;game.core.heroElevation=0;game.settings.cameraMode = .following;game.lastRound=0;tick()
                _=try save("opening-pier-\(design.entrance)-\(name)")
            }
        }
        for entry in 0..<4 {for (stage,fraction) in [("submerged",0.18),("surfacing",0.48),("landed",1.0)] {
            let route=game.core.layout.enemyArrival(index:entry),total=zip(route.points,route.points.dropFirst()).map{($1.p-$0.p).length}.reduce(0,+)
            var arrival=route,p=route.start.p,h=route.start.height
            _=arrival.advance(position:&p,height:&h,distance:total*fraction)
            game.core.foes=[Foe(id:830000+entry,p:p,hp:999,speed:0,gait:0,elevation:h,arrival:fraction<1 ? arrival:nil)]
            game.core.hero=route.end.p+(route.end.p-route.start.p).unit*1.7;game.core.heroElevation=0;game.settings.cameraMode = .following;game.lastRound=0;tick()
            _=try save("opening-water-\(entry)-\(stage)")
        }}
        for round in [1,4] {
            fixture(round);game.settings.cameraMode = .following;game.core.hero=OpeningMapDesign.boat.p+V2(x:2,y:0);game.lastRound=0;tick()
            _=try save("opening-boat-round-\(round)")
        }
        fixture(1);_=capture()
        // Trace the actual relocated hut, including its rotated flattened geometry, against sampled walkable ground.
        game.core.foes=[];game.core.hero=V2(x:1,y:1);game.settings.cameraMode = .overview;tick()
        let hut=game.decor.childNode(withName:"opening-island-hut",recursively:false)!
        let bounds=hut.boundingBox
        var hutSamples=0
        for ix in 0...25 {for iz in 0...25 {
            let p=hut.convertPosition(SCNVector3(Double(bounds.min.x)+(Double(bounds.max.x-bounds.min.x))*Double(ix)/25,0,Double(bounds.min.z)+(Double(bounds.max.z-bounds.min.z))*Double(iz)/25),to:nil)
            let hits=hut.hitTestWithSegment(from:hut.convertPosition(SCNVector3(p.x,4,p.z),from:nil),to:hut.convertPosition(SCNVector3(p.x,-1,p.z),from:nil),options:[SCNHitTestOption.backFaceCulling.rawValue:false])
            if !hits.isEmpty {hutSamples+=1;try require(!game.core.layout.walkable(V2(x:Double(p.x),y:Double(p.z)),clearance:0.29),"Visible hut still occupies playable ground without a matching solid")}
        }}
        try require(hutSamples>20,"Hut geometry was not actually sampled")
        // Isolate the actual production material to verify world-space texture orientation with real pixels.
        game.hero.isHidden=true;renderer.overlaySKScene=nil
        let grass=game.decor.childNode(withName:"island-grass-surface",recursively:false)!,mat=grass.geometry!.firstMaterial!,lighting=mat.lightingModel
        mat.lightingModel = .constant
        let colourImage=try save("opening-island-path-uv-calibration")
        var rgba=[UInt8](repeating:0,count:1600*900*4)
        rgba.withUnsafeMutableBytes{raw in
            let context=CGContext(data:raw.baseAddress,width:1600,height:900,bitsPerComponent:8,bytesPerRow:1600*4,space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGBitmapInfo.byteOrder32Big.rawValue|CGImageAlphaInfo.premultipliedLast.rawValue)!
            context.draw(colourImage,in:CGRect(x:0,y:0,width:1600,height:900))
        }
        func colour(_ p:V2)->(Int,Int){
            let q=NativeCameraProjection.project(SCNVector3(p.x,0.055,p.y),camera:game.camera,size:size),x=max(0,min(1599,Int(q.x))),y=max(0,min(899,Int(900-q.y))),i=(y*1600+x)*4
            return (Int(rgba[i]),Int(rgba[i+1]))
        }
        let path=colour(V2(x:6,y:1)),grassColour=colour(V2(x:6,y:-1.5))
        try require(path.0>path.1 && grassColour.1>grassColour.0,"Production island path image is flipped or detached from its world anchors:path\(path),grass\(grassColour)")
        let junction=[V2.zero,V2(x:0.24,y:0),V2(x:0,y:-0.24)].map{colour($0)}
        try require(junction.allSatisfy{$0.0>$0.1},"Triangle-fan centre does not sample the same worn path surface as its surrounding world-space junction: \(junction)")
        mat.lightingModel=lighting;game.hero.isHidden=false;renderer.overlaySKScene=game.hud
        for round in [1,5] {
            fixture(round);game.settings.cameraMode = .following;game.core.hero=round==1 ? V2(x:2,y:0):V2(x:3,y:0);game.lastRound=0;tick();_=try save("opening-close-\(round)")
        }
        try require(game.artMaterials["opening-island-terrain"] === cachedTerrain,"Map revisits regenerate the cached terrain material")
        try require(game.openingTerrainLoads==2 && game.openingTerrainBuilds==0,"Opening arenas did not load exactly two prepared terrain fields, or regenerated terrain on the scene path")
        try require(game.openingTextureImages["path-earth-v59.png"] != nil && game.openingTextureImages["paving-limestone-v59.png"] != nil,"The real scene did not use both new raw material textures")
        let rawURL=Bundle.main.resourceURL!.appendingPathComponent("Assets/path-earth-v59.png")
        try require(OpeningTerrainSurface.readBaked(rawURL,kind:.island)==nil,"Untagged source texture incorrectly accepted as a prepared map")
        try require(game.audio.voiceCount==0 && game.audio.playedCount==0 && game.music.playedCount==0,"Map proof attempted audio")
        print("PASS terrain59 prepared runtime:\(game.openingTerrainLoads)loads,\(game.openingTerrainBuilds)CPUrebakes,new earth/stone used,untagged input refused")
        print("PASS opening maps:\(images)nativeimages,\(surfaceSamples)actual deck/ramp ray heights,\(hutSamples)actual hut footprint samples,production path UV pixel colours\(path)/\(grassColour),centre-junction pixel colours\(junction),cached terrain revisits,initial scene build\(buildMS)ms;8own opening rounds,no window/audio/native input;not original map measurement,hardware or windowFPS acceptance")
    }
}
#endif
