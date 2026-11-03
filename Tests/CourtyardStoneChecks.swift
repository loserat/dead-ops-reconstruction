import Foundation
@main struct CourtyardStoneChecks {
 static func main(){
  var checks=0,stones=0,missing=0,topology=true,convex=true,bounds=true,deterministic=true
  func expect(_ value:Bool,_ message:String){precondition(value,message);checks+=1;print("PASS \(message)")}
  for x in -20...20 {for z in -13...13 {
   let p=V2(x:Double(x)*OpeningMapDesign.Stone.spacing,y:Double(z)*OpeningMapDesign.Stone.spacing)
   guard OpeningMapDesign.isCourtyardPath(p),p.length>1.58 else{continue}
   let stone=OpeningMapDesign.courtyardStone(ix:x,iz:z),again=OpeningMapDesign.courtyardStone(ix:x,iz:z),outline=stone.outline
   stones+=1;if stone.missing {missing+=1}
   deterministic = deterministic && stone.missing==again.missing && outline==again.outline
   topology = topology && (4...8).contains(outline.count)
   var area=0.0
   for i in outline.indices {
    let a=outline[i],b=outline[(i+1)%outline.count],c=outline[(i+2)%outline.count]
    area+=a.x*b.y-b.x*a.y
    convex = convex && (b.x-a.x)*(c.y-b.y)-(b.y-a.y)*(c.x-b.x)>1e-12
    bounds = bounds && a.x.isFinite && a.y.isFinite && abs(a.x)<=0.276 && abs(a.y)<=0.276 && (b-a).length>0.01
   }
   topology = topology && area>0.55 && area<=2*0.552*0.552+1e-12
   if stone.missing {precondition(p.length>2.8,"missing stone encroached on the fountain apron")}
  }}
  expect(stones>500 && missing>0 && missing<stones/12,"courtyard retains dense clear routes with only sparse chipped boundary gaps")
  expect(topology,"every stone has a nondegenerate four-to-eight-corner polygon with a substantial top area")
  expect(convex && bounds,"all stone fans are convex finite and confined to their old horizontal footprints")
  expect(deterministic,"paving wear is deterministic and cannot flicker or change on arena revisit")
  expect(OpeningMapDesign.courtyardStone(ix:7,iz:4).outline != OpeningMapDesign.courtyardStone(ix:-9,iz:3).outline,"different stone positions receive visibly distinct wear profiles rather than repeating one cutout")
  for (x,z) in [(Int.min,Int.max),(Int.max,Int.min),(0,0)] {
   let outline=OpeningMapDesign.courtyardStone(ix:x,iz:z).outline
   expect(outline.allSatisfy{$0.x.isFinite && $0.y.isFinite},"wrapping coordinate hashes cannot overflow or corrupt a stone profile")
  }
  expect(OpeningMapDesign.Stone.thickness==0.035 && OpeningMapDesign.Stone.spacing==0.57,"existing paving height and path-grid placement remain unchanged")
  print("\(checks) courtyard stone checks passed;\(stones)tilepositions,\(missing)missingedgetiles;actual model heights/normals/materials and GPU cost checked separately")
 }
}
