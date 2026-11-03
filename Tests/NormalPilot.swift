import Foundation

/// Test driver only: ordinary controls, no world writes or equipment grants.
final class NormalPilot {
 let nav=ArenaNavigation(),vehiclePilot=VehiclePilot()
 var waypoint=0
 let waypoints=[V2(x:0,y:-5.7),V2(x:9,y:-5.7),V2(x:9,y:0),V2(x:9,y:5.7),V2(x:0,y:5.7),V2(x:-9,y:5.7),V2(x:-9,y:0),V2(x:-9,y:-5.7)]
 func sample(_ g:GameCore)->Controls {
    var c=Controls()
    var target=waypoints[waypoint]
    if g.phase == .cleared {target=g.exitClock<0.45 && g.arenaExits.first?.teleporter != true ? g.hero:g.suggestedExit}
    else if g.phase == .bonusRoom {target=g.pickups.min(by:{($0.p-g.hero).length<($1.p-g.hero).length})?.p ?? g.suggestedExit}
    else {
     if (g.hero-target).length<0.8 {waypoint=(waypoint+1)%waypoints.count;target=waypoints[waypoint]}
     if let nearest=g.foes.filter({$0.hp>0}).min(by:{($0.p-g.hero).length<($1.p-g.hero).length}), (nearest.p-g.hero).length<2.7 {
      let away=(g.hero-nearest.p).unit
      let options=(0..<16).map{i in V2(x:cos(Double(i)*Double.pi/8),y:sin(Double(i)*Double.pi/8))}
      let dir=options.max{a,b in
       func score(_ d:V2)->Double {
        let q=g.layout.moved(g.hero,by:d*2.2)
        let threat=g.foes.map{($0.p-q).length}.min() ?? 99
        let danger=g.layout.traps.contains{($0.p-q).length<$0.radius+0.3 && $0.state(at:g.hazardClock+0.7) != .safe}
        return (q-g.hero).length*0.8+min(5,threat)*2+(d.x*away.x+d.y*away.y)*0.2-(danger ? 100:0)
       }
       return score(a)<score(b)
      }!
      target=g.layout.clamped(g.hero+dir*2.2)
     }
    }
    nav.update(layout:g.layout,target:target,dt:1.0/60);c.move=nav.direction(from:g.hero,to:target,layout:g.layout);vehiclePilot.steer(&c,core:g,target:target)
    let clear=g.foes.filter{$0.hp>0 && g.projectileClear(from:g.hero,to:$0.p,height:g.heroElevation+0.53)}
    if let foe=(clear.isEmpty ? g.foes:clear).min(by:{($0.p-g.hero).length<($1.p-g.hero).length}) {c.aim=(foe.p-g.hero).unit}
    let imminent=g.foes.filter{($0.p-g.hero).length<1.7 && abs($0.elevation-g.heroElevation)<0.7}.count
    if imminent>=3 && g.bombs>0 {c.bomb=true}
    if g.phase == .playing && g.layout.traps.contains(where:{($0.p-g.hero).length<$0.radius+0.15 && $0.state(at:g.hazardClock+0.12) == .active}) && g.dashes>0 {c.dash=true;c.aim=c.move}
    // A player checks the actual intended movement for nearby hazards in every frame,
    // including quiet gaps between groups. Never change the world or grant equipment.
    if g.vehicle==nil {
     let dangerFoes=g.foes.filter{$0.hp>0 && ($0.p-g.hero).length<5 && abs($0.elevation-g.heroElevation)<0.7}
     let visitor=g.treasureRaider.flatMap{$0.hostile && abs($0.elevation-g.heroElevation)<0.9 ? $0.p:nil}
     let intended=g.layout.moved(g.hero,by:c.move*1.8)
     let visitorClose=visitor.map{($0-g.hero).length<3} ?? false
     if PilotAvoidance.unsafe(g.layout,phase:g.phase,clock:g.hazardClock,from:g.hero,to:intended) || visitorClose {
      let directions=(0..<32).map{i in V2(x:cos(Double(i)*Double.pi/16),y:sin(Double(i)*Double.pi/16))}
      c.move=directions.max{a,b in
       func score(_ d:V2)->Double {
        let q=g.layout.moved(g.hero,by:d*1.8),progress=(g.hero-target).length-(q-target).length
        let threat=dangerFoes.map{($0.p-q).length}.min() ?? 5
        let raiderRisk=visitor.map{($0-q).length<2.2 ? 1000.0:0} ?? 0
        return (q-g.hero).length+min(5,threat)*1.5+progress*0.5-(PilotAvoidance.unsafe(g.layout,phase:g.phase,clock:g.hazardClock,from:g.hero,to:q) ? 1000:0)-raiderRisk
       }
       return score(a)<score(b)
      } ?? c.move
     }
    }
    return c
 }
}

private enum PilotAvoidance {
 nonisolated static func unsafe(_ layout:ArenaLayout,phase:RunPhase,clock:Double,from:V2,to:V2)->Bool {
  (phase == .playing || phase == .cleared) && layout.traps.contains{trap in trap.p.distance(toSegmentFrom:from,to:to)<1.85 && (trap.state(at:clock+0.20) != .safe || trap.state(at:clock+0.55) != .safe)}
 }
}
