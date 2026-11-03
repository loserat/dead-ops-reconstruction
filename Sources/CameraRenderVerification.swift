#if os(macOS)
import Foundation
import AppKit
import SceneKit
import Metal

/// SCNRenderer.snapshot leaves currentViewport empty; request the actual camera matrix for the image size.
enum NativeCameraProjection {
 static func project(_ world:SCNVector3,camera:SCNNode,size:CGSize)->SCNVector3 {
  let p=camera.convertPosition(world,from:nil),m=camera.camera!.projectionTransform(withViewportSize:size)
  let x=p.x*m.m11+p.y*m.m21+p.z*m.m31+m.m41,y=p.x*m.m12+p.y*m.m22+p.z*m.m32+m.m42,z=p.x*m.m13+p.y*m.m23+p.z*m.m33+m.m43,w=p.x*m.m14+p.y*m.m24+p.z*m.m34+m.m44
  return SCNVector3((x/w+1)*size.width/2,(y/w+1)*size.height/2,(z/w+1)/2)
 }
}

/// Current production geometry and real renderer projection, without native input, window or audio.
enum CameraRenderVerification {
 static func run(_ output:URL)throws {
  setbuf(stdout,nil);try FileManager.default.createDirectory(at:output,withIntermediateDirectories:true)
  for size in [CGSize(width:1920,height:1080),CGSize(width:1440,height:900),CGSize(width:1024,height:768),CGSize(width:2560,height:1440)] {
   let rect=AppDelegate.startingContentRect(visibleFrame:NSRect(origin:.zero,size:size))
   guard abs(rect.width/rect.height-16.0/9)<1e-10 && rect.width<=size.width-80 && rect.height<=size.height-100 && rect.width<=1280 else{throw NSError(domain:"AutomaticCameraWindow",code:1)}
  }
  print("PASS automatic standard window:four screen sizes retain16:9 content within the available desktop")
  let game=ArcadeGame(view:GameView(frame:NSRect(x:0,y:0,width:1600,height:900)),defaults:nil)
  let renderer=SCNRenderer(device:MTLCreateSystemDefaultDevice(),options:nil);renderer.scene=game.scene;renderer.pointOfView=game.camera;renderer.overlaySKScene=game.hud
  var images=0,corners=0,mapCorners=0
  func require(_ yes:Bool,_ message:String)throws{if !yes{throw NSError(domain:"PerspectiveProof",code:1,userInfo:[NSLocalizedDescriptionKey:message])}}
  func tick(_ size:CGSize=CGSize(width:1600,height:900)){
   game.lastTime=ProcessInfo.processInfo.systemUptime;game.tick(players:Array(repeating:Controls(),count:game.core.playerCount),devices:[],viewSize:size)
  }
  func stage(_ round:Int=1,_ count:Int=1){
   game.settings.cameraMode = .following;game.settings.zoom = .normal
   game.core.reset(playerCount:count);game.core.round=round;game.core.beginRound();game.core.foes=[];game.core.pickups=[];game.core.combatSpawningHeld=true
   for p in game.core.players {p.hero=game.core.layout.clamped(V2(x:Double(p.slot)*3-4,y:Double(p.slot%2)*6-3));p.heroElevation=game.core.layout.height(p.hero);p.invulnerable=0}
   game.lastRound=0
  }
  func checkHUDClear(_ projected:[SCNVector3],_ name:String,_ size:CGSize)throws {
   guard game.cameraRig.usesCenteredFrame,!projected.isEmpty else{return}
   let left=projected.map{Double($0.x)}.min()!,right=projected.map{Double($0.x)}.max()!
   let bottom=projected.map{Double($0.y)}.min()!,top=projected.map{Double($0.y)}.max()!
   let bounds=CGRect(x:left,y:bottom,width:right-left,height:top-bottom)
   let factor=min(size.width/1280,size.height/720),offset=game.hudCanvas.position
   var panels=[CGRect]()
   if !game.teamHUD.isHidden {for p in game.core.players {panels.append(game.playerArtStates[p.slot].tile.calculateAccumulatedFrame())}}
   if !game.roundBackdrop.isHidden {panels.append(game.roundBackdrop.calculateAccumulatedFrame())}
   for panel in panels {
    let screen=CGRect(x:offset.x+panel.minX*factor,y:offset.y+panel.minY*factor,width:panel.width*factor,height:panel.height*factor).insetBy(dx:-8*factor,dy:-8*factor)
    try require(!screen.intersects(bounds),"Centered view occludes \(name) behind actual rendered HUD bounds \(screen),actor\(bounds)")
   }
  }
  func checkGeometry(_ source:SCNNode,_ size:CGSize)throws{
   func visit(_ node:SCNNode)throws{
    guard !node.isHidden,node.opacity>0.01 else{return}
    if node.geometry != nil {
     let box=node.boundingBox
     var projected=[SCNVector3]()
     for x in [box.min.x,box.max.x] {for y in [box.min.y,box.max.y] {for z in [box.min.z,box.max.z] {
      let world=node.convertPosition(SCNVector3(x,y,z),to:nil),p=NativeCameraProjection.project(world,camera:game.camera,size:size)
      try require(p.x.isFinite && p.y.isFinite && p.z>0 && p.z<1 && p.x>size.width*0.035 && p.x<size.width*0.965 && p.y>size.height*0.055 && p.y<size.height*(game.cameraRig.usesCenteredFrame ? 0.965:0.82),"Actual geometry clipped by view/HUD: \(source.name ?? "actor")/\(node.name ?? "piece"),world\(world),projected\(p),camera\(game.camera.worldPosition),presentation\(game.camera.presentation.worldPosition),viewport\(renderer.currentViewport)")
      projected.append(p)
      corners+=1
     }}}
     try checkHUDClear(projected,source.name ?? "actor",size)
    }
    for child in node.childNodes {try visit(child)}
   }
   try visit(source)
  }
  func save(_ name:String,_ size:CGSize=CGSize(width:1600,height:900),ending:Bool=false)throws {
   tick(size)
   let picture=renderer.snapshot(atTime:ProcessInfo.processInfo.systemUptime,with:size,antialiasingMode:.multisampling4X)
   guard let cg=picture.cgImage(forProposedRect:nil,context:nil,hints:nil),let data=NSBitmapImageRep(cgImage:cg).representation(using:.png,properties:[:]) else{throw NSError(domain:"PerspectiveProof",code:2)}
   try data.write(to:output.appendingPathComponent(name+".png"),options:.withoutOverwriting)
   if !ending && game.core.layout.kind == .island {
    let pixels=NSBitmapImageRep(cgImage:cg)
    for x in [2,pixels.pixelsWide-3] {for y in [2,pixels.pixelsHigh-3] {
     let color=pixels.colorAt(x:x,y:y)!.usingColorSpace(.deviceRGB)!
     try require(color.redComponent+color.greenComponent+color.blueComponent>0.06,"The full-map camera exposed a black corner outside the water background")
    }}
   }
   try require(!game.camera.camera!.usesOrthographicProjection && game.camera.camera!.projectionDirection == .horizontal && abs(game.camera.camera!.fieldOfView-65)<1e-6,"Production camera is not using the chosen perspective projection")
   if !ending {
    let f=game.camera.worldFront,pitch=atan2(-Double(f.y),hypot(Double(f.x),Double(f.z)))*180/Double.pi
    try require(abs(pitch-75)<0.001,"Actual renderer view lost the archived75degree pitch")
    try require(abs(Double(f.x))<0.0001 && Double(f.z)*game.core.viewOrientation.sign<0,"Actual renderer yaw disagrees with the current round/bonus view")
    // Check map borders and each near entrance approach against the actual camera matrix.
    for subject in game.core.layout.overviewSubjects {
     var projected=[SCNVector3]()
     for dx in [-subject.radius,subject.radius] {for dz in [-subject.radius,subject.radius] {for dy in [0.0,subject.height] {
      let p=NativeCameraProjection.project(SCNVector3(subject.p.x+dx,subject.elevation+dy,subject.p.y+dz),camera:game.camera,size:size)
      let fit=min(1,Double(size.width/size.height)/(16.0/9))
      let top=game.cameraRig.usesCenteredFrame ? 0.465:0.285
      try require(p.z>0 && p.z<1 && p.x>size.width*0.035 && p.x<size.width*0.965 && p.y>size.height*(0.5-0.435*fit) && p.y<size.height*(0.5+top*fit),"Whole playable map or near entrance cropped by actual camera:round\(game.core.round),subject\(subject.p),projected\(p)")
      projected.append(p)
      mapCorners+=1
     }}}
     try checkHUDClear(projected,"map/entrance",size)
    }
    for player in game.core.livingPlayers {let art=game.playerArtStates[player.slot];try checkGeometry(art.vehicleNode ?? art.hero,size)}
    for node in Array(game.fateDoorNodes.values)+Array(game.fateDropNodes.values)+Array(game.fateBootNodes.values)+Array(game.fateLifeNodes.values) where !node.isHidden {try checkGeometry(node,size)}
   }else {
    // The pedestal camera deliberately has its own cinematic angle; it must survive projection changes.
    try require(game.camera.worldUp.y>0 && game.camera.worldRight.x>0,"Ending view inherited the preceding gameplay camera's inverted up direction")
    for x in [-3.0,3] {for z in [-3.0,3] {
     let p=NativeCameraProjection.project(SCNVector3(x,101.1,z),camera:game.camera,size:size);try require(p.x>20 && p.x<size.width-20 && p.y>size.height*0.1 && p.y<size.height*0.87,"Ending pedestal left its cinematic view")
    }}
   }
   images+=1;print("PASS perspective image \(name),\(corners)actualgeometrycornerprojections")
  }
  stage();game.core.hero = .zero;try save("camera-solo-center")
  let viewCenter=game.cameraRig.center
  func width(at z:Double)->Double {
   let a=NativeCameraProjection.project(SCNVector3(viewCenter.x-0.5,0,z),camera:game.camera,size:CGSize(width:1600,height:900)),b=NativeCameraProjection.project(SCNVector3(viewCenter.x+0.5,0,z),camera:game.camera,size:CGSize(width:1600,height:900));return abs(Double(b.x-a.x))
  }
  try require(width(at:viewCenter.y+3)>width(at:viewCenter.y-3)*1.01,"Actual nearer and farther objects still have equal orthographic widths")
  func calibrate(_ name:String,orientation:ArenaViewOrientation)throws {
   let near=box(3,0.04,0.8,0xff0000),far=box(3,0.04,0.8,0x0000ff)
   for (node,p) in [(near,SCNVector3(-2*orientation.sign,0.06,3*orientation.sign)),(far,SCNVector3(2*orientation.sign,0.06,-3*orientation.sign))] {
    node.position=p;node.geometry!.firstMaterial!.lightingModel = .constant;node.castsShadow=false;game.scene.rootNode.addChildNode(node)
   }
   let calibration=renderer.snapshot(atTime:ProcessInfo.processInfo.systemUptime,with:CGSize(width:1600,height:900),antialiasingMode:.none)
   let calibrationCG=calibration.cgImage(forProposedRect:nil,context:nil,hints:nil)!,bitmap=NSBitmapImageRep(cgImage:calibrationCG)
   var pixels=[UInt8](repeating:0,count:1600*900*4)
   pixels.withUnsafeMutableBytes {buffer in
    let context=CGContext(data:buffer.baseAddress,width:1600,height:900,bitsPerComponent:8,bytesPerRow:1600*4,space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGBitmapInfo.byteOrder32Big.rawValue|CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.draw(calibrationCG,in:CGRect(x:0,y:0,width:1600,height:900))
   }
   var bounds=[(1600,900,-1,-1),(1600,900,-1,-1)]
   for y in 0..<900 {for x in 0..<1600 {
    let p=(y*1600+x)*4,r=pixels[p],g=pixels[p+1],b=pixels[p+2]
    let i=r>230 && g<50 && b<50 ? 0:b>230 && r<50 && g<50 ? 1:-1
    if i>=0 {let b=bounds[i];bounds[i]=(min(x,b.0),min(y,b.1),max(x,b.2),max(y,b.3))}
   }}
   var direct=true,flipped=true
   let calibrationData=bitmap.representation(using:.png,properties:[:])!;try calibrationData.write(to:output.appendingPathComponent(name+".png"),options:.withoutOverwriting)
   for (i,node) in [near,far].enumerated() {
    let b=bounds[i],p=NativeCameraProjection.project(node.worldPosition,camera:game.camera,size:CGSize(width:1600,height:900)),x=Double(b.0+b.2)/2,y=Double(b.1+b.3)/2
    try require(b.2>b.0 && b.3>b.1 && abs(x-Double(p.x))<3,"Camera matrix did not agree with the actual colored pixel center:marker\(i),bounds\(b),expected\(p)")
    direct = direct && abs(y-Double(p.y))<3;flipped = flipped && abs(y-(900-Double(p.y)))<3
   }
   try require(direct || flipped,"Camera matrix and native pixel coordinates disagree vertically")
   try require(Double(bounds[0].2-bounds[0].0)>Double(bounds[1].2-bounds[1].0)*1.01,"Actual red near marker is not wider than the equal blue far marker")
   images+=1
   print("PASS native pixel calibration:near\(bounds[0]),far\(bounds[1]),matrix matches two actual color centers,width ratio greater1.01")
   near.removeFromParentNode();far.removeFromParentNode()
  }
  try calibrate("camera-pixel-calibration",orientation:.normal)
  let centralWidth=width(at:viewCenter.y)
  print("PASS whole-map framing:one metre=\(centralWidth)pixels;complete playable ground and near water/pier approaches remain visible;far spawn shelters may lie outside the image")
  for (index,point) in [V2(x:11,y:7),V2(x:-11,y:-7),V2(x:11,y:-7),V2(x:-11,y:7)].enumerated() {
   stage(index%2+1);game.core.hero=game.core.layout.clamped(point);game.core.heroElevation=game.core.layout.height(game.core.hero)
   try save("camera-close-corner-\(index)")
   try require(abs(game.cameraRig.scale-game.cameraRig.baseScale)<0.0001,"Ground movement changed the fixed whole-map frame")
  }
  for round in [1,2] {
   stage(round)
   for index in 0..<game.core.layout.enemyEntranceCount {
    var foe=game.core.arrivingFoe(kind:.zombie,hp:100,speed:0,entrance:index,lane:0)
    let route=game.core.layout.enemyArrival(index:index)
    let entry=NearEntranceFrame.points(route,width:IslandLayout.width,depth:IslandLayout.depth).first!
    foe.p=entry.p;foe.elevation=entry.height;game.core.foes.append(foe)
   }
   try save("camera-complete-entries-round-\(round)")
   for node in game.foeNodes.values {try checkGeometry(node,CGSize(width:1600,height:900))}
   try require(game.foeNodes.count==6,"The independent entrance fixture lost an enemy")
  }
  stage();game.core.hero = .zero;game.settings.zoom = .close;try save("camera-zoom-close")
  game.settings.zoom = .wide;game.lastRound=0;try save("camera-zoom-wide")
  stage();game.core.hero = .zero;tick()
  game.core.hero=game.core.layout.clamped(V2(x:11,y:6));game.lastRound=0;try save("camera-solo-island-edge")
  game.settings.cameraMode = .overview;game.settings.zoom = .close;game.lastRound=0;try save("camera-solo-overview-edge")
  stage();game.core.hero=V2(x:6,y:4);game.core.apply(.helicopter);try save("camera-solo-hind")
  stage();game.core.hero=V2(x:6,y:4);game.core.apply(.tank);try save("camera-solo-tank")
  stage(21);game.core.hero=V2(x:-7,y:-1.3);game.core.heroElevation=game.core.layout.height(game.core.hero);try save("camera-solo-urban-rooftop")
  stage(9,4);game.core.withPlayer(0){game.core.apply(.tank)};game.core.withPlayer(1){game.core.apply(.helicopter)}
  try save("camera-team-prison-vehicles")
  try save("camera-team-prison-4x3",CGSize(width:1200,height:900))
  try save("camera-team-prison-square",CGSize(width:900,height:900))
  try save("camera-team-prison-portrait",CGSize(width:675,height:900))
  stage(15,4);game.core.phase = .cleared;game.core.enterFateRoom();game.core.sideRoom!.clock=5.7
  for fate in FateKind.allCases {game.core.players[fate.rawValue].hero=game.core.fateRoom!.door(for:fate).p}
  game.core.step(0,inputs:[]);try save("camera-fate-high-deliveries")
  stage(15,4);game.core.phase = .cleared
  for p in game.core.players {p.lives=0;p.donationCooldown=999;if p.slot>0 {p.isDown=true;p.reviveRemaining=50}}
  game.core.enterFateRoom();game.core.players[0].hero=V2(x:-3,y:-2)
  try save("camera-fate-life-high")
  game.core.sideRoom!.clock=1.31;game.core.step(0,inputs:[]);try save("camera-fate-life-ground")
  stage();game.core.lives=0;game.core.invulnerable=0;game.core.loseLife()
  var ending=GameOverSequence();ending.step(2.5,input:Controls());game.core.gameOverSequence=ending
  try save("camera-ending-pedestal",ending:true)
  try save("camera-ending-pedestal-4x3",CGSize(width:1200,height:900),ending:true)
  ending.step(1.3,input:Controls());game.core.gameOverSequence=ending;try save("camera-ending-theft",ending:true)
  stage(2);game.core.lives=0;game.core.invulnerable=0;game.core.loseLife()
  var reversedEnding=GameOverSequence();reversedEnding.step(2.5,input:Controls());game.core.gameOverSequence=reversedEnding
  try save("camera-ending-from-reversed",ending:true)
  try save("camera-ending-from-reversed-4x3",CGSize(width:1200,height:900),ending:true)
  stage();game.core.hero = .zero;tick();let start=game.cameraRig.center,startingScale=game.cameraRig.scale
  for _ in 0..<60 {game.lastTime=ProcessInfo.processInfo.systemUptime-1.0/60;game.tick(players:[Controls(move:V2(x:1,y:0))],devices:[],viewSize:CGSize(width:1600,height:900))}
  try save("camera-following-motion")
  try require(game.cameraRig.center==start && game.cameraRig.scale==startingScale && game.core.hero.x>5,"Real movement changed the whole-map center or zoom")
  for round in 1...8 {
   stage(round);game.core.hero = .zero;game.core.phase = .cleared;game.core.prepareArenaExits();game.core.clearClock=3;game.core.messageTime=0
   try save("camera-round-\(round)-view")
   let view=game.core.viewOrientation,size=CGSize(width:1600,height:900)
   let origin=NativeCameraProjection.project(SCNVector3(0,0.1,0),camera:game.camera,size:size)
   let right=view.transform(V2(x:1,y:0)),up=view.transform(V2(x:0,y:-1))
   let rp=NativeCameraProjection.project(SCNVector3(right.x,0.1,right.y),camera:game.camera,size:size)
   let upPoint=NativeCameraProjection.project(SCNVector3(up.x,0.1,up.y),camera:game.camera,size:size)
   try require(rp.x>origin.x && upPoint.y>origin.y,"Screen/world directions disagree with actual rendered axes in round\(round)")
   try require(game.notice.text?.contains(game.core.exitInstruction)==true,"Exit guidance disagrees with the actual open paths in round\(round)")
  }
  stage(1,2);game.core.phase = .cleared;game.core.fateRoomVisited=true
  game.core.enterSideRoom(SideRoomOffer(kind:.treasure,p:game.core.layout.exit))
  try save("camera-bonus-entry-reversed")
  try require(game.core.viewOrientation == .reversed,"Bonus entry did not apply its first view update")
  game.core.startNextCombatRound();try save("camera-bonus-exit-normal")
  try require(game.core.viewOrientation == .normal && game.core.bonusViewFlip,"Bonus return lost its extra view update")
  game.core.startNextCombatRound();try save("camera-after-bonus-reversed")
  try require(game.core.viewOrientation == .reversed,"Later combat lost its retained bonus parity")
  stage(2,2);game.core.players[0].hero=V2(x:-1,y:0);game.core.players[1].hero=V2(x:1,y:0);tick()
  let starts=game.core.players.map(\.hero)
  for _ in 0..<30 {
   game.lastTime=ProcessInfo.processInfo.systemUptime-1.0/60
   game.tick(players:[Controls(move:V2(x:1,y:0),aim:V2(x:1,y:0)),Controls(move:V2(x:0,y:-1),aim:V2(x:0,y:-1))],devices:[],viewSize:CGSize(width:1600,height:900))
  }
  let positions=game.core.players.map(\.hero)
  try require(positions[0].x<starts[0].x-2 && positions[1].y>starts[1].y+2,"The production input adapter did not rotate both players' movement")
  try require(game.core.players[0].facing.x == -1 && game.core.players[1].facing.y == 1 && game.core.shots.contains{$0.ownerSlot==0 && $0.v.x<0} && game.core.shots.contains{$0.ownerSlot==1 && $0.v.y>0},"The production input adapter did not rotate both players' firing")
  try save("camera-reversed-two-player-input")
  stage(2);game.core.hero = .zero;tick();try calibrate("camera-pixel-calibration-reversed",orientation:.reversed)
  stage();game.settings=GameSettings.decode(Data("{\"cameraMode\":\"overview\",\"zoom\":2,\"playerColor\":\"blue\"}".utf8))
  game.core.phase = .paused;game.menu.openSettings(phase:.paused)
  try save("camera-automatic-settings")
  let labels=game.menuNames.filter{!$0.isHidden}.map{$0.text ?? ""}
  try require(labels.count==5 && !labels.contains(where:{$0.contains("Kamera") || $0.contains("Zoom")}) && game.settings.cameraMode == .following && game.settings.zoom == .normal,"Production menu still exposes manual camera controls or accepts legacy framing preferences")
  game.handleMenus(Controls(accept:true,menuRow:2),dt:0)
  try require(game.menu.audioOpen,"Compact production settings lost the sound submenu")
  game.handleMenus(Controls(back:true),dt:0);game.handleMenus(Controls(accept:true,menuRow:4),dt:0)
  try require(!game.menu.settingsOpen && game.core.phase == .paused,"Compact production Back row unexpectedly resumed the game")
  try require(game.audio.voiceCount==0 && game.audio.playedCount==0 && game.music.playedCount==0,"Perspective proof attempted audio")
  print("PASS perspective camera:\(images)nativeimages,\(corners)actualgeometrycornerprojections,\(mapCorners)map-and-entry-cornerprojections,75degree gameplay pitch,65degree horizontal FOV,depth-size difference,both native pixel calibrations,first8roundyaw/bonusparity/screenrelative2playermovementandfire/nearoutsideapproaches,solo/team/vehicles/roof/Fate/ending/4aspects/fixed whole-map movement;0audio,no window or real controller polling;not hardware/windowFPS/original-engine acceptance")
 }
}
#endif
