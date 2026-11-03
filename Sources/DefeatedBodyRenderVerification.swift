#if os(macOS)
import AppKit
import SceneKit
import Metal

enum DefeatedBodyRenderVerification {
    static func run(_ output:URL)throws->Int {
        try FileManager.default.createDirectory(at:output,withIntermediateDirectories:true)
        let size=CGSize(width:1600,height:900),game=ArcadeGame(view:GameView(frame:NSRect(origin:.zero,size:size)),defaults:nil)
        let renderer=SCNRenderer(device:MTLCreateSystemDefaultDevice(),options:nil)
        renderer.scene=game.scene;renderer.pointOfView=game.camera;renderer.overlaySKScene=game.hud
        var images=0,checks=0
        func require(_ value:Bool,_ why:String)throws {checks+=1;if !value{throw NSError(domain:"BodyFallProof",code:1,userInfo:[NSLocalizedDescriptionKey:why])}}
        func sync() {game.lastTime=ProcessInfo.processInfo.systemUptime+1000;game.tick(controls:Controls(),viewSize:size);SCNTransaction.flush()}
        func save(_ name:String)throws {
            let image=renderer.snapshot(atTime:0,with:size,antialiasingMode:.multisampling4X)
            let cg=image.cgImage(forProposedRect:nil,context:nil,hints:nil)!
            try NSBitmapImageRep(cgImage:cg).representation(using:.png,properties:[:])!.write(to:output.appendingPathComponent(name+".png"),options:.withoutOverwriting);images+=1
        }
        game.core.reset();game.core.combatSpawningHeld=true;game.core.sourceLoot=nil;game.core.pickups=[];game.core.elapsed=1;game.core.invulnerable=999;game.core.hero=V2(x:8,y:4)
        let kinds:[FoeKind]=[.zombie,.prisoner,.engineer,.crawler,.hound,.sasquatch]
        game.core.foes=(0..<18).map {i in Foe(id:700000+i,p:V2(x:Double(i%6)*2.3-6,y:Double(i/6)*2.8-3),hp:10,speed:0,gait:Double(i)*0.3,kind:kinds[i%6])}
        sync();try save("fall78-living-reference")
        let oldNodes=game.foeNodes,foes=game.core.foes
        game.core.foes=[]
        for (i,foe) in foes.enumerated() {var f=foe;f.launchedByContact=i>=6;game.core.kill(f)}
        sync();try save("fall78-start")
        try require(game.corpseNodes.count==18 && game.fallingBodies.count==18 && game.foeNodes.isEmpty,"Actual kill events did not create exactly eighteen bounded corpse animations")
        try require(game.core.score==1800 && game.core.takeDefeatPresentations().isEmpty,"Renderer changed ordinary kill score or left duplicate pending events")
        let bodies=game.fallingBodies
        let originalCamera=game.camera.transform
        for (age,name) in [(0.18,"rising"),(DefeatedBodyMotion.launchSpeed/DefeatedBodyMotion.gravity,"apex"),(1.1,"landed")] {
            game.core.elapsed=1+age;sync();try save("fall78-"+name)
            for body in bodies {
                let expected=body.motion.pose(age:age)
                let minimum=body.corners.map{body.node.convertPosition($0,to:nil).y}.min()!
                try require(abs(Double(minimum)-body.base-expected.lift)<1e-5,"Rotated corpse penetrates its support surface or loses the explicit upward arc")
            }
            try require(SCNMatrix4EqualToMatrix4(originalCamera,game.camera.transform),"Cosmetic corpses moved or zoomed the whole-map camera")
        }
        try require(game.fallingBodies.isEmpty && game.corpseNodes.count==18,"Landed bodies keep doing per-frame animation work or vanish too early")
        for (id,old) in oldNodes {
            let clone=game.corpseNodes.first{$0.name=="fallen-foe-\(id)"}!.childNodes.first!
            if let a=old.childNode(withName:"leftLeg",recursively:true),let b=clone.childNode(withName:"leftLeg",recursively:true) {try require(a !== b,"Fallen clone shares a live actor's bones")}
            if (id-700000)%6==2 {try require(clone.childNode(withName:"engineer-wrench",recursively:true) != nil,"Engineer corpse lost its attached tool")}
        }
        // Actual pause path freezes the core clock and therefore every active fall.
        game.addFallenBody(DefeatPresentation(id:800000,position:.zero,elevation:0,launched:true),from:oldNodes[700000]!)
        game.animateFallenBodies();let paused=game.corpseNodes.last!,before=paused.transform
        game.core.step(0,input:Controls(pause:true));game.core.step(5,input:Controls());sync()
        try require(SCNMatrix4EqualToMatrix4(before,paused.transform),"Pause advanced a falling corpse")
        try save("fall78-paused")
        game.core.phase = .playing
        for id in 0..<70 {game.addFallenBody(DefeatPresentation(id:900000+id,position:V2(x:Double(id%10)-4.5,y:Double(id/10)-3),elevation:0,launched:id%2==0),from:oldNodes[700000]!)}
        game.animateFallenBodies();try save("fall78-budget55")
        try require(game.corpseNodes.count==55 && game.fallingBodies.count<=55 && game.remains.childNodes.count==55,"Retained or animated body count exceeded the existing55body budget")
        game.clearFallenBodies();try require(game.corpseNodes.isEmpty && game.fallingBodies.isEmpty && game.remains.childNodes.isEmpty,"Arena cleanup left an animated or retained corpse")
        try require(game.audio.playedCount==0 && game.music.playedCount==0,"Offscreen proof attempted audio playback")
        let report:[String:Any]=["images":images,"checks":checks,"body_limit":55,"initial_bodies":18,"normal_kill_score":game.core.score,"camera_fixed":true,"scope":"Production SCNRenderer,actual core death queue and same rendering sync. Own kinematic fall/vertical launch,rigid cloned poses,55body cap,pause,six types,skin rebinding. Synthetic scene,not normal play/windowFPS/human/audio/physical controller acceptance;original articulated ragdoll engine absent."]
        try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]).write(to:output.appendingPathComponent("report.json"))
        print("PASS native fall78: \(images) images,\(checks) assertions,18 actual deaths,55body cap,pause/floor support/fixed camera;own motion,not original physics/windowFPS")
        return images
    }
}
#endif
