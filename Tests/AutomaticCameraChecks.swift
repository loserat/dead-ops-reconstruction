import Foundation
@main struct AutomaticCameraChecks {
 static func main(){
  var count=0
  func expect(_ yes:Bool,_ message:String){precondition(yes,message);count+=1;print("PASS \(message)")}
  for mode in ["following","overview","bad"] {for zoom in [-1,0,1,2,999] {
   let data=Data("{\"cameraMode\":\"\(mode)\",\"zoom\":\(zoom),\"godMode\":true,\"brighter\":true,\"soundEnabled\":false,\"effectsVolume\":40,\"musicVolume\":20,\"playerColor\":\"blue\"}".utf8)
   let s=GameSettings.decode(data)
   expect(s.cameraMode == .following && s.zoom == .normal,"legacy camera settings cannot replace the automatic standard")
   expect(s.godMode && s.brighter && !s.soundEnabled && s.effectsVolume==40 && s.musicVolume==20 && s.playerColor == .blue,"retiring camera preferences preserves gameplay audio brightness and player color")
   let object=try! JSONSerialization.jsonObject(with:JSONEncoder().encode(s)) as! [String:Any]
   expect(object["cameraMode"]==nil && object["zoom"]==nil,"new preferences no longer persist manual framing keys")
  }}
  var menu=GameMenu();menu.openSettings(phase:.paused)
  expect(menu.count==5,"global settings contain five meaningful rows without camera or zoom controls")
  expect(menu.handle(Controls(menuX:1,menuRow:1),phase:.paused) == .setting(1,1),"the second row now adjusts brightness")
  expect(menu.handle(Controls(accept:true,menuRow:2),phase:.paused) == .none && menu.audioOpen,"sound remains directly reachable in the compact settings page")
  _=menu.handle(Controls(back:true),phase:.paused)
  expect(menu.selected==2 && menu.settingsOpen && !menu.audioOpen,"audio returns to its visible parent row")
  expect(menu.handle(Controls(menuX:-1,menuRow:3),phase:.paused) == .setting(3,-1),"player color remains reachable without hidden camera actions")
  _=menu.handle(Controls(accept:true,menuRow:4),phase:.paused)
  expect(!menu.settingsOpen && menu.selected==1,"the final visible row returns to the pause menu")
  var zoom=CameraZoomEnvelope();zoom.update(requiredScale:5,dt:0,snap:true)
  zoom.update(requiredScale:8,dt:1.0/60)
  expect(zoom.scale==8,"a suddenly larger subject receives enough view immediately")
  for _ in 0..<30 {zoom.update(requiredScale:5,dt:1.0/60)}
  expect(zoom.scale==8,"half a second of contraction requests cannot pump a newly widened view")
  for _ in 0..<30 {zoom.update(requiredScale:5,dt:1.0/60)}
  expect(zoom.scale<8 && zoom.scale>5,"after the hold the camera gently returns toward its standard size")
  zoom.update(requiredScale:10,dt:0)
  expect(zoom.scale==10,"safety enlargement is immediate even with zero time delta")
  let last=zoom.scale;zoom.update(requiredScale:.nan,dt:1);zoom.update(requiredScale:0,dt:1)
  expect(zoom.scale==last,"invalid scale requests cannot corrupt the previous view")
  zoom.update(requiredScale:5,dt:0,snap:true)
  expect(zoom.scale==5,"arena and orientation snaps reset the zoom envelope immediately")
  for i in 0..<240 {zoom.update(requiredScale:i%2==0 ? 5:5.02,dt:1.0/60)}
  expect(zoom.scale>=5 && zoom.scale<=5.021,"tiny framing fluctuations stay inside a stable deadband")
  var a=CameraZoomEnvelope(),b=a
  a.update(requiredScale:8,dt:0);b.update(requiredScale:8,dt:0)
  for _ in 0..<60 {a.update(requiredScale:5,dt:1.0/60)}
  for _ in 0..<30 {b.update(requiredScale:5,dt:1.0/30)}
  expect(abs(a.scale-b.scale)<0.00001,"hold and damped contraction integrate elapsed time consistently at30and60updates")
  print("\(count) automatic-camera preference/menu/stability checks passed")
 }
}
