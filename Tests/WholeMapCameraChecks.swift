import Foundation
import CoreGraphics
@main struct WholeMapCameraChecks {
 static func main(){
  var passed=0,projections=0
  func expect(_ yes:Bool,_ text:String){precondition(yes,text);passed+=1;print("PASS \(text)")}
  func fits(_ subjects:[CameraSubject],_ rig:ArenaOverviewCamera,_ aspect:Double,_ orientation:ArenaViewOrientation)->Bool {
   let pitch=75.0*Double.pi/180,tanH=tan(65.0*Double.pi/360),d=rig.scale*aspect/tanH,fit=min(1,aspect/(16.0/9))
   for s in subjects {
    var screen=[V2]()
    for dx in [-s.radius,s.radius] {for dz in [-s.radius,s.radius] {for dy in [0.0,s.height] {
    let x=(s.p.x+dx-rig.center.x)*orientation.sign,z=(s.p.y+dz-rig.center.y)*orientation.sign,h=s.elevation+dy
    let depth=d-h*sin(pitch)-z*cos(pitch),u=x/(depth*tanH),v=(h*cos(pitch)-z*sin(pitch))/(depth*tanH/aspect)
    if depth<=0 || abs(u)>0.92001 || v>(rig.usesCenteredFrame ? 0.92001:0.56001)*fit || v < -0.86001*fit {return false}
    screen.append(V2(x:u,y:v))
    projections+=1
    }}}
    if rig.usesCenteredFrame {
     // Independent projection against the logical visible card/banner footprints, plus8px clearance.
     let factor=min(aspect/1280,1.0/720)
     let bounds=CGRect(x:screen.map(\.x).min()!,y:screen.map(\.y).min()!,width:screen.map(\.x).max()!-screen.map(\.x).min()!,height:screen.map(\.y).max()!-screen.map(\.y).min()!)
     for r in [CGRect(x:16,y:568,width:296,height:136),CGRect(x:748,y:644,width:516,height:60)] {
      let panel=CGRect(x:(Double(r.minX)-640)*2*factor/aspect,y:(Double(r.minY)-360)*2*factor,width:Double(r.width)*2*factor/aspect,height:Double(r.height)*2*factor)
      if panel.intersects(bounds) {return false}
     }
    }
   }
   return true
  }
  for round in 1...40 {for orientation in ArenaViewOrientation.allCases {for aspect in [16.0/9,16.0/10,4.0/3,1.0,0.75] {
   let layout=ArenaLayout.forRound(round);var rig=ArenaOverviewCamera()
   rig.update(layout:layout,subjects:[],aspect:aspect,dt:0,orientation:orientation)
   expect(fits(layout.overviewSubjects,rig,aspect,orientation),"entire round\(round) playable ground and near entrances fit \(aspect)/\(orientation)")
   // Independent physical route samples: outside shelters must remain real routes,
   // but the latest framing requirement no longer reserves the entire outside area.
   // Sample actual travel rather than calling the camera's segment-clipping helper.
   let w=layout.kind == .cave ? CaveLayout.width:IslandLayout.width
   let d=layout.kind == .cave ? CaveLayout.depth:IslandLayout.depth
   var independentRoutes=[CameraSubject]()
   for entry in 0..<layout.enemyEntranceCount {
    var route=layout.enemyArrival(index:entry),p=route.start.p,h=route.start.height
    for _ in 0..<1200 {
     if abs(p.x)<=w+0.35 && abs(p.y)<=d+0.35 {
      independentRoutes.append(CameraSubject(p:p,elevation:max(0,h),radius:0.25,height:1.6))
     }
     if route.advance(position:&p,height:&h,distance:0.1){break}
    }
   }
   expect(!independentRoutes.isEmpty && fits(independentRoutes,rig,aspect,orientation),"real near-entrance travel remains visible independently of the framing input")
   let center=rig.center,scale=rig.scale
   for frame in 0..<120 {
    let t=Double(frame)/60,p=layout.clamped(V2(x:sin(t)*10,y:cos(t)*6)),s=CameraSubject(p:p,elevation:layout.height(p),radius:1.2,height:2.4)
    rig.update(layout:layout,subjects:[s],aspect:aspect,dt:1.0/60,orientation:orientation)
    // Later maps may have raised ground and a different playable footprint.
    // Preserve the fixed map center and full playable view, while allowing the
    // existing height/body safety rule when the actor genuinely needs more space.
    precondition(rig.center==center && rig.scale>=scale && fits(layout.overviewSubjects+[s],rig,aspect,orientation),"movement lost a playable border or active actor")
    if round<=8 {precondition(abs(rig.scale-scale)<1e-9,"opening ground movement caused unnecessary zoom")}
   }
   expect(rig.center==center && rig.scale>=scale,"ground movement keeps the fixed map center and complete playable frame")
   let aircraft=CameraSubject(p:V2(x:11,y:7),elevation:8,radius:3,height:3)
   rig.update(layout:layout,subjects:[aircraft],aspect:aspect,dt:0,orientation:orientation)
   expect(rig.center==center && rig.scale>=scale && fits(layout.overviewSubjects+[aircraft],rig,aspect,orientation),"a high vehicle may only widen the complete map view,never crop a border")
   for _ in 0..<300 {rig.update(layout:layout,subjects:[],aspect:aspect,dt:1.0/60,orientation:orientation)}
   expect(rig.scale>=scale && rig.scale<scale*1.03,"after additional height disappears the camera returns only to the full-map baseline")
  }}}
  var rig=ArenaOverviewCamera(),map=ArenaLayout(kind:.courtyard)
  rig.update(layout:map,subjects:[],aspect:16.0/9,dt:0);let center=rig.center,scale=rig.scale
  rig.update(layout:map,subjects:[CameraSubject(p:V2(x:.nan,y:0),elevation:0)],aspect:.nan,dt:.nan)
  expect(rig.center==center && rig.scale==scale,"invalid actor/time samples do not break the map frame")
  map.bonusRoom = .fate;rig.update(layout:map,subjects:[],aspect:16.0/9,dt:0)
  expect(fits(map.overviewSubjects,rig,16.0/9,.normal),"the complete side room has its own fixed frame")
  print("\(passed) whole-map camera checks passed;\(projections) perspective corners,normal movement,near entrances,airborne safety;native renderer and window checks separate")
 }
}
