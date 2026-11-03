#if os(macOS)
import AppKit
import SceneKit
import Metal

enum OrbRetirementRenderVerification {
 static func run(_ output:URL)throws->Int {
  let size=CGSize(width:1600,height:900)
  let game=ArcadeGame(view:GameView(frame:NSRect(origin:.zero,size:size)),defaults:nil)
  let renderer=SCNRenderer(device:MTLCreateSystemDefaultDevice(),options:nil)
  renderer.scene=game.scene;renderer.pointOfView=game.camera;renderer.overlaySKScene=game.hud
  var images=0
  func require(_ yes:Bool,_ message:String)throws {if !yes {throw NSError(domain:"OrbRetirement68",code:1,userInfo:[NSLocalizedDescriptionKey:message])}}
  func sync() {game.lastTime=ProcessInfo.processInfo.systemUptime+1;game.tick(players:[],devices:[],viewSize:size)}
  func fixture(_ count:Int=1) {
   game.settings.godMode=false;game.settings.cameraMode = .overview;game.settings.zoom = .normal
   game.core.godMode=false;game.core.reset(playerCount:count);game.core.round=1;game.core.beginRound()
   game.core.foes=[];game.core.pickups=[];game.core.sourceLoot=nil;game.core.combatSpawningHeld=true;game.core.messageTime=0
   game.core.forEachPlayer {game.core.hero=game.core.layout.clamped(V2(x:Double(game.core.activePlayerSlot%2)*4-2,y:Double(game.core.activePlayerSlot/2)*4-2));game.core.heroElevation=0;game.core.invulnerable=999}
   game.lastRound=0;sync()
  }
  func capture()->CGImage {renderer.snapshot(atTime:42,with:size,antialiasingMode:.multisampling4X).cgImage(forProposedRect:nil,context:nil,hints:nil)!}
  func save(_ name:String)throws->CGImage {
   sync();let image=capture()
   try NSBitmapImageRep(cgImage:image).representation(using:.png,properties:[:])!.write(to:output.appendingPathComponent(name+".png"),options:.withoutOverwriting)
   images+=1;return image
  }
  func rgba(_ image:CGImage)->[UInt8] {
   var bytes=[UInt8](repeating:0,count:1600*900*4)
   bytes.withUnsafeMutableBytes{raw in
    let c=CGContext(data:raw.baseAddress,width:1600,height:900,bitsPerComponent:8,bytesPerRow:6400,space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGBitmapInfo.byteOrder32Big.rawValue|CGImageAlphaInfo.premultipliedLast.rawValue)!
    c.draw(image,in:CGRect(origin:.zero,size:size))
   };return bytes
  }
  func step(_ dt:Double) {game.core.step(dt,inputs:Array(repeating:Controls(),count:game.core.playerCount))}
  fixture();game.core.grantOrbs();_=try save("orb68-active-four")
  let old=game.core.orbShields.map(\.id),nodes=Dictionary(uniqueKeysWithValues:game.orbNodes.map{($0.key,ObjectIdentifier($0.value))})
  game.core.grantOrbs();step(0.25);let present=rgba(try save("orb68-refill-old-and-new"))
  try require(game.orbNodes.count==4 && game.flyingOrbNodes.count==4 && old.allSatisfy{id in guard let node=game.flyingOrbNodes[id] else{return false};return ObjectIdentifier(node)==nodes[id]},"Cleanup rebuilt/lost the four real retained scene nodes on replacement")
  try require(game.core.flyingOrbs.filter(\.launched).count==1 && game.flyingOrbNodes.values.allSatisfy{$0.opacity==1},"Cleanup does not start with exactly one detached opaque model")
  let probe=game.flyingOrbNodes[old[1]]!;probe.isHidden=true;let absent=rgba(capture());probe.isHidden=false
  let point=NativeCameraProjection.project(probe.worldPosition,camera:game.camera,size:size),px=Int(point.x),py=Int(900-point.y)
  var pixels=0
  for y in max(0,py-14)...min(899,py+14) {for x in max(0,px-14)...min(1599,px+14) {
   let o=(y*1600+x)*4;if (0..<3).contains(where:{abs(Int(present[o+$0])-Int(absent[o+$0]))>12}) {pixels+=1}
  }}
  try require(pixels>=4,"Still-linked retired model contributes no real image pixels")
  step(0.249);_=try save("orb68-before-second-departure")
  try require(game.core.flyingOrbs.filter(\.launched).count==1,"Native second object detached early")
  step(0.001);_=try save("orb68-second-departure")
  try require(game.core.flyingOrbs.filter(\.launched).count==2,"Native half-second departure missing")
  step(1);_=try save("orb68-all-four-departed")
  try require(game.core.flyingOrbs.filter(\.launched).count==4,"Native fourth object did not detach at1.5seconds")
  step(2.499);_=try save("orb68-before-common-delete")
  try require(game.flyingOrbNodes.count==4 && game.core.flyingOrbs.count==4,"Native models disappeared before the shared deadline")
  for orb in game.core.flyingOrbs {
   let n=game.flyingOrbNodes[orb.id]!
   try require(abs(Double(n.position.y)-orb.height)<1e-5 && n.opacity==1,"Native model does not follow its real cosmetic physics height or fades early")
  }
  step(0.001);_=try save("orb68-common-delete-new-charges-retained")
  try require(game.flyingOrbNodes.isEmpty && game.orbNodes.count==4 && game.core.orbRemaining>35.9,"Shared deletion stole fresh charges or left obsolete scene nodes")
  game.core.grantOrbs();game.core.step(0,input:Controls(pause:true));_=try save("orb68-paused-cleanup")
  let before=game.core.flyingOrbs.map(\.p),clock=game.core.playerRoster.current.orbRetirement.clock
  step(15);sync();try require(game.core.flyingOrbs.map(\.p)==before && game.core.playerRoster.current.orbRetirement.clock==clock,"Paused native cleanup continued to move")
  fixture(2);game.core.withPlayer(1){game.core.grantOrbs()};sync()
  let dyingIDs=game.core.players[1].orbShields.map(\.id)
  game.core.withPlayer(1){game.core.invulnerable=0;game.core.playerRoster.current.bodyShield=nil;game.core.loseLife()}
  _=try save("orb68-player-two-death-cleanup")
  try require(game.playerArtStates[1].orbNodes.isEmpty && game.playerArtStates[1].flyingOrbNodes.count==4 && game.core.players[1].isDown,"Down owner lost retained cleanup nodes or kept damaging charges")
  step(2);_=try save("orb68-player-two-return-free-models")
  try require(!game.core.players[1].isDown && game.playerArtStates[1].flyingOrbNodes.count==4 && dyingIDs.allSatisfy{game.playerArtStates[1].flyingOrbNodes[$0] != nil},"Respawn removed actual already free nodes")
  fixture(4);game.core.forEachPlayer{game.core.grantOrbs()};sync()
  let allIDs=game.core.players.map{$0.orbShields.map(\.id)}
  game.core.forEachPlayer{game.core.grantOrbs()};step(0.5);_=try save("orb68-four-owner-generations")
  try require(game.playerArtStates.count==4 && game.core.activePlayerSlot==0,"Four-role render fixture leaked current owner")
  for slot in 0..<4 {
   let art=game.playerArtStates[slot],state=game.core.players[slot]
   try require(art.orbNodes.count==4 && art.flyingOrbNodes.count==4 && state.flyingOrbs.filter(\.launched).count==2 && allIDs[slot].allSatisfy{art.flyingOrbNodes[$0] != nil},"Role\(slot) lost its independent real active/retiring models")
  }
  game.core.clearArenaSupport();game.core.round=5;game.core.beginRound();game.lastRound=0;_=try save("orb68-map-cleanup-keeps-carried-charges")
  try require(game.playerArtStates.allSatisfy{$0.flyingOrbNodes.isEmpty && $0.orbNodes.count==4},"Old-map physics leaked through map-support cleanup")
  try require(game.audio.playedCount==0 && game.audio.voiceCount==0 && game.music.playedCount==0,"Native cleanup test attempted audio")
  print("PASS native orb68:\(images)images,4retainedactualnodes,\(pixels)retired-object-onlypixels,actualexpiry/refill/.5stagger/shared4sdelete/pause/down-owner/return/4role32models/mapcleanup;opaque cosmetic3Dflight,0hits/0audio,no window/controller,not original PhysicsLaunch parameters/FX/windowFPS/hardware")
  return images
 }
}
#endif
