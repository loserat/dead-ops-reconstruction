#if os(macOS)
import AppKit
import SceneKit
import Metal

/// Own model gallery and real value-input pose checks; never opens a game window or polls hardware.
enum CharacterRenderVerification {
    static func run(_ output:URL)throws {
        setbuf(stdout,nil);try FileManager.default.createDirectory(at:output,withIntermediateDirectories:true)
        let game=ArcadeGame(view:GameView(frame:NSRect(x:0,y:0,width:1600,height:900)),defaults:nil)
        let renderer=SCNRenderer(device:MTLCreateSystemDefaultDevice(),options:nil)
        renderer.scene=game.scene;renderer.pointOfView=game.camera;renderer.overlaySKScene=game.hud
        var images=0
        func require(_ yes:Bool,_ message:String)throws {if !yes{throw NSError(domain:"CharacterArtProof",code:1,userInfo:[NSLocalizedDescriptionKey:message])}}
        func tick(_ controls:Controls=Controls(),dt:Double=1.0/60){game.lastTime=ProcessInfo.processInfo.systemUptime-dt;game.tick(controls:controls,viewSize:CGSize(width:1600,height:900))}
        func save(_ name:String,_ source:SCNRenderer)throws {
            let image=source.snapshot(atTime:ProcessInfo.processInfo.systemUptime,with:CGSize(width:1600,height:900),antialiasingMode:.multisampling4X)
            guard let cg=image.cgImage(forProposedRect:nil,context:nil,hints:nil),let data=NSBitmapImageRep(cgImage:cg).representation(using:.png,properties:[:]) else{throw NSError(domain:"CharacterArtProof",code:2)}
            try data.write(to:output.appendingPathComponent(name+".png"),options:.withoutOverwriting);images+=1;print("PASS character image \(name)")
        }
        func stage(_ count:Int=1){
            game.core.reset(playerCount:count);game.core.pickups=[];game.core.foes=[];game.core.combatSpawningHeld=true
            for player in game.core.players {player.invulnerable=0;player.hero=game.core.layout.clamped(V2(x:Double(player.slot)*2-3,y:-2));player.heroElevation=game.core.layout.height(player.hero)}
            game.lastRound=0;tick(dt:0)
        }
        // Sharing GPU meshes must never share a limb pose, a burn attachment or an
        // engineer's additions. Inspect actual production instances before rendering.
        var sharedMeshes=0
        for prisoner in [false,true] {for variant in 0..<3 {
            let a=game.detailedCharacter(player:false,variant:variant,prisoner:prisoner)
            let b=game.detailedCharacter(player:false,variant:variant+3,prisoner:prisoner)
            func compare(_ x:SCNNode,_ y:SCNNode)throws {
                try require(x !== y && x.childNodes.count==y.childNodes.count,"Enemy instances share mutable pose nodes")
                if let g=x.geometry {try require(g === y.geometry,"Identical enemies reallocated immutable geometry");sharedMeshes+=1}
                for (u,v) in zip(x.childNodes,y.childNodes){try compare(u,v)}
            }
            try compare(a,b)
            let skinA=a.childNode(withName:"human-skinned-mesh",recursively:false)!.skinner!
            let skinB=b.childNode(withName:"human-skinned-mesh",recursively:false)!.skinner!
            try require(skinA !== skinB && skinA.baseGeometry === skinB.baseGeometry,"Enemy instances share a mutable skin controller or duplicate mesh buffers")
            try require(skinA.skeleton === a && skinB.skeleton === b && skinA.bones.count==7 && zip(skinA.bones,skinB.bones).allSatisfy{$0 !== $1},"Cloned enemies still point to another skeleton")
            game.animateHumanCharacter(a,phase:Double.pi/2,amount:1,player:false)
            let left=a.childNode(withName:"leftLeg",recursively:false)!,other=b.childNode(withName:"leftLeg",recursively:false)!
            try require(abs(Double(left.eulerAngles.x))>0.3 && abs(Double(other.eulerAngles.x))<0.0001,"Animating one enemy moved another enemy's leg")
            let burn=SCNNode();burn.name="burning";a.addChildNode(burn)
            try require(b.childNode(withName:"burning",recursively:false)==nil,"One enemy's burn attachment leaked into another instance")
        }}
        let engineer=game.engineerModel(),fallen=engineer.clone()
        let tool=fallen.childNode(withName:"engineer-wrench",recursively:true)!.childNodes.first!.geometry!
        game.rebindEnemySkin(on:fallen)
        let fallenSkin=fallen.childNode(withName:"human-skinned-mesh",recursively:false)!.skinner!
        let engineerSkin=engineer.childNode(withName:"human-skinned-mesh",recursively:false)!.skinner!
        try require(fallenSkin.skeleton === fallen && zip(fallenSkin.bones,engineerSkin.bones).allSatisfy{$0 !== $1},"A fallen engineer follows a living enemy's joints")
        try require(fallen.childNode(withName:"engineer-wrench",recursively:true)!.childNodes.first!.geometry === tool,"Rebinding a fallen enemy removed its equipment")
        let plain=game.detailedCharacter(player:false,prisoner:true)
        try require(plain.childNode(withName:"engineer-wrench",recursively:true)==nil && abs(Double(plain.scale.x)-0.9)<0.0001,"Engineer additions or size contaminated the cached prisoner")
        try require(game.enemyCharacterTemplates.count==6 && sharedMeshes>0,"Enemy geometry cache is unbounded or did not share real mesh resources")
        try require(game.enemySkinGeometries.count==6,"Immutable skin assets did not stay bounded to the six existing variants")
        print("PASS enemy mesh reuse:6boundedtemplates,\(sharedMeshes)sharedgeometryreferences,independentlimbposes/burns/engineerparts;player materials checked separately")
        let bulletKinds:[PickupKind?]=[nil,.spread,.ray,.rocket,.grenade,.deathMachine,.flamethrower]
        for kind in bulletKinds {
            let a=game.projectileNode(kind),b=game.projectileNode(kind)
            try require(a !== b && a.geometry === b.geometry,"Shots share mutable nodes or allocate duplicate geometry")
            a.position=SCNVector3(2,3,4);a.opacity=0.25
            try require(b.position.x==0 && b.position.y==0 && b.position.z==0 && b.opacity==1,"Moving or fading one shot affected another")
            let mat=a.geometry!.firstMaterial!
            try require((mat.emission.contents as? GameColor)==rgb(kind == .ray ? 0x91ff55:0xffc565),"Shared projectile appearance changed its glow colour")
            if kind == .grenade {try require(abs(Double((a.geometry as! SCNSphere).radius)-0.10)<1e-8,"Grenade model lost its existing radius")}
            else {let box=a.geometry as! SCNBox;try require(abs(Double(box.width)-0.05)<1e-8 && abs(Double(box.height)-0.05)<1e-8 && abs(Double(box.length)-(kind == .rocket ? 0.5:0.8))<1e-8,"Projectile sharing changed its existing shape")}
        }
        try require(game.projectileGeometries.count==4,"Projectile resource cache did not stay bounded to four appearances")
        print("PASS projectile reuse:7weaponkinds/4immutablegeometries,independentpositions/opacity,existingdimensionsandglow;combat rules unchanged")
        stage(4)
        try require(game.clothTexture != nil,"Cloth image did not reach the game material cache")
        for player in game.core.players {
            let model=game.playerArtStates[player.slot].hero.childNodes.first!
            try require(model.childNode(withName:"human-spine",recursively:false) != nil && model.childNode(withName:"leftLeg",recursively:false)?.childNode(withName:"human-knee",recursively:false) != nil,"A model lost its articulated spine or knee")
            let b=model.boundingBox,height=Double(b.max.y-b.min.y)*Double(model.scale.y)
            try require(height>1.4 && height<1.8,"New body is outside the camera/collision readability height envelope")
            guard let material=game.core.withPlayer(player.slot,{game.artMaterials[game.ownerMaterialKey("cloth-player")]}) ?? nil else{throw NSError(domain:"CharacterArtProof",code:3)}
            try require(material.diffuse.contents.map{CFGetTypeID($0 as CFTypeRef)==CGImage.typeID} == true,"Player uniform fell back to an untextured material")
            var ownsUniform=false;model.enumerateChildNodes{node,_ in if node.geometry?.materials.contains(where:{$0 === material})==true {ownsUniform=true}}
            try require(ownsUniform,"Flattened body lost its independently tinted owner material")
        }
        let helmetMaterials=game.core.players.compactMap{game.playerArtStates[$0.slot].hero.childNodes.first?.childNode(withName:"player-helmet",recursively:true)?.geometry?.firstMaterial}
        try require(helmetMaterials.count==4 && Set(helmetMaterials.map{ObjectIdentifier($0)}).count==4,"Player helmets share a tint material across owners")
        // This camera is solely an asset inspection sheet, not a claim about the in-game perspective.
        let sheet=SCNScene(),camera=SCNNode();camera.camera=SCNCamera();camera.camera!.usesOrthographicProjection=true;camera.camera!.orthographicScale=2.35
        camera.position=SCNVector3(0,3.7,-6.8);camera.look(at:SCNVector3(0,0.72,0));sheet.rootNode.addChildNode(camera)
        sheet.background.contents=NSColor(calibratedRed:0.08,green:0.11,blue:0.13,alpha:1)
        let floor=SCNFloor();floor.reflectivity=0;let mat=SCNMaterial();mat.diffuse.contents=NSColor(calibratedWhite:0.15,alpha:1);floor.materials=[mat];sheet.rootNode.addChildNode(SCNNode(geometry:floor))
        let sun=SCNNode();sun.light=game.sun.light!.copy() as? SCNLight;sun.eulerAngles=game.sun.eulerAngles;sheet.rootNode.addChildNode(sun)
        let ambient=SCNNode();ambient.light=SCNLight();ambient.light!.type = .ambient;ambient.light!.intensity=450;sheet.rootNode.addChildNode(ambient)
        var models=(0..<3).map{game.playerArtStates[$0].hero.childNodes.first!.clone()}
        models += [game.detailedCharacter(player:false,variant:0),game.detailedCharacter(player:false,variant:1,prisoner:true),game.engineerModel()]
        for (index,model) in models.enumerated(){model.position=SCNVector3(Double(index)*1.3-3.25,0,0);model.eulerAngles.y=0.12;game.animateHumanCharacter(model,phase:Double(index)*0.7,amount:index==0 ? 0:0.5,player:index<3);sheet.rootNode.addChildNode(model)}
        let gallery=SCNRenderer(device:MTLCreateSystemDefaultDevice(),options:nil);gallery.scene=sheet;gallery.pointOfView=camera
        try save("character-model-gallery",gallery)
        // Real equipped models and muzzle transforms, viewed from two gameplay directions.
        let weapons:[PickupKind?]=[nil,.spread,.ray,.rocket,.grenade,.deathMachine,.flamethrower]
        let weaponSheet=SCNScene();weaponSheet.background.contents=sheet.background.contents
        let weaponCamera=camera.clone();weaponCamera.position=SCNVector3(0,5.7,-5.0);weaponCamera.look(at:SCNVector3(0,0.4,0));weaponCamera.camera?.orthographicScale=2.8;weaponSheet.rootNode.addChildNode(weaponCamera)
        weaponSheet.rootNode.addChildNode(sun.clone());weaponSheet.rootNode.addChildNode(ambient.clone())
        let weaponFloor=SCNNode(geometry:floor.copy() as? SCNGeometry);weaponSheet.rootNode.addChildNode(weaponFloor)
        for (index,kind) in weapons.enumerated() {
            let model=game.weaponModel(kind);model.position=SCNVector3(Double(index)*1.1-3.3,0.65,0);model.eulerAngles.y=0.4;weaponSheet.rootNode.addChildNode(model)
            if let kind {let pickup=game.pickupWeaponModel(kind);let base=SCNNode();base.position=SCNVector3(Double(index)*1.1-3.3,0.08,-1.8);base.addChildNode(pickup);weaponSheet.rootNode.addChildNode(base)}
            var meshes=0;model.enumerateChildNodes{n,_ in if n.geometry != nil{meshes+=1}}
            try require(meshes<=3,"A detailed weapon bypassed static geometry batching")
        }
        let weaponRenderer=SCNRenderer(device:MTLCreateSystemDefaultDevice(),options:nil);weaponRenderer.scene=weaponSheet;weaponRenderer.pointOfView=weaponCamera
        try save("weapon-model-gallery",weaponRenderer)
        for (index,kind) in weapons.enumerated() {
            stage();game.core.weapon=kind;game.core.weaponReserve=50
            for (angle,direction) in [(0,V2(x:0,y:-1)),(1,V2(x:1,y:0))] {
                game.core.facing=direction;tick(dt:0)
                let model=game.hero.childNodes.first!,name=kind.map{$0 == .deathMachine ? "death-machine":"held-\($0.rawValue)"} ?? "standard-gun"
                let active=model.childNode(withName:name,recursively:false)!,flash=model.childNode(withName:"muzzle",recursively:false)!
                try require(!active.isHidden,"Actual equipped weapon is hidden")
                let muzzle=active.childNode(withName:"weapon-muzzle",recursively:true)!,position=muzzle.convertPosition(SCNVector3Zero,to:model)
                let error=hypot(hypot(Double(position.x-flash.position.x),Double(position.y-flash.position.y)),Double(position.z-flash.position.z))
                try require(error<0.0001,"Visible muzzle flash no longer follows the equipped weapon")
                if kind == .deathMachine {
                    let rotor=active.childNode(withName:"barrel-rotor",recursively:false)!
                    try require(abs(Double(rotor.position.z)+0.16)<0.0001,"Merged barrel rotor moved off its own axis")
                }
                try save("weapon-held-\(index)-view-\(angle)",renderer)
            }
        }
        stage();let before=game.core.hero
        for _ in 0..<90 {tick(Controls(move:V2(x:1,y:0),aim:V2(x:1,y:0)))}
        let art=game.playerArtStates[0],model=art.hero.childNodes.first!
        try require((game.core.hero-before).length>8 && art.locomotionAmount>0.8,"Real movement did not drive a sustained running pose")
        try require(abs(Double(model.childNode(withName:"leftLeg",recursively:false)!.eulerAngles.x))>0.03,"Running body kept an idle leg")
        try save("character-running",renderer)
        game.core.step(0,input:Controls(pause:true));let phase=art.walking,amount=art.locomotionAmount,elapsed=game.core.elapsed
        for _ in 0..<20 {tick()}
        try require(game.core.elapsed==elapsed && art.walking==phase && art.locomotionAmount==amount,"Pause advanced a visual gait while simulation was frozen")
        game.core.step(0,input:Controls(accept:true));for _ in 0..<30 {tick()}
        try require(art.locomotionAmount<0.002 && abs(Double(model.childNode(withName:"leftLeg",recursively:false)!.eulerAngles.x))<0.002,"Stopped body did not blend back to idle")
        try save("character-idle-after-running",renderer)
        game.core.hero=game.core.layout.boundary(V2(x:100,y:0),clearance:0.29);game.core.heroElevation=game.core.layout.height(game.core.hero);tick(dt:0)
        let wall=game.core.hero
        for _ in 0..<60 {tick(Controls(move:V2(x:1,y:0)))}
        try require((game.core.hero-wall).length<0.01 && art.locomotionAmount<0.01,"Blocked movement still ran in place from the requested input vector")
        try save("character-blocked-at-shore",renderer)
        stage();game.core.hero=V2(x:0,y:1.5);game.core.facing=V2(x:0,y:-1)
        game.core.foes=(0..<24).map{i in let angle=Double(i)*2.399,point=game.core.layout.clamped(V2(x:cos(angle)*(2.3+Double(i%4)),y:sin(angle)*(2.3+Double(i%4))));let kinds:[FoeKind]=[.zombie,.prisoner,.villager,.engineer];return Foe(id:73000+i,p:point,hp:999,speed:0,gait:Double(i)*0.7,kind:kinds[i%4])}
        tick(dt:0);try save("character-live-crowd",renderer)
        try require(game.foeNodes.count==24 && game.foeNodes.values.allSatisfy{$0.childNode(withName:"human-spine",recursively:false) != nil},"A live humanoid enemy bypassed the new articulated model")
        try require(game.audio.voiceCount==0 && game.audio.playedCount==0 && game.music.playedCount==0,"Character proof attempted audio")
        images += try PickupReadabilityRenderVerification.run(output)
        images += try PickupReadabilityRenderVerification.run(output,size:CGSize(width:960,height:540),suffix:"-960",includeGalleries:false)
        images += try CharacterMotionRenderVerification.run(output)
        print("PASS character art:\(images) native images,6-model inspection sheet,7batched weapons/6ground models/14real equipped directions and muzzle checks,4 independently tinted textured players and helmets,real running/stopping/blocking/pause,24live humanoids,cached cloth image,and576actualpickup-onlypixelmasks/2logicalwindowsizes;0audio,no window or real controller polling;not hardware or on-screen FPS acceptance")
    }
}
#endif
