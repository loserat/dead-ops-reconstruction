#if os(macOS)
import AppKit
import SceneKit
import Metal

/// Separate native executable; not part of the shipping app or pure logic suite.
/// Keeps the 0.81 animation below as an independent before/after control.
@main enum MacRenderProbe {
    static func legacy(_ model:SCNNode,phase:Double,amount:Double,player:Bool,direction:V2=V2(x:0,y:-1)) {
        guard let spine=model.childNode(withName:"human-spine",recursively:false) else{return}
        let stride=max(0,min(1,amount)),swing=sin(phase)*0.36*stride
        for (name,sign) in [("leftLeg",1.0),("rightLeg",-1.0)] {
            let leg=model.childNode(withName:name,recursively:false)
            if player {
                let pose=CharacterLegPose.plan(phase:phase,amount:stride,direction:direction,left:name=="leftLeg")
                leg?.eulerAngles=SCNVector3(pose.pitch,pose.yaw,pose.roll)
                leg?.childNode(withName:"human-knee",recursively:false)?.eulerAngles.x=NodeFloat(pose.knee)
            }else{
                leg?.eulerAngles.x=NodeFloat(swing*sign)
                leg?.childNode(withName:"human-knee",recursively:false)?.eulerAngles.x=NodeFloat(max(0,-sin(phase)*sign)*0.32*stride)
            }
        }
        spine.position.y=NodeFloat(abs(sin(phase*2))*0.018*stride)
        spine.eulerAngles.x=NodeFloat(player ? -0.025*stride:-0.14-0.035*sin(phase)*stride)
        spine.eulerAngles.z=NodeFloat(sin(phase)*(player ? 0.018:0.035)*stride)
        if !player {
            spine.childNode(withName:"player-arm-left",recursively:false)?.eulerAngles.x=NodeFloat(-0.08+0.10*sin(phase+0.9)*stride)
            spine.childNode(withName:"player-arm-right",recursively:false)?.eulerAngles.x=NodeFloat(0.02-0.12*sin(phase)*stride)
        }
    }
    static func stats(_ values:[Double])->[String:Double] {
        let s=values.sorted();return ["samples":Double(s.count),"p50_ms":s[s.count/2],"p95_ms":s[Int(Double(s.count-1)*0.95)],"max_ms":s.last!]
    }
    static func main()throws {
        let app=NSApplication.shared;app.setActivationPolicy(.prohibited);setbuf(stdout,nil)
        guard CommandLine.arguments.count==2,let device=MTLCreateSystemDefaultDevice() else{fatalError("Output directory and Metal device required")}
        let out=URL(fileURLWithPath:CommandLine.arguments[1],isDirectory:true)
        guard !FileManager.default.fileExists(atPath:out.path) else{fatalError("Use a fresh output directory")}
        try FileManager.default.createDirectory(at:out,withIntermediateDirectories:true)
        let size=CGSize(width:2560,height:1440)
        let game=ArcadeGame(view:GameView(frame:NSRect(origin:.zero,size:size)),defaults:nil)
        func tick(_ dt:Double=0) {
            game.lastTime=ProcessInfo.processInfo.systemUptime+(dt==0 ? 1:-dt)
            game.tick(controls:Controls(),viewSize:size)
        }
        func stage(_ round:Int,_ count:Int=80) {
            game.core.reset();game.core.round=round;game.core.beginRound();game.core.combatSpawningHeld=true
            game.core.pickups=[];game.core.foes=[];game.core.messageTime=0
            game.core.hero=game.core.layout.clamped(V2(x:-3,y:3));game.core.heroElevation=game.core.layout.height(game.core.hero)
            game.core.foes=(0..<count).map{i in
                let p=game.core.layout.clamped(V2(x:Double(i%16)*1.1-8,y:Double(i/16)*1.2-4))
                return Foe(id:800000+i,p:p,hp:999999,speed:0,gait:Double(i),elevation:game.core.layout.height(p))
            }
            game.lastRound=0;tick();game.core.messageTime=0;tick()
        }
        // Compare every named joint after independent animations; clones must not share joints.
        var transformChecks=0
        for player in [false,true] {for prisoner in [false,true] {for variant in 0..<3 {
            let a=game.humanCharacter(player:player,variant:variant,prisoner:prisoner)
            let b=a.clone(),rig=HumanCharacterRig(b)!
            precondition(rig.spine !== HumanCharacterRig(a)!.spine)
            for phase in [0.0,0.4,1.57,3.14,4.7,7.0] {for amount in [0.0,0.3,1.0] {
                legacy(a,phase:phase,amount:amount,player:player,direction:V2(x:0.8,y:-0.6))
                game.animateHumanCharacter(rig,phase:phase,amount:amount,player:player,direction:V2(x:0.8,y:-0.6))
                let old=EnemySkinGeometry.bones(a),new=EnemySkinGeometry.bones(b)
                for i in old.indices {
                    let x=old[i].simdTransform,y=new[i].simdTransform
                    for column in 0..<4 {for row in 0..<4 {precondition(abs(x[column][row]-y[column][row])<0.00001);transformChecks+=1}}
                }
            }}
        }}}
        print("PASS independent pose parity: \(transformChecks) matrix components; clone-local joints")
        stage(5,176)
        precondition(game.foeAnimationRigs.count==176)
        let nodes=game.core.foes.map{game.foeNodes[$0.id]!},rigs=game.core.foes.map{game.foeAnimationRigs[$0.id]!}
        var before=[Double](),after=[Double]()
        // Balanced ABBA order with identical phase sequence and 40 warmup frames per block.
        for cached in [false,true,true,false,false,true] {
            for frame in 0..<340 {
                let began=ProcessInfo.processInfo.systemUptime,phase=Double(frame)/20
                for i in nodes.indices {
                    if cached {game.animateHumanCharacter(rigs[i],phase:phase+Double(i),amount:1,player:false)}
                    else {
                        nodes[i].childNode(withName:"leftLeg",recursively:false)?.eulerAngles.x=NodeFloat(sin(phase+Double(i))*0.4)
                        nodes[i].childNode(withName:"rightLeg",recursively:false)?.eulerAngles.x=NodeFloat(-sin(phase+Double(i))*0.4)
                        legacy(nodes[i],phase:phase+Double(i),amount:1,player:false)
                    }
                }
                let elapsed=(ProcessInfo.processInfo.systemUptime-began)*1000
                if frame>=40 {if cached {after.append(elapsed)}else{before.append(elapsed)}}
            }
        }
        game.core.foes=[];tick();precondition(game.foeNodes.isEmpty && game.foeAnimationRigs.isEmpty)
        for round in [1,5] {
            stage(round,16);precondition(game.foeAnimationRigs.count==16)
            let ids=game.core.foes.prefix(8).map(\.id);game.core.foes.removeFirst(8);tick()
            precondition(ids.allSatisfy{game.foeAnimationRigs[$0]==nil} && game.foeAnimationRigs.count==8)
        }
        print("PASS production rig lifecycle:176 actors,removal,reset,reused IDs; no retained dead rigs")
        stage(13,0)
        let kinds:[FoeKind]=[.zombie,.prisoner,.engineer,.hound,.crawler,.sasquatch,.martyr]
        game.core.foes=kinds.enumerated().map{i,kind in
            let p=game.core.layout.clamped(V2(x:Double(i)*2-6,y:3))
            return Foe(id:900000+i,p:p,hp:999999,speed:0,gait:1,elevation:game.core.layout.height(p),kind:kind)
        };tick()
        precondition(game.foeAnimationRigs.count==3 && game.foeNodes.count==7)
        print("PASS mixed enemy art:humanoid/prisoner/engineer cached;hound/crawler/sasquatch/martyr keep own animation")
        let renderer=SCNRenderer(device:device,options:nil)
        renderer.scene=game.scene;renderer.pointOfView=game.camera;renderer.overlaySKScene=game.hud
        func image()->CGImage {renderer.snapshot(atTime:42,with:size,antialiasingMode:.multisampling4X).cgImage(forProposedRect:nil,context:nil,hints:nil)!}
        func save(_ name:String)throws {try NSBitmapImageRep(cgImage:image()).representation(using:.png,properties:[:])!.write(to:out.appendingPathComponent(name+".png"))}
        func select(_ current:Bool) {
            game.syncArenaLighting()
            if !current {
                game.ambient.light?.color=rgb(0xb0bcc6);game.ambient.light?.intensity=340;game.sun.light?.shadowColor=rgb(0x17251b,0.42)
                game.sun.light?.color=rgb(game.core.round%4==3 ? 0xffbc70:game.core.round%4==0 ? 0x7f9ad8:game.core.layout.kind != .island ? 0xf4f5ec:0xfff0ce)
                game.sun.light?.intensity=game.core.round%4==0 ? 650:1000
            }
            if let sea=game.artMaterials["water"] {
                sea.diffuse.contents=rgb(current ? 0x344e58:0x476e78);sea.specular.contents=rgb(current ? 0x657c88:0x7a9394);sea.shininess=current ? 28:45;sea.normal.intensity=current ? 0.55:1
                sea.normal.contentsTransform=game.waterNormalTransform(now:42)
            }
            SCNTransaction.flush()
        }
        var pictures=[String](),lighting=[[String:Any]]()
        for round in [1,3,4,5,7,8] {
            stage(round,16)
            select(false);try save("round\(round)-before");pictures.append("round\(round)-before.png")
            select(true);try save("round\(round)-after");pictures.append("round\(round)-after.png")
            let a=MacProbeTarget.rgba(image()),b=MacProbeTarget.rgba(image())
            let changed=zip(a,b).filter{abs(Int($0)-Int($1))>8}.count
            precondition(changed<a.count/100,"Static lighting flicker")
            print("PASS lighting scene \(round),static changed components \(changed)")
        }
        let target=MacProbeTarget(device:device,width:2560,height:1440)
        for round in [1,8] {
            stage(round,176);select(true);_=image();_=image()
            // Verify explicit target contains the actual scene AND HUD before accepting timings.
            _=target.render(renderer,time:42);let a=MacProbeTarget.rgba(target.image()),b=MacProbeTarget.rgba(image())
            var total=0,hud=0,hudError=0
            for i in stride(from:0,to:a.count,by:4) {
                for c in 0..<3 {total+=abs(Int(a[i+c])-Int(b[i+c]))}
                if i<2560*300*4 && min(b[i],b[i+1],b[i+2])>165 && abs(Int(b[i])-Int(b[i+2]))<20 {
                    hud+=1;for c in 0..<3 {hudError+=abs(Int(a[i+c])-Int(b[i+c]))}
                }
            }
            let mean=Double(total)/Double(2560*1440*3)/255,hudMean=Double(hudError)/Double(max(1,hud)*3)/255
            precondition(mean<0.01 && hud>100 && hudMean<0.04,"Uncalibrated target or missing HUD")
            var oldGPU=[Double](),newGPU=[Double](),oldCPU=[Double](),newCPU=[Double]()
            for current in [false,true,true,false] {
                select(current)
                for frame in 0..<110 {
                    for i in game.core.foes.indices {
                        let id=game.core.foes[i].id
                        game.animateHumanCharacter(game.foeAnimationRigs[id]!,phase:Double(frame)/20+Double(i),amount:1,player:false)
                    }
                    SCNTransaction.flush();let t=target.render(renderer,time:42)
                    if frame>=30 {
                        if current {newGPU.append(t["gpu_buffer_interval_ms"]!);newCPU.append(t["cpu_encode_ms"]!)}
                        else {oldGPU.append(t["gpu_buffer_interval_ms"]!);oldCPU.append(t["cpu_encode_ms"]!)}
                    }
                }
            }
            lighting.append(["round":round,"foes":176,"width":2560,"height":1440,"calibrated_mean":mean,"HUD_pixels":hud,"HUD_mean":hudMean,"before_GPU_buffer":stats(oldGPU),"after_GPU_buffer":stats(newGPU),"before_CPU_encode":stats(oldCPU),"after_CPU_encode":stats(newCPU)])
        }
        precondition(game.audio.playedCount==0 && game.music.playedCount==0)
        let report:[String:Any]=["pose_components_checked":transformChecks,"animation_176_before":stats(before),"animation_176_after":stats(after),"lighting":lighting,"images":pictures,"scope":"Controlled offscreen scene and animation comparisons; actual production rigs and renderer, no screen capture, no live input/audio, not window FPS or physical controller acceptance"]
        try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]).write(to:out.appendingPathComponent("report.json"))
        print("PASS native Mac render comparison; animation before \(stats(before)),after \(stats(after))")
    }
}
#endif

