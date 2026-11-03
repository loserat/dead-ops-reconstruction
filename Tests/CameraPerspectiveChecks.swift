import Foundation
@main struct CameraPerspectiveChecks {
 static func main(){
  var count=0
  func expect(_ yes:Bool,_ message:String){guard yes else{fatalError(message)};count+=1;print("PASS \(message)")}
  let pitch=75.0*Double.pi/180,tanH=tan(65.0*Double.pi/360)
  expect(abs(GameCameraProjection.ground-sin(pitch))<1e-12 && abs(GameCameraProjection.up-cos(pitch))<1e-12,"camera basis uses the archived setup75degree pitch")
  expect(abs(GameCameraProjection.tangent-tanH)<1e-12,"horizontal perspective uses the explicitly chosen65degree FOV convention")
  let sourcePitch=75.0*Double.pi/180
  let planeWidth=1.0,depth=GameCameraProjection.distance(scale:6.1,aspect:16.0/9)
  let nearWidth=planeWidth/((depth-3*cos(sourcePitch))*tanH)
  let farWidth=planeWidth/((depth+3*cos(sourcePitch))*tanH)
  let oldPitch=70.0*Double.pi/180
  let oldRatio=(depth+3*cos(oldPitch))/(depth-3*cos(oldPitch))
  expect(nearWidth/farWidth>1.05 && nearWidth/farWidth<oldRatio,"archived75degree angle retains readable near/far depth while reducing the old70degree ground distortion")
  var checks=0
  for aspect in [16.0/9,4.0/3,1.0,0.75] {for mode in CameraMode.allCases {for zoom in CameraZoom.allCases {
   var prefs=GameSettings();prefs.cameraMode=mode;prefs.zoom=zoom;var rig=CameraRig()
   for frame in 0..<240 {
    let t=Double(frame)/60,point=V2(x:sin(t)*11,y:cos(t)*7),height=frame<120 ? 0.0:3.1
    let subject=CameraSubject(p:point,elevation:height,radius:frame<120 ? 1.2:2.5,height:2.4)
    rig.update(hero:point,settings:prefs,aspect:aspect,dt:1.0/60,snap:frame==0,movement:V2(x:6,y:3),subject:subject,elevation:0)
    let distance=rig.scale*aspect/tanH,fit=min(1,aspect/(16.0/9))
    for dx in [-subject.radius,subject.radius] {for dz in [-subject.radius,subject.radius] {for dy in [0.0,subject.height] {
     let x=subject.p.x+dx-rig.center.x,z=subject.p.y+dz-rig.center.y,h=height+dy
     let depth=distance-h*sin(pitch)-z*cos(pitch),u=x/(depth*tanH),v=(h*cos(pitch)-z*sin(pitch))/(depth*tanH/aspect)
     precondition(depth>=0.1999 && abs(u)<=0.88001 && v<=0.56001*fit && v >= -0.64001*fit,"perspective solo corner crossed the safe view rectangle")
    }}}
    checks+=1
   }
  }}}
  expect(checks==5760,"5760 moving solo/airborne camera frames across modes,zooms and four aspects fit every3Dsubject corner")
  let center=V2.zero,point=CameraSubject(p:V2(x:3,y:2),elevation:0,radius:1,height:1.6)
  let low=GameCameraProjection.requiredScale([point],center:center,elevation:0,aspect:16.0/9)
  var airborne=point;airborne.elevation=5
  let high=GameCameraProjection.requiredScale([airborne],center:center,elevation:0,aspect:16.0/9)
  expect(high>low,"an airborne subject's perspective depth requires additional framing distance")
  let distance=GameCameraProjection.distance(scale:5,aspect:16.0/9)
  let near=1/((distance-2*cos(pitch))*tanH),far=1/((distance+2*cos(pitch))*tanH)
  expect(near>far,"equal-sized nearer and farther objects no longer have an orthographic size")
  expect(GameCameraProjection.aspect(.nan)==16.0/9 && GameCameraProjection.aspect(0)==0.5,"invalid aspect values retain a finite bounded projection")
  print("\(count) perspective camera checks passed;5760movingframes,not renderer or hardware acceptance")
 }
}
