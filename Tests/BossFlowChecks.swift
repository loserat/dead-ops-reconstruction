import Foundation

@main struct BossFlowChecks {
 static func main() {
  setbuf(stdout,nil);var passed=0
  func expect(_ ok:Bool,_ text:String){guard ok else{print("FAIL \(text)");exit(1)};passed+=1;print("PASS \(text)")}
  expect(BossArrivalClock(round:0)==nil && BossArrivalClock(round:39)==nil && BossArrivalClock(round:-40)==nil,"only positive forty-round boundaries create a source boss introduction")
  for round in [40,80,120,160] {
   var intro=BossArrivalClock(round:round)!
   expect(intro.brotherCount==round/40 && intro.battleStartsAt==5.1+Double(round/40)*10,"round\(round) waits ten seconds after every brother including the last")
   expect(intro.step(5.099).isEmpty,"round\(round) no boss materializes before setup plus complete HUD introduction")
   expect(intro.step(0.001)==[.brother(0)] && !intro.battleStarted,"round\(round) first real brother is due at5100ms without starting the wave sequence")
   if round>40 {
    expect(intro.step(9.999).isEmpty,"round\(round) second brother is not an immediate cloned actor")
    expect(intro.step(0.001)==[.brother(1)],"round\(round) second arrival is ten seconds after the first")
   }
   var remaining=[BossArrivalClock.Event]()
   while !intro.battleStarted {remaining+=intro.step(0.1)}
   expect(remaining.last == .startBattle && intro.spawned==round/40,"round\(round) attaches the last-brother health monitor only after the final wait")
   expect(intro.step(100).isEmpty,"round\(round) completed arrival sequence cannot duplicate a boss or a monitor")
  }
  var paused=BossArrivalClock(round:80)!
  _=paused.step(2.1);let clock=paused.clock
  for dt in [0.0,-1,.nan,.infinity,.greatestFiniteMagnitude] {expect(paused.step(dt).isEmpty && paused.clock==clock,"invalid intro delta\(dt) cannot skip a brother")}
  expect(paused.step(100,paused:true).isEmpty && paused.clock==clock,"pause freezes introduction and arrival deadlines")
  expect(abs(paused.introductionOpacity-1)<1e-9,"source title reaches full opacity after its two-second fade")
  expect(abs(paused.subtitleOpacity-0.8)<1e-9,"source subtitle uses its distinct two-and-a-half-second fade")
  _=paused.step(2);expect(abs(paused.introductionOpacity-0.5)<1e-9,"source title fades out during the last two introduction seconds")
  expect(abs(paused.subtitleOpacity-0.5)<1e-9,"title and subtitle share the final two-second fade-out")
  for round in [40,80,160] {
   var one=BossArrivalClock(round:round)!,many=BossArrivalClock(round:round)!
   let large=one.step(60);var small=[BossArrivalClock.Event]()
   for _ in 0..<3600 {small+=many.step(1.0/60)}
   expect(large==small && one.spawned==many.spawned && one.battleStarted==many.battleStarted,"round\(round) arrival ordering agrees for one large step and3600small steps")
  }
  expect(BossHealthBurstClock(health:0)==nil && BossHealthBurstClock(health:.nan)==nil,"a dead or invalid last boss cannot receive a health monitor")
  let bands:[(Double,FoeKind,Int,Int)]=[(0.949,.prisoner,10,15),(0.799,.crawler,10,16),(0.649,.villager,10,15),(0.499,.martyr,3,10),(0.349,.engineer,10,20),(0.199,.hound,3,6)]
  for (fraction,kind,lower,upper) in bands {
   expect(BossHealthBurstClock.band(fraction:fraction)==BossHealthBurstClock.Band(kind:kind,lower:lower,upper:upper),"strict source health band\(fraction) maps to\(kind),including moss_big as martyr")
   for roll in [0.0,0.5,1.0.nextDown] {
    var monitor=BossHealthBurstClock(health:100)!,events=[BossHealthBurstClock.Attempt](),draws=0
    monitor.step(0.001,health:{fraction*100},random:{draws+=1;return roll},admit:{events.append($0);return false})
    let count=BossSourceRandom.integer(lower,upper,roll:roll)
    expect(events.count==1 && events[0].kind==kind && events[0].time==0 && draws==1,"\(kind)/\(roll) first burst admission is immediate and samples its count once")
    monitor.step(Double(count-1)*0.05-0.001,health:{fraction*100},random:{draws+=1;return roll},admit:{events.append($0);return false})
    expect(events.count==count && monitor.rejected==count && monitor.admitted==0 && draws==1,"\(kind)/\(roll) attempts remain50ms apart and failed admissions are consumed,not queued")
    expect(zip(events,events.dropFirst()).allSatisfy{abs($1.time-$0.time-0.05)<1e-9},"\(kind)/\(roll) all source burst intervals remain50ms")
    monitor.step(0.05,health:{fraction*100},random:{draws+=1;return roll},admit:{events.append($0);return true})
    expect(events.count==count && draws==2,"\(kind)/\(roll) final50ms wait precedes the cooldown draw and emits no extra enemy")
    let cooldown=Double(BossSourceRandom.integer(5,12,roll:roll))
    monitor.step(cooldown-0.001,health:{fraction*100},random:{draws+=1;return roll},admit:{events.append($0);return true})
    expect(events.count==count,"\(kind)/\(roll) freeing AI capacity cannot replay a rejected burst during cooldown")
    monitor.step(0.001,health:{fraction*100},random:{draws+=1;return roll},admit:{events.append($0);return true})
    expect(events.count==count+1 && monitor.admitted==1,"\(kind)/\(roll) next cooldown deadline starts a fresh burst")
   }
  }
  for (boundary,kind) in [(0.80,FoeKind.prisoner),(0.65,.crawler),(0.50,.villager),(0.35,.martyr),(0.20,.engineer)] {
   expect(BossHealthBurstClock.band(fraction:boundary)?.kind==kind,"exact\(boundary) boundary retains the preceding health band")
  }
  expect(BossHealthBurstClock.band(fraction:0.95)==nil && BossHealthBurstClock.band(fraction:1)==nil,"full health and exact95percent never trigger arbitrary reinforcement")
  var untouched=BossHealthBurstClock(health:600)!,countDraws=0
  untouched.step(0.1,health:{600},random:{countDraws+=1;return 0},admit:{_ in fatalError("Full-health burst")})
  expect(untouched.attempts==0 && countDraws==1 && untouched.nextEventAt==5,"full-health evaluation still schedules the source random cooldown")
  var snapshot=BossHealthBurstClock(health:600)!,snapshotEvents=[BossHealthBurstClock.Attempt]()
  snapshot.step(0.01,health:{599},random:{0},admit:{snapshotEvents.append($0);return true})
  expect(snapshotEvents.isEmpty,"attachment baseline uses remaining600HP,not the original1200HP maximum")
  snapshot.step(5,health:{540},random:{0},admit:{snapshotEvents.append($0);return true})
  expect(snapshotEvents.first?.kind == .prisoner,"health loss after attachment is measured against the actual last-brother snapshot")
  let stop=snapshot.attempts;snapshot.step(20,health:{0},random:{fatalError("Death RNG")},admit:{_ in fatalError("Dead boss admission")})
  expect(snapshot.isCancelled && snapshot.attempts==stop && snapshot.nextEventAt==nil,"last-brother death cancels both pending burst and cooldown")
  var frozen=BossHealthBurstClock(health:100)!
  frozen.step(30,paused:true,health:{50},random:{fatalError("Paused random")},admit:{_ in fatalError("Paused admission")})
  for dt in [0.0,-1,.nan,.infinity,.greatestFiniteMagnitude] {frozen.step(dt,health:{50},random:{fatalError("Invalid random")},admit:{_ in fatalError("Invalid admission")})}
  expect(frozen.clock==0 && frozen.attempts==0 && !frozen.isCancelled,"paused/invalid monitor time cannot consume health waves or randomness")
  var cancelled=BossHealthBurstClock(health:100)!;cancelled.cancel();cancelled.step(10,health:{50},random:{fatalError("Cancelled RNG")},admit:{_ in fatalError("Cancelled admission")})
  expect(cancelled.attempts==0,"explicit cancellation removes a live monitor without a late burst")
  var changing=BossHealthBurstClock(health:100)!,changingHealth=90.0,changingEvents=[BossHealthBurstClock.Attempt]()
  changing.step(0.5,health:{changingHealth},random:{0},admit:{changingEvents.append($0);changingHealth=15;return true})
  expect(changingEvents.count==10 && changingEvents.allSatisfy{$0.kind == .prisoner},"health loss during a burst cannot switch its already-selected enemy type or resample its count")
  changing.step(5.1,health:{changingHealth},random:{0},admit:{changingEvents.append($0);return true})
  expect(changingEvents.count==13 && changingEvents.suffix(3).allSatisfy{$0.kind == .hound},"next health evaluation observes the new low-health type after the complete burst and cooldown")
  var interrupted=BossHealthBurstClock(health:100)!,interruptHealth=50.0
  interrupted.step(2,health:{interruptHealth},random:{0},admit:{_ in interruptHealth=0;return true})
  expect(interrupted.attempts==1 && interrupted.isCancelled,"monitored death during actual admission stops the rest of that burst immediately")

  // Independent oracle: schedule group starts with a plain loop; then flatten each
  // thread's700ms attempts and sort. No reuse of the production event-merging code.
  func oracle(_ templates:[TimedAttackWaves.Group],death:Double,rolls:[Double])->([BossAttackWaves.Start],[BossAttackWaves.Attempt],Double,Int) {
   var starts=[BossAttackWaves.Start](),events=[BossAttackWaves.Attempt](),index=0,at=0.0,backs=0
   while at<death {
    if index==templates.count-1 {let rollback=4+min(5,Int(rolls[backs%rolls.count]*6));index=max(0,index-rollback);backs+=1}
    let template=templates[index],occurrence=starts.count
    starts.append(.init(occurrence:occurrence,group:index,time:at))
    var ordinal=0
    while Double(ordinal)*700<template.durationMilliseconds {
     let when=(at*1000+Double(ordinal)*700)/1000
     if when<death {events.append(.init(occurrence:occurrence,group:index,ordinal:ordinal,side:template.side,time:when))}
     ordinal+=1
    }
    at+=template.nextGroupDelay;index+=1
   }
   events.sort {a,b in a.time != b.time ? a.time<b.time:a.occurrence<b.occurrence}
   return (starts,events,at+1,backs)
  }
  for round in [40,80,120] {for seed in 0..<6 {
   var state=UInt64(seed+1)
   let ordinary=try! TimedAttackWaves(round:round,random:{state=state &* 6364136223846793005 &+ 1442695040888963407;return Double(state>>11)/Double(UInt64.max>>11)})
   let rolls=[0.0,0.2,0.75,1.0.nextDown],death=2500.0
   let expected=oracle(ordinary.groups,death:death,rolls:rolls)
   for hz in [30,60] {
    var wave=BossAttackWaves(templates:ordinary.groups)!,events=[BossAttackWaves.Attempt](),starts=[BossAttackWaves.Start](),draws=0
    while wave.clock<expected.2+2 {
     let dead=wave.clock>=death-1e-9
     let dt=dead ? 1.0/Double(hz):min(1.0/Double(hz),death-wave.clock)
     _=wave.step(dt,bossDead:dead,rollbackRandom:{defer{draws+=1};return rolls[draws%rolls.count]},started:{starts.append($0)},admit:{events.append($0);return $0.ordinal%3 != 0})
    }
    expect(starts.count==expected.0.count && zip(starts,expected.0).allSatisfy{$0.group==$1.group && abs($0.time-$1.time)<1e-8},"round\(round)/seed\(seed)/\(hz)Hz source rollback starts match independent flattened oracle")
    expect(events.count==expected.1.count && zip(events,expected.1).allSatisfy{$0.group==$1.group && $0.ordinal==$1.ordinal && $0.side==$1.side && abs($0.time-$1.time)<1e-8},"round\(round)/seed\(seed)/\(hz)Hz all overlapping attempts match independent oracle")
    expect(wave.mainFunctionHasReturned && !wave.roundActiveFlag && abs(wave.mainFunctionReturnsAt!-expected.2)<1e-8 && wave.activeThreadCount==0,"round\(round)/seed\(seed)/\(hz)Hz boss death stops at source group boundary then waits one second")
    expect(wave.rollbacks==expected.3 && draws==expected.3 && wave.rollbacks>0 && wave.totals.rejected>0 && wave.totals.attempts==events.count,"round\(round)/seed\(seed)/\(hz)Hz replays templates without fresh planning draws or failed admission backlog")
   }
  }}
  let templates=(try! TimedAttackWaves(round:40,random:{0})).groups
  var dead=BossAttackWaves(templates:templates)!
  _=dead.step(0.001,bossDead:true,rollbackRandom:{fatalError("Dead rollback")},admit:{_ in fatalError("Dead spawn")})
  expect(dead.groupsStarted==0 && dead.mainSequenceEndsAt==0 && dead.mainFunctionReturnsAt==1,"already-dead source flag returns from a newly started boss program after one second without a group")
  _=dead.step(0.999,bossDead:true,rollbackRandom:{0},admit:{_ in false})
  expect(dead.mainFunctionHasReturned,"dead-at-entry main function still observes its one-second source return wait")
  var repeatWave=BossAttackWaves(templates:templates)!
  _=repeatWave.step(100,bossDead:false,rollbackRandom:{0},admit:{_ in false})
  expect(repeatWave.groupsStarted>templates.count && repeatWave.rollbacks>0 && repeatWave.roundActiveFlag && !repeatWave.mainFunctionHasReturned && repeatWave.currentGroup?.index != templates.count-1,"living boss repeats earlier sampled templates instead of exhausting a fixed replacement population")
  expect(repeatWave.currentGroupStartedAt==100 && repeatWave.currentGroup!.startsAt<100,"replayed front exposes its actual new start time separately from the original sampled template")
  var long=BossAttackWaves(templates:templates)!,longPeak=0
  for _ in 0..<30000 {_=long.step(1,bossDead:false,rollbackRandom:{0.99},admit:{_ in false});longPeak=max(longPeak,long.activeThreadCount)}
  expect(long.roundActiveFlag && long.groupsStarted>29000 && long.rollbacks>1000 && longPeak<=2 && long.pendingAttemptCount<=4,"thirty-thousand-second live boss retains only active threads rather than accumulating replay history or a failed-spawn queue")
  let waveClock=repeatWave.clock,waveTotals=repeatWave.totals
  _=repeatWave.step(100,paused:true,bossDead:false,rollbackRandom:{fatalError("Paused rollback")},admit:{_ in fatalError("Paused wave")})
  for dt in [0.0,-1,.nan,.infinity,.greatestFiniteMagnitude] {_=repeatWave.step(dt,bossDead:false,rollbackRandom:{fatalError("Invalid rollback")},admit:{_ in fatalError("Invalid wave")})}
  expect(repeatWave.clock==waveClock && repeatWave.totals==waveTotals,"pause and invalid time preserve live repeat state and consume no events")
  repeatWave.cancel();_=repeatWave.step(100,bossDead:false,rollbackRandom:{fatalError("Cancelled rollback")},admit:{_ in fatalError("Cancelled wave")})
  expect(repeatWave.pendingAttemptCount==0 && repeatWave.nextEventAt==nil && repeatWave.totals==waveTotals,"cancelled boss program cannot create delayed bodies on another map")
  expect(BossAttackWaves(templates:[])==nil && BossAttackWaves(templates:Array(templates.prefix(1)))==nil,"malformed replay programs are rejected explicitly")
  print("\(passed) boss flow checks passed;source arrival/replay/last-brother health clocks;world integration,original engine/animations/hardware not verified")
 }
}
