import Foundation
@main struct NavigationParity {
 static func main(){
  setbuf(stdout,nil);var bytes=Data(),state:UInt64=5127
  func random()->Double {state=state &* 6364136223846793005 &+ 1442695040888963407;return Double(state>>11)/Double(UInt64.max>>11)}
  func scalar(_ value:Double){var b=value.bitPattern.littleEndian;withUnsafeBytes(of:&b){bytes.append(contentsOf:$0)}}
  func integer(_ value:Int){var b=Int64(value).littleEndian;withUnsafeBytes(of:&b){bytes.append(contentsOf:$0)}}
  func vector(_ p:V2){scalar(p.x);scalar(p.y)}
  var geometrySamples=0,navigationSamples=0,frames=0,poses=0
  for kindIndex in 0..<10 {
   for room in ([nil,.treasure,.armory,.fate] as [SideRoomKind?]) {
    var layout=ArenaLayout(kind:ArenaKind(rawValue:kindIndex)!);layout.bonusRoom=room
    integer(layout.obstacles.count)
    for o in layout.obstacles {vector(o.p);scalar(o.angle);scalar(o.elevation);scalar(o.height);switch o.shape {case .circle(let radius):integer(0);scalar(radius);case .rectangle(let half):integer(1);vector(half)}}
    for i in 0..<160 {
     let p=V2(x:random()*26-13,y:random()*18-9),q=V2(x:random()*26-13,y:random()*18-9),clearance=i%2==0 ? 0.29:0.68
     integer(layout.walkable(p,clearance:clearance) ? 1:0);scalar(layout.height(p));vector(layout.clamped(p,clearance:clearance));integer(layout.lineClear(p,q,clearance:clearance) ? 1:0);vector(layout.moved(p,by:V2(x:0.43,y:-0.31),clearance:clearance));geometrySamples+=1
    }
    let navigation=ArenaNavigation()
    for _ in 0..<24 {
     let from=layout.clamped(V2(x:random()*22-11,y:random()*14-7)),to=layout.clamped(V2(x:random()*22-11,y:random()*14-7))
     navigation.update(layout:layout,target:to,dt:0.3);vector(navigation.direction(from:from,to:to,layout:layout));navigationSamples+=1
    }
   }
   let g=GameCore();g.godMode=true;g.reset();g.round=kindIndex*4+1;g.beginRound();g.hero=g.layout.spawn;g.heroElevation=g.layout.height(g.hero);g.pickups=[];g.combatSpawningHeld=false;g.combatSpawningHeld=true
   g.foes=(0..<120).map{i in
    if i%4==0 {return g.arrivingFoe(kind:.zombie,hp:5,speed:2,entrance:i%g.layout.enemyEntranceCount,lane:Double(i%3)/3)}
    let p=g.layout.clamped(V2(x:Double(i%15)*1.2-8.4,y:Double(i/15)*1.3-4.5));return Foe(id:40000+i,p:p,hp:5,speed:2,gait:Double(i),elevation:g.layout.height(p))
   }
   for frame in 0..<180 {
    if frame==60 {g.apply(.teddy)};if frame==90 {g.apply(.monkey,at:g.layout.clamped(V2(x:3,y:0)))}
    g.step(1.0/60,input:Controls(move:V2(x:cos(Double(frame)*0.017),y:sin(Double(frame)*0.017)),aim:V2(x:sin(Double(frame)*0.031),y:cos(Double(frame)*0.031))))
    vector(g.hero);scalar(g.heroElevation);scalar(g.elapsed);integer(g.score);integer(g.lives);integer(g.trainingHits);integer(g.foes.count);integer(g.pickups.count)
    for f in g.foes {integer(f.id);vector(f.p);scalar(f.elevation);scalar(f.hp);scalar(f.gait);scalar(f.fallSpeed);poses+=1}
    for p in g.pickups {integer(p.id);vector(p.p);integer(p.kind.rawValue);scalar(p.ttl);integer(p.persistent ? 1:0)}
    frames+=1
   }
  }
  try! bytes.write(to:URL(fileURLWithPath:CommandLine.arguments[1]))
  print("TRACE parity:40arena/room configurations,\(geometrySamples) geometry probes,\(navigationSamples) navigation queries,\(frames) combat frames,\(poses) actor poses,\(bytes.count) raw comparison bytes;native rendering/FPS separate")
 }
}
