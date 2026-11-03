#if os(macOS)
import AppKit
import SceneKit
import Metal

/// Actual world input drives all poses. Inspection probes do not invent a second simulation or poll devices.
enum CharacterMotionRenderVerification {
    static func run(_ output:URL)throws->Int {
        let size=CGSize(width:1600,height:900)
        let game=ArcadeGame(view:GameView(frame:NSRect(origin:.zero,size:size)),defaults:nil)
        let renderer=SCNRenderer(device:MTLCreateSystemDefaultDevice(),options:nil)
        renderer.scene=game.scene;renderer.pointOfView=game.camera;renderer.overlaySKScene=game.hud
        var images=0,posePixels=0,sideComparisons=0
        func require(_ value:Bool,_ message:String)throws {if !value{throw NSError(domain:"Motion66Proof",code:1,userInfo:[NSLocalizedDescriptionKey:message])}}
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
        func poseDifference(_ actual:[UInt8],_ counterfactual:[UInt8],model:SCNNode)->Int {
            let b=model.boundingBox,points=[b.min.x,b.max.x].flatMap{x in [b.min.y,b.max.y].flatMap{y in [b.min.z,b.max.z].map{z in NativeCameraProjection.project(model.convertPosition(SCNVector3(x,y,z),to:nil),camera:game.camera,size:size)}}}
            let x0=max(0,Int(floor(points.map{Double($0.x)}.min()!))-2),x1=min(1599,Int(ceil(points.map{Double($0.x)}.max()!))+2)
            let y0=max(0,Int(floor(900-points.map{Double($0.y)}.max()!))-2),y1=min(899,Int(ceil(900-points.map{Double($0.y)}.min()!))+2)
            var changed=0
            if x0<=x1 && y0<=y1 {for y in y0...y1 {for x in x0...x1 {let o=(y*1600+x)*4;if (0..<3).contains(where:{abs(Int(actual[o+$0])-Int(counterfactual[o+$0]))>12}){changed+=1}}}}
            return changed
        }
        let torso=game.humanTorsoMesh(game.artMaterial("cloth-player",0xc5c5c5)).geometry!
        let normals=torso.sources(for:.normal).first!,positions=torso.sources(for:.vertex).first!
        try require(normals.vectorCount==155 && positions.vectorCount==155 && normals.componentsPerVector==3 && normals.bytesPerComponent==4,"Production torso lost its bounded smooth-profile geometry")
        var checkedNormals=0
        normals.data.withUnsafeBytes {raw in
            for i in 0..<normals.vectorCount {
                let o=normals.dataOffset+i*normals.dataStride
                let x=Double(raw.loadUnaligned(fromByteOffset:o,as:Float.self)),y=Double(raw.loadUnaligned(fromByteOffset:o+4,as:Float.self)),z=Double(raw.loadUnaligned(fromByteOffset:o+8,as:Float.self))
                if x.isFinite && y.isFinite && z.isFinite && abs(sqrt(x*x+y*y+z*z)-1)<1e-5 {checkedNormals+=1}
            }
        }
        try require(checkedNormals==155,"Production torso has invalid or non-unit smooth lighting normals")
        func vector(_ source:SCNGeometrySource,_ index:Int)->SCNVector3 {
            source.data.withUnsafeBytes {raw in
                let o=source.dataOffset+index*source.dataStride
                if source.bytesPerComponent==8 {return SCNVector3(raw.loadUnaligned(fromByteOffset:o,as:Double.self),raw.loadUnaligned(fromByteOffset:o+8,as:Double.self),raw.loadUnaligned(fromByteOffset:o+16,as:Double.self))}
                return SCNVector3(raw.loadUnaligned(fromByteOffset:o,as:Float.self),raw.loadUnaligned(fromByteOffset:o+4,as:Float.self),raw.loadUnaligned(fromByteOffset:o+8,as:Float.self))
            }
        }
        var fittedVertices=0
        for center in [0.80,0.96,1.08] {
            let band=game.humanTorsoBand(center:center,height:0.037,mat:game.artMaterial("cloth-prisoner-bands",0xb4bbaa)).geometry!.sources(for:.vertex).first!
            try require(band.vectorCount==(center==1.08 ? 51:34),"A fitted stripe lost its exact body-section split")
            for i in 0..<band.vectorCount {
                let point=vector(band,i),sector=i%17
                let ring=(0..<6).first{Double(point.y)<=Double(vector(positions,($0+1)*17+sector).y)+1e-7} ?? 5
                let a=vector(positions,ring*17+sector),b=vector(positions,(ring+1)*17+sector),t=Double(point.y-a.y)/Double(b.y-a.y)
                let x=Double(a.x)+(Double(b.x)-Double(a.x))*t,z=Double(a.z)+(Double(b.z)-Double(a.z))*t
                let gap=hypot(Double(point.x)-x,Double(point.z)-z)
                try require(abs(gap-0.004)<1e-6,"Stripe penetrates or floats away from actual generated torso vertices")
                fittedVertices+=1
            }
        }
        for round in [1,5,8] {
            for index in 0..<8 {
                game.core.reset();game.core.round=round;game.core.beginRound();game.core.combatSpawningHeld=true;game.core.sourceLoot=nil;game.core.foes=[];game.core.pickups=[]
                game.core.hero=V2(x:-4,y:-2);game.core.invulnerable=999;game.lastRound=0;sync()
                let a=Double(index)*Double.pi/4,direction=V2(x:cos(a),y:sin(a)),start=game.core.hero
                var steps=0
                repeat {
                    game.core.step(1/60,input:Controls(move:direction,aim:V2(x:0,y:-1)));sync();steps+=1
                }while steps<12 || (abs(sin(game.playerArtStates[0].walking))<0.65 && steps<18)
                let art=game.playerArtStates[0],model=game.hero.childNodes.first!,local=art.locomotion.localDirection(facing:game.core.facing)
                try require(abs((game.core.hero-start).length-Double(steps)/60*6.4)<1e-6 && (local-direction).length<1e-6 && art.locomotionAmount>0.9,"Actual directional world movement failed to reach or drive its gait")
                try require(game.core.facing==V2(x:0,y:-1) && abs(Double(game.hero.eulerAngles.y))<1e-6 && game.core.shots.contains{abs($0.v.x)<1e-7 && $0.v.y<0},"Running pose changed independent actual weapon aim")
                let left=model.childNode(withName:"leftLeg",recursively:false)!,right=model.childNode(withName:"rightLeg",recursively:false)!
                if abs(direction.y)<0.01 {
                    try require(abs(Double(left.eulerAngles.x))<1e-6 && abs(Double(right.eulerAngles.x))<1e-6 && abs(Double(left.eulerAngles.z))+abs(Double(right.eulerAngles.z))>0.05,"Side input still renders a forward-running pair of hips")
                }else if abs(direction.x)<0.01 {
                    try require(abs(Double(left.eulerAngles.z))+abs(Double(right.eulerAngles.z))<1e-6 && abs(Double(left.eulerAngles.x))>0.1,"Forward/back input did not drive its own sagittal stride")
                }else{
                    try require(abs(Double(left.eulerAngles.x))>0.1 && abs(Double(left.eulerAngles.z))+abs(Double(right.eulerAngles.z))>0.03,"Diagonal input lost either of its two stride axes")
                }
                try require(game.hero.opacity==1 && left.parent === model && right.parent === model,"Live motion hides or detaches the actual player's opaque body")
                let actual=rgba(try save("motion66-round\(round)-direction\(index)"))
                if index==0 || index==4 {
                    game.animateHumanCharacter(model,phase:art.walking,amount:art.locomotionAmount,player:true,direction:V2(x:0,y:-1))
                    let oldDirection=rgba(capture());game.animateHumanCharacter(model,phase:art.walking,amount:art.locomotionAmount,player:true,direction:local)
                    let changed=poseDifference(actual,oldDirection,model:model)
                    try require(changed>=8,"Actual side-step pose does not visibly differ inside the rendered body bounds from its forward-running counterfactual")
                    posePixels+=changed;sideComparisons+=1
                }
            }
        }
        let art=game.playerArtStates[0],model=game.hero.childNodes.first!,left=model.childNode(withName:"leftLeg",recursively:false)!,right=model.childNode(withName:"rightLeg",recursively:false)!
        let beforeLeft=left.transform,beforeRight=right.transform,phase=art.walking,amount=art.locomotionAmount
        game.core.step(0,input:Controls(pause:true));game.core.step(5,input:Controls());_=try save("motion66-paused-diagonal")
        try require(art.walking==phase && art.locomotionAmount==amount && SCNMatrix4EqualToMatrix4(beforeLeft,left.transform) && SCNMatrix4EqualToMatrix4(beforeRight,right.transform),"Pause changes a directional hip or knee transform")
        game.core.step(0,input:Controls(accept:true))
        for _ in 0..<60 {game.core.step(1/60,input:Controls());sync()}
        _=try save("motion66-idle-after-diagonal")
        try require(art.locomotionAmount<0.00001 && abs(Double(left.eulerAngles.x))+abs(Double(left.eulerAngles.z))+abs(Double(left.eulerAngles.y))<0.0001,"Stopped diagonal runner retains a rotated or rolling hip")
        game.core.reset(playerCount:4);game.core.round=5;game.core.beginRound();game.core.combatSpawningHeld=true;game.core.sourceLoot=nil;game.core.foes=[];game.core.pickups=[]
        let directions=[V2(x:1,y:0),V2(x:0,y:-1),V2(x:-1,y:0),V2(x:0,y:1)]
        for p in game.core.players {p.hero=V2(x:p.slot%2==0 ? -5:5,y:p.slot<2 ? -3:3);p.heroElevation=0;p.invulnerable=999}
        game.lastRound=0;sync()
        for _ in 0..<12 {game.core.step(1/60,inputs:directions.map{Controls(move:$0,aim:V2(x:0,y:-1))});sync()}
        _=try save("motion66-four-role-directions")
        for p in game.core.players {
            let role=game.playerArtStates[p.slot]
            try require((role.locomotion.localDirection(facing:p.facing)-directions[p.slot]).length<1e-6 && role.locomotionAmount>0.9 && role.hero.opacity==1,"Four concurrent motion directions crossed player ownership")
        }
        try require(game.audio.voiceCount==0 && game.audio.playedCount==0 && game.music.playedCount==0,"Motion proof attempted audio output")
        print("PASS native motion66:\(images)images,24actual eight-way movement/independent-aim scenes on rounds1/5/8,\(sideComparisons)actualbody comparisons/\(posePixels)posepixels,155unit smoothnormals/\(fittedVertices)fittedstripevertices,pause/idle/four-owner directions,opaque bodies,0audio;own animation/geometry,not original clips/physical input/windowFPS/hardware acceptance")
        return images
    }
}
#endif
