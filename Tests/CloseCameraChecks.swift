import Foundation
@main struct CloseCameraChecks {
 static func main(){
  var passed=0
  func expect(_ value:Bool,_ message:String){precondition(value,message);passed+=1;print("PASS \(message)")}
  let settings=GameSettings(),aspect=16.0/9
  var rig=CameraRig()
  rig.update(hero:.zero,settings:settings,aspect:aspect,dt:0,subject:CameraSubject(p:.zero,elevation:0,radius:1.2,height:2.4))
  expect(6.1/rig.scale>=1.20,"normal central framing enlarges ground details by at least20percent over0.68")
  for point in [V2(x:11,y:7),V2(x:-11,y:-7),V2(x:-11,y:7),V2(x:11,y:-7)] {
   for orientation in ArenaViewOrientation.allCases {
    rig=CameraRig()
    for _ in 0..<180 {rig.update(hero:point,settings:settings,aspect:aspect,dt:1.0/60,subject:CameraSubject(p:point,elevation:0,radius:1.2,height:2.4),orientation:orientation)}
    expect((rig.center-point).length<2.4,"edge tracking keeps the player near the view center in both camera directions")
    expect(rig.scale<5.5,"settled ground camera stays close at the arena corners instead of pulling back toward the arena center")
   }
  }
  rig=CameraRig();rig.update(hero:.zero,settings:settings,aspect:aspect,dt:0,snap:true)
  for frame in 1...120 {
   let p=V2(x:Double(frame)*6.4/60,y:0)
   rig.update(hero:p,settings:settings,aspect:aspect,dt:1.0/60,movement:V2(x:6.4,y:0),subject:CameraSubject(p:p,elevation:0,radius:1.2,height:2.4))
  }
  expect(rig.center.x>9 && rig.scale<5.5,"a two-second full-speed run tracks smoothly without the old edge zoom-out")
  let center=rig.center,scale=rig.scale
  rig.update(hero:V2(x:.nan,y:0),settings:settings,aspect:.nan,dt:.nan)
  expect(rig.center==center && rig.scale==scale,"invalid camera samples retain the previous finite view")
  rig.update(hero:.zero,settings:settings,aspect:.nan,dt:.nan,snap:true)
  expect(rig.center == .zero && rig.scale.isFinite,"a finite respawn can recover from an invalid aspect and delta")
  var a=CameraRig(),b=CameraRig();a.update(hero:.zero,settings:settings,aspect:aspect,dt:0,snap:true);b=a
  for i in 1...60 {let p=V2(x:Double(i)/10,y:0);a.update(hero:p,settings:settings,aspect:aspect,dt:1.0/60)}
  for i in 1...30 {let p=V2(x:Double(i)/5,y:0);b.update(hero:p,settings:settings,aspect:aspect,dt:1.0/30)}
  expect((a.center-b.center).length<0.05,"tracking damping remains consistent at30and60updates rather than depending on frame count")
  print("\(passed) close-camera checks passed;projection corners and native performance verified separately")
 }
}
