import Foundation
@main struct CoastalBankChecks {
 static func main(){
  var checks=0,finite=true,outerClearance=true,wetMonotone=true,heightMonotone=true,minRadius=Double.infinity,maxRadius=0.0
  func expect(_ value:Bool,_ message:String){precondition(value,message);checks+=1;print("PASS \(message)")}
  for i in 0..<360 {
   let angle=Double(i)*Double.pi/180;var oldWet=0.0,oldHeight=1.0
   for ring in 0...18 {
    let f=Double(ring)/18,b=OpeningMapDesign.coastalBank(angle:angle,fraction:f)
    finite = finite && b.radius.isFinite && b.height.isFinite && b.wetness.isFinite && (0...1).contains(b.wetness)
    wetMonotone = wetMonotone && b.wetness>=oldWet;heightMonotone = heightMonotone && b.height<=oldHeight
    oldWet=b.wetness;oldHeight=b.height
    if ring==18 {
     minRadius=min(minRadius,b.radius);maxRadius=max(maxRadius,b.radius)
     let coast=IslandLayout.edge(angle:angle,scale:1.19*b.radius),grass=IslandLayout.edge(angle:angle,scale:1.025)
     outerClearance = outerClearance && coast.length-grass.length>0.75
    }
   }
  }
  expect(finite && wetMonotone && heightMonotone,"entire native sand-bank grid is finite with a continuous seaward wetness and descending height")
  expect(outerClearance,"every irregular coast stays outside the unchanged grass perimeter with a visible beach margin")
  expect(maxRadius-minRadius>0.06,"shoreline has broad nonuniform coves instead of one evenly offset rounded rectangle")
  let a=OpeningMapDesign.coastalBank(angle:0,fraction:1),b=OpeningMapDesign.coastalBank(angle:2*Double.pi,fraction:1)
  expect(abs(a.radius-b.radius)<1e-12 && abs(a.height-b.height)<1e-12,"closed shoreline meets without a radial or height seam")
  expect(abs(a.height+0.135)<1e-12 && a.wetness==1,"wet coast keeps its previous water-facing height rather than introducing a raised wall")
  expect(OpeningMapDesign.coastalBank(angle:1,fraction:0).radius==1 && OpeningMapDesign.coastalBank(angle:1,fraction:0.7).wetness==0,"interior sand is dry and the central terrain anchor does not drift")
  expect(OpeningMapDesign.coastalBank(angle:2,fraction:-3).radius==OpeningMapDesign.coastalBank(angle:2,fraction:0).radius && OpeningMapDesign.coastalBank(angle:2,fraction:4).radius==OpeningMapDesign.coastalBank(angle:2,fraction:1).radius,"out-of-range authoring fractions remain bounded to the shore grid")
  print("\(checks) coastal bank checks passed;360angles/19rings,visual geometry only;native pixels,body arrivals and performance checked separately")
 }
}
