import Foundation

@main struct BossWorldChecks {
 static func main() {
  setbuf(stdout,nil);var passed=0
  func expect(_ ok:Bool,_ text:String){guard ok else{print("FAIL \(text)");exit(1)};passed+=1;print("PASS \(text)")}
  func introduction(_ round:Int=40,_ players:Int=1)->GameCore {
   let g=GameCore();g.godMode=true;g.reset(playerCount:players);g.round=round;g.beginRound()
   g.finishCombatSpawning();g.foes=[];g.pickups=[];g.step(0,input:Controls())
   return g
  }
  func battle(_ round:Int=40,_ players:Int=1)->GameCore {
   let g=introduction(round,players)
   _=g.stepGameplaySpawns(g.bossArrivalClock!.battleStartsAt)
   return g
  }
  let first=introduction()
  expect(first.silverbackStarted && first.silverbacks.isEmpty && first.bossArrivalClock?.clock==0 && first.phase == .playing,"actual exhausted normal horde arms an introduction without an immediate boss or open exit")
  let held=GameCore();held.reset();held.round=40;held.beginRound();held.combatSpawningHeld=true;held.foes=[];held.step(1,input:Controls())
  expect(!held.silverbackStarted && held.bossArrivalClock==nil,"empty arena cannot bypass the active normal wave into the boss phase")
  first.step(5.099,input:Controls());expect(first.silverbacks.isEmpty,"actual combat step waits through setup and nearly all five seconds of introduction")
  first.step(0.001,input:Controls())
  expect(first.silverbacks.count==1 && first.silverback!.arrival != nil && !first.layout.contains(first.silverback!.p),"actual first boss is born at5100ms on a real exterior jungle route")
  expect(first.silverback!.gait<1e-8 && first.combatSpawnFlow!.forcedFinished,"boss birth at a frame's endpoint receives no fabricated full-frame movement or premature wave program")
  let partial=introduction();partial.step(5,input:Controls());partial.step(0.2,input:Controls())
  let start=partial.silverback!.arrival!.start.p
  expect((partial.silverback!.p-start).length>0.26 && (partial.silverback!.p-start).length<=0.270001,"birth inside a200ms frame moves only for its actual remaining100ms")
  let paused=introduction();paused.step(2,input:Controls());paused.step(0,input:Controls(pause:true));let stopped=paused.bossArrivalClock!.clock
  paused.step(100,input:Controls());expect(paused.bossArrivalClock!.clock==stopped && paused.silverbacks.isEmpty,"real pause freezes boss introduction and cannot create a missed-arrival backlog")
  paused.step(0,input:Controls(accept:true));paused.step(3.1,input:Controls())
  expect(paused.silverbacks.count==1,"resumed actual introduction continues from its saved deadline")
  let pair=introduction(80);let before=pair.combatSpawnFlow!.waves.groups.map(\.duration)
  _=pair.stepGameplaySpawns(5.1);let firstID=pair.silverbacks[0].id
  pair.damageSilverback(100,id:firstID)
  _=pair.stepGameplaySpawns(9.999);expect(pair.silverbacks.count==1 && pair.silverbacks[0].hp==1100,"first brother keeps independent damage during the ten-second interval")
  _=pair.stepGameplaySpawns(0.001)
  expect(pair.silverbacks.count==2 && pair.silverbacks[0].id != pair.silverbacks[1].id && pair.silverbacks[1].arrival != nil,"second brother is a new exterior body precisely ten seconds later")
  pair.damageSilverback(112,id:pair.silverbacks[1].id)
  _=pair.stepGameplaySpawns(9.999)
  expect(pair.combatSpawnFlow!.bossWaves==nil && pair.combatSpawnFlow!.healthBurst==nil,"last brother's ten-second wait cannot be skipped even while both actors exist")
  _=pair.stepGameplaySpawns(0.001)
  let flow=pair.combatSpawnFlow!
  expect(flow.bossWaves != nil && flow.clock==0 && flow.healthBurst?.baselineHealth==1088 && flow.monitoredBossID==pair.silverbacks[1].id,"new source program attaches to the last brother with his actual health after the final wait")
  expect(flow.waves.groups.map(\.duration) != before && flow.roundActive,"boss phase samples a fresh source sequence instead of reviving the pre-boss horde plan")
  pair.stepCombatSpawns(0.01)
  expect(flow.bossWaves!.totals.attempts==1 && flow.healthBurst!.attempts==0 && pair.foes.count==1,"new boss program starts an ordinary outside wave but no arbitrary full-health reinforcement")
  expect(pair.foes[0].arrival != nil && !pair.layout.contains(pair.foes[0].p),"new actual boss-wave body uses the shared outside-entry pipeline")
  pair.beginSilverbackEncounter();expect(pair.combatSpawnFlow === flow && pair.silverbacks.count==2,"repeated encounter trigger cannot restart the source program or duplicate brothers")

  let early=introduction(80);_=early.stepGameplaySpawns(5.1)
  early.damageSilverback(9999,id:early.silverbacks[0].id);early.stepSilverback(0)
  expect(early.sourceBossDead && early.silverbacks[0].deathAwarded,"first brother's real death sets the original global source flag")
  _=early.stepGameplaySpawns(10)
  expect(!early.sourceBossDead && early.silverbacks.count==2 && early.silverbacks[1].hp>0,"later scheduled brother resets source-death flag even after an earlier brother was killed")
  early.stepSilverback(0)
  expect(!early.sourceBossDead,"a previously awarded dead brother cannot reassert its old death event every frame")
  _=early.stepGameplaySpawns(10);early.stepCombatSpawns(0.01)
  expect(early.combatSpawnFlow!.roundActive && early.combatSpawnFlow!.bossWaves!.groupsStarted==1,"reset source flag permits real new boss waves after the full staggered arrival sequence")
  early.damageSilverback(9999,id:early.silverbacks[1].id)
  expect(early.sourceBossDead,"each later actual death independently sets the source flag")
  let race=introduction(80);_=race.stepGameplaySpawns(15.09)
  race.damageSilverback(9999,id:race.silverbacks[0].id)
  expect(race.sourceBossDead && !race.silverbacks[0].deathAwarded && race.silverbacks[0].sourceDeathNotified,"actual projectile kill publishes its source event before the next frame's reward animation")
  _=race.stepGameplaySpawns(0.01);race.stepSilverback(0.01)
  expect(!race.sourceBossDead && race.silverbacks[0].deathAwarded && race.silverbacks.count==2,"a brother arriving between a kill and its next-frame reward keeps its new source flag;old reward cannot replay death")

  let admission=battle(80,4),a=admission.combatSpawnFlow!
  a.bossWaves=BossAttackWaves(templates:(try! TimedAttackWaves(round:80,random:{0})).groups)
  a.healthBurst=BossHealthBurstClock(health:1000);a.monitoredBossID=admission.silverbacks[1].id
  admission.silverbacks[1].hp=900;a.nextMini=0.025
  admission.foes=(0..<29).map{Foe(id:50000+$0,p:V2(x:8,y:4),hp:999,speed:0,gait:0)}
  admission.stepCombatSpawns(0.05)
  expect(admission.activeAIEnemies==32 && a.bossWaves!.totals.admitted==1 && a.healthBurst!.admitted==0 && a.healthBurst!.rejected==2,"ordinary0ms spawn consumes one actual free slot before tied HP attempts;all source clocks share the32-AI ceiling")
  expect(a.miniAttempts==2 && a.miniAdmitted==0,"four-player mini and extra engineer also consume failed attempts instead of exceeding shared capacity")
  admission.foes.removeFirst();let attempts=a.healthBurst!.attempts
  admission.stepCombatSpawns(0.001)
  expect(admission.activeAIEnemies==31 && a.healthBurst!.attempts==attempts,"releasing capacity between50ms deadlines never replays a rejected health burst")
  admission.stepCombatSpawns(0.049)
  expect(admission.activeAIEnemies==32 && a.healthBurst!.admitted==1 && admission.foes.last!.kind == .prisoner,"real future100ms health admission wins capacity before the later700ms ordinary attempt")
  let life=battle(),lf=life.combatSpawnFlow!
  life.rareLifeTimer=RareLifeTimer(baseWait:240)
  var windows=life.stepGameplaySpawns(5);life.stepRareLifeTimer(5,activeWindows:windows)
  expect(life.rareLifeTimer!.remaining==235 && lf.roundActive,"real active repeating boss sequence participates in the global rare-life clock")
  let gated=introduction();gated.rareLifeTimer=RareLifeTimer(baseWait:240)
  windows=gated.stepGameplaySpawns(15.1);gated.stepRareLifeTimer(15.1,activeWindows:windows)
  expect(gated.rareLifeTimer!.remaining==240 && windows.isEmpty && gated.combatSpawnFlow!.clock==0,"entire introduction and final wait contribute no fake active time to rare life or source spawning")
  windows=gated.stepGameplaySpawns(9.9);gated.stepRareLifeTimer(9.9,activeWindows:windows)
  expect(gated.rareLifeTimer!.remaining==235,"life timer resumes at its real five-second poll after the handoff,without crediting the earlier inactive wait")
  let boundary=introduction();boundary.rareLifeTimer=RareLifeTimer(baseWait:240)
  var intro=boundary.bossArrivalClock!;_=intro.step(0.1);boundary.bossArrivalClock=intro
  windows=boundary.stepGameplaySpawns(15);boundary.stepRareLifeTimer(15,activeWindows:windows)
  expect(boundary.combatSpawnFlow!.clock==0 && boundary.rareLifeTimer!.remaining==240,"handoff exactly at a global life boundary is active only at that boundary,without retroactive countdown")
  windows=boundary.stepGameplaySpawns(5);boundary.stepRareLifeTimer(5,activeWindows:windows)
  expect(boundary.rareLifeTimer!.remaining==235,"exact final handoff state starts the following genuine five-second life wait")

  let repeatBoss=battle();let rp=repeatBoss.combatSpawnFlow!
  rp.bossWaves=BossAttackWaves(templates:(try! TimedAttackWaves(round:40,random:{0})).groups);rp.healthBurst=nil;rp.nextMini=nil
  repeatBoss.stepCombatSpawns(100)
  expect(rp.bossWaves!.rollbacks>0 && rp.roundActive && !rp.takeDeathCheck() && repeatBoss.phase == .playing,"actual world repeats source groups for a living boss and cannot clear a finite replacement population")
  let sentinel=Foe(id:987654,p:V2(x:7,y:5),hp:999,speed:0,gait:0)
  repeatBoss.foes=[sentinel];repeatBoss.damageSilverback(9999)
  repeatBoss.step(2.1,input:Controls())
  expect(rp.functionHasReturned && repeatBoss.allSilverbacksDefeated && repeatBoss.phase == .playing && repeatBoss.foes.contains{$0.id==sentinel.id && $0.hp>0},"dead boss and finished source program retain a genuine surviving horde member and keep the exit closed")
  repeatBoss.foes[0].hp=0;repeatBoss.resolveDefeatedFoes();repeatBoss.step(1.01,input:Controls())
  expect(repeatBoss.phase == .cleared && repeatBoss.bossArenaCleared && !repeatBoss.arenaExits.isEmpty,"actual final supporting death plus next source poll opens the boss teleporter")
  let firstDead=battle(80);let fd=firstDead.combatSpawnFlow!
  fd.bossWaves=BossAttackWaves(templates:(try! TimedAttackWaves(round:80,random:{0})).groups)
  firstDead.stepCombatSpawns(0.01);firstDead.damageSilverback(9999,id:firstDead.silverbacks[0].id)
  firstDead.stepCombatSpawns(1.1)
  expect(!fd.roundActive && firstDead.silverbacks[1].hp>0 && !firstDead.allSilverbacksDefeated,"source main may stop after one brother dies while the actual second boss still blocks the round")
  firstDead.foes=[];firstDead.step(0,input:Controls())
  expect(firstDead.phase == .playing,"source death flag is independent from actual all-brothers-defeated exit eligibility")
  firstDead.damageSilverback(600,id:firstDead.silverbacks[1].id);firstDead.foes=[];firstDead.stepCombatSpawns(12)
  expect(!fd.roundActive && (fd.healthBurst?.admitted ?? 0)>0 && firstDead.foes.contains{$0.kind == .villager},"last living brother's health monitor continues after another brother stopped the main source sequence")
  let reset=introduction(80);_=reset.stepGameplaySpawns(15.2);reset.sourceBossDead=true;reset.reset()
  expect(reset.round==1 && reset.bossArrivalClock==nil && !reset.sourceBossDead && reset.bossFrameBirths.isEmpty && reset.silverbacks.isEmpty && reset.combatSpawnFlow!.bossWaves==nil,"new game clears arrival health/replay/death/birth state and restores an ordinary first-round program")
  print("\(passed) boss world checks passed;actual production staggered arrivals/handoff/shared admissions/source flags/rare-life windows/final horde;original damage/animation/hardware remain open")
 }
}
