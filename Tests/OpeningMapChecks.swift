import Foundation

@main struct OpeningMapChecks {
    static func main(){
        var checks=0
        func expect(_ value:Bool,_ text:String){if !value {print("FAIL \(text)");exit(1)};checks+=1;print("PASS \(text)")}
        let island=ArenaLayout.forRound(1),court=ArenaLayout.forRound(5)
        expect((1...8).map{ArenaLayout.forRound($0).kind} == Array(repeating:.island,count:4)+Array(repeating:.courtyard,count:4),"first eight rounds retain two coherent four-round opening arenas")
        expect(!island.walkable(OpeningMapDesign.boat.p) && island.walkable(island.clamped(OpeningMapDesign.boat.p)),"shared boat footprint blocks its body but leaves an escape boundary")
        for design in OpeningMapDesign.piers {
            for lane in [-0.32,0,0.32] {
                let a=island.enemyArrival(index:design.entrance,lane:lane/0.32),expected=design.route(lane:lane)
                expect(a.points.map(\.p)==expected.points.map(\.p) && a.points.map(\.height)==expected.points.map(\.height),"pier\(design.entrance) lane\(lane) uses the same three anchors for approach and deck/ramp")
                expect(!island.contains(a.start.p) && island.walkable(a.end.p,clearance:0.4),"pier\(design.entrance) lane\(lane) starts outside and finishes on a body-width clear arena surface")
                var route=a,p=a.start.p,h=a.start.height,valid=true,steps=0
                while steps<1000 {
                    let before=p,oldHeight=h,finished=route.advance(position:&p,height:&h,distance:0.04)
                    if (p-before).length>0.040001 || abs(h-oldHeight)>0.010001 {valid=false}
                    if abs(h-design.surfaceHeight(p))>0.00001 {valid=false}
                    steps+=1;if finished{break}
                }
                expect(valid && steps<1000 && p==a.end.p && abs(h)<0.00001,"pier\(design.entrance) lane\(lane) walks continuously down its visible ramp without a jump")
            }
        }
        var hutClear=true
        // Sample the entire visible 3.7x3.75m roof/floor footprint after its actual yaw.
        let hut=ArenaObstacle(OpeningMapDesign.hut,half:V2(x:1.85,y:1.875),angle:-0.16)
        for x in -25...25 {for y in -25...25 {let p=hut.world(V2(x:Double(x)/25*1.85,y:Double(y)/25*1.875));if island.walkable(p,clearance:0.29){hutClear=false}}}
        expect(hutClear,"relocated island hut no longer occupies any sampled playable body position without collision")
        var pathsClear=true
        for path in OpeningMapDesign.islandPaths {for segment in zip(path.points,path.points.dropFirst()) {if !island.lineClear(segment.0,segment.1,clearance:0.29){pathsClear=false}}}
        expect(pathsClear,"authored island paths do not guide a body through the boat or outside the arena")
        let ring=[V2(x:-10.8,y:-6.9),V2(x:10.8,y:-6.9),V2(x:10.8,y:6.9),V2(x:-10.8,y:6.9)]
        expect((0..<4).allSatisfy{court.lineClear(ring[$0],ring[($0+1)%4],clearance:0.4)},"courtyard perimeter walk remains continuous around the fountain before runtime hazards")
        expect(!court.walkable(.zero) && court.lineClear(V2(x:-8,y:0),V2(x:-2.1,y:0),clearance:0.4),"fountain stays solid while its cross approach remains accessible")
        print("\(checks) opening map checks passed;own editable surface/landmark data,real outside pier routes and continuous body-width approaches;not original map measurements")
    }
}
