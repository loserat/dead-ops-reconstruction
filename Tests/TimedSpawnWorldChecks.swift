import Foundation
@main struct TimedSpawnWorldChecks {
 static func main(){
  setbuf(stdout,nil);var passed=0
  func expect(_ value:Bool,_ text:String){guard value else{print("FAIL \(text)");exit(1)};passed+=1;print("PASS \(text)")}
  func fixture(_ round:Int=1,_ players:Int=1,_ roll:Double=0)->GameCore {
   let g=GameCore();g.reset(playerCount:players);g.round=round;g.beginRound();g.foes=[];g.pickups=[]
   g.combatSpawnFlow!.waves=try! TimedAttackWaves(round:round,random:{roll});g.combatSpawnFlow!.nextDeathCheck=g.combatSpawnFlow!.waves.mainFunctionReturnsAt
   for p in g.players {p.invulnerable=999};return g
  }
  let g=fixture();expect(g.spawnRemaining==14 && g.spawnClock==0,"production world arms actual fourteen source attempts rather than the old forty-enemy budget")
  g.stepCombatSpawns(0.1)
  expect(g.foes.count==1 && g.foes[0].arrival != nil && !g.layout.contains(g.foes[0].p) && g.foes[0].homeEntrance.map{g.layout.enemyEntrySide(index:$0)} == .north,"first timed attempt creates a real exterior body on its source front")
  g.stepCombatSpawns(0.59);expect(g.foes.count==1,"local world never uses the former compressed group delay")
  g.stepCombatSpawns(0.01);expect(g.foes.count==2,"local world admits its next attempt after700ms")
  for round in stride(from:1,through:37,by:4) {for side in EntrySide.allCases {
   let w=fixture(round);w.foes=[]
   let admitted=w.admitWaveEnemy(side:side,kind:.zombie)
   expect(admitted && w.foes.last!.homeEntrance.map{w.layout.enemyEntrySide(index:$0)}==side && w.foes.last!.arrival != nil && !w.layout.contains(w.foes.last!.p),"arena\(round)/\(side) maps a real source front to an outside walking route")
  }}
  for (round,limit) in [(1,32),(9,20),(13,20),(17,20),(22,20),(30,28),(34,10),(49,32),(81,32)] {
   let w=fixture(round);w.foes=(0..<limit).map{i in Foe(id:10000+i,p:V2(x:8,y:0),hp:99,speed:0,gait:0)}
   w.stepCombatSpawns(3)
   let lost=w.combatSpawnFlow!.waves.totals.rejected,attempts=w.combatSpawnFlow!.waves.totals.attempts,ids=w.foes.map(\.id)
   expect(lost==attempts && lost>0 && w.foes.count==limit,"round\(round) consumes all due failed timed attempts at the real shared AI ceiling")
   w.foes.removeFirst();w.stepCombatSpawns(0.001)
   expect(w.foes.count==limit-1 && w.foes.map(\.id)==Array(ids.dropFirst()),"round\(round) releasing capacity between deadlines cannot replay an old admission")
   let next=w.combatSpawnFlow!.waves.nextAttemptAt!,delta=next-w.combatSpawnFlow!.waves.clock
   w.stepCombatSpawns(delta)
   expect(w.foes.count==limit && w.enemySpawnCapacity==0,"round\(round) fills one free slot at an actual future timed deadline")
  }
  let empty=fixture();empty.stepCombatSpawns(6.7);empty.foes=[];empty.step(0,input:Controls())
  expect(empty.phase == .playing && empty.spawnRemaining==0,"exhausted emissions alone cannot clear before the source main timer returns")
  empty.stepCombatSpawns(1.3);empty.foes=[];empty.step(0,input:Controls())
  expect(empty.phase == .cleared,"the source main return and empty world permit the first actual round-clear check")
  let poll=fixture();poll.stepCombatSpawns(8);poll.foes=[Foe(id:555,p:V2(x:10,y:0),hp:99,speed:0,gait:0)];poll.step(0,input:Controls())
  poll.foes=[];poll.step(0.2,input:Controls());expect(poll.phase == .playing,"a kill immediately after a failed death poll waits for its next one-second check")
  poll.stepCombatSpawns(0.8);poll.step(0,input:Controls());expect(poll.phase == .cleared,"one-second source polling eventually opens the real arena exits")
  let paused=fixture();paused.step(0.1,input:Controls());paused.step(0,input:Controls(pause:true));let clock=paused.combatSpawnFlow!.waves.clock,remaining=paused.spawnRemaining
  paused.step(100,input:Controls());expect(paused.combatSpawnFlow!.waves.clock==clock && paused.spawnRemaining==remaining,"real world pause freezes the timed source program without accumulating a backlog")
  paused.step(0,input:Controls(accept:true));paused.step(0.1,input:Controls());expect(paused.combatSpawnFlow!.waves.clock>clock,"resumed world continues from its actual source clock")
  let original=paused.combatSpawnFlow!;paused.reset();expect(paused.combatSpawnFlow !== original && paused.combatSpawnFlow!.waves.clock==0 && paused.retiringSpawnFlows.isEmpty,"new run replaces source programs and removes old background work")
  for r in [10,14,18,23,31,35] {
   expect(CombatSpawnFlow.unlocked(r).count==[10,14,18,23,31,35].firstIndex(of:r)!+1,"round\(r) unlocks one additional mini-boss type only after its challenge")
  }
  expect(CombatSpawnFlow.miniDelay(round:10,players:1,random:0)==4 && CombatSpawnFlow.miniDelay(round:10,players:4,random:0)==1,"separate source mini-boss clock depends on actual local player count and round")
  let order=fixture(81,4);order.combatSpawnFlow!.nextMini=0.95
  order.foes=(0..<30).map{i in Foe(id:50000+i,p:V2(x:9,y:0),hp:999,speed:0,gait:0)}
  order.stepCombatSpawns(0.9);order.foes.removeFirst();order.stepCombatSpawns(0.2)
  expect(order.combatSpawnFlow!.miniAdmitted==1 && order.combatSpawnFlow!.waves.totals.rejected>=1 && order.foes.count==32,"a950ms mini-boss consumes the free slot before a later1000ms ordinary group;fourth-player engineer cannot exceed capacity")
  var draw=0
  let late=fixture();late.combatSpawnFlow!.waves=try! TimedAttackWaves(round:1,random:{defer{draw+=1};return draw%4==3 ? 0:1.0.nextDown})
  late.combatSpawnFlow!.nextDeathCheck=late.combatSpawnFlow!.waves.mainFunctionReturnsAt
  late.stepCombatSpawns(8);late.foes=[];late.step(0,input:Controls())
  expect(late.phase == .cleared && late.spawnRemaining>0,"a source death poll may open exits while an older parallel group still has timed work")
  late.clearClock=1;let oldFlow=late.combatSpawnFlow!,oldPending=late.spawnRemaining
  late.stepCombatSpawns(0.7)
  expect(late.foes.isEmpty && late.spawnRemaining<oldPending && oldFlow.retiredAtExit>0,"post-exit timed attempts expire through world cleanup without creating an interior body or player reward")
  let lateExit=late.availableExits.first!;late.requestArenaExit(lateExit);let beforeFade=oldFlow.waves.clock
  late.step(0.6,input:Controls(move:V2(x:1,y:0),bomb:true))
  expect(oldFlow.waves.clock>beforeFade && late.foes.isEmpty && late.bombs==1,"real fade-out advances outstanding source timers while player inputs stay blocked")
  late.step(2.2,input:Controls())
  expect(late.round==2 && late.arenaTransit?.committed==true && late.combatSpawnFlow !== oldFlow && late.combatSpawnFlow!.waves.clock==0,"map commit replaces its active program without starting new groups under the black fade")
  late.step(1.7,input:Controls())
  expect(late.phase == .playing && late.combatSpawnFlow!.waves.clock==0 && late.foes.isEmpty,"new arena source groups wait until fade-in and controls are fully restored")
  print("\(passed) timed spawn-world checks passed;actual production admissions/fronts/limits/pause/round polling;boss sequence replacement and full gameplay acceptance still pending")
 }
}