#if os(macOS)
import Foundation
import SceneKit
import Metal
import CoreGraphics

/// Explicit offscreen render target. GPU times are command-buffer intervals,
/// never a display cadence or an exclusive-GPU/FPS measurement.
final class MacProbeTarget {
 let device:MTLDevice,queue:MTLCommandQueue,width:Int,height:Int,samples:Int
 let resolved:MTLTexture,msaa:MTLTexture,depth:MTLTexture
 init(device:MTLDevice,width:Int,height:Int,samples:Int=4){
  self.device=device;self.width=width;self.height=height;self.samples=samples;queue=device.makeCommandQueue()!
  precondition(device.supportsTextureSampleCount(samples))
  let color=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.bgra8Unorm_srgb,width:width,height:height,mipmapped:false);color.storageMode = .shared;color.usage=[.renderTarget,.shaderRead]
  resolved=device.makeTexture(descriptor:color)!
  color.textureType = .type2DMultisample;color.sampleCount=samples;color.storageMode = .private;color.usage = .renderTarget;msaa=device.makeTexture(descriptor:color)!
  let z=MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.depth32Float_stencil8,width:width,height:height,mipmapped:false);z.textureType = .type2DMultisample;z.sampleCount=samples;z.storageMode = .private;z.usage = .renderTarget;depth=device.makeTexture(descriptor:z)!
 }
 func render(_ renderer:SCNRenderer,time:Double)->[String:Double] {
  let pass=MTLRenderPassDescriptor();pass.colorAttachments[0].texture=msaa;pass.colorAttachments[0].resolveTexture=resolved;pass.colorAttachments[0].loadAction = .clear;pass.colorAttachments[0].storeAction = .multisampleResolve;pass.colorAttachments[0].clearColor=MTLClearColorMake(0,0,0,1)
  pass.depthAttachment.texture=depth;pass.depthAttachment.loadAction = .clear;pass.depthAttachment.storeAction = .dontCare;pass.depthAttachment.clearDepth=1
  pass.stencilAttachment.texture=depth;pass.stencilAttachment.loadAction = .clear;pass.stencilAttachment.storeAction = .dontCare;pass.stencilAttachment.clearStencil=0
  let start=ProcessInfo.processInfo.systemUptime,buffer=queue.makeCommandBuffer()!;buffer.label="DeadOps own offscreen GPU comparison"
  renderer.render(atTime:time,viewport:CGRect(x:0,y:0,width:width,height:height),commandBuffer:buffer,passDescriptor:pass)
  let encoded=ProcessInfo.processInfo.systemUptime;buffer.commit();buffer.waitUntilCompleted();let end=ProcessInfo.processInfo.systemUptime
  precondition(buffer.status == .completed && buffer.error==nil,"Own Metal render failed")
  precondition(buffer.gpuStartTime>0 && buffer.gpuEndTime>buffer.gpuStartTime,"GPU completion timestamps unavailable")
  return ["cpu_encode_ms":(encoded-start)*1000,"cpu_wall_with_wait_ms":(end-start)*1000,"gpu_buffer_interval_ms":(buffer.gpuEndTime-buffer.gpuStartTime)*1000]
 }
 func image()->CGImage {
  var bytes=[UInt8](repeating:0,count:width*height*4)
  bytes.withUnsafeMutableBytes {raw in resolved.getBytes(raw.baseAddress!,bytesPerRow:width*4,from:MTLRegionMake2D(0,0,width,height),mipmapLevel:0)}
  return CGImage(width:width,height:height,bitsPerComponent:8,bitsPerPixel:32,bytesPerRow:width*4,space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGBitmapInfo.byteOrder32Little.union(CGBitmapInfo(rawValue:CGImageAlphaInfo.premultipliedFirst.rawValue)),provider:CGDataProvider(data:Data(bytes) as CFData)!,decode:nil,shouldInterpolate:true,intent:.defaultIntent)!
 }
 static func rgba(_ image:CGImage)->[UInt8] {
  let width=image.width,height=image.height;var bytes=[UInt8](repeating:0,count:width*height*4)
  bytes.withUnsafeMutableBytes {raw in let c=CGContext(data:raw.baseAddress,width:width,height:height,bitsPerComponent:8,bytesPerRow:width*4,space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGBitmapInfo.byteOrder32Big.rawValue|CGImageAlphaInfo.premultipliedLast.rawValue)!;c.draw(image,in:CGRect(x:0,y:0,width:width,height:height))}
  return bytes
 }
}

#endif
