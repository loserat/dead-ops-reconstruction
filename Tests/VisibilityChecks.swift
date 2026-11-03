import Foundation
@main struct VisibilityChecks {
 static func main(){
  setbuf(stdout,nil);var passed=0
  func expect(_ condition:Bool,_ text:String){if !condition {print("FAIL \(text)");exit(1)};passed+=1;print("PASS \(text)")}
  var cue=PlayerOcclusionState();cue.update(blocked:3,dt:0.1,phase:.playing)
  expect(cue.strength>0.8 && cue.strength<1 && cue.blockedSamples==3,"an actually obscured player gains a quick bounded visibility cue")
  var partial=PlayerOcclusionState();partial.update(blocked:1,dt:0.1,phase:.playing)
  expect(partial.strength>0 && partial.strength<cue.strength*0.4,"one wire or partial obstruction produces a weaker cue than complete body occlusion")
  let before=cue.strength;cue.update(blocked:0,dt:0.05,phase:.playing)
  expect(cue.strength>0 && cue.strength<before && cue.blockedSamples==0,"cleared sightlines fade the cue instead of flashing it abruptly off")
  for _ in 0..<60 {cue.update(blocked:0,dt:1.0/60,phase:.playing)}
  expect(cue.strength<0.001,"a long clear view leaves no permanent extra player overlay")
  var a=PlayerOcclusionState(),b=PlayerOcclusionState()
  for _ in 0..<60 {a.update(blocked:1,dt:1.0/60,phase:.playing)}
  for _ in 0..<30 {b.update(blocked:1,dt:1.0/30,phase:.playing)}
  expect(abs(a.strength-b.strength)<0.000001,"cue timing is independent of30/60frame update subdivision")
  expect([RunPhase.paused,.title,.gameOver,.checkpointComplete,.loopReturn].allSatisfy{phase in var x=a;x.update(blocked:3,dt:1,phase:phase);return x.strength==0 && x.blockedSamples==0},"menus death and loop animation hide the cue immediately")
  expect([RunPhase.playing,.cleared,.bonusRoom].allSatisfy{phase in var x=PlayerOcclusionState();x.update(blocked:1,dt:0.1,phase:phase);return x.strength>0},"combat collection and bonus rooms retain owner visibility")
  var invalid=PlayerOcclusionState();invalid.update(blocked:100,dt:Double.nan,phase:.playing)
  expect(invalid.strength==0 && invalid.blockedSamples==3,"a nonfinite frame time cannot produce a nonfinite or unbounded ghost opacity")
  invalid.update(blocked:-10,dt:-1,phase:.playing);expect(invalid.blockedSamples==0 && invalid.strength==0,"invalid negative sample counts/times cannot create a spurious highlight")
  let velocity=PlayerOcclusionState.velocity(previous:.zero,hero:V2(x:0.1,y:0),dt:0.02,snap:false)
  expect(abs(velocity.x-5)<0.00001 && velocity.y==0,"camera lead derives from real displacement rather than a stick held against a wall")
  expect(PlayerOcclusionState.velocity(previous:V2(x:2,y:0),hero:V2(x:2,y:0),dt:0.02,snap:false) == .zero,"a blocked or stationary player never pushes the camera forward")
  expect(PlayerOcclusionState.velocity(previous:.zero,hero:V2(x:0.1,y:0),dt:0.02,snap:true) == .zero,"arena changes and explicit camera snaps suppress stale movement lead")
  expect(PlayerOcclusionState.velocity(previous:.zero,hero:V2(x:9,y:0),dt:0.02,snap:false) == .zero,"respawn teleport cannot become extreme predictive camera movement")
  expect(PlayerOcclusionState.velocity(previous:nil,hero:V2(x:1,y:1),dt:0.02,snap:false) == .zero && PlayerOcclusionState.velocity(previous:.zero,hero:V2(x:1,y:0),dt:0,snap:false) == .zero,"missing prior position and empty time steps cannot divide by zero")
  expect(abs(PlayerOcclusionState.velocity(previous:.zero,hero:V2(x:1,y:0),dt:0.01,snap:false).length-6)<0.00001,"boost lead is limited even at high movement speed")
  var settings=GameSettings(),leadRig=CameraRig(),plainRig=CameraRig()
  leadRig.update(hero:.zero,settings:settings,aspect:16.0/9,dt:0,snap:true);plainRig=leadRig
  for i in 1...60 {let p=V2(x:Double(i)/12,y:0);leadRig.update(hero:p,settings:settings,aspect:16.0/9,dt:1.0/60,movement:V2(x:5,y:0));plainRig.update(hero:p,settings:settings,aspect:16.0/9,dt:1.0/60)}
  expect(leadRig.center.x>plainRig.center.x+0.27 && leadRig.center.x<5,"small movement lead reduces following lag while keeping the player in view")
  for _ in 0..<120 {leadRig.update(hero:V2(x:5,y:0),settings:settings,aspect:16.0/9,dt:1.0/60)}
  expect(abs(leadRig.center.x-4.5)<0.0001,"stopping removes movement lead smoothly without permanent camera drift")
  settings.cameraMode = .overview;leadRig.update(hero:V2(x:7,y:5),settings:settings,aspect:16.0/9,dt:0,snap:true,movement:V2(x:6,y:4))
  expect(leadRig.center == .zero,"fixed overview ignores movement assistance")
  settings.cameraMode = .following
  for _ in 0..<120 {leadRig.update(hero:V2(x:11,y:7),settings:settings,aspect:4.0/3,dt:1.0/60,movement:V2(x:6,y:6))}
  expect(leadRig.center.x>8.5 && leadRig.center.x<11 && leadRig.center.y>5.5 && leadRig.center.y<7 && leadRig.scale>5,"camera follows to the arena edge while preserving narrow-window compensation")
  var menu=GameMenu();menu.openSettings(phase:.paused)
  expect(menu.handle(Controls(menuX:-1,menuRow:2),phase:.paused) == .none && !menu.audioOpen && menu.settingsOpen,"left on the top sound opening row no longer secretly mutes all sound")
  expect(menu.handle(Controls(menuX:1),phase:.paused) == .none && !menu.audioOpen,"right on the same opening row cannot silently toggle a hidden global setting")
  _=menu.handle(Controls(accept:true),phase:.paused)
  expect(menu.audioOpen && menu.handle(Controls(menuX:-1,menuRow:0),phase:.paused) == .audioSetting(0,-1),"confirm opens audio and the visible global sound row remains adjustable")
  print("\(passed) visibility/camera/menu checks passed;geometry and color inspection are separate native tests")
 }
}
