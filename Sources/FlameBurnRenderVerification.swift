#if os(macOS)
import AppKit
import SceneKit
import Metal

enum FlameBurnRenderVerification {
    static func run(_ output:URL)throws->Int {
        let size=CGSize(width:1600,height:900)
        let game=ArcadeGame(view:GameView(frame:NSRect(origin:.zero,size:size)),defaults:nil)
        let renderer=SCNRenderer(device:MTLCreateSystemDefaultDevice(),options:nil)
        renderer.scene=game.scene;renderer.pointOfView=game.camera;renderer.overlaySKScene=game.hud
        var images=0
        func require(_ yes:Bool,_ message:String)throws {if !yes{throw NSError(domain:"FlameBurnProof",code:1,userInfo:[NSLocalizedDescriptionKey:message])}}
        func sync(){game.lastTime=ProcessInfo.processInfo.systemUptime+1;game.tick(players:[Controls()],devices:[],viewSize:size)}
        func capture()->CGImage {renderer.snapshot(atTime:42,with:size,antialiasingMode:.multisampling4X).cgImage(forProposedRect:nil,context:nil,hints:nil)!}
        func save(_ name:String)throws->CGImage {
            sync();let image=capture(),data=NSBitmapImageRep(cgImage:image).representation(using:.png,properties:[:])!
            try data.write(to:output.appendingPathComponent(name+".png"),options:.withoutOverwriting);images+=1;return image
        }
        func rgba(_ image:CGImage)->[UInt8] {
            var bytes=[UInt8](repeating:0,count:1600*900*4)
            bytes.withUnsafeMutableBytes{raw in
                let c=CGContext(data:raw.baseAddress,width:1600,height:900,bitsPerComponent:8,bytesPerRow:6400,space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGBitmapInfo.byteOrder32Big.rawValue|CGImageAlphaInfo.premultipliedLast.rawValue)!
                c.draw(image,in:CGRect(origin:.zero,size:size))
            };return bytes
        }
        game.core.reset();game.core.foes=[];game.core.pickups=[];game.core.sourceLoot=nil;game.core.combatSpawningHeld=true
        game.core.hero=V2(x:-3,y:-3);game.core.invulnerable=0;game.core.weapon = .flamethrower;game.core.weaponReserve=50
        try require(game.core.admitWaveEnemy(side:.north,kind:.zombie),"Production mini admission refused the burn fixture")
        game.core.foes[0].p=V2(x:-1,y:-3);game.core.foes[0].arrival=nil;game.core.foes[0].elevation=0;game.core.foes[0].speed=0
        let id=game.core.foes[0].id,maximum=game.core.foes[0].hp
        try require(game.core.foes[0].referenceVitality?.sourceMaximum==11000,"Fixture lost its actual admission health domain")
        game.lastRound=0;game.lastTime=ProcessInfo.processInfo.systemUptime-0.05
        game.tick(players:[Controls(aim:V2(x:1,y:0))],devices:[],viewSize:size)
        let afterContact=game.core.foes[0].hp
        _=try save("flame64-actual-ignition")
        try require(game.core.foes[0].flameAfterburn?.age==0 && game.core.foes[0].flameAfterburn?.ticks==0 && afterContact<maximum,"Real firing frame aged or failed to ignite the actual admitted body")
        game.core.step(0.399,input:Controls());_=try save("flame64-before-first-tick")
        try require(game.core.foes[0].hp==afterContact && game.core.foes[0].flameAfterburn?.ticks==0,"Native world substituted continuous damage before400ms")
        game.core.step(0.001,input:Controls());let bright=rgba(try save("flame64-first-400ms-tick"))
        let projected=120*maximum/11000
        try require(abs(game.core.foes[0].hp-(afterContact-projected))<1e-7 && game.core.foes[0].flameAfterburn?.ticks==1,"Native world failed its first projected damage tick")
        guard let body=game.foeNodes[id],let flame=body.childNode(withName:"burning",recursively:false) else{throw NSError(domain:"FlameBurnProof",code:2)}
        flame.isHidden=true;let dark=rgba(capture());flame.isHidden=false
        let b=flame.boundingBox,points=[b.min.x,b.max.x].flatMap{x in [b.min.y,b.max.y].flatMap{y in [b.min.z,b.max.z].map{z in NativeCameraProjection.project(flame.convertPosition(SCNVector3(x,y,z),to:nil),camera:game.camera,size:size)}}}
        let x0=max(0,Int(floor(points.map{Double($0.x)}.min()!))-2),x1=min(1599,Int(ceil(points.map{Double($0.x)}.max()!))+2)
        let y0=max(0,Int(floor(900-points.map{Double($0.y)}.max()!))-2),y1=min(899,Int(ceil(900-points.map{Double($0.y)}.min()!))+2)
        var pixels=0
        if x0<=x1 && y0<=y1 {for y in y0...y1 {for x in x0...x1 {let o=(y*1600+x)*4;if (0..<3).contains(where:{abs(Int(bright[o+$0])-Int(dark[o+$0]))>16}){pixels+=1}}}}
        try require(pixels>=10 && game.hero.opacity==1 && body.opacity==1,"Burn effect is invisible or has hidden a living actor")
        game.core.step(0,input:Controls(pause:true));let hp=game.core.foes[0].hp,age=game.core.foes[0].flameAfterburn!.age
        game.core.step(3,input:Controls());_=try save("flame64-real-pause")
        try require(game.core.foes[0].hp==hp && game.core.foes[0].flameAfterburn!.age==age,"Pause advanced native burning")
        game.core.step(0,input:Controls(accept:true));game.core.step(7.6,input:Controls());_=try save("flame64-eight-second-survivor")
        try require(game.core.foes[0].flameAfterburn?.ticks==20 && game.core.foes[0].burning==0 && game.foeNodes[id]?.childNode(withName:"burning",recursively:false)==nil,"Twenty ticks did not clean up the bounded own burn visual")
        try require(abs(game.core.foes[0].hp-(afterContact-20*projected))<1e-7 && game.core.score==0,"Surviving mini received wrong afterburn damage or premature points")
        game.core.foes[0].speed=2;let old=game.core.foes[0].p;game.core.step(0.1,input:Controls());sync()
        let moved=(game.core.foes[0].p-old).length,node=game.foeNodes[id]!
        try require(abs(moved-0.13)<1e-6 && abs(Double(node.position.x)-game.core.foes[0].p.x)<1e-6,"Own persistent gas root-motion factor diverged from actual rendered position")
        try require(game.audio.voiceCount==0 && game.audio.playedCount==0 && game.music.playedCount==0,"Flame proof attempted audio")
        print("PASS native flame64:\(images)images,actualmini-admission11000,realM2firstcontact/400ms/20ticks/8s/pause,\(pixels)actualburnpixels,opaque player/target,once-only surviving body with own0.65rootmotion;0audio,no window/controller,not original gas damage/FX/engine/hardware acceptance")
        return images
    }
}
#endif
