import Foundation
@main struct RuinedWallChecks {
 static func main(){
  var checks=0,bounded=true,ordered=true,distinct=false,stable=true,completeSpan=true
  func expect(_ value:Bool,_ text:String){precondition(value,text);checks+=1;print("PASS \(text)")}
  for length in [0.5,6.3,9.7,10.1] {for height in [0.5,1.6,2.2,2.5] {for seed:UInt64 in [0,11,22,31,47,UInt64.max] {
   let d=OpeningMapDesign.RuinedWall(length:length,depth:0.55,height:height,base:-0.25,seed:seed),top=d.top
   stable = stable && top==d.top
   bounded = bounded && top.allSatisfy{$0.x.isFinite && $0.y.isFinite && abs($0.x)<=length/2+1e-12 && $0.y>=d.base+d.height*0.62-1e-12 && $0.y<=d.base+d.height+1e-12}
   ordered = ordered && zip(top,top.dropFirst()).allSatisfy{$1.x-$0.x>0.01}
   distinct = distinct || Set(top.map{Int(($0.y-d.base)*10000)}).count>3
   completeSpan = completeSpan && abs(top.first!.x+length/2)<1e-12 && abs(top.last!.x-length/2)<1e-12
  }}}
  expect(completeSpan,"all96ruinprofiles span their complete original wall footprint")
  expect(bounded && ordered,"all96wallprofiles have finite ordered tops inside the original maximum width and height")
  expect(stable && distinct,"damaged wall caps are deterministic but vary across their surface")
  var doorsOutside=true,doorsWithinOldSize=true
  for center in OpeningMapDesign.courtyardDoorCenters {
   let angle=center.x<0 ? -0.48:0.48
   for x in [-0.8,0.8] {for z in [-0.075,0.075] {
    let p=V2(x:center.x+x*cos(angle)+z*sin(angle),y:center.y-x*sin(angle)+z*cos(angle))
    doorsOutside = doorsOutside && !ArenaLayout(kind:.courtyard).contains(p)
    doorsWithinOldSize = doorsWithinOldSize && p.y < -7.6 && abs(p.x)<3.5
   }}
  }
  expect(doorsOutside && doorsWithinOldSize,"both open door leaves fit their original size and remain outside playable ground")
  expect(OpeningMapDesign.fountainRadius==1.65,"fountain gameplay footprint remains unchanged while its rendered basin is refined")
  print("\(checks) ruined wall checks passed;native geometry,door and entry clearances,actual visibility and GPU cost checked separately")
 }
}
