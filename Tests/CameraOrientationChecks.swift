import Foundation
@main struct CameraOrientationChecks {
 static func main(){
  var count=0
  func expect(_ yes:Bool,_ message:String){guard yes else{fatalError(message)};count+=1;print("PASS \(message)")}
  var sourceFlip=false,arenaRound=1,matches=true
  for round in 1...161 {
   matches = matches && ArenaViewOrientation.combat(round:round)==(sourceFlip ? .reversed:.normal)
   arenaRound+=1
   if arenaRound<=4 {sourceFlip.toggle()}else{arenaRound=1}
  }
  expect(matches,"161 combat rounds match the independently stepped three flips per arena and retained direction at each arena boundary")
  expect((1...8).map{ArenaViewOrientation.combat(round:$0)} == [.normal,.reversed,.normal,.reversed,.reversed,.normal,.reversed,.normal],"the first eight views alternate inside arenas and keep direction between rounds4and5")
  expect(ArenaViewOrientation.combat(round:0) == .normal && ArenaViewOrientation.combat(round:Int.max).sign.isFinite,"invalid low and extreme round numbers retain a finite view")
  let raw=Controls(move:V2(x:0.3,y:-0.8),aim:V2(x:-0.7,y:0.2),dash:true,bomb:true,accept:true,pause:true,back:true,openSettings:true,systemPause:true,menuX:1,menuY:-1,menuRow:4,menuPoint:V2(x:600,y:300))
  let flipped=ArenaViewOrientation.reversed.worldControls(raw)
  expect(flipped.move == raw.move * -1 && flipped.aim == raw.aim * -1,"a half-turn rotates both sticks and keyboard movement/firing vectors")
  expect(flipped.dash && flipped.bomb && flipped.accept && flipped.pause && flipped.back && flipped.openSettings && flipped.systemPause,"view conversion preserves every one-shot gameplay and system action")
  expect(flipped.menuX==1 && flipped.menuY == -1 && flipped.menuRow==4 && flipped.menuPoint==raw.menuPoint,"menu and pointer coordinates remain in screen space")
  expect(abs(flipped.move.length-raw.move.length)<1e-12 && abs(flipped.aim.length-raw.aim.length)<1e-12,"analog strength and diagonal speed are unchanged by the view")
  expect(ArenaViewOrientation.reversed.transform(flipped.move)==raw.move,"screen/world conversion is reversible without cumulative drift")
  expect(ArenaViewOrientation.normal.worldControls(raw).move==raw.move,"the initial view retains existing world directions")
  expect(ArenaViewOrientation.reversed.exitEdge=="OBEN" && ArenaViewOrientation.reversed.sideEdge(-7)=="RECHTS" && ArenaViewOrientation.reversed.sideEdge(7)=="LINKS","exit and side-route guidance use visible screen directions after a half-turn")
  let core=GameCore();core.reset();core.round=2;core.beginRound();core.hero = .zero;core.foes=[];core.pickups=[];core.combatSpawningHeld=true
  core.step(1.0/60,input:core.viewOrientation.worldControls(Controls(move:V2(x:1,y:0),aim:V2(x:1,y:0))))
  expect(core.hero.x<0 && core.facing.x == -1 && core.shots.contains{$0.v.x<0},"screen-right movement and fire produce world-left motion and projectiles in the reversed view")
  core.reset(playerCount:4);core.round=5;core.beginRound();core.foes=[];core.pickups=[];core.combatSpawningHeld=true
  for p in core.players {p.hero=V2(x:p.slot%2==0 ? -4:4,y:p.slot<2 ? -2.5:2.5)}
  let starts=core.players.map(\.hero),vectors=[V2(x:1,y:0),V2(x:-1,y:0),V2(x:0,y:1),V2(x:0,y:-1)]
  core.step(1.0/60,inputs:vectors.map{core.viewOrientation.worldControls(Controls(move:$0))})
  expect(zip(core.players.indices,vectors).allSatisfy{slot,v in let delta=core.players[slot].hero-starts[slot];return delta.x * -v.x+delta.y * -v.y>0},"four independent player inputs follow their own screen directions under the shared reversed view")
  for round in [1,4] {
   core.reset();core.round=round;core.beginRound();core.fateRoomVisited=true;core.phase = .cleared
   let before=core.viewOrientation,ordinary=ArenaViewOrientation.combat(round:round+1)
   core.enterSideRoom(SideRoomOffer(kind:.treasure,p:core.layout.exit))
   expect(core.sideRoom?.kind == .treasure && core.viewOrientation==ordinary,"bonus entry after round\(round) uses the next-arena update direction")
   let roomView=core.viewOrientation;core.startNextCombatRound()
   expect(core.round==round+1 && core.viewOrientation==roomView.opposite && core.bonusViewFlip,"bonus exit after round\(round) adds a second view update without dropping the retained parity")
   let after=core.viewOrientation;core.phase = .cleared;core.startNextCombatRound()
   expect(core.viewOrientation==after.opposite && core.bonusViewFlip,"later ordinary progress retains the extra bonus parity after round\(round)")
   expect(before==ArenaViewOrientation.combat(round:round),"bonus fixtures begin with the ordinary combat direction for round\(round)")
  }
  core.reset();core.round=14;core.beginRound();core.phase = .cleared;let prior=core.viewOrientation
  core.enterFateRoom();expect(core.viewOrientation==prior && !core.bonusViewFlip,"Fate keeps the current view rather than counting an ordinary bonus-room update")
  core.startNextCombatRound();expect(core.viewOrientation==ArenaViewOrientation.combat(round:15) && !core.bonusViewFlip,"returning from Fate makes the ordinary round update exactly once")
  core.bonusViewFlip=true;core.reset();expect(core.viewOrientation == .normal && !core.bonusViewFlip,"a new run clears bonus parity and restores the initial view")
  let pitch=75.0*Double.pi/180,tangent=tan(65.0*Double.pi/360)
  func fits(_ subject:CameraSubject,center:V2,elevation:Double,scale:Double,aspect:Double,orientation:ArenaViewOrientation)->Bool {
   let distance=scale*aspect/tangent,fit=min(1,aspect/(16.0/9))
   for dx in [-subject.radius,subject.radius] {for dz in [-subject.radius,subject.radius] {for dy in [0.0,subject.height] {
    let x=(subject.p.x+dx-center.x)*orientation.sign,z=(subject.p.y+dz-center.y)*orientation.sign,h=subject.elevation+dy-elevation
    let depth=distance-h*sin(pitch)-z*cos(pitch),u=x/(depth*tangent),v=(h*cos(pitch)-z*sin(pitch))/(depth*tangent/aspect)
    if !depth.isFinite || depth<0.1999 || abs(u)>0.88001 || v>0.56001*fit || v < -0.64001*fit {return false}
   }}}
   return true
  }
  var frames=0
  for orientation in ArenaViewOrientation.allCases {for aspect in [16.0/9,4.0/3,1.0,0.75] {for mode in CameraMode.allCases {for zoom in CameraZoom.allCases {
   var prefs=GameSettings();prefs.cameraMode=mode;prefs.zoom=zoom;var solo=CameraRig(),team=TeamCameraRig()
   for frame in 0..<180 {
    let t=Double(frame)/60
    let subjects=(0..<4).map{i -> CameraSubject in
     let phase=Double(i),p=V2(x:sin(t+phase)*10,y:cos(t*1.3+phase)*6.5)
     let height:Double=i==1 ? 3.1:i==2 ? 1.4:0,radius:Double=i==1 ? 2.5:i==2 ? 2:1.2
     return CameraSubject(p:p,elevation:height,radius:radius,height:2.4)
    }
    solo.update(hero:subjects[0].p,settings:prefs,aspect:aspect,dt:1.0/60,snap:frame==0,subject:subjects[0],orientation:orientation)
    team.update(subjects:subjects,settings:prefs,aspect:aspect,floor:0.7,dt:1.0/60,snap:frame==0,orientation:orientation)
    guard fits(subjects[0],center:solo.center,elevation:0,scale:solo.scale,aspect:aspect,orientation:orientation) && subjects.allSatisfy({fits($0,center:team.center,elevation:team.elevation,scale:team.scale,aspect:aspect,orientation:orientation)}) else{fatalError("rotated subject corner clipped in \(orientation),\(aspect),\(mode),\(zoom),frame\(frame)")}
    frames+=1
   }
  }}}}
  expect(frames==8640,"8640 paired solo/team frames in both directions across modes zooms and four aspects keep every spatial corner inside the HUD-safe rectangle")
  var team=TeamCameraRig();let subjects=[CameraSubject(p:V2(x:7,y:5),elevation:3.1,radius:2.5,height:2.4)]
  team.update(subjects:subjects,settings:GameSettings(),aspect:16.0/9,floor:0,dt:0,snap:true)
  team.update(subjects:subjects,settings:GameSettings(),aspect:16.0/9,floor:0,dt:0,orientation:.reversed)
  expect(fits(subjects[0],center:team.center,elevation:team.elevation,scale:team.scale,aspect:16.0/9,orientation:.reversed),"a zero-delta half-turn immediately reframes its elevated subject")
  print("\(count) camera orientation checks passed;8640pairedframes,own coordinates and bonus-room mapping,not original engine/hardware acceptance")
 }
}
