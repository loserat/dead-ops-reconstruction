import Foundation
@main struct WaveChecks {
 static func main(){
  setbuf(stdout,nil);var passed=0
  func expect(_ ok:Bool,_ text:String){if !ok {print("FAIL \(text)");exit(1)};passed+=1;print("PASS \(text)")}
  for round in stride(from:1,through:37,by:4) {
   let layout=ArenaLayout.forRound(round)
   expect(Set((0..<layout.enemyEntranceCount).map{layout.enemyEntrySide(index:$0)}).count==4,"arena\(round) exposes all four actual physical directions rather than treating two neighboring lanes as different sides")
   for entry in 0..<layout.enemyEntranceCount {
    let route=layout.enemyArrival(index:entry),start=route.start.p
    let inferred:EntrySide=abs(start.x)>abs(start.y) ? (start.x>0 ? .east:.west):(start.y>0 ? .south:.north)
    expect(inferred==layout.enemyEntrySide(index:entry),"arena\(round) entry\(entry) side agrees with its actual exterior starting position")
   }
   let program=try! TimedAttackWaves(round:round,random:{0})
   expect(program.groups.allSatisfy{$0.side == .north},"arena\(round) retains independent source side draws instead of forcing every doorway through a deck")
  }
  let water=GameCore();water.reset();water.foes=[water.arrivingFoe(kind:.zombie,hp:1,speed:2.1,entrance:0,lane:0)];let submerged=water.foes[0].p;water.advanceFoeArrival(0,0.1);let waterDistance=(water.foes[0].p-submerged).length
  water.foes[0].p=V2(x:-11.5,y:0);water.foes[0].elevation=0;water.foes[0].arrival=EnemyArrival(kind:.water,points:[EnemyEntryPoint(p:water.foes[0].p,height:0),EnemyEntryPoint(p:V2(x:-9.7,y:0),height:0)]);let ashore=water.foes[0].p;water.advanceFoeArrival(0,0.1);expect(waterDistance<0.13 && (water.foes[0].p-ashore).length>0.20,"submerged sea arrivals advance more slowly before surfacing rather than charging across the water at full land pace")
  let prison=ArenaLayout.forRound(9)
  expect(prison.enemyEntranceCount==6 && (0..<6).map{prison.enemyArrival(index:$0)}.filter{$0.end.height==0}.count==4 && (0..<6).map{prison.enemyArrival(index:$0)}.filter{$0.end.height==1.6}.count==2,"prison keeps both raised bridges and adds four ordinary ground approaches")
  expect((2..<6).allSatisfy{prison.entranceForBody(index:$0,height:1.95)<2} && prison.entranceForBody(index:2,height:1.3)==2,"large bodies avoid the low prison underpasses while ordinary prisoners retain the ground routes")
  let g=GameCore();g.godMode=true;g.reset();g.step(0.001,input:Controls());let initial=g.combatSpawnFlow!,spawnBudget=g.spawnRemaining
  g.step(0,input:Controls(pause:true));let waiting=g.spawnClock;g.step(20,input:Controls())
  expect(g.phase == .paused && g.spawnClock==waiting && g.spawnRemaining==spawnBudget && g.combatSpawnFlow === initial,"pause freezes timed source groups without catch-up work")
  g.step(0,input:Controls(accept:true));g.finishCombatSpawning();g.foes=[g.arrivingFoe(kind:.zombie,hp:999,speed:0,entrance:0,lane:0)];g.step(0.001,input:Controls())
  expect(g.phase == .playing && g.foes.first?.arrival != nil,"an existing outside body prevents a cleared source program from opening exits")
  g.beginRound();expect(g.combatSpawnFlow !== initial && g.combatSpawnFlow!.waves.clock==0,"round transition creates a new source program without retaining the previous front")
  print("\(passed) wave checks passed;physical map fronts and timed source ownership;original geometry and full boss behavior remain separate")
 }
}
