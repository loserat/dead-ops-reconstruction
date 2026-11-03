import Foundation

/// Test controller only: drives the same public Controls as a player, without state/equipment injection.
final class VehiclePilot {
    private let tankNavigation=ArenaNavigation(clearance:0.65)
    func steer(_ input:inout Controls,core g:GameCore,target:V2) {
        guard let v=g.vehicle,v.landingTarget==nil else{return}
        let distance=(target-g.hero).length
        if v.kind == .tank {
            let destination=g.layout.clamped(target,clearance:0.72)
            tankNavigation.update(layout:g.layout,target:destination,dt:1.0/60)
            let d=tankNavigation.direction(from:g.hero,to:destination,layout:g.layout)
            let dot=max(-1,min(1,d.unit.x*v.heading.x+d.unit.y*v.heading.y))
            let throttle=min(1,max(0.14,distance*0.55))*(dot<0.8 ? 0.22:1)
            input.move=d.unit*throttle
        }else {
            let desired=(target-g.hero).unit
            let directions=[desired]+(0..<24).map{i in V2(x:cos(Double(i)*Double.pi/12),y:sin(Double(i)*Double.pi/12))}
            let best=directions.max{a,b in
                func score(_ d:V2)->Double {
                    let q=g.flightPosition(g.hero,by:d*min(3,distance))
                    return (distance-(q-target).length)*2+(q-g.hero).length*0.10+(d.x*desired.x+d.y*desired.y)*0.05
                }
                return score(a)<score(b)
            } ?? desired
            input.move=best*min(1,max(0.12,distance*0.6))
        }
    }
}
