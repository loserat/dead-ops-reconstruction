#if os(macOS)
import Foundation
import AppKit
import SceneKit
import Metal

/// Explicit offscreen verification only. No live input sampling, user defaults, window or audio.
enum TeamRenderVerification {
    static func run(_ output:URL)throws {
        setbuf(stdout,nil)
        try FileManager.default.createDirectory(at:output,withIntermediateDirectories:true)
        let game=ArcadeGame(view:GameView(frame:NSRect(x:0,y:0,width:1600,height:900)),defaults:nil)
        let renderer=SCNRenderer(device:MTLCreateSystemDefaultDevice(),options:nil)
        renderer.scene=game.scene;renderer.pointOfView=game.camera;renderer.overlaySKScene=game.hud
        var images=0,projections=0
        func require(_ value:Bool,_ message:String)throws {
            if !value {throw NSError(domain:"DeadOpsTeamRender",code:1,userInfo:[NSLocalizedDescriptionKey:message])}
        }
        func tick(_ size:CGSize=CGSize(width:1600,height:900)) {
            game.lastTime=ProcessInfo.processInfo.systemUptime
            game.tick(players:Array(repeating:Controls(),count:game.core.playerCount),devices:[],viewSize:size)
        }
        func fixture(_ round:Int,_ count:Int=4){
            game.core.reset(playerCount:count);game.core.round=round;game.core.pickups=[];game.core.beginRound()
            game.core.pickups=[];game.core.foes=[];game.core.combatSpawningHeld=true
            let points=[V2(x:-6,y:-3.5),V2(x:6,y:-3.5),V2(x:-6,y:3.5),V2(x:6,y:3.5)]
            let weapons:[PickupKind]=[.ray,.grenade,.rocket,.flamethrower]
            for p in game.core.players {game.core.withPlayer(p.slot){
                game.core.hero=game.core.layout.clamped(points[p.slot],clearance:0.4)
                game.core.heroElevation=game.core.layout.height(game.core.hero)
                game.core.facing=V2(x:p.slot%2==0 ? 1:-1,y:0);game.core.invulnerable=999
                game.core.apply(weapons[(p.slot+round/4)%weapons.count]);game.core.score=(p.slot+1)*12345
            }}
            game.lastRound=0
        }
        func save(_ name:String,_ size:CGSize=CGSize(width:1600,height:900))throws {
            tick(size)
            let time=ProcessInfo.processInfo.systemUptime
            let personalEffects=(name.hasPrefix("shield-") || name.hasPrefix("boost-four")) ? game.playerArtStates.flatMap{[$0.bodyShieldNode,$0.boostTrailNode].compactMap{$0}.filter{!$0.isHidden}}:[]
            let hazardEffects=(name=="hazards-warning" || name=="hazards-active") ? game.trapNodes.flatMap{node in [node.childNode(withName:"danger-ring",recursively:false),node.childNode(withName:"arcs",recursively:false)].compactMap{$0}.filter{!$0.isHidden}}:[]
            let effectNodes=personalEffects+hazardEffects
            var effectBaseline:CGImage?
            if !effectNodes.isEmpty {
                for node in effectNodes {node.isHidden=true}
                let baseline=renderer.snapshot(atTime:time,with:size,antialiasingMode:.multisampling4X)
                effectBaseline=baseline.cgImage(forProposedRect:nil,context:nil,hints:nil)
                for node in effectNodes {node.isHidden=false}
            }
            let image=renderer.snapshot(atTime:time,with:size,antialiasingMode:.multisampling4X)
            guard let cg=image.cgImage(forProposedRect:nil,context:nil,hints:nil),let data=NSBitmapImageRep(cgImage:cg).representation(using:.png,properties:[:]) else{throw NSError(domain:"DeadOpsTeamRender",code:2)}
            try data.write(to:output.appendingPathComponent(name+".png"),options:.withoutOverwriting)
            if let baseline=effectBaseline {
                func rgba(_ cg:CGImage)->[UInt8] {
                    let width=cg.width,height=cg.height;var values=[UInt8](repeating:0,count:width*height*4)
                    values.withUnsafeMutableBytes{raw in
                        let ctx=CGContext(data:raw.baseAddress,width:width,height:height,bitsPerComponent:8,bytesPerRow:width*4,space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGBitmapInfo.byteOrder32Big.rawValue|CGImageAlphaInfo.premultipliedLast.rawValue)!
                        ctx.draw(cg,in:CGRect(x:0,y:0,width:width,height:height))
                    };return values
                }
                let a=rgba(baseline),b=rgba(cg),width=cg.width,height=cg.height
                for node in effectNodes {
                    let bounds=node.boundingBox
                    let projected=[bounds.min.x,bounds.max.x].flatMap{x in [bounds.min.y,bounds.max.y].flatMap{y in [bounds.min.z,bounds.max.z].map{z in NativeCameraProjection.project(node.convertPosition(SCNVector3(x,y,z),to:nil),camera:game.camera,size:size)}}}
                    let x0=max(0,Int(floor(projected.map{Double($0.x)}.min()!))-2),x1=min(width-1,Int(ceil(projected.map{Double($0.x)}.max()!))+2)
                    let y0=max(0,Int(floor(Double(height)-projected.map{Double($0.y)}.max()!))-2),y1=min(height-1,Int(ceil(Double(height)-projected.map{Double($0.y)}.min()!))+2)
                    var changed=0
                    if x0<=x1 && y0<=y1 {for y in y0...y1 {for x in x0...x1 {
                        let p=(y*width+x)*4
                        if (0..<3).contains(where:{abs(Int(a[p+$0])-Int(b[p+$0]))>20}) {changed+=1}
                    }}}
                    try require(changed>=10,"Effect state existed but did not produce10visiblepixels in its projected region:\(name),\(node.name ?? ""),changed\(changed),bounds\(x0),\(y0),\(x1),\(y1)")
                    print("PASS effect pixels \(name):\(node.name ?? ""),\(changed) native changed pixels in its own projected bounds")
                }
            }
            try require(game.playerArtStates.count==game.core.playerCount,"Wrong number of retained player art states")
            try require(game.core.activePlayerSlot==0,"Renderer leaked an actor selection into simulation")
            for p in game.core.livingPlayers {
                let art=game.playerArtStates[p.slot]
                try require(art.hero.parent === game.actors && !art.hero.isHidden,"A living player's root is absent")
                try require(art.hero.opacity==1,"A protected living player lost body readability through transparent blinking")
                let p0=art.hero.position,screen=NativeCameraProjection.project(SCNVector3(p0.x,p0.y+0.8,p0.z),camera:game.camera,size:size)
                if (game.core.arenaTransit?.darkness ?? 0)<1 {try require(screen.x>0 && screen.x<size.width && screen.y>0 && screen.y<size.height,"Renderer projection lost a visible living player in \(name):\(p.slot),\(screen)")}
                projections+=1
                try require(art.appliedPlayerColor==game.settings.color(for:p.slot),"Wrong player tint")
                if game.core.playerCount>1 {
                    if game.core.phase == .paused {try require(art.badge.isHidden,"Pause retained an active world role badge over its menu")}
                    else {try require(!art.badge.isHidden && art.roleText?.string as? String == "P\(p.slot+1)","Missing individual role badge")}
                }
                else {try require(art.badge.isHidden,"Solo retained a team role badge")}
            }
            if !game.teamHUD.isHidden {
                for player in game.core.players {
                    let art=game.playerArtStates[player.slot]
                    try require(art.hudCounters.count==3 && art.hudCounterTitles.count==3,"Visible player card lacks its real life/bomb/boost counters")
                    let expected=player.isDown ? String(Int(ceil(player.recoverySeconds)))+"s":String(game.core.withPlayer(player.slot){game.core.displayedLives}!)
                    try require(art.hudCounters[0].text==expected && art.hudCounters[1].text==String(player.bombs) && art.hudCounters[2].text==String(player.dashes),"A visible reserve counter belongs to another role or loses its sign/countdown")
                    for label in art.tileLabels+art.hudCounters+art.hudCounterTitles where !(label.text ?? "").isEmpty {
                        try require(label.frame.minX>=7 && label.frame.maxX<=273 && label.frame.minY>=1 && label.frame.maxY<=116,"A new HUD label leaves its own card in \(name):\(label.text ?? ""),\(label.frame)")
                    }
                    try require(!art.tileLabels[0].frame.intersects(art.tileLabels[1].frame),"Player name and score overlap in \(name)")
                    try require(art.tile.childNode(withName:"hud-life-icon") != nil && art.tile.childNode(withName:"hud-bomb-icon") != nil && art.tile.childNode(withName:"hud-boost-icon") != nil,"Visible resource counters lack their distinct vector glyphs")
                }
            }
            if game.core.sideRoom?.kind == .fate {
                for node in Array(game.fateDoorNodes.values)+Array(game.fateDropNodes.values)+Array(game.fateBootNodes.values)+Array(game.fateLifeNodes.values) where !node.isHidden {
                    let point=NativeCameraProjection.project(node.position,camera:game.camera,size:size)
                    try require(point.x>20 && point.x<size.width-20 && point.y>size.height*0.16 && point.y<size.height*0.81,"Fate choice or falling reward is clipped by the viewport/HUD in \(name)")
                }
            }
            if game.core.playerCount>1 {
                try require(game.teamHUD.isHidden == (game.core.phase == .paused),"Shared HUD visibility disagrees with gameplay or pause")
                if !game.pickupHintLabel.isHidden && !game.roundLabel.isHidden {try require(!game.pickupHintLabel.frame.intersects(game.roundLabel.frame),"The near-item readout overlaps the team round line")}
                try require(game.playerArtStates.allSatisfy{$0.tile.parent === game.teamHUD && $0.tileLabels.count==5},"A player's HUD tile is missing")
                for player in game.core.players {
                    let art=game.playerArtStates[player.slot],expected=max(0,min(1,player.multiplierCharge))*260
                    try require(art.tileMeter?.parent === art.tile && abs(Double(art.tileMeter?.path?.boundingBoxOfPath.width ?? -1)-expected)<0.01,"A personal treasure bar has another player's progress")
                }
            }
            let materials=game.core.players.compactMap{p -> SCNMaterial? in game.core.withPlayer(p.slot){game.artMaterials[game.ownerMaterialKey("cloth-player")]} ?? nil}
            try require(materials.count==game.core.playerCount && Set(materials.map(ObjectIdentifier.init)).count==materials.count,"Player uniform materials are shared mutably")
            for (slot,mat) in materials.enumerated() {
                try require((mat.multiply.contents as? NSColor)?.isEqual(rgb(game.settings.color(for:slot).tint))==true,"Wrong actual uniform tint at slot \(slot)")
                if let node=game.playerArtStates[slot].vehicleNode {
                    let badge=node.childNode(withName:"vehicle-owner-badge",recursively:true)?.geometry?.firstMaterial?.diffuse.contents as? NSColor
                    try require(badge?.isEqual(rgb(game.settings.color(for:slot).tint))==true,"Wrong actual vehicle badge tint at slot \(slot)")
                }
            }
            if game.core.phase == .transition,game.core.arenaTransit?.darkness==1 {
                let bitmap=NSBitmapImageRep(cgImage:cg)
                for y in stride(from:0,to:cg.height,by:max(1,cg.height/20)) {for x in stride(from:0,to:cg.width,by:max(1,cg.width/20)) {
                    guard let color=bitmap.colorAt(x:x,y:y)?.usingColorSpace(.deviceRGB) else{throw NSError(domain:"DeadOpsBlackFrame",code:1)}
                    try require(max(color.redComponent,max(color.greenComponent,color.blueComponent))<0.01,"A map or HUD pixel leaked through full black in\(name):\(x),\(y)")
                }}
                print("PASS full black pixels \(name):entire viewport grid including HUD/letterbox edges")
            }
            images+=1;print("PASS scene \(name):\(game.core.playerCount) retained players,scale\(game.camera.camera!.orthographicScale),\(projections) actual renderer projections")
        }
        for round in stride(from:1,through:37,by:4) {fixture(round);try save("team4-arena-\(round)")}
        fixture(1)
        let fractions=[0.0,0.25,0.75,1.0],multipliers=[1,2,5,9]
        for player in game.core.players {player.multiplier=multipliers[player.slot];player.multiplierCharge=fractions[player.slot]}
        game.core.players[0].score=199375
        for (i,units) in [128,256,512].enumerated(){game.core.addLoot(at:V2(x:Double(i)*3-3,y:0),kind:.gem,appearance:.gem(.red,.large),ttl:100,gemUnits:units)}
        try save("treasure-team-personal-bars")
        let sizes=game.core.pickups.compactMap{p -> Double? in guard p.kind == .gem,let root=game.pickupNodes[p.id]?.childNode(withName:"loot-model",recursively:true) ?? game.pickupNodes[p.id]?.childNode(withName:"gem-1-\(p.loot!.size!.rawValue)",recursively:true) else{return nil};return Double(root.boundingBox.max.x-root.boundingBox.min.x)}
        try require(sizes.count==3 && sizes[0]<=sizes[1] && sizes[2]>sizes[1]*1.8,"Stored gem values did not reach the rendered geometry size")
        let item=game.core.pickups.first!;game.core.hero=item.p;game.core.heroElevation=game.core.layout.height(item.p);game.core.step(0,inputs:[])
        game.core.advanceDirectedRewards(1.3);game.core.collectDirectedRewards()
        try save("treasure-team-gem-extra-life")
        try require(game.core.players[0].score==200000 && game.core.players[0].lives==4 && game.core.players[0].multiplierCharge==0.25 && game.core.players[1].multiplierCharge==0.25,"Gem score/life collection crossed a player boundary")
        game.core.withPlayer(2){game.core.invulnerable=0;game.core.loseLife()}
        try save("treasure-team-death-spill")
        try require(game.core.players[2].multiplier==1 && game.core.players[2].multiplierCharge==0 && game.core.pickups.contains{$0.gemUnits != nil && $0.gemUnits!<=128},"Actual death did not render physical recovery gems with a reset personal bar")
        fixture(1,1);game.core.multiplier=9;game.core.multiplierCharge=0.5
        try save("treasure-solo-times9-partial-bar")
        try require(abs(Double(game.multiplierFill.path!.boundingBoxOfPath.width)-135)<0.01,"Solo times9 HUD falsely showed a full bar")
        fixture(1,2);game.core.players[0].hero=V2(x:-2,y:0);game.core.players[1].hero=V2(x:2,y:0)
        try save("team2-island-close")
        fixture(9)
        game.core.withPlayer(0){game.core.apply(.tank);game.core.apply(.orb)}
        game.core.withPlayer(1){game.core.apply(.helicopter);game.core.apply(.chicken)}
        game.core.withPlayer(2){game.core.apply(.turret);game.core.apply(.monkey)}
        game.core.withPlayer(3){game.core.apply(.barrelShield);game.core.apply(.teddy)}
        try save("team4-vehicles-prison")
        try require(game.playerArtStates[0].vehicleNode?.name=="tank" && game.playerArtStates[1].vehicleNode?.name=="helicopter" && game.playerArtStates[2].vehicleNode==nil,"Vehicle rendering crossed owners")
        try require(game.playerArtStates[0].orbNodes.count==4 && game.playerArtStates[1].chickenNodes.count==1 && game.playerArtStates[2].sentryNodes.count==1 && game.playerArtStates[2].monkeyNodes.count==1 && game.playerArtStates[3].shieldBarrelNodes.count==2,"Support rendering crossed owners")
        try save("team4-vehicles-prison-4x3",CGSize(width:1200,height:900))
        fixture(5);for p in game.core.players {p.lives=0};game.core.invulnerable=0;game.core.loseLife()
        try save("team4-waiting")
        try require(game.playerArtStates[0].hero.eulerAngles.x < -1 && game.playerArtStates[0].tileLabels[2].text?.contains("WIEDERKEHR")==true,"Waiting body or countdown HUD is missing")
        fixture(14);game.core.phase = .cleared;game.core.enterFateRoom()
        try save("team4-fate")
        let before=game.settings.teamColors
        game.settings.playerColor = .pink;game.settings.playerTwoColor = .white
        game.settings.playerThreeColor = .blue;game.settings.playerFourColor = .green
        try require(zip(before,game.settings.teamColors).allSatisfy{$0 != $1},"The recolor fixture did not change every player")
        try save("team4-fate-recolored")
        try require(game.fateDoorNodes.count==4 && game.fateDropNodes.count==4 && game.fateBootNodes.count==1 && game.fateDoorNodes.values.allSatisfy(\.isHidden) && game.fateDropNodes.values.allSatisfy(\.isHidden),"Fate entry leaked an arrow or reward before its reveal")
        let fateNodes=Array(game.fateDoorNodes.values)+Array(game.fateDropNodes.values)+Array(game.fateBootNodes.values)
        game.core.sideRoom!.clock=FateRoomTiming.firstArrow+0.05
        try save("team4-fate-first-arrow")
        try require(game.fateDoorNodes.values.filter{!$0.isHidden}.count==1 && game.fateDropNodes.values.allSatisfy(\.isHidden),"The first arrow did not reveal alone")
        game.core.sideRoom!.clock=FateRoomTiming.firstArrow+0.7
        try save("team4-fate-four-arrows")
        try save("team4-fate-four-arrows-4x3",CGSize(width:1200,height:900))
        try require(game.fateDoorNodes.values.allSatisfy{!$0.isHidden},"A revealed Fate arrow is absent")
        for arrow in game.fateDoorNodes.values {
            try require(arrow.childNodes.count==2 && arrow.childNodes.allSatisfy{$0.geometry?.firstMaterial?.lightingModel == .constant && ($0.geometry?.firstMaterial?.diffuse.contents as? NSColor)?.isEqual(rgb(0xe7ca59))==true},"An arrow leaked its fate through a different color")
        }
        for fate in FateKind.allCases where fate != .feet {game.core.players[fate.rawValue].hero=game.core.fateRoom!.door(for:fate).p}
        game.core.players[3].hero=V2(x:2,y:2)
        game.core.sideRoom!.clock=6;game.core.step(0,inputs:[])
        for player in game.core.players.prefix(3) {player.hero=V2(x:Double(player.slot)*3-3,y:0)}
        game.core.sideRoom!.clock=6.6
        try save("team4-fate-following-rewards")
        try require(game.fateDropNodes.values.filter{!$0.isHidden}.count==3 && game.core.players.prefix(3).allSatisfy(\.fatePending),"A reserved Fate did not wait for its personal delivery")
        for door in FateDoor.allCases {if let delivery=game.core.fateRoom?.deliveries[door.rawValue] {let point=game.fateDropNodes[door.rawValue]!.position,owner=game.core.players[delivery.slot];try require(abs(Double(point.x)-owner.hero.x)<0.01 && abs(Double(point.z)-owner.hero.y)<0.01,"A falling Fate lost its moving owner")}}
        game.core.sideRoom!.clock=7.31;game.core.step(0,inputs:[])
        try save("team4-fate-three-delivered")
        try require(game.core.players.map(\.fate)==[.fortitude,.firepower,.friendship,nil] && game.core.players.prefix(3).allSatisfy{!$0.fatePending} && game.fateDropNodes.values.allSatisfy(\.isHidden),"Delivered rewards did not disappear and apply to their owners")
        game.core.sideRoom!.clock=FateRoomTiming.choiceEnd;game.core.step(0,inputs:[])
        try save("team4-fate-choice-expired")
        try require(game.core.phase == .bonusRoom && game.core.players[3].fate==nil,"An expired unchosen door granted a fate")
        game.core.sideRoom!.clock=FateRoomTiming.choiceEnd+FateRoomTiming.settle
        try save("team4-fate-farewell")
        try require(game.fateDoorNodes.values.allSatisfy(\.isHidden) && game.core.fateRoomInstruction.contains("ENTSCHIEDEN"),"Farewell retained a false exit opportunity")
        game.core.sideRoom!.clock=FateRoomTiming.choiceEnd+FateRoomTiming.settle+FateRoomTiming.farewell+0.01;game.core.step(0,inputs:[])
        game.core.step(2.7,inputs:[])
        try save("team4-fate-timeout-return")
        try require(game.core.round==15 && game.core.players[3].missedFate && game.playerArtStates[3].tileLabels[4].text?.contains("SCHICKSAL VERPASST")==true,"Timed-out player is missing its personal HUD explanation")
        try require(game.fateDoorNodes.isEmpty && game.fateDropNodes.isEmpty && game.fateBootNodes.isEmpty && fateNodes.allSatisfy{$0.parent==nil},"Returning to combat retained Fate nodes")
        fixture(14);game.core.phase = .cleared;game.core.enterFateRoom()
        for fate in FateKind.allCases {game.core.players[fate.rawValue].hero=game.core.fateRoom!.door(for:fate).p}
        for _ in 0..<1080 {game.core.step(1.0/60,inputs:[])}
        try save("team4-fate-four-collected")
        try require(game.core.round==15 && game.core.players.map(\.fate)==FateKind.allCases.map{Optional($0)} && game.core.players.allSatisfy{!$0.fatePending && !$0.missedFate},"Four real visitors failed reservation delivery and farewell")
        fixture(14,1);game.core.phase = .cleared;game.core.enterFateRoom();game.core.sideRoom!.clock=5.7
        try save("solo-fate-four-arrows")
        game.core.hero=game.core.fateRoom!.door(for:.firepower).p;game.core.sideRoom!.clock=6;game.core.step(0,inputs:[])
        try save("solo-fate-high-delivery-4x3",CGSize(width:1200,height:900))
        fixture(14,1);game.core.phase = .cleared;game.core.enterFateRoom();game.core.hero=game.core.fateRoom!.door(for:.feet).p;game.core.sideRoom!.clock=6;game.core.step(0,inputs:[])
        game.core.sideRoom!.clock=7.1
        try save("solo-fate-feet-two-deliveries")
        try require(game.fateDropNodes.values.filter{!$0.isHidden}.count==1 && game.fateBootNodes.values.filter{!$0.isHidden}.count==1,"Feet is missing its separate bolt and boots deliveries")
        fixture(15,4);game.core.phase = .cleared;game.core.clearClock=4
        game.core.prepareArenaExits();let selected=game.core.availableExits[0];game.core.players[2].hero=selected.p;game.core.players[2].heroElevation=selected.height
        game.core.step(0,inputs:[]);game.core.step(4.5,inputs:[])
        try save("team4-fate-replaces-ordinary-way")
        try require(game.core.round==15 && game.core.sideRoom?.kind == .fate && game.core.pickups.isEmpty && !game.core.visitedSideRoomRounds.contains(15),"A real teammate's ordinary exit did not reach the guaranteed Fate visit through blackout")
        game.core.sideRoom!.clock=5.7
        try save("team4-fate-guaranteed-after15")
        game.core.sideRoom!.clock=FateRoomTiming.choiceEnd;game.core.step(0,inputs:[])
        game.core.sideRoom!.clock=FateRoomTiming.choiceEnd+FateRoomTiming.settle+FateRoomTiming.farewell;game.core.step(0,inputs:[])
        game.core.step(2.7,inputs:[])
        try save("team4-fate-guaranteed-return16")
        try require(game.core.round==16 && game.core.sideRoom==nil && game.core.fateRoomVisited && game.core.players.allSatisfy(\.missedFate),"The guaranteed visit failed to return exactly once after missed choices")
        game.core.round=17;game.core.beginRound();game.core.phase = .cleared;game.core.clearClock=4
        for seed in 1...100 {game.core.exitSeed=UInt64(seed);game.core.prepareArenaExits();if game.core.arenaExits.contains(where:{$0.bonus == .armory}) {break}}
        guard let retained=game.core.availableExits.first(where:{$0.bonus == .armory}) else{throw NSError(domain:"DeadOpsTeamRender",code:46)}
        game.core.players[1].hero=retained.p;game.core.players[1].heroElevation=retained.height;game.core.step(0,inputs:[])
        game.core.step(game.core.arenaTransit!.commitAt,inputs:[])
        try require(game.core.sideRoom?.kind == .armory && game.core.pickups.count<=1 && game.core.sourceLoot!.pendingRoomPrograms==1,"A visited Fate room swallowed the source armory program at the black-frame commit")
        let entryCount=game.core.pickups.count,bornAtCommit=game.core.sourceLoot!.emitted,collectedAtCommit=game.core.collectedWorldFunds
        game.core.step(game.core.arenaTransit!.endAt-game.core.arenaTransit!.clock,inputs:[])
        let bornDuringFade=game.core.sourceLoot!.emitted-bornAtCommit,collectedDuringFade=game.core.collectedWorldFunds-collectedAtCommit
        try require(game.core.phase == .bonusRoom && game.core.pickups.count==entryCount+bornDuringFade-collectedDuringFade && game.core.sourceLoot!.pendingRoomPrograms==1,"Armory fade lost source births/contact awards or incorrectly completed its equipment sequence at entry")
        print("PASS retained source armory:\(entryCount)funds at black commit,\(bornDuringFade)newborn and\(collectedDuringFade)physical contacts during fade,\(game.core.pickups.count)remaining")
        try save("team4-visited-fate-keeps-later-armory")
        for _ in 0..<900 {if game.core.sourceLoot!.pendingRoomPrograms==0 {break};game.core.stepSideRoom(1.0/60,inputs:[])}
        try save("team4-armory-source-program-complete")
        try require(game.core.sourceLoot!.roomProgramsCompleted==1 && game.core.sourceLoot!.roomFundsEmitted==17 && game.core.sourceLoot!.pendingRoomPrograms==0 && game.pickupNodes.count==game.core.pickups.count,"Four-role source armory failed to finish seventeen real gifts in the native renderer")
        fixture(15,4);game.core.phase = .cleared
        for actor in game.core.players {actor.lives=actor.slot==0 ? 8:0;actor.donationCooldown=999;if actor.slot>0 {actor.isDown=true;actor.reviveRemaining=50}}
        game.core.enterFateRoom();game.core.players[0].hero=V2(x:-3,y:-2)
        try save("team4-fate-life-high")
        let lifeModels=Array(game.fateLifeNodes.values)
        try require(lifeModels.allSatisfy{$0.childNodes.filter{$0.name=="pickup-class-marker"}.count==1},"Actual Fate life statues have coincident duplicate floor marks")
        try require(lifeModels.count==3 && game.core.players.dropFirst().allSatisfy(\.isDown),"Entry life models are missing or granted revival without physical collection")
        game.core.sideRoom!.clock=0.6;game.core.step(0,inputs:[]);try save("team4-fate-life-falling")
        game.core.sideRoom!.clock=1.31;game.core.step(0,inputs:[]);try save("team4-fate-life-landed")
        try require(game.fateLifeNodes.count==3 && game.core.fateRoom!.lifeStatues.allSatisfy(\.landed),"Ground life statues disappeared without a collector")
        game.core.players[0].hero=game.core.fateRoom!.lifeStatues[0].p;game.core.players[0].heroElevation=0;game.core.step(0,inputs:[])
        try save("team4-fate-life-award-pending")
        try require(game.core.players[1].isDown && game.core.players[1].respawnRemaining != nil && game.core.players.map(\.lives)==[9,1,0,0] && game.fateLifeNodes.count==2,"A physical life statue did not start its staged roster award")
        game.core.step(2,inputs:[]);try save("team4-fate-life-first-return")
        try require(!game.core.players[1].isDown && game.core.players[2].respawnRemaining != nil && game.core.players[3].collectedLives==0,"The next waiting role did not follow the first two-second return")
        game.core.step(2,inputs:[]);try save("team4-fate-life-second-return")
        game.core.step(2,inputs:[])
        try save("team4-fate-life-all-collected")
        try require(game.fateLifeNodes.isEmpty && lifeModels.allSatisfy{$0.parent==nil} && game.core.players.map(\.lives)==[9,2,2,2],"Collected statues leaked models or granted the wrong repeated/capped team reserves")
        game.core.sideRoom!.clock=FateRoomTiming.choiceEnd;game.core.step(0,inputs:[])
        game.core.sideRoom!.clock=FateRoomTiming.choiceEnd+FateRoomTiming.settle+FateRoomTiming.farewell;game.core.step(0,inputs:[])
        game.core.step(2.7,inputs:[])
        try save("team4-fate-life-room-cleanup")
        try require(game.core.round==16 && game.core.fateRoom==nil && game.fateLifeNodes.isEmpty,"A returned arena retained life statue state or models")
        fixture(1,2);for actor in game.core.players {actor.lives=1;game.core.withPlayer(actor.slot){game.core.invulnerable=0;game.core.loseLife()}}
        try save("team2-last-funded-bodies")
        try require(game.core.phase == .playing && game.core.players.allSatisfy(\.isDown) && game.playerArtStates.allSatisfy{$0.tileLabels[2].text?.contains("RÜCKKEHR LÄUFT")==true},"All pending funded bodies falsely ended the run or lost their short return HUD")
        game.core.stepTeamRecovery(2);try save("team2-funded-return-zero-reserve")
        try require(game.core.players.allSatisfy{!$0.isDown && $0.lives==0},"Final spare lives did not restore the last playable bodies")
        fixture(1,4);tick()
        let retired=Array(game.playerArtStates.dropFirst());fixture(1,1);tick()
        try require(game.playerArtStates.count==1 && retired.allSatisfy{$0.hero.parent==nil && $0.badge.parent==nil && $0.tile.parent==nil && $0.playerVisibility.root.parent==nil},"Removing teammates left their nodes attached")
        try require(game.stat.isHidden && !game.teamHUD.isHidden && game.playerArtStates.count==1,"Returning to solo retained team HUD state")
        // Drive setup through the same value-only path as native input, with fabricated devices.
        let key=InputDeviceStatus(token:"keyboard",name:"Tastatur",connected:true)
        let pads=(0..<4).map{InputDeviceStatus(token:"proof-pad-\($0)",name:"Synthetic pad \($0)",connected:true)}
        func menuTick(_ controls:Controls=Controls(),_ devices:[InputDeviceStatus],_ available:Int){
            game.lastTime=ProcessInfo.processInfo.systemUptime-0.02
            game.tick(players:Array(repeating:Controls(),count:devices.count),devices:devices,viewSize:CGSize(width:1600,height:900),availableControllers:available,operatorControls:controls)
        }
        func saveMenu(_ name:String)throws {
            let image=renderer.snapshot(atTime:ProcessInfo.processInfo.systemUptime,with:CGSize(width:1600,height:900),antialiasingMode:.multisampling4X)
            guard let cg=image.cgImage(forProposedRect:nil,context:nil,hints:nil),let data=NSBitmapImageRep(cgImage:cg).representation(using:.png,properties:[:]) else{throw NSError(domain:"DeadOpsTeamRender",code:3)}
            try data.write(to:output.appendingPathComponent(name+".png"),options:.withoutOverwriting);images+=1
        }
        game.core.phase = .title
        menuTick(Controls(),[key],1)
        try saveMenu("menu-title-team-entry")
        menuTick(Controls(accept:true,menuRow:2),[key],1)
        try require(game.menu.teamOpen && game.inputMailbox.routing()==InputRouting(count:2,keyboardPlayer:true) && !game.teamStartReady,"Setup did not request keyboard plus one pad")
        try saveMenu("menu-team-two-missing")
        menuTick(Controls(accept:true,menuRow:0),[key],1)
        try require(game.core.phase == .title,"An incomplete team started")
        menuTick(Controls(accept:true,menuRow:0),Array(pads.prefix(2)),2)
        try require(game.core.phase == .title,"A stale controller-only packet started a keyboard team")
        menuTick(Controls(),[key,pads[0]],1)
        try require(game.teamStartReady,"Complete keyboard team was not ready")
        try saveMenu("menu-team-two-ready")
        menuTick(Controls(accept:true,menuRow:0),[key,pads[0]],1)
        try require(game.core.playerCount==2 && game.core.phase == .playing && game.keyboardPlayer && game.playerArtStates.count==2,"Two-player setup did not create both actors")
        // Reach setup again from a completed run and choose four pads, without touching live devices.
        game.core.phase = .checkpointComplete;menuTick(Controls(),[key,pads[0]],1)
        menuTick(Controls(accept:true,menuRow:2),[key,pads[0]],1)
        menuTick(Controls(menuX:-1,menuRow:1),[key,pads[0]],1)
        try require(game.menu.teamCount==4 && game.inputMailbox.routing().count==4,"Four-player selection did not reconfigure sampling")
        let colors=game.settings.teamColors
        menuTick(Controls(menuX:1,menuRow:6),[key]+Array(pads.prefix(3)),3)
        try require(game.settings.color(for:3) != colors[3] && Set(game.settings.teamColors).count==4,"Fourth color selection failed")
        try saveMenu("menu-team-four-keyboard")
        menuTick(Controls(accept:true,menuRow:2),[key]+Array(pads.prefix(3)),3)
        menuTick(Controls(accept:true,menuRow:0),[key]+Array(pads.prefix(3)),3)
        try require(game.core.phase == .checkpointComplete && !game.teamStartReady,"Stale keyboard input started a four-controller team")
        menuTick(Controls(),pads,4)
        try require(game.teamStartReady,"Four controllers did not enable start")
        try saveMenu("menu-team-four-ready")
        menuTick(Controls(accept:true,menuRow:0),pads,4)
        try require(game.core.phase == .playing && game.core.playerCount==4 && !game.keyboardPlayer && game.playerArtStates.count==4,"Four-controller team did not start")
        menuTick(Controls(pause:true),pads,4)
        try require(game.core.phase == .paused && game.menu.count==2 && !game.menu.teamOpen,"Pause exposed destructive team setup")
        try saveMenu("menu-team-pause")
        var absent=pads;absent[2] = .missing
        menuTick(Controls(accept:true),absent,3)
        try require(game.core.phase == .paused,"Missing controller could resume the team")
        menuTick(Controls(accept:true),pads,4)
        try require(game.core.phase == .playing,"Restored controllers could not resume")
        game.core.phase = .checkpointComplete;menuTick(Controls(),pads,4)
        try saveMenu("menu-team-results-solo-entry")
        menuTick(Controls(accept:true,menuRow:0),absent,3)
        try require(game.core.phase == .playing && game.core.playerCount==1 && !game.keyboardPlayer && game.playerArtStates.count==1 && !game.teamHUD.isHidden,"Solo entry did not retire the complete old team")
        fixture(34)
        game.core.players[1].fate = .friendship;game.core.withPlayer(1){game.core.restoreFateBenefits()}
        game.core.players[2].deaths=1
        for (slot,bites) in [2,3,1,0].enumerated() {for _ in 0..<bites {game.core.withPlayer(slot){game.core.invulnerable=0;game.core.houndHit()}}}
        try save("hound-team-different-wounds")
        try require(game.playerArtStates[0].tileLabels[4].text?.contains("HUND 2/3 · ERHOLUNG")==true && game.playerArtStates[1].tileLabels[4].text?.contains("HUND 3/4 · ERHOLUNG")==true,"Personal hound damage or recovery HUD is incorrect")
        try require(game.playerArtStates[2].tileLabels[4].text?.contains("HUND 1/3")==true && game.playerArtStates[2].tileLabels[4].text?.contains("ERHOLUNG")==false,"A previous death incorrectly shows healing in the HUD")
        fixture(34,1)
        game.core.hero=V2(x:-3,y:-4);game.core.heroElevation=game.core.layout.height(game.core.hero)
        for _ in 0..<2 {game.core.invulnerable=0;game.core.houndHit()}
        try save("hound-solo-two-bites")
        try require(game.stat.text?.contains("HUND 2/3")==true && game.stat.fontColor?.isEqual(rgb(0xffb3a0))==true,"Solo hound damage is missing or illegible")
        for _ in 0..<Int(HoundRules.recoverySecondsPerBite*2*60)+1 {game.core.step(1.0/60,input:Controls())}
        try save("hound-solo-recovered")
        try require(game.stat.text?.contains("HUND")==false && game.stat.fontColor?.isEqual(rgb(0xe1f5bf))==true,"Recovered solo HUD did not clear its warning")
        fixture(25,1);game.core.hero=V2(x:-3,y:-2);game.core.heroElevation=0;game.core.invulnerable=0
        let blastID=game.core.id();game.core.barrels=[FlamingBarrel(id:blastID,p:game.core.hero+V2(x:1.85,y:0),v:.zero,elevation:0)]
        game.core.detonateBarrels([blastID]);game.core.resolveDeferredBlasts()
        try save("blast-solo-fringe")
        try require(game.core.players[0].barrelWounds==1 && game.core.deaths==0 && game.stat.text?.contains("DRUCKWELLE")==true,"Actual barrel fringe did not render its survivable injury")
        for _ in 0..<Int(PlayerDamageRules.barrelRecoverySeconds*60)+1 {game.core.step(1.0/60,input:Controls())}
        try save("blast-solo-recovered")
        try require(!game.core.hasPlayerWounds && game.stat.text?.contains("DRUCKWELLE")==false,"Actual barrel recovery retained its warning")
        fixture(30)
        game.core.withPlayer(0){game.core.invulnerable=0;game.core.applyBlastDamage(.martyrFringe)}
        game.core.withPlayer(1){game.core.invulnerable=0;game.core.applyBlastDamage(.barrelFringe)}
        game.core.withPlayer(2){game.core.deaths=1;game.core.invulnerable=0;game.core.houndHit()}
        try save("blast-team-personal-wounds")
        try require(game.playerArtStates[0].tileLabels[4].text?.contains("DRUCKWELLE")==true && game.playerArtStates[0].tileLabels[4].text?.contains("ERHOLUNG")==false,"Persistent blast injury falsely advertises recovery")
        try require(game.playerArtStates[1].tileLabels[4].text?.contains("DRUCKWELLE · ERHOLUNG")==true && game.playerArtStates[2].tileLabels[4].text?.contains("HUND 1/3")==true,"Mixed personal injury HUD crossed owners")
        fixture(34,1);game.core.hero=V2(x:-3,y:-4);game.core.heroElevation=0;game.core.invulnerable=0
        game.core.applyBlastDamage(.martyrFringe)
        try save("blast-solo-martyr-wound")
        game.core.invulnerable=0;game.core.houndHit()
        try save("blast-solo-funded-wait")
        try require(game.core.players[0].isDown && game.core.lives==3 && game.stat.text?.contains("RÜCKKEHR")==true,"Solo funded wait was not visible before spending a reserve")
        game.core.stepTeamRecovery(2)
        try save("blast-solo-mixed-respawn")
        try require(game.core.deaths==1 && game.core.lives==2 && !game.core.hasPlayerWounds && game.stat.text?.contains("DRUCKWELLE")==false,"Mixed blast/bite death did not reset its HUD and personal wounds")
        func donationFixture(_ round:Int=1){
            fixture(round,2);game.settings.cameraMode = .following;game.settings.zoom = .normal
            game.core.players[0].lives=2;game.core.players[1].lives=0
            game.core.withPlayer(1){game.core.invulnerable=0;game.core.loseLife()}
        }
        donationFixture();try save("team2-donation-search")
        try require(game.core.lifeTransfers.isEmpty && game.core.players[0].lives==2 && game.playerArtStates[1].tileLabels[0].text?.contains("60s")==true,"The initial real death did not show its sixty-second wait without an immediate donation")
        game.core.stepTeamRecovery(1.2);try save("team2-donation-link")
        try require(game.lifeLinkNodes.count==1 && game.lifeTransferNodes.isEmpty && game.core.players[0].lives==2 && game.playerArtStates[1].tileLabels[2].text?.contains("LEBENSGABE VON P1")==true,"The funded link or its donor guidance is absent before the delayed debit")
        game.core.stepTeamRecovery(1.25);try save("team2-donation-flight")
        let transfer=game.core.lifeTransfers[0],model=game.lifeTransferNodes[transfer.id]!,expected=transfer.origin+(transfer.target-transfer.origin)*transfer.flightProgress
        let projected=NativeCameraProjection.project(model.position,camera:game.camera,size:CGSize(width:1600,height:900))
        try require(game.core.players[0].lives==1 && game.core.players[0].donationsGiven==1 && game.core.players[1].donationsReceived==0 && abs(Double(model.position.x)-expected.x)<0.001 && abs(Double(model.position.z)-expected.y)<0.001 && projected.x>20 && projected.x<1580 && projected.y>150 && projected.y<750,"The actual life model is not at its production in-flight position inside the frame")
        game.core.stepTeamRecovery(0.7);try save("team2-donation-credit")
        try require(game.lifeTransferNodes.isEmpty && game.core.players[1].sponsoredRespawn && game.core.players[1].respawnRemaining != nil && game.playerArtStates[1].tileLabels[2].text?.contains("RÜCKKEHR")==true,"Arrival did not remove the travelling statue and display the short funded wait")
        game.core.stepTeamRecovery(0.8);try save("team2-donation-reward-falling")
        try require(!game.directedRewardNodes.isEmpty && game.core.players[0].bombs==1 && game.core.players[0].dashes==2 && game.core.players[0].vehicle==nil,"Compensation is missing as a physical drop or was granted instantly")
        game.core.players[0].hero = .zero;game.core.players[0].heroElevation=0
        game.core.stepTeamRecovery(2.3)
        let rewards=game.core.directedLifeRewards,kind=rewards[0].kind,amount=rewards.count
        game.core.players[0].hero=V2(x:-5,y:2)
        try save("team2-donation-reward-landed")
        try require(game.core.players.allSatisfy{!$0.isDown} && rewards.allSatisfy(\.landed) && game.directedRewardNodes.count==game.core.visibleRewardBundles.count && game.core.visibleRewardBundles[0].count==rewards.count,"The donor's logical compensation did not persist as a readable rendered bundle after its target moved away")
        game.core.players[1].hero=rewards[0].p+V2(x:1.8,y:0)
        try save("team2-donation-reward-hint")
        let rewardTitle=PickupPresentation.forKind(kind).title
        try require(game.pickupHintLabel.text?.contains("\(amount) × \(rewardTitle)")==true && game.pickupHintLabel.text?.hasPrefix("P2")==true,"The recipient's nearby hint does not identify the real compensation type and separate-item count")
        let previous=kind == .bomb ? game.core.players[1].bombs:game.core.players[1].dashes
        game.core.players[1].hero=rewards[0].p;game.core.players[1].heroElevation=rewards[0].elevation
        try save("team2-donation-reward-other-collector")
        let current=kind == .bomb ? game.core.players[1].bombs:game.core.players[1].dashes
        try require(game.core.directedLifeRewards.isEmpty && game.directedRewardNodes.isEmpty && current==min(9,previous+amount) && game.core.players[0].bombs==1 && game.core.players[0].dashes==2,"A different live teammate could not collect the physical bundle exactly once")
        fixture(2,2);try save("team2-donation-reset-cleanup")
        try require(game.lifeLinkNodes.isEmpty && game.lifeTransferNodes.isEmpty && game.directedRewardNodes.isEmpty,"A new run retained transfer or reward nodes")
        donationFixture(2);game.core.stepTeamRecovery(2.45);try save("team2-donation-flight-reversed")
        try require(game.core.viewOrientation == .reversed && game.lifeTransferNodes.count==1 && game.lifeLinkNodes.count==1,"The reversed view lost its life-transfer models")
        fixture(1,2);game.settings.cameraMode = .overview
        game.core.makeDirectedReward(for:0,kind:.bomb);game.core.stepTeamRecovery(1.31)
        let rewardPosition=game.core.directedLifeRewards[0].p
        game.core.players[0].hero=V2(x:-4,y:2);game.core.players[1].hero=V2(x:4,y:2)
        try save("team2-donation-reward-stored-island")
        game.core.round=5;game.core.beginRound();game.core.foes=[];game.core.pickups=[]
        try save("team2-donation-reward-other-map")
        try require(game.directedRewardNodes.isEmpty && game.core.directedLifeRewards.count==1,"A stored physical gift appeared in a different own map")
        game.core.round=1;game.core.beginRound();game.core.foes=[];game.core.pickups=[]
        try save("team2-donation-reward-returned-map")
        try require(game.directedRewardNodes.count==1,"Revisiting the original map failed to restore its uncollected reward model")
        let bombsBefore=game.core.players[1].bombs
        game.core.players[1].hero=rewardPosition;game.core.players[1].heroElevation=0
        try save("team2-donation-reward-stored-collected")
        try require(game.directedRewardNodes.isEmpty && game.core.directedLifeRewards.isEmpty && game.core.players[1].bombs==bombsBefore+1,"Revisited compensation did not clean up after actual physical collection")
        fixture(1,1);game.settings.cameraMode = .following;game.core.hero=V2(x:-6,y:2)
        game.core.step(0.1,input:Controls(aim:V2(x:1,y:0),dash:true));try save("boost-launch-100ms")
        try require(game.core.dashes==1 && game.core.dashTime>0.4,"Native boost launch lost its personal reserve or600ms timing")
        game.core.step(0.2,input:Controls(aim:V2(x:0,y:-1)));try save("boost-mid-300ms")
        try require(abs(game.core.hero.y-2)<0.01 && game.core.hero.x > -0.1,"Turning the gun bent the boost movement")
        game.core.step(0.31,input:Controls());try save("boost-ended-600ms")
        try require(game.core.dashTime==0 && game.core.dashes==1,"Native boost failed to finish without spending another reserve")
        for (round,kind) in [(1,FoeKind.zombie),(34,FoeKind.hound)] {
            fixture(round,1);game.settings.cameraMode = .overview
            let limit=CombatRules.enemyLimit(round:round)
            game.core.foes=(0..<limit).map{i in game.core.arrivingFoe(kind:kind,hp:999,speed:2,entrance:i%game.core.layout.enemyEntranceCount,lane:Double(i%5-2)*0.35)}
            game.core.combatSpawningHeld=false
            let budget=game.core.spawnRemaining
            game.core.stepCombatSpawns(0.01)
            try save("pressure-round-\(round)-limit-\(limit)")
            try require(game.core.activeAIEnemies==limit && game.core.spawnRemaining<budget && game.core.combatSpawnFlow!.waves.totals.rejected>0 && game.core.foes.allSatisfy{$0.arrival != nil},"At-cap native scene admitted a body or failed to consume its timed attempt")
        }
        fixture(9,1);game.core.beginVehicle(.helicopter);let boosters=game.core.dashes
        game.core.step(0.1,input:Controls(dash:true));try save("boost-refused-in-hind")
        try require(game.core.dashes==boosters && game.core.dashTime==0,"Native Hind consumed a foot booster")
        fixture(1,1);game.core.beginBodyShield();game.core.stepTeamRecovery(0.051)
        try save("shield-full-readable-body")
        try require(game.activeArt.bodyShieldNode?.isHidden==false && game.activeArt.bodyShieldNode?.parent === game.actors && game.hero.opacity==1 && game.activeArt.bodyShieldFading==false,"A full return shield hides the body or lacks its attached thin-ring model")
        game.core.stepTeamRecovery(5.6);try save("shield-last-three-seconds")
        try require(game.activeArt.bodyShieldFading==true && game.activeArt.bodyShieldNode?.isHidden==false,"Last-three-second warning did not reach the shield material")
        game.core.stepTeamRecovery(3.1);try save("shield-expired-cleanup")
        try require(game.activeArt.bodyShieldNode?.isHidden==true && game.core.playerRoster.current.bodyShield==nil,"Expired shield retained a visible model")
        fixture(1,2);game.core.hero=V2(x:-3,y:0);game.core.invulnerable=0;game.core.lives=1
        game.core.foes=[Foe(id:990001,p:V2(x:-2.7,y:0),hp:100,speed:0,gait:0),Foe(id:990002,p:V2(x:-1.5,y:0),hp:100,speed:0,gait:0)]
        game.core.loseLife();game.core.stepTeamRecovery(2)
        try require(game.core.foes.count==2 && game.core.players[0].bodyShield != nil,"Return still silently removes the old wide-radius crowd")
        let shieldScore=game.core.players[0].score
        try save("shield-return-no-wide-clear")
        game.core.step(0.06,inputs:[]);try save("shield-contact-credited-kill")
        try require(!game.core.foes.contains{$0.id==990001} && game.core.foes.contains{$0.id==990002} && game.core.players[0].score>=shieldScore+100,"Actual contact did not kill/credit the small touching foe while retaining the distant one")
        fixture(1,2);game.core.withPlayer(0){game.core.beginBodyShield()};game.core.stepTeamRecovery(6)
        game.core.withPlayer(1){game.core.beginBodyShield()};game.core.stepTeamRecovery(0.05)
        try save("shield-two-personal-phases")
        try require(game.playerArtStates[0].bodyShieldFading==true && game.playerArtStates[1].bodyShieldFading==false,"Two personal shield clocks shared one visual phase")
        try require(game.playerArtStates.allSatisfy{$0.bodyShieldNode?.parent === game.actors && $0.bodyShieldNode?.isHidden==false},"A retained shield was detached by an arena rebuild and never reattached")
        let shieldMaterials=game.playerArtStates.compactMap{$0.bodyShieldNode?.childNodes.first?.geometry?.firstMaterial}
        try require(shieldMaterials.count==2 && shieldMaterials[0] !== shieldMaterials[1],"Separate shield phases mutate shared material")
        fixture(1,4);let boostDirections=[V2(x:1,y:0),V2(x:-1,y:0),V2(x:0,y:1),V2(x:0,y:-1)]
        for player in game.core.players {game.core.withPlayer(player.slot){game.core.moveCombatPlayer(0.1,input:Controls(aim:boostDirections[player.slot],dash:true))}}
        try save("boost-four-personal-trails")
        try require(game.playerArtStates.allSatisfy{$0.boostTrailNode?.isHidden==false && $0.boostTrailNode?.parent === game.actors},"A personal boost lacks its own attached motion streak after an arena rebuild")
        try require(!game.core.effects.contains{$0.color==2},"Boost retained its ambiguous gold explosion sphere")
        game.core.step(0.6,inputs:[]);try save("boost-four-trails-expired")
        try require(game.playerArtStates.allSatisfy{$0.boostTrailNode?.isHidden==true},"Finished boost retained a motion streak")
        fixture(5,4);game.settings.cameraMode = .overview;game.core.phase = .cleared;game.core.messageTime=0
        for seed in 1...100 {game.core.exitSeed=UInt64(seed);game.core.prepareArenaExits();if game.core.arenaExits.count==3 {break}}
        game.core.clearClock=0;try save("paths-first-open")
        try require(game.arenaExitNodes.values.filter{!$0.isHidden}.count==1,"Staggered paths all appeared at once")
        game.core.clearClock=0.2;try save("paths-second-open")
        try require(game.arenaExitNodes.values.filter{!$0.isHidden}.count==2,"Second path did not open after200ms")
        game.core.clearClock=0.4;try save("paths-three-open")
        try require(game.arenaExitNodes.values.filter{!$0.isHidden}.count==3 && game.notice.text?.contains(game.core.exitInstruction)==true,"Open path models and actual direction hint disagree")
        let normalPath=game.core.availableExits.first(where:{$0.bonus==nil})!
        game.core.players[3].hero=normalPath.p;game.core.players[3].heroElevation=normalPath.height;game.core.step(0,inputs:[])
        try save("paths-transition-start")
        try require(game.core.phase == .transition,"Player four did not start a shared physical path transition")
        game.core.step(0.6,inputs:[]);try save("paths-half-fade-out")
        try require(abs(Double(game.transitCurtain.alpha)-0.5)<0.01 && game.core.round==5,"Fade-out did not preserve the previous map until black")
        game.core.step(1,inputs:[]);try save("paths-black-before-map")
        try save("paths-black-before-map-4x3",CGSize(width:1200,height:900))
        try save("paths-black-before-map-square",CGSize(width:900,height:900))
        try save("paths-black-before-map-portrait",CGSize(width:720,height:1000))
        try require(game.core.round==5 && game.core.arenaTransit?.committed==false,"Map changed before its black hold completed")
        game.core.step(1.3,inputs:[]);try save("paths-black-after-map")
        try require(game.core.round==6 && game.core.arenaTransit?.committed==true && game.core.arenaTransit!.cameraProgress>0 && game.core.arenaTransit!.cameraProgress<1,"New map and camera tween were not fully concealed")
        game.core.step(0.85,inputs:[]);try save("paths-half-fade-in")
        try require(abs(Double(game.transitCurtain.alpha)-0.5)<0.01,"New arena was not revealed over1.5s")
        game.core.step(0.75,inputs:[]);try save("paths-controls-restored")
        try require(game.core.phase == .playing && game.core.arenaTransit==nil && game.transitCurtain.isHidden,"Transition curtain or input lock survived the ready boundary")
        fixture(6,4);game.core.phase = .cleared;game.core.prepareArenaExits();game.core.clearClock=1
        game.core.requestArenaExit(game.core.availableExits.first(where:{$0.bonus==nil})!);game.core.step(0.6,inputs:[]);game.core.step(0,input:Controls(pause:true))
        try save("paths-paused-fade-4x3",CGSize(width:1200,height:900))
        try require(game.core.phase == .paused && game.title.text=="PAUSE" && !game.title.isHidden,"Pause controls were hidden beneath the transition curtain")
        fixture(4,4);game.core.phase = .cleared;game.core.prepareArenaExits();game.core.clearClock=1.5;game.core.messageTime=0
        try save("paths-pad-rising")
        try require(game.core.availableExits.isEmpty && game.arenaExitNodes.count==1,"Pad became usable before its rise finished")
        game.core.clearClock=3;try save("paths-pad-ready")
        try require(game.core.availableExits.count==1 && game.core.availableExits[0].teleporter,"Ready pad did not replace ordinary boundary paths")
        fixture(7,4);game.core.phase = .cleared;game.core.prepareArenaExits();game.core.clearClock=1;game.core.messageTime=0
        try save("paths-single-before-fourth")
        try require(game.arenaExitNodes.count==1 && game.core.sideRoomOffer==nil,"Third arena round retained extra or magic paths")
        fixture(5,4);game.settings.cameraMode = .overview;game.core.messageTime=0
        for seed in 1...30 {game.core.hazardSeed=UInt64(seed);game.core.prepareElectricHazards();if game.core.electricTraps.count==2 {break}}
        game.core.hazardClock=0.2;try save("hazards-initial-pulse")
        try require(game.trapNodes.count==2 && game.core.electricTraps.count==2,"Native hazard fixture did not create two actual generated posts")
        let originalPosts=game.trapNodes;let postIDs=originalPosts.map(ObjectIdentifier.init)
        for (trap,node) in zip(game.core.electricTraps,game.trapNodes) {
            try require(node.parent === game.decor && abs(Double(node.position.x)-trap.p.x)<0.001 && abs(Double(node.position.z)-trap.p.y)<0.001 && abs(Double(node.position.y)-trap.elevation)<0.001,"Rendered post disagrees with actual hazard or floor")
        }
        game.core.hazardClock=1;try save("hazards-lead-in-safe")
        try require(game.trapNodes.allSatisfy{$0.childNode(withName:"danger-ring",recursively:false)?.isHidden==true && $0.childNode(withName:"arcs",recursively:false)?.isHidden==true},"Safe post retained an electrical danger effect")
        game.core.hazardClock=10.6;try save("hazards-warning")
        try require(game.trapNodes.allSatisfy{$0.childNode(withName:"danger-ring",recursively:false)?.isHidden==false && $0.childNode(withName:"arcs",recursively:false)?.isHidden==true},"Red warning is missing its narrow footprint or pretends to discharge")
        game.core.hazardClock=11.8;try save("hazards-active")
        try require(game.trapNodes.allSatisfy{$0.childNode(withName:"arcs",recursively:false)?.isHidden==false},"Real discharge lacks actual visible arcs")
        try require(game.trapNodes.map(ObjectIdentifier.init)==postIDs,"Every hazard phase rebuilt its retained model")
        game.core.step(0,input:Controls(pause:true));try save("hazards-paused-4x3",CGSize(width:1200,height:900))
        try require(game.trapNodes.allSatisfy{$0.childNode(withName:"arcs",recursively:false)?.isHidden==false},"Pause erased the frozen hazard state")
        fixture(6,4);game.core.hazardClock=11.8;game.core.messageTime=0;try save("hazards-new-round")
        try require(game.trapNodes.count==game.core.electricTraps.count && !game.trapNodes.contains{node in originalPosts.contains{$0 === node}},"A new round retained stale post nodes")
        fixture(79,4);game.settings.cameraMode = .overview;game.core.messageTime=0
        for seed in 1...120 {game.core.hazardSeed=UInt64(seed);game.core.prepareElectricHazards();if game.core.electricTraps.count>=25 {break}}
        game.core.hazardClock=11.8;try save("hazards-dense-round79")
        try require(game.trapNodes.count>=25 && game.trapNodes.count==game.core.electricTraps.count,"Late native field kept four static posts or lost some generated models")
        game.core.phase = .cleared;game.core.enterSideRoom(SideRoomOffer(kind:.treasure,p:.zero));try save("hazards-safe-room-cleanup")
        try require(game.trapNodes.isEmpty && !game.decor.childNodes.contains{$0.name?.hasPrefix("hazard-")==true},"Safe room retained detached or invisible hazard nodes")
        try require(game.audio.voiceCount==0 && game.audio.playedCount==0 && game.music.playedCount==0,"Verification attempted audio output")
        print("PASS team rendering:\(images) native scenes,\(projections) projected living actors,per-owner materials/vehicles/support/HUD,role badges,waiting state,color changes,2/4-player lobby,stale-route and missing-pad start/resume gates,4-to-1 cleanup,personal hound and blast wounds/recovery HUD,timed Fate arrows/fall/claims/expiry/missed-HUD/cleanup,stored gem sizes/personal treasure bars/gem life awards/physical death gems/times9 partial bar,actual teammate armory-exit overridden by guaranteed Fate then round16 return and later retained armory,threephysicalFate life statues/fall/teamrestoration/cap/singleaward/modelcleanup,sixtysecondHUD/delayedlifelink/chargedflight/fundedreturn/physicalcompensation/othercollector/retainedmapgift/reset/reversedview;0audio,no window or real controller polling;not hardware/FPS acceptance")
    }
}
#endif
