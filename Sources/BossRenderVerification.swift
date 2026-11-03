#if os(macOS)
import Foundation
import AppKit
import SceneKit
import Metal

/// Controlled, windowless views of the actual new boss path. No normal startup or devices.
enum BossRenderVerification {
    static func run(_ output:URL)throws {
        setbuf(stdout,nil);try FileManager.default.createDirectory(at:output,withIntermediateDirectories:true)
        let size=CGSize(width:1600,height:900)
        let game=ArcadeGame(view:GameView(frame:NSRect(origin:.zero,size:size)),defaults:nil)
        let renderer=SCNRenderer(device:MTLCreateSystemDefaultDevice(),options:nil)
        renderer.scene=game.scene;renderer.pointOfView=game.camera;renderer.overlaySKScene=game.hud
        var pictures=0
        func require(_ ok:Bool,_ text:String)throws {if !ok {throw NSError(domain:"BossRender",code:1,userInfo:[NSLocalizedDescriptionKey:text])}}
        func tick(){game.lastTime=ProcessInfo.processInfo.systemUptime+1;game.tick(players:[],devices:[],viewSize:size)}
        func fixture(_ round:Int=80,_ players:Int=1) {
            game.settings.godMode=true;game.settings.cameraMode = .overview;game.settings.zoom = .normal
            game.core.godMode=true;game.core.reset(playerCount:players);game.core.round=round;game.core.beginRound()
            game.core.foes=[];game.core.pickups=[];game.core.finishCombatSpawning();game.core.step(0,input:Controls())
            for p in game.core.players {p.hero=game.core.layout.clamped(V2(x:-6+Double(p.slot),y:-3));p.heroElevation=game.core.layout.height(p.hero)}
            game.lastRound=0
        }
        func advance(_ duration:Double) {
            let frames=Int(floor(duration*60))
            for _ in 0..<frames {game.core.step(1.0/60,inputs:[])}
            let rest=duration-Double(frames)/60;if rest>1e-10 {game.core.step(rest,inputs:[])}
        }
        func save(_ name:String)throws->[UInt8] {
            tick()
            let rendered=renderer.snapshot(atTime:42,with:size,antialiasingMode:.multisampling4X)
            guard let cg=rendered.cgImage(forProposedRect:nil,context:nil,hints:nil),let png=NSBitmapImageRep(cgImage:cg).representation(using:.png,properties:[:]) else{throw NSError(domain:"BossRender",code:2)}
            try png.write(to:output.appendingPathComponent(name+".png"),options:.withoutOverwriting);pictures+=1
            var bytes=[UInt8](repeating:0,count:cg.width*cg.height*4)
            bytes.withUnsafeMutableBytes {raw in
                let ctx=CGContext(data:raw.baseAddress,width:cg.width,height:cg.height,bitsPerComponent:8,bytesPerRow:cg.width*4,space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGBitmapInfo.byteOrder32Big.rawValue|CGImageAlphaInfo.premultipliedLast.rawValue)!
                ctx.draw(cg,in:CGRect(x:0,y:0,width:cg.width,height:cg.height))
            }
            print("PASS boss image \(name)");return bytes
        }
        fixture();advance(1.1);let fade=try save("boss-intro-fade-in")
        try require(!game.bossIntroHUD.isHidden && abs(game.bossIntroTitle.alpha-0.5)<0.001 && abs(game.bossIntroSubtitle.alpha-0.4)<0.001 && game.core.silverbacks.isEmpty,"Introduction omitted its separate title/subtitle fades or created an early boss")
        advance(1.5);let hold=try save("boss-intro-hold")
        try require(abs(game.bossIntroTitle.alpha-1)<0.001 && abs(game.bossIntroSubtitle.alpha-1)<0.001,"Introduction did not reach full opacity")
        var changed=0
        for y in 330..<610 {for x in 360..<1240 {let p=(y*1600+x)*4;if (0..<3).contains(where:{abs(Int(fade[p+$0])-Int(hold[p+$0]))>15}) {changed+=1}}}
        try require(changed>1000,"Introduction fade did not change actual rendered center pixels")
        advance(1.5);_=try save("boss-intro-fade-out")
        try require(abs(game.bossIntroTitle.alpha-0.5)<0.001 && abs(game.bossIntroSubtitle.alpha-0.5)<0.001,"Source final fade is missing")
        advance(3.7);_=try save("boss-first-entered")
        try require(game.bossIntroHUD.isHidden && game.core.silverbacks.count==1 && game.silverbackNodes.count==1 && !game.bossHUD.isHidden,"First scheduled brother did not replace the introduction with a real boss body and health display")
        advance(6.2);_=try save("boss-between-brothers")
        try require(game.core.silverbacks.count==1,"Second brother appeared before its ten-second interval")
        advance(9);_=try save("boss-two-entered")
        try require(game.core.silverbacks.count==2 && game.silverbackNodes.count==2 && game.core.silverbacks.allSatisfy{$0.arrival==nil} && game.bossLabel.text?.contains("2/2")==true,"Two separately admitted brothers or their shared readable count is missing")
        advance(2.2)
        let flow=game.core.combatSpawnFlow!
        try require(flow.bossWaves != nil && flow.healthBurst != nil,"Boss world did not hand off to its actual health/replay clocks")
        game.core.damageSilverback(150,id:flow.monitoredBossID)
        flow.nextMini=nil
        let until=max(0,(flow.healthBurst!.nextEventAt ?? 0)-flow.clock)
        if until>0.01 {game.core.stepCombatSpawns(until-0.01)}
        game.core.foes=[] // Deliberate visible-admission fixture; not a natural-balance run.
        game.core.stepCombatSpawns(0.12)
        _=try save("boss-health-burst")
        try require((flow.healthBurst?.admitted ?? 0)>0 && game.core.foes.contains{$0.kind == .prisoner && $0.arrival != nil},"Actual selected health-band burst never produced its outside body")
        game.core.step(0,input:Controls(pause:true));_=try save("boss-pause-clean")
        try require(game.bossHUD.isHidden && game.bossIntroHUD.isHidden && game.teamHUD.isHidden,"Paused boss scene retained live combat counters or introduction")
        game.core.step(0,input:Controls(accept:true))
        game.core.damageSilverback(99999)
        game.core.foes=[Foe(id:700001,p:V2(x:5,y:3),hp:999,speed:0,gait:0)]
        advance(3);_=try save("boss-surviving-horde")
        try require(game.core.phase == .playing && game.core.foes.contains{$0.id==700001 && $0.hp>0} && game.core.silverbacks.allSatisfy{$0.hp<=0},"Dead bosses silently removed a surviving real enemy")
        for i in game.core.foes.indices {game.core.foes[i].hp=0};game.core.resolveDefeatedFoes()
        for _ in 0..<2400 where game.core.phase == .playing {game.core.step(1.0/60,inputs:[])}
        _=try save("boss-actual-clear")
        try require(game.core.phase == .cleared && !game.core.arenaExits.isEmpty,"Source return and actual empty horde failed to open the teleporter")
        fixture(40,4);advance(2.6);_=try save("boss-four-person-intro")
        try require(!game.bossIntroHUD.isHidden && game.core.silverbacks.isEmpty && game.playerArtStates.count==4,"Four-person introduction bypassed arrival or lost personal cards")
        // Continue the actual four-person encounter into a controlled post-horde victory fixture.
        advance(12.6);game.core.damageSilverback(999999);game.core.finishCombatSpawning()
        game.core.foes=[];game.core.bulls=[];game.core.barrels=[]
        advance(2.2)
        for _ in 0..<2400 where game.core.phase == .playing {game.core.step(1.0/60,inputs:[])}
        try require(game.core.phase == .cleared,"Four-person real boss fixture never reached its source victory gate")
        game.core.pickups=[];game.core.clearClock=4
        let portal=game.core.availableExits.first!,oldMap=game.core.environmentRevision
        game.core.withPlayer(0){game.core.hero=portal.p;game.core.heroElevation=portal.height;game.core.apply(.tank)}
        game.core.withPlayer(1){game.core.apply(.helicopter)}
        for p in game.core.players {p.invulnerable=999}
        game.core.step(0,inputs:[]);_=try save("boss-victory-contact-wait")
        try require(game.core.bossVictory != nil && game.core.phase == .cleared && game.core.arenaTransit==nil && game.bossVictoryHUD.isHidden,"Boss contact faded early or displayed victory before its1s lead-in")
        advance(2);_=try save("boss-victory-main-half")
        try require(abs(Double(game.bossVictoryTitle.alpha)-0.5)<0.002 && game.bossVictoryBrothers.alpha==0,"Main victory fade or delayed brother line differs from source")
        advance(1.5);_=try save("boss-victory-brothers-started")
        try require(abs(Double(game.bossVictoryBrothers.alpha)-0.2)<0.002,"Third victory line did not start two seconds after its title")
        advance(2);let victoryFull=try save("boss-victory-full")
        try require(!game.bossVictoryHUD.isHidden && game.bossVictoryTitle.alpha==1 && game.bossVictorySubtitle.alpha==1 && game.bossVictoryBrothers.alpha>0.999,"Source victory text never reached full native opacity")
        try require([game.bossVictoryTitle,game.bossVictorySubtitle,game.bossVictoryBrothers].allSatisfy{!($0.text ?? "").isEmpty && $0.frame.width<760},"Victory text clips its own native panel")
        try require(game.playerArtStates[0].vehicleNode?.isHidden==false && game.playerArtStates[1].vehicleNode?.isHidden==false,"Victory HUD prematurely replaced the actual tank/Hind with movie bodies")
        game.core.step(0,input:Controls(pause:true));let pausedVictory=game.core.bossVictory!.clock
        game.core.step(10,inputs:[]);_=try save("boss-victory-paused")
        try require(game.bossVictoryHUD.isHidden && game.core.bossVictory?.clock==pausedVictory,"Pause left victory HUD visible or advanced its source clock")
        game.core.step(0,input:Controls(accept:true));advance(1.5);let victoryFading=try save("boss-victory-fading")
        var victoryPixels=0
        for y in 280..<530 {for x in 300..<1300 {let i=(y*1600+x)*4;if (0..<3).contains(where:{abs(Int(victoryFull[i+$0])-Int(victoryFading[i+$0]))>20}) {victoryPixels+=1}}}
        try require(victoryPixels>1000 && abs(Double(game.bossVictoryTitle.alpha)-0.5)<0.002,"Actual native victory panel did not visibly fade at source HUD second6")
        advance(1);_=try save("boss-return-movie-arrival")
        try require(game.core.phase == .loopReturn && game.core.bossVictory==nil && game.bossVictoryHUD.isHidden && game.teamHUD.isHidden && game.loopVisitor != nil,"Movie began before victory ended or retained gameplay overlays")
        try require(game.playerArtStates.allSatisfy{$0.hero.childNodes.first?.isHidden==false} && game.playerArtStates[0].vehicleNode?.isHidden==true && game.playerArtStates[1].vehicleNode?.isHidden==true,"Stored tank/Hind lost visible on-foot movie bodies")
        advance(1.35);_=try save("boss-return-movie-kick")
        game.core.step(0,input:Controls(pause:true));let pausedMovie=game.core.loopReturn!.clock
        game.core.step(10,inputs:[]);_=try save("boss-return-movie-paused")
        try require(game.core.loopReturn?.clock==pausedMovie && game.playerArtStates[0].vehicleNode?.isHidden==true && game.playerArtStates[1].vehicleNode?.isHidden==true,"Pause changed the movie pose back into saved vehicles")
        game.core.step(0,input:Controls(accept:true));advance(0.65);_=try save("boss-return-movie-flight")
        try require(game.playerArtStates.allSatisfy{Double($0.hero.position.y)>3 && $0.hero.opacity==1},"Four movie bodies failed to share the actual airborne phase")
        advance(0.8);_=try save("boss-return-fade-start")
        try require(game.core.phase == .transition && game.core.loopReturn != nil && game.core.environmentRevision==oldMap,"Movie end replaced the old map before its fade-out")
        advance(0.5);_=try save("boss-return-fade-half")
        try require(game.core.environmentRevision==oldMap && abs(Double(game.transitCurtain.alpha)-0.5)<0.002 && game.playerArtStates[0].vehicleNode?.isHidden==true,"Half fade snapped back into a vehicle or changed maps early")
        advance(0.5);_=try save("boss-return-black-map-commit")
        try require(game.core.round==41 && game.core.environmentRevision==oldMap+1 && game.core.loopReturn==nil && game.loopVisitor==nil && game.transitCurtain.alpha==1,"Black-frame return failed its once-only map/visitor handoff")
        advance(0.2);_=try save("boss-return-black-hold")
        advance(0.75);_=try save("boss-return-island-fading-in")
        advance(0.75);_=try save("boss-return-island-restored")
        try require(game.core.phase == .playing && game.core.round==41 && game.core.playerCount==4 && game.core.arenaTransit==nil && game.transitCurtain.isHidden && game.playerArtStates[0].vehicleNode?.isHidden==false && game.playerArtStates[1].vehicleNode?.isHidden==false,"Returned island failed to restore four roles and the actual stored tank/Hind")
        print("PASS source victory/own movie:\(victoryPixels)actual fading panel pixels,three source-timed text lines,4roles/tank/Hind,pause in HUD and movie,retained airborne pose until black,one real round41commit and restored vehicles;original movie duration/notification overlap not verified")
        try require(game.audio.playedCount==0 && game.music.playedCount==0,"Boss proof played audio")
        print("PASS boss rendering:\(pictures)images,\(changed)actual intro fade pixels,source-timed real brothers/health-burst/retained-horde/exit/pause/four-player cards/victoryHUD/ownmovie/blackreturn;0audio,no window or real controller;controlled diagnostics,not hardware/windowFPS acceptance")
    }
}
#endif
