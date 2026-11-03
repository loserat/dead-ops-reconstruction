#if os(macOS)
import Foundation
import AppKit
import SceneKit
import Metal

/// Windowless production look/HUD/temporal checks. No user preferences, audio or live input.
enum LookRenderVerification {
    static func run(_ output:URL)throws {
        setbuf(stdout,nil);try FileManager.default.createDirectory(at:output,withIntermediateDirectories:true)
        let game=ArcadeGame(view:GameView(frame:NSRect(x:0,y:0,width:1600,height:900)),defaults:nil)
        let renderer=SCNRenderer(device:MTLCreateSystemDefaultDevice(),options:nil)
        renderer.scene=game.scene;renderer.pointOfView=game.camera;renderer.overlaySKScene=game.hud
        var pictures=0,pairs=0,alphaSamples=0
        let size=CGSize(width:1600,height:900)
        func require(_ value:Bool,_ message:String)throws {if !value {throw NSError(domain:"LookProof",code:1,userInfo:[NSLocalizedDescriptionKey:message])}}
        func tick(_ dt:Double=0,_ controls:[Controls]=[]) {
            game.lastTime=ProcessInfo.processInfo.systemUptime+(dt==0 ? 1:-dt)
            game.tick(players:controls,devices:[],viewSize:size)
        }
        func fixture(_ round:Int=1,_ count:Int=1) {
            game.settings.godMode=false;game.core.godMode=false;game.settings.cameraMode = .following;game.settings.zoom = .normal
            game.core.reset(playerCount:count);game.core.round=round;game.core.beginRound();game.core.foes=[];game.core.pickups=[];game.core.combatSpawningHeld=true;game.core.messageTime=0
            for player in game.core.players {
                player.hero=game.core.layout.clamped(game.core.layout.spawn+V2(x:Double(player.slot)*1.15,y:0));player.heroElevation=game.core.layout.height(player.hero);player.invulnerable=999
            };game.lastRound=0
        }
        func capture()->CGImage {
            let image=renderer.snapshot(atTime:42,with:size,antialiasingMode:.multisampling4X)
            return image.cgImage(forProposedRect:nil,context:nil,hints:nil)!
        }
        func rgba(_ image:CGImage)->[UInt8] {
            var bytes=[UInt8](repeating:0,count:image.width*image.height*4)
            bytes.withUnsafeMutableBytes { raw in
                let context=CGContext(data:raw.baseAddress,width:image.width,height:image.height,bitsPerComponent:8,bytesPerRow:image.width*4,space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGBitmapInfo.byteOrder32Big.rawValue|CGImageAlphaInfo.premultipliedLast.rawValue)!
                context.draw(image,in:CGRect(x:0,y:0,width:image.width,height:image.height))
            };return bytes
        }
        func save(_ name:String)throws->CGImage {
            tick();let image=capture(),data=NSBitmapImageRep(cgImage:image).representation(using:.png,properties:[:])!
            try data.write(to:output.appendingPathComponent(name+".png"),options:.withoutOverwriting);pictures+=1
            print("PASS look image \(name)");return image
        }
        for round in stride(from:1,through:37,by:4) {
            fixture(round);game.settings.cameraMode = .overview
            for i in 0..<8 {game.core.foes.append(game.core.arrivingFoe(kind:.zombie,hp:999,speed:1,entrance:i%game.core.layout.enemyEntranceCount,lane:Double(i%3-1)*0.5))}
            game.core.step(1.4,inputs:[]);game.core.messageTime=0
            let a=rgba(try save("look-map-\(round)")),b=rgba(capture())
            var changed=0,total=0
            for pixel in 0..<1600*900 {
                let offset=pixel*4,d=(0..<3).map{abs(Int(a[offset+$0])-Int(b[offset+$0]))}
                if d.max()!>8 {changed+=1};total+=d.reduce(0,+)
            }
            let mean=Double(total)/Double(1600*900*3)
            try require(changed<7200 && mean<0.10,"Static production map changes without movement:round\(round),pixels\(changed),mean\(mean)")
            pairs+=1;print("PASS static pair map\(round):\(changed) changed pixels over8/255,mean\(mean)")
        }
        fixture();game.core.score=199999;_=try save("hud-life-threshold-before")
        try require(game.activeArt.hudCounters[0].text=="3" && game.activeArt.tileLabels[2].text?.contains("1 P")==true,"One point before a real extra life is not shown correctly")
        game.core.award(1);_=try save("hud-life-score-inflight")
        try require(game.activeArt.hudCounters[0].text=="3" && game.activeArt.tileLabels[2].text=="LEBENSSTATUE IM ANFLUG" && game.directedRewardNodes.count==1,"Score threshold must show a pending real statue without pre-crediting reserve")
        game.core.advanceDirectedRewards(1.3)
        let scoreStatue=game.core.directedLifeRewards[0]
        game.core.hero=scoreStatue.p+V2(x:1.6,y:0);game.core.heroElevation=game.core.layout.height(game.core.hero)
        let personalPixels=rgba(try save("hud-life-score-landed")),personalNode=game.directedRewardNodes[scoreStatue.id]!
        try require(personalNode.childNodes.filter{$0.name=="pickup-class-marker"}.count==1,"Actual score-life reward has coincident duplicate floor marks")
        try require(game.notice.text=="LEBENSSTATUE BEREIT","Global score-life notice still claims an already landed statue is falling")
        personalNode.isHidden=true;let withoutPersonal=rgba(capture());personalNode.isHidden=false
        let personalBounds=personalNode.boundingBox
        let personalRegion=[personalBounds.min.x,personalBounds.max.x].flatMap{x in [personalBounds.min.y,personalBounds.max.y].flatMap{y in [personalBounds.min.z,personalBounds.max.z].map{z in NativeCameraProjection.project(personalNode.convertPosition(SCNVector3(x,y,z),to:nil),camera:game.camera,size:size)}}}
        let px0=max(0,Int(floor(personalRegion.map{Double($0.x)}.min()!))-3),px1=min(1599,Int(ceil(personalRegion.map{Double($0.x)}.max()!))+3)
        let py0=max(0,Int(floor(900-personalRegion.map{Double($0.y)}.max()!))-3),py1=min(899,Int(ceil(900-personalRegion.map{Double($0.y)}.min()!))+3)
        var personalChanged=0
        if px0<=px1 && py0<=py1 {for y in py0...py1 {for x in px0...px1 {let p=(y*1600+x)*4;if (0..<3).contains(where:{abs(Int(personalPixels[p+$0])-Int(withoutPersonal[p+$0]))>20}) {personalChanged+=1}}}}
        try require(personalChanged>=10,"Personal score statue does not actually render visible pixels in its projected object region")
        print("PASS personal-score statue pixels:\(personalChanged)actual changed pixels,physical landed model and personal hint,one collected life only")
        try require(game.activeArt.hudCounters[0].text=="3" && game.activeArt.tileLabels[2].text=="LEBENSSTATUE BEREIT" && game.pickupHintLabel.text?.contains("PERSÖNLICH")==true,"Landed personal statue is missing a clear physical effect/readiness hint")
        game.core.hero=scoreStatue.p;game.core.heroElevation=game.core.layout.height(scoreStatue.p);game.core.collectDirectedRewards()
        _=try save("hud-life-threshold-after")
        try require(game.activeArt.hudCounters[0].text=="4" && game.activeArt.tileLabels[1].text?.contains("200.000")==true,"The real point threshold did not update the visible life/score")
        fixture();game.core.lives=0;_=try save("hud-zero-reserve-live-body")
        try require(game.activeArt.hudCounters[0].text=="0" && !game.core.playerRoster.current.isDown,"Zero reserve was confused with a missing current body")
        fixture();game.settings.godMode=true;game.core.godMode=true;game.core.trainingHits=54;_=try save("hud-godmode-negative")
        try require(game.activeArt.hudCounters[0].text=="-51" && game.activeArt.hudCounterTitles[0].text?.contains("ÜBUNG")==true,"Training loss sign or mode label is missing")
        fixture();game.core.lives=9;_=try save("hud-nine-reserves")
        try require(game.activeArt.hudCounters[0].text=="9" && game.activeArt.tileLabels[2].text=="LEBEN VOLL · 9","The reserve cap or extra-life explanation is wrong")
        fixture();game.core.invulnerable=0;game.core.loseLife();_=try save("hud-funded-return")
        try require(game.activeArt.hudCounters[0].text=="2s" && game.activeArt.tileLabels[2].text?.contains("RESERVE 3")==true,"A funded return lost its actual two-second wait or held reserve")
        fixture(5,4)
        for p in game.core.players {game.core.withPlayer(p.slot){game.core.award((p.slot+1)*1234567)};p.lives=[0,3,9,1][p.slot];p.bombs=p.slot;p.dashes=p.slot*2};game.core.messageTime=0
        _=try save("hud-four-person-counters")
        for p in game.core.players {try require(game.playerArtStates[p.slot].hudCounters[0].text==String(p.lives),"Shared HUD crossed reserve owners")}
        game.core.step(0,input:Controls(pause:true));_=try save("hud-paused-clean")
        try require(game.teamHUD.isHidden && game.roundBackdrop.isHidden && game.noticeBackdrop.isHidden,"Pause did not clear the gameplay cards")

        fixture(81);game.core.rareLifeTimer=RareLifeTimer(baseWait:240)
        game.core.stepRareLifeTimer(270,combatStartClock:0)
        guard let rare=game.core.pickups.first(where:{$0.sourcePowerupTimeout}) else{throw NSError(domain:"LookProof",code:10)}
        game.core.hero=game.core.layout.clamped(rare.p+V2(x:1.6,y:0));game.core.heroElevation=game.core.layout.height(game.core.hero)
        let steady=rgba(try save("life-rare-steady")),lifeNode=game.pickupNodes[rare.id]!
        let bounds=lifeNode.boundingBox
        let region=[bounds.min.x,bounds.max.x].flatMap{x in [bounds.min.y,bounds.max.y].flatMap{y in [bounds.min.z,bounds.max.z].map{z in NativeCameraProjection.project(lifeNode.convertPosition(SCNVector3(x,y,z),to:nil),camera:game.camera,size:size)}}}
        game.core.stepPickupLifetimes(12.9)
        let dark=rgba(try save("life-rare-flashing-dark"))
        try require(game.core.pickups.contains(where:{$0.id==rare.id}) && game.pickupNodes[rare.id]?.opacity==0 && game.pickupHintLabel.text?.contains("LÄUFT AB")==true,"Dark-phase rare life vanished from the world or lost its expiry hint")
        let x0=max(0,Int(floor(region.map{Double($0.x)}.min()!))-3),x1=min(1599,Int(ceil(region.map{Double($0.x)}.max()!))+3)
        let y0=max(0,Int(floor(900-region.map{Double($0.y)}.max()!))-3),y1=min(899,Int(ceil(900-region.map{Double($0.y)}.min()!))+3)
        var lifePixels=0
        if x0<=x1 && y0<=y1 {for y in y0...y1 {for x in x0...x1 {
            let p=(y*1600+x)*4
            if (0..<3).contains(where:{abs(Int(steady[p+$0])-Int(dark[p+$0]))>20}) {lifePixels+=1}
        }}}
        try require(lifePixels>=10,"Rare-life steady/flash states did not change ten actual pixels in the item region")
        let reserve=game.core.lives;game.core.hero=rare.p;game.core.heroElevation=game.core.layout.height(rare.p);game.core.collectNearbyPickups()
        _=try save("life-collected-during-flash")
        try require(game.core.lives==reserve+1 && !game.core.pickups.contains(where:{$0.id==rare.id}) && game.pickupNodes[rare.id]==nil,"A physically touching player cannot collect a dark-phase rare life exactly once")
        print("PASS rare-life expiry pixels:\(lifePixels) actual changed pixels,27.5s local lifetime,dark-phase world collectible and one real reserve award")

        // Ordinary weapons/gems must visibly blink while remaining physically collectible.
        func itemPixels(_ node:SCNNode,_ before:[UInt8],_ after:[UInt8])->Int {
            let box=node.boundingBox
            let corners=[box.min.x,box.max.x].flatMap{x in [box.min.y,box.max.y].flatMap{y in [box.min.z,box.max.z].map{z in NativeCameraProjection.project(node.convertPosition(SCNVector3(x,y,z),to:nil),camera:game.camera,size:size)}}}
            let left=max(0,Int(floor(corners.map{Double($0.x)}.min()!))-3),right=min(1599,Int(ceil(corners.map{Double($0.x)}.max()!))+3)
            let top=max(0,Int(floor(900-corners.map{Double($0.y)}.max()!))-3),bottom=min(899,Int(ceil(900-corners.map{Double($0.y)}.min()!))+3)
            guard left<=right,top<=bottom else{return 0}
            var count=0
            for y in top...bottom {for x in left...right {let offset=(y*1600+x)*4
                if (0..<3).contains(where:{abs(Int(before[offset+$0])-Int(after[offset+$0]))>20}) {count+=1}
            }};return count
        }
        for kind in [PickupKind.ray,.gem] {
            fixture();game.settings.cameraMode = .overview
            let item=game.core.worldPickup(id:90000+kind.rawValue,p:game.core.hero+V2(x:1.6,y:0),kind:kind,gemUnits:256)
            game.core.pickups=[item]
            let bright=rgba(try save("pickup-\(kind)-steady")),node=game.pickupNodes[item.id]!
            game.core.stepPickupLifetimes(kind == .gem ? 25:12.9)
            let hidden=rgba(try save("pickup-\(kind)-blink-dark")),changed=itemPixels(node,bright,hidden)
            try require(changed>=10 && game.pickupNodes[item.id]?.opacity==0 && game.core.pickups.count==1,"Ordinary \(kind) does not actually disappear during the source blink in its projected model region")
            if kind == .ray {try require(game.pickupHintLabel.text?.contains("LÄUFT AB")==true,"Expiring ordinary weapon lost its visible warning")}
            let score=game.core.score
            game.core.hero=item.p;game.core.heroElevation=game.core.layout.height(item.p);game.core.collectNearbyPickups()
            _=try save("pickup-\(kind)-dark-collected")
            try require(game.core.pickups.isEmpty && game.pickupNodes[item.id]==nil && (kind == .gem ? game.core.score==score+625:game.core.weapon == .ray),"A dark-phase \(kind) cannot be physically collected with its actual reward")
            print("PASS ordinary \(kind) expiry:\(changed)actual model-region pixels,real dark contact and once-only reward")
        }
        fixture();let warm=game.core.worldPickup(id:90100,p:game.core.hero,kind:.life);game.core.pickups=[warm]
        game.core.collectNearbyPickups();_=try save("pickup-life-contact-warming")
        try require(game.core.lives==3 && game.pickupNodes[warm.id] != nil,"A newly visible life bypassed its actual contact warmup")
        game.core.stepPickupLifetimes(0.4);game.core.collectNearbyPickups();_=try save("pickup-life-contact-ready")
        try require(game.core.lives==4 && game.pickupNodes[warm.id]==nil && game.activeArt.hudCounters[0].text=="4","Ready physical life did not update both model and real reserve HUD")
        fixture();game.settings.cameraMode = .overview
        let gold=game.core.worldPickup(id:90200,p:game.core.hero+V2(x:1.6,y:0),kind:.treasure,lifetime:.untilCleanup)
        game.core.pickups=[gold];game.core.stepPickupLifetimes(1000)
        let goldPixels=rgba(try save("pickup-special-gold-untimed")),goldNode=game.pickupNodes[gold.id]!
        goldNode.isHidden=true;let withoutGold=rgba(capture());goldNode.isHidden=false
        let goldChanged=itemPixels(goldNode,goldPixels,withoutGold)
        try require(goldChanged>=10 && goldNode.opacity==1 && game.core.pickups.count==1,"Untimed special-event gold failed to render after prolonged world aging")
        print("PASS untimed special gold:\(goldChanged)actual visible model pixels after1000s,independent from rare static equipment")

        fixture(17);game.core.hero=V2(x:-2,y:-2);game.core.heroElevation=0
        game.core.bulls=[Bull(id:90300,p:V2(x:0,y:1),direction:V2(x:1,y:0),golden:true)]
        game.core.explodeBulls(at:V2(x:0,y:1),radius:2)
        _=try save("golden-bull-source-first")
        try require(game.core.pickups.count==2 && game.pickupNodes.count==2 && game.core.sourceLoot!.pendingChildren==2,"Golden bull still renders an instant fixed twelve-item ring")
        let firstPopupID=game.core.pickups.first{$0.popup != nil}!.id
        game.core.stepWorldLoot(0.6)
        let airbornePixels=rgba(try save("golden-bull-source-airborne")),popupNode=game.pickupNodes[firstPopupID]!
        let airborneFund=game.core.pickups.first{$0.id==firstPopupID}!
        try require(Double(popupNode.position.y)>game.core.layout.height(airborneFund.p)+3 && !airborneFund.readyForContact,"Actual popup model has no visible elevated flight or unlocks before its source trigger deadline")
        popupNode.isHidden=true;let withoutPopup=rgba(capture());popupNode.isHidden=false
        let popupPixelCount=itemPixels(popupNode,airbornePixels,withoutPopup)
        try require(popupPixelCount>=10,"The airborne golden-bull gem has no measurable native model pixels")
        game.core.stepWorldLoot(1.9);_=try save("golden-bull-source-complete")
        let specialGoldCount=game.core.pickups.filter{$0.kind == .treasure}.count
        let specialTreasureChildren=game.core.pickups.filter{$0.popup==nil}.count
        let specialGemCount=game.core.pickups.filter{$0.popup != nil}.count
        try require((5...9).contains(specialTreasureChildren) && (4...12).contains(specialGemCount) && game.pickupNodes.count==game.core.pickups.count,"Actual source golden-bull reward counts or native models disagree")
        // Isolate the real oldest item so neighboring money cannot hide a false early collection.
        game.core.pickups.removeAll{$0.id != firstPopupID};game.core.hero=game.core.pickups[0].p;game.core.heroElevation=game.core.layout.height(game.core.hero)
        let specialScore=game.core.score,specialUnits=game.core.pickups[0].gemUnits!
        game.core.stepPickupLifetimes(0.599);game.core.collectNearbyPickups();_=try save("golden-bull-source-contact-locked")
        try require(game.core.pickups.count==1 && game.pickupNodes[firstPopupID] != nil && game.core.score==specialScore,"Native popup fixture collected its real gem before3seconds after launch")
        game.core.stepPickupLifetimes(0.001);game.core.collectNearbyPickups();_=try save("golden-bull-source-collected")
        try require(game.core.pickups.isEmpty && game.pickupNodes[firstPopupID]==nil && game.core.score==specialScore+625 && game.core.multiplierCharge==Double(specialUnits)/512,"Unlocked popup failed one physical score/meter collection and native model removal")
        print("PASS source golden-bull renderer:\(specialTreasureChildren)treasurechildren,\(specialGoldCount)ordinarytreasures,\(specialGemCount)quartergems,\(popupPixelCount)airbornemodelpixels,3secondtriggerlock,onephysicalcollection;own flight scale/physics")

        fixture(9,4)
        for p in game.core.players {p.hero=game.core.layout.clamped(V2(x:Double(p.slot)*3-4,y:-2));p.heroElevation=game.core.layout.height(p.hero)}
        game.core.withPlayer(0){game.core.apply(.helicopter);game.core.weapon = .ray;game.core.weaponReserve=17}
        game.core.withPlayer(1){game.core.apply(.tank)}
        game.core.withPlayer(2){game.core.apply(.helicopter)}
        game.core.finishCombatSpawning();game.core.foes=[Foe(id:90301,p:V2(x:10,y:0),hp:999,speed:0,gait:0)]
        _=try save("prison-hind-before-last-enemy")
        try require(game.core.phase == .playing && game.playerArtStates[0].vehicleNode != nil && game.playerArtStates[2].vehicleNode != nil,"Prison Hinds disappeared while the final foe was still alive")
        game.core.foes=[];_=try save("prison-hind-after-round-cleanup")
        try require(game.core.phase == .cleared && [0,2].allSatisfy{game.core.players[$0].vehicle==nil && game.playerArtStates[$0].vehicleNode==nil && !game.playerArtStates[$0].hero.isHidden && game.playerArtStates[$0].hero.opacity==1},"Real prison cleanup did not restore both opaque player models after deleting their Hinds")
        try require(game.core.players[1].vehicle?.kind == .tank && game.playerArtStates[1].vehicleNode != nil && game.core.players[0].weapon == .ray && game.core.players[0].weaponReserve==17,"Prison cleanup changed another vehicle or lost the pilot's stored weapon")
        print("PASS source prison Hind renderer:twoactivepilotskeptuntilfinalfoe,twovehiclesremovedatrealroundcleanup,tankandhandweaponpreserved,fouropaqueplayers")

        fixture(5);game.core.phase = .cleared
        game.core.enterSideRoom(SideRoomOffer(kind:.treasure,p:game.core.layout.sideRoute(onLeft:true)))
        _=try save("pickup-bonus-room-fresh")
        let initialRoomFunds=game.core.pickups.count
        try require(game.pickupNodes.count==initialRoomFunds && initialRoomFunds<=4 && game.core.sourceLoot!.roomProgramsStarted==1,"Bonus entry did not render the actual early source sequence")
        for _ in 0..<120 {game.core.stepSideRoom(1.0/60,inputs:[])}
        _=try save("pickup-bonus-room-growing")
        try require(game.pickupNodes.count==game.core.pickups.count && game.pickupNodes.count>initialRoomFunds,"Staggered source bonus globs did not grow into visible native models")
        for _ in 0..<1800 {if game.core.sourceLoot!.pendingChildren==0 {break};game.core.stepSideRoom(1.0/60,inputs:[])}
        _=try save("pickup-bonus-room-complete")
        let completeRoomFunds=game.core.pickups.count
        try require(game.core.sourceLoot!.pendingChildren==0 && game.core.sourceLoot!.clusterStarts==25 && completeRoomFunds>=75 && game.pickupNodes.count==completeRoomFunds,"Completed source room does not render its actual twenty-five globs and equipment gifts")
        let finalOrdinary=game.core.pickups.filter{$0.kind != .gem}.map(\.ttl).max()!
        game.core.stepSideRoom(finalOrdinary+0.01,inputs:[]);_=try save("pickup-bonus-room-gems-remain")
        try require(game.pickupNodes.count==game.core.pickups.count && game.core.pickups.allSatisfy{$0.kind == .gem},"Room renderer retained ordinary source funds past their own deadlines")
        game.core.stepSideRoom(40,inputs:[]);_=try save("pickup-bonus-room-expired")
        try require(game.pickupNodes.isEmpty && game.core.phase == .bonusRoom,"Fully expired source-room funds still have native models")
        print("PASS source room renderer:\(initialRoomFunds)entrymodels,\(completeRoomFunds)completedmodels,25globs,real staggered growth,own expiry deadlines,0finalmodels;no guaranteed four-gem preset")

        fixture();game.core.phase = .cleared;game.core.clearClock=4;game.core.prepareArenaExits()
        let pickupExit=game.core.availableExits.first(where:{$0.bonus==nil})!
        game.core.hero=pickupExit.p;game.core.heroElevation=pickupExit.height
        let fadeFund=game.core.worldPickup(id:90300,p:game.core.hero,kind:.life),fadePosition=game.core.hero,fadeBombs=game.core.bombs
        game.core.pickups=[fadeFund];game.core.requestArenaExit(pickupExit)
        _=try save("pickup-fade-life-warming")
        try require(game.core.lives==3 && game.pickupNodes[fadeFund.id] != nil,"Fade-contact fixture lost the newly visible life before it was ready")
        game.core.step(0.5,input:Controls(move:V2(x:1,y:0),bomb:true));_=try save("pickup-fade-life-awarded")
        try require(game.core.phase == .transition && game.core.lives==4 && game.pickupNodes[fadeFund.id]==nil && game.core.hero==fadePosition && game.core.bombs==fadeBombs,"Real fade contact removed its model without crediting the life or executed locked combat input")
        print("PASS native fade life:physical warmup,one real reserve,model removed,locked position/resources")

        // New global producers must reach the actual renderer through ordinary combat frames.
        fixture(10);game.settings.cameraMode = .overview;game.core.combatSpawningHeld=false
        game.core.sourceLoot=SourceLootDirector(random:{0})
        for _ in 0..<599 {game.core.step(1.0/60,input:Controls())}
        _=try save("loot-source-before-first-deadline")
        try require(game.core.pickups.isEmpty && game.pickupNodes.isEmpty,"Global source funds appeared before the first ten-second deadline")
        for _ in 599..<720 {game.core.step(1.0/60,input:Controls())}
        _=try save("loot-source-both-streams-born")
        guard let actualFund=game.core.pickups.first(where:{$0.kind != .treasure && $0.kind != .gem}) else{throw NSError(domain:"LookProof",code:54,userInfo:[NSLocalizedDescriptionKey:"Real combat frames did not create a source equipment fund"])}
        try require(game.core.sourceLoot!.powerups.completed==1 && game.core.sourceLoot!.prizes.completed==1 && game.pickupNodes.count==game.core.pickups.count,"Real global producer streams did not create their actual native world models")
        game.core.combatSpawningHeld=true;game.core.foes=[];game.core.sourceLoot!.clearArenaChildren();game.core.pickups=[actualFund]
        game.core.hero=game.core.layout.clamped(actualFund.p+V2(x:1.6,y:0));game.core.heroElevation=game.core.layout.height(game.core.hero)
        let sourceBright=rgba(try save("loot-source-equipment-steady")),sourceNode=game.pickupNodes[actualFund.id]!
        game.core.stepWorldLoot(max(0,12.9-actualFund.age))
        let sourceDark=rgba(try save("loot-source-equipment-blink-dark")),sourcePixels=itemPixels(sourceNode,sourceBright,sourceDark)
        try require(sourcePixels>=10 && game.pickupNodes[actualFund.id]?.opacity==0 && game.core.pickups.contains(where:{$0.id==actualFund.id}),"A real source-produced equipment fund failed its native expiry blink")
        let collected=game.core.collectedWorldFunds
        game.core.hero=actualFund.p;game.core.heroElevation=game.core.layout.height(actualFund.p);game.core.collectNearbyPickups()
        _=try save("loot-source-equipment-physically-collected")
        try require(game.pickupNodes[actualFund.id]==nil && game.core.collectedWorldFunds==collected+1,"Actual source equipment did not leave the renderer after exactly one physical collection")
        print("PASS real source loot renderer:720ordinarycombatframes,oneequipment/oneprizestream,\(sourcePixels)actualequipmentblinkpixels,onephysicalcollection;no fabricated kill drop")

        // Synthetic asymmetric cutout: check actual rendered alpha against CPU ray masks.
        fixture();game.settings.cameraMode = .overview;tick()
        let data=Data([255,0,0,255, 255,0,0,0, 255,0,0,0, 255,0,0,255] as [UInt8])
        let image=CGImage(width:2,height:2,bitsPerComponent:8,bitsPerPixel:32,bytesPerRow:8,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGBitmapInfo(rawValue:CGImageAlphaInfo.last.rawValue),provider:CGDataProvider(data:data as CFData)!,decode:nil,shouldInterpolate:false,intent:.defaultIntent)!
        let leaf=SCNMaterial();leaf.lightingModel = .constant;game.configureFoliageCutout(leaf,image:image)
        for p in [leaf.diffuse,leaf.transparent] {p.minificationFilter = .nearest;p.magnificationFilter = .nearest;p.mipFilter = .none}
        let plane=SCNNode(geometry:SCNPlane(width:4,height:4));plane.geometry!.materials=[leaf];plane.eulerAngles.x = -NodeFloat.pi/2;plane.position.y=4.6;plane.castsShadow=false;game.scene.rootNode.addChildNode(plane)
        let back=SCNNode(geometry:SCNPlane(width:6,height:6));let blue=material(0x0000ff);blue.lightingModel = .constant;back.geometry!.materials=[blue];back.eulerAngles.x = -NodeFloat.pi/2;back.position.y=4.4;back.castsShadow=false;game.scene.rootNode.addChildNode(back)
        let pixels=rgba(try save("look-cutout-mask-probe")),mask=game.foliageMasks[ObjectIdentifier(leaf)]!
        for x in [-1.0,1] {for z in [-1.0,1] {
            let target=SCNVector3(x,4.6,z),projected=NativeCameraProjection.project(target,camera:game.camera,size:size)
            let hits=game.scene.rootNode.hitTestWithSegment(from:game.camera.worldPosition,to:SCNVector3(x,4.59,z),options:nil)
            guard let hit=hits.first(where:{$0.node === plane}) else{throw NSError(domain:"LookProof",code:2,userInfo:[NSLocalizedDescriptionKey:"Missing actual cutout UV hit"])}
            let expected=mask.isOpaque(at:hit.textureCoordinates(withMappingChannel:0))
            let px=max(0,min(1599,Int(projected.x))),py=max(0,min(899,899-Int(projected.y))),offset=(py*1600+px)*4
            let red=Int(pixels[offset]),blue=Int(pixels[offset+2]),opaque=red>blue+80
            try require(expected==opaque,"CPU foliage alpha disagrees with actual pixel:uv\(hit.textureCoordinates(withMappingChannel:0)),red\(red),blue\(blue),expected\(expected)")
            alphaSamples+=1
        }}
        // Flattening merges materials: the actual hit element must select the leaf, not material zero.
        let combined=SCNNode(),solid=SCNNode(geometry:SCNBox(width:0.1,height:0.1,length:0.1,chamferRadius:0))
        solid.geometry!.materials=[blue];solid.position=SCNVector3(9,5,0);combined.addChildNode(solid)
        plane.removeFromParentNode();combined.addChildNode(plane)
        let flattened=combined.flattenedClone();game.decor.addChildNode(flattened)
        _=capture() // Commit the new renderer tree before querying the replacement geometry.
        var leafHits=0
        for x in [-1.0,1] {for z in [-1.0,1] {
            let hits=game.scene.rootNode.hitTestWithSegment(from:game.camera.worldPosition,to:SCNVector3(x,4.59,z),options:[SCNHitTestOption.searchMode.rawValue:SCNHitTestSearchMode.all.rawValue])

            guard let hit=hits.first(where:{abs(Double($0.worldCoordinates.y)-4.6)<0.01 && abs(Double($0.worldCoordinates.x))<2 && abs(Double($0.worldCoordinates.z))<2}),let mat=game.hitMaterial(hit),let actualMask=game.foliageMask(for:mat) else{throw NSError(domain:"LookProof",code:3,userInfo:[NSLocalizedDescriptionKey:"Merged foliage lost its actual hit-element material/mask: hits \(hits.map{String(describing:$0.node.name)+"/"+String($0.geometryIndex)+"/"+String(describing:game.hitMaterial($0)?.name)})"])}
            try require(actualMask.isOpaque(at:hit.textureCoordinates(withMappingChannel:0))==mask.isOpaque(at:hit.textureCoordinates(withMappingChannel:0)),"Merged canopy reads the wrong alpha mask")
            leafHits+=1
        }}
        try require(leafHits==4,"Missing flattened material hits")
        back.removeFromParentNode();_=capture()
        let savedCamera=game.camera.transform,source=SCNNode()
        var solidSamples=0,clearSamples=0
        for x in [-1.0,1] {for z in [-1.0,1] {
            source.position=SCNVector3(x,0,z);game.camera.position=SCNVector3(x,20,z)
            let hits=game.decor.hitTestWithSegment(from:game.camera.worldPosition,to:SCNVector3(x,4.59,z),options:nil)
            guard let hit=hits.first,let mat=game.hitMaterial(hit),let actualMask=game.foliageMask(for:mat) else{throw NSError(domain:"LookProof",code:4,userInfo:[NSLocalizedDescriptionKey:"Vertical map query:camera\(game.camera.worldPosition),hits\(hits.map{String(describing:$0.node.name)+"/"+String(describing:game.hitMaterial($0)?.name)})"])}
            let opaque=actualMask.isOpaque(at:hit.textureCoordinates(withMappingChannel:0)),blocked=game.playerVisibility.blockedSamples(game:game,source:source)
            try require(blocked==(opaque ? 3:0),"Production visibility misreads merged canopy:opaque\(opaque),blocked\(blocked)")
            if opaque {solidSamples+=1}else{clearSamples+=1}
        }}
        try require(solidSamples==2 && clearSamples==2,"Canopy visibility fixture did not test both clear and solid regions")
        print("PASS actual merged-canopy visibility:2clear regions with0blocked rays,2solid regions with3blocked rays")
        game.camera.transform=savedCamera;flattened.removeFromParentNode()
        let cachedMaskCount=game.foliageMasksByImage.count
        fixture(33);tick();fixture(1);tick()
        let retainedPalm=game.artMaterials["textured-palm-crown"]!
        try require(game.foliageMasks[ObjectIdentifier(retainedPalm)] != nil && game.foliageMasksByImage.count==cachedMaskCount,"Changing arenas discarded or reallocated retained canopy masks")
        fixture();game.core.hero=V2(x:-6,y:0);tick()
        var last=game.cameraRig.center,lastScale=game.cameraRig.scale
        for frame in 0...120 {
            if frame>0 {tick(1.0/60,[Controls(move:V2(x:1,y:0))])}
            try require((game.cameraRig.center-last).length<0.15 && abs(game.cameraRig.scale-lastScale)<0.15,"Whole-map camera makes an abrupt step during ordinary movement")
            last=game.cameraRig.center;lastScale=game.cameraRig.scale
            if frame%10==0 {_=try save(String(format:"look-tracking-%03d",frame))}
        }
        try require(game.cameraRig.center==last && game.core.hero.x>6,"Whole-map center drifted during actual player movement")
        var stampedeSides=Set<EntrySide>(),stampedeRays=0
        for attempt in 0..<64 where stampedeSides.count<4 {
            fixture(18);game.settings.cameraMode = .overview
            for _ in 0..<attempt {_=game.core.random()}
            game.core.bullClock=0;game.core.stepStampede(0)
            guard let bull=game.core.bulls.first else{throw NSError(domain:"LookProof",code:60)}
            let side:EntrySide=abs(bull.p.x)>abs(bull.p.y) ? (bull.p.x<0 ? .west:.east):(bull.p.y<0 ? .north:.south)
            guard stampedeSides.insert(side).inserted else{continue}
            game.core.stampede?.stop();tick();_=capture()
            let lateral=V2(x:-bull.direction.y,y:bull.direction.x)
            let landing=game.core.layout.enemyArrival(index:game.core.layout.entrance(on:side,roll:0)).end.p
            for offset in [-0.64,0,0.64] {for height in [0.4,0.9,1.35] {
                let a=bull.p+lateral*offset,z=landing+lateral*offset
                let hits=game.decor.hitTestWithSegment(from:SCNVector3(a.x,height,a.y),to:SCNVector3(z.x,height,z.y),options:[SCNHitTestOption.backFaceCulling.rawValue:false])
                try require(hits.isEmpty,"Native bull body route crosses solid market decoration:side\(side),offset\(offset),height\(height)");stampedeRays+=1
            }}
            _=try save("stampede-\(side)-outside")
            let initial=game.core.bulls[0].p
            game.core.stepStampede(2+max(0,-bull.age));_=try save("stampede-\(side)-entering")
            try require(game.core.bulls.count==1 && game.core.layout.contains(game.core.bulls[0].p) && game.core.bulls[0].p != initial && game.bullNodes[bull.id] != nil,"Actual world traveller/model did not fully enter through its native market lane")
            game.core.stepStampede(3);_=try save("stampede-\(side)-midpoint")
            let node=game.bullNodes[bull.id]!,body=game.core.bulls[0]
            try require(abs(Double(node.position.x)-body.p.x)<1e-5 && abs(Double(node.position.z)-body.p.y)<1e-5 && body.p.length<1e-5,"Native cow model diverged from its actual five-second world midpoint")
        }
        try require(stampedeSides.count==4 && stampedeRays==36,"Stampede proof did not exercise all four real source-directed world entrances")
        print("PASS native source stampede:4actual source-directed entrances,36body-width/height rays through real decoration,12actual outside/entering/midpoint frames,10second endpoint semantics pure-checked;no arbitrary fixture herd")
        for kind in VehicleKind.allCases {
            fixture(5);game.settings.cameraMode = .following
            game.core.hero=V2(x:4,y:3);game.core.heroElevation=0;game.core.invulnerable=0
            game.core.beginVehicle(kind);_=try save("vehicle-\(kind)-before-exit")
            let origin=game.core.hero
            game.core.foes=[Foe(id:95001,p:origin+V2(x:1,y:0),hp:2,speed:0,gait:0),Foe(id:95002,p:origin+V2(x:2.5,y:0),hp:2,speed:0,gait:0)]
            game.core.vehicle!.remaining=0.001;game.core.step(0.002,input:Controls())
            if kind == .helicopter {
                try require(game.core.vehicle?.landingTarget != nil && !game.core.effects.contains{$0.color==8},"Hind emitted its ground pulse before actually completing safe landing")
                _=try save("vehicle-helicopter-landing")
                for _ in 0..<120 where game.core.vehicle != nil {game.core.step(1.0/60,input:Controls())}
            }else {_=try save("vehicle-tank-pulse-birth")}
            try require(game.core.vehicle==nil && game.core.playerRoster.current.bodyShield != nil && !game.core.foes.contains{$0.id==95001} && game.core.foes.contains{$0.id==95002},"Actual vehicle exit failed its separate close pulse,far survivor or short shield")
            game.core.step(0.12,input:Controls())
            let pixels=rgba(try save("vehicle-\(kind)-pulse-visible"))
            let pulse=game.core.effects.first{$0.color==8}!,node=game.effectNodes[pulse.id]!
            try require(node.name=="vehicle-exit-pulse" && game.activeArt.vehicleNode==nil && game.activeArt.hero.opacity==1,"Exited pilot retained its vehicle or lost its actual opaque body/pulse model")
            node.isHidden=true;let without=rgba(capture());node.isHidden=false
            let visible=itemPixels(node,pixels,without)
            try require(visible>=10,"Actual pale ground pulse has too few native model pixels to be readable")
            game.core.step(0.4,input:Controls());_=try save("vehicle-\(kind)-short-shield")
            try require(!game.core.effects.contains{$0.color==8} && game.effectNodes[pulse.id]==nil && game.core.damageProtected,"Pulse model must end before the separate short shield")
            game.core.foes=[];game.core.step(3.1,input:Controls());_=try save("vehicle-\(kind)-shield-ended")
            try require(game.core.playerRoster.current.bodyShield==nil && !game.core.damageProtected,"Exited pilot's short shield did not expire in real shared frames")
            print("PASS native vehicle exit \(kind):\(visible)pulse pixels,actual timer/landing,close defeat/far survivor,opaque returned body,once-only ground pulse and separate3.05s shield")
        }
        fixture(9,4);game.core.withPlayer(0){game.core.beginVehicle(.helicopter)};game.core.withPlayer(1){game.core.beginVehicle(.tank)};game.core.withPlayer(2){game.core.beginVehicle(.helicopter)}
        game.core.foes=[];game.core.finishCombatSpawning();game.core.step(0,inputs:[]);_=try save("vehicle-prison-two-pilot-exits")
        try require(game.playerArtStates[0].vehicleNode==nil && game.playerArtStates[2].vehicleNode==nil && game.playerArtStates[1].vehicleNode != nil && game.core.effects.filter{$0.color==8}.count==2,"Real prison cleanup did not render exactly two independent pilot returns while retaining the tank")
        try require(!game.camera.camera!.wantsExposureAdaptation && game.audio.playedCount==0 && game.music.playedCount==0,"Look proof enabled exposure pumping or audio")
        pictures += try FlameBurnRenderVerification.run(output)
        pictures += try TeslaRenderVerification.run(output)
        pictures += try OrbRetirementRenderVerification.run(output)
        print("PASS look rendering:\(pictures)images,\(pairs)static-map pairs,\(alphaSamples)actual alpha/UV pixel matches,121trackingframes,physical score-life in-flight/landed/personal-hint/collection and real thresholds/zero/negative/cap/return/team counters,and actual M2burn clocks;0audio,no window or native input;not hardware/windowFPS acceptance")
    }
}
#endif
