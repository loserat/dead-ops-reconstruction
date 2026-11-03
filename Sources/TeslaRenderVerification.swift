#if os(macOS)
import AppKit
import SceneKit
import Metal

/// Staged actual admissions/contacts in the shipping scene. No window, controller polling or audio output.
enum TeslaRenderVerification {
    static func run(_ output:URL)throws->Int {
        let size=CGSize(width:1600,height:900)
        let game=ArcadeGame(view:GameView(frame:NSRect(origin:.zero,size:size)),defaults:nil)
        let renderer=SCNRenderer(device:MTLCreateSystemDefaultDevice(),options:nil)
        renderer.scene=game.scene;renderer.pointOfView=game.camera;renderer.overlaySKScene=game.hud
        var images=0
        func require(_ value:Bool,_ message:String)throws {if !value {throw NSError(domain:"Tesla65Proof",code:1,userInfo:[NSLocalizedDescriptionKey:message])}}
        func sync(){game.lastTime=ProcessInfo.processInfo.systemUptime+1;game.tick(players:[Controls()],devices:[],viewSize:size)}
        func capture()->CGImage {renderer.snapshot(atTime:42,with:size,antialiasingMode:.multisampling4X).cgImage(forProposedRect:nil,context:nil,hints:nil)!}
        func save(_ name:String)throws->CGImage {
            sync();let image=capture(),data=NSBitmapImageRep(cgImage:image).representation(using:.png,properties:[:])!
            try data.write(to:output.appendingPathComponent(name+".png"),options:.withoutOverwriting);images+=1;return image
        }
        func rgba(_ image:CGImage)->[UInt8] {
            var bytes=[UInt8](repeating:0,count:1600*900*4)
            bytes.withUnsafeMutableBytes {raw in
                let c=CGContext(data:raw.baseAddress,width:1600,height:900,bitsPerComponent:8,bytesPerRow:6400,space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGBitmapInfo.byteOrder32Big.rawValue|CGImageAlphaInfo.premultipliedLast.rawValue)!
                c.draw(image,in:CGRect(origin:.zero,size:size))
            };return bytes
        }
        game.core.reset();game.core.combatSpawningHeld=true;game.core.sourceLoot=nil;game.core.hero=V2(x:-4,y:-3);game.core.invulnerable=999;game.core.foes=[];game.core.pickups=[]
        game.core.grantOrbs();_=try save("tesla65-four-source-offsets")
        try require(game.orbNodes.count==4 && game.core.orbShields.allSatisfy{abs(($0.p-game.core.hero).length-0.8)<1e-7},"Native grant does not match its four actual mapped offsets")
        for i in 0..<3 {
            try require(game.core.admitWaveEnemy(side:.north,kind:.zombie),"Actual wave admission refused Tesla fixture")
            game.core.foes[i].arrival=nil;game.core.foes[i].speed=0;game.core.foes[i].elevation=0
        }
        let first=game.core.orbShields[0].p,rootID=game.core.foes[0].id,childID=game.core.foes[1].id,farID=game.core.foes[2].id
        game.core.foes[0].p=first;game.core.foes[1].p=first+V2(x:1.8,y:0);game.core.foes[2].p=V2(x:7,y:3)
        let hp=game.core.foes[0].hp,raw=game.core.foes[0].referenceVitality!.sourceMaximum
        game.core.step(0,input:Controls());_=try save("tesla65-real-trigger-before-damage")
        try require(game.core.orbShields.count==3 && game.orbNodes.count==3 && abs(game.core.foes[0].hp-(hp-hp/raw))<1e-7 && game.core.foes[0].hp>0,"Native contact did not consume exactly one physical charge with only initial raw1")
        game.core.step(0.099,input:Controls());_=try save("tesla65-before-first-network-wait")
        try require(game.core.foes.contains{$0.id==rootID && $0.hp>0},"Native root died before the source local .1-second wait")
        game.core.step(0.001,input:Controls());sync()
        try require(!game.core.foes.contains{$0.id==rootID} && game.core.score==100 && game.core.foes.contains{$0.id==childID && $0.hp>0},"First native chain boundary did not score the root once while retaining pending child")
        for _ in 0..<100 {
            if !game.core.electricArcs.isEmpty {break}
            game.core.step(1/120,input:Controls())
        }
        let visible=rgba(try save("tesla65-bolt-launch"))
        guard let arc=game.core.electricArcs.first,let node=game.arcNodes[arc.id] else{throw NSError(domain:"Tesla65Proof",code:2,userInfo:[NSLocalizedDescriptionKey:"Real delayed child never launched its moving bolt model"])}
        try require(arc.travelDuration==0.5 && game.core.foes.contains{$0.id==childID && $0.hp>0},"Native far child died before bolt arrival")
        func requirePosition(_ value:ElectricArc)throws {
            let p=value.a+(value.b-value.a)*value.progress,h=value.aHeight+(value.bHeight-value.aHeight)*value.progress
            try require(abs(Double(node.position.x)-p.x)<1e-6 && abs(Double(node.position.z)-p.y)<1e-6 && abs(Double(node.position.y)-h)<1e-6,"Moving rendered Tesla emitter does not match actual timed simulation endpoint interpolation")
        }
        try requirePosition(arc)
        node.isHidden=true;let hidden=rgba(capture());node.isHidden=false
        var pixels=0
        for p in 0..<(1600*900) {let o=p*4;if (0..<3).contains(where:{abs(Int(visible[o+$0])-Int(hidden[o+$0]))>12}){pixels+=1}}
        try require(pixels>=8,"Actual Tesla emitter has insufficient visible pixels against its own hidden comparison")
        let old=node.position,oldProgress=arc.progress
        game.core.step(0.25,input:Controls());_=try save("tesla65-bolt-halfway")
        guard let halfway=game.core.electricArcs.first else{throw NSError(domain:"Tesla65Proof",code:3)}
        try requirePosition(halfway)
        try require(halfway.progress>oldProgress+0.49 && hypot(Double(node.position.x-old.x),Double(node.position.z-old.z))>0.7 && game.core.foes.contains{$0.id==childID && $0.hp>0},"Native bolt is a static full-span beam or damages its target before half-second arrival")
        try require(game.hero.opacity==1 && game.foeNodes[childID]?.opacity==1,"Tesla effect has faded the live player or pending target")
        game.core.step(0,input:Controls(pause:true));let clock=game.core.playerRoster.current.tesla.clock,remaining=halfway.ttl
        game.core.step(5,input:Controls());_=try save("tesla65-paused-flight")
        try require(game.core.playerRoster.current.tesla.clock==clock && game.core.electricArcs.first?.ttl==remaining,"Actual pause moved or completed a flying Tesla bolt")
        game.core.step(0,input:Controls(accept:true));game.core.step(0.26,input:Controls());_=try save("tesla65-child-arrival-cleanup")
        try require(game.core.score==200 && game.core.foes.map(\.id)==[farID] && game.core.electricArcs.isEmpty && game.arcNodes.isEmpty,"Arrived native child did not score once and remove its finished emitter while preserving distant body")
        game.core.reset(playerCount:4);game.core.combatSpawningHeld=true;game.core.sourceLoot=nil;game.core.foes=[];game.core.pickups=[]
        let positions=[V2(x:-5,y:-3),V2(x:5,y:-3),V2(x:-5,y:3),V2(x:5,y:3)]
        for slot in 0..<4 {
            game.core.withPlayer(slot){game.core.hero=positions[slot];game.core.invulnerable=999;game.core.grantOrbs()}
            try require(game.core.admitWaveEnemy(side:.north,kind:.zombie),"Four-role production admission failed")
            game.core.foes[slot].p=game.core.players[slot].orbShields[0].p;game.core.foes[slot].arrival=nil;game.core.foes[slot].speed=0;game.core.foes[slot].elevation=0
        }
        game.core.step(0,inputs:[]);_=try save("tesla65-team-four-independent-gates")
        try require(game.core.players.allSatisfy{$0.orbShields.count==3 && $0.tesla.pendingPrograms==1 && $0.tesla.gateRemaining==2},"Four actual trigger owners share a gate or consume each other's physical charges")
        try require(game.playerArtStates.allSatisfy{$0.orbNodes.count==3 && $0.hero.opacity==1},"Four-role native orbit bodies crossed render ownership")
        game.core.step(0.1,inputs:[]);_=try save("tesla65-team-four-owned-kills")
        try require(game.core.foes.isEmpty && game.core.players.allSatisfy{$0.score==100 && $0.tesla.pendingNodes==0},"Four-role shared .1-second step failed independent ordinary kill credit")
        try require(game.audio.voiceCount==0 && game.audio.playedCount==0 && game.music.playedCount==0,"Tesla proof attempted active audio")
        print("PASS native Tesla65:\(images)images,actual-wave admissions/raw1/.1s-root/.5s-moving-bolt/\(pixels)effectpixels/pause/arrival-cleanup/four-owner-credit,opaque bodies,0audio;staged own-scene evidence,not native original FX/physics/VM/windowFPS/hardware acceptance")
        return images
    }
}
#endif
