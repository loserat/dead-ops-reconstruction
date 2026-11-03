import Foundation
@main struct TeamCameraChecks {
 static func main(){
  setbuf(stdout,nil);var passed=0
  func expect(_ value:Bool,_ message:String){guard value else{fatalError(message)};passed+=1;print("PASS \(message)")}
  var settings=GameSettings();settings.playerColor = .blue;settings.godMode=true;settings.effectsVolume=40
  expect(settings.teamColors.count==4 && Set(settings.teamColors).count==4 && settings.color(for:0) == .blue,"legacy player color remains first while teammates get distinct default colors")
  let encoded=try! JSONEncoder().encode(settings),restored=GameSettings.decode(encoded)
  expect(restored==settings && restored.teamColors==settings.teamColors,"all four color preferences survive settings encoding and loading")
  for slot in 0..<4 {for _ in 0..<10 {settings.adjustColor(slot:slot,delta:1);expect(Set(settings.teamColors).count==4,"color choice can swap a teammate's color while keeping four distinct visible roles")}}
  expect(settings.godMode && settings.effectsVolume==40,"team color selection preserves gameplay and audio preferences")
  let old=settings;settings.adjustColor(slot:-1,delta:1);settings.adjustColor(slot:4,delta:1)
  expect(settings==old,"invalid color roles cannot alter another player's preference")
  let legacy=GameSettings.decode(Data("{\"playerColor\":\"pink\",\"playerTwoColor\":\"unknown\",\"godMode\":true}".utf8))
  expect(legacy.playerColor == .pink && legacy.godMode && Set(legacy.teamColors).count==4,"unknown new color data does not discard old settings or duplicate team colors")
  func visible(_ rig:TeamCameraRig,_ subjects:[CameraSubject],aspect:Double)->Bool {
   let pitch=75.0*Double.pi/180,fit=min(1,aspect/(16.0/9)),tangent=tan(65.0*Double.pi/360)
   let distance=rig.scale*aspect/tangent
   for s in subjects {
    for dx in [-s.radius,s.radius] {for dz in [-s.radius,s.radius] {for dy in [0.0,s.height] {
     let point=s.p+V2(x:dx,y:dz),height=s.elevation+dy-rig.elevation
     let depth=distance-height*sin(pitch)-(point.y-rig.center.y)*cos(pitch)
     let x=(point.x-rig.center.x)/(2*depth*tangent)+0.5
     let vertical=height*cos(pitch)-(point.y-rig.center.y)*sin(pitch)
     let y=vertical/(2*depth*tangent/aspect)+0.5
     if !x.isFinite || !y.isFinite || x<0.05999 || x>0.94001 || y<(0.5-0.32*fit)-0.00001 || y>(0.5+0.28*fit)+0.00001 {return false}
    }}}
   }
   return true
  }
  var checked=0
  for mode in CameraMode.allCases {for zoom in CameraZoom.allCases {for aspect in [16.0/9,4.0/3,1.0,0.75] {
   var prefs=GameSettings();prefs.cameraMode=mode;prefs.zoom=zoom;var rig=TeamCameraRig()
   for frame in 0..<300 {
    let t=Double(frame)/60
    let subjects=(0..<4).map{i -> CameraSubject in
        let phase=Double(i)*1.5,point=V2(x:cos(t*1.2+Double(i)*1.5)*11,y:sin(t+Double(i)*1.5)*7)
        let elevation:Double=i==1 ? 3.1:i==2 ? 1.4:0,radius:Double=i==1 ? 2.5:i==2 ? 2:1.2
        return CameraSubject(p:point,elevation:elevation,radius:radius,height:2.4)
    }
    rig.update(subjects:subjects,settings:prefs,aspect:aspect,floor:0.7,dt:1.0/60,snap:frame==0)
    guard visible(rig,subjects,aspect:aspect) else{fatalError("shared camera clips an active player or vehicle: \(mode)/\(zoom)/\(aspect)/\(frame)")};checked+=1
   }
  }}}
  expect(checked==7200,"7200 moving team frames across camera modes, zooms and four aspects keep all subject bounds inside the safe HUD rectangle")
  var rig=TeamCameraRig();let near=[CameraSubject(p:V2(x:-1,y:0),elevation:0),CameraSubject(p:V2(x:1,y:0),elevation:0)]
  var prefs=GameSettings();rig.update(subjects:near,settings:prefs,aspect:16.0/9,floor:0,dt:1.0/60,snap:true)
  let initial=rig.scale,far=[CameraSubject(p:V2(x:-11,y:-7),elevation:0),CameraSubject(p:V2(x:11,y:7),elevation:3.1,radius:2.5)]
  rig.update(subjects:far,settings:prefs,aspect:16.0/9,floor:0,dt:1.0/60)
  expect(rig.scale>initial && visible(rig,far,aspect:16.0/9),"sudden separation enlarges the camera immediately instead of waiting until a player leaves the image")
  let expanded=rig.scale;rig.update(subjects:near,settings:prefs,aspect:16.0/9,floor:0,dt:1.0/60)
  expect(rig.scale==expanded,"the camera holds a newly enlarged view instead of immediately pumping back in")
  for _ in 0..<45 {rig.update(subjects:near,settings:prefs,aspect:16.0/9,floor:0,dt:1.0/60)}
  expect(rig.scale<expanded && rig.scale>initial,"after the short hold the camera returns to nearby players smoothly")
  prefs.cameraMode = .overview;rig.update(subjects:far,settings:prefs,aspect:16.0/9,floor:5,dt:1,snap:true)
  expect(rig.center == .zero && rig.elevation==0 && visible(rig,far,aspect:16.0/9),"team overview retains the arena center while fitting elevated vehicles")
  let safe=rig.scale;rig.update(subjects:[],settings:prefs,aspect:.nan,floor:.nan,dt:.nan)
  expect(rig.scale==safe && rig.center == .zero,"an empty camera subject list cannot destroy the last valid view")
  rig.update(subjects:[CameraSubject(p:V2(x:.nan,y:0),elevation:0)],settings:prefs,aspect:0,floor:0,dt:-1)
  expect(rig.scale==safe,"invalid subjects are excluded before camera arithmetic")
  print("\(passed) team color/camera checks passed;actual renderer projection and hardware performance are separate")
 }
}
