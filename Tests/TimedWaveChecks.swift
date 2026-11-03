import Foundation
@main struct TimedWaveChecks {
 static func main(){
  setbuf(stdout,nil);var passed=0
  func expect(_ value:Bool,_ message:String){guard value else{print("FAIL \(message)");exit(1)};passed+=1;print("PASS \(message)")}
  let counts=[(1,7),(8,14),(24,30),(40,30),(41,47),(54,60),(80,60),(81,87),(84,90),(120,90),(121,120)]
  for (round,count) in counts {expect(try! TimedAttackWaves.groupCount(round:round)==count,"archived round\(round) creates\(count) timed groups instead of a population budget")}
  expect((try? TimedAttackWaves.groupCount(round:0))==nil && (try? TimedAttackWaves(round:Int.max,random:{0}))==nil,"invalid or unrepresentable programs are rejected rather than silently shortened")
  var minimum=try! TimedAttackWaves(round:1,random:{0}),minimumEvents=[TimedAttackWaves.Attempt]()
  expect(minimum.groups.count==7 && minimum.pendingAttemptCount==14,"minimum first round has seven one-second groups with exactly fourteen local admission attempts")
  expect(minimum.groups.allSatisfy{$0.side == .north},"independent original front draws may repeat one side; an invented coverage deck is not retained")
  let fixed=try! TimedAttackWaves(round:1,random:{0.5})
  expect(fixed.groups[0].duration==2.1 && fixed.groups[0].nextGroupDelay==2.05 && fixed.groups[0].side == .west && fixed.groups[0].attemptCount==3,"fixed independent midpoint draws give2.1s duration/2.05s next group and three strict local attempts")
  expect(abs(fixed.groups[1].startsAt-2.05)<0.0000001 && fixed.groups[1].duration==2.25,"the zero-based group number changes duration while the next start uses its predecessor's gap")
  _=minimum.step(6.7){minimumEvents.append($0);return true}
  expect(minimumEvents.map(\.time)==[0,0.7,1,1.7,2,2.7,3,3.7,4,4.7,5,5.7,6,6.7],"minimum local timeline matches explicit zero and700ms source attempts")
  expect(minimum.pendingAttemptCount==0 && minimum.roundActiveFlag && !minimum.mainFunctionHasReturned,"an empty attempt heap is not equivalent to source round end")
  _=minimum.step(0.3){_ in false};expect(!minimum.roundActiveFlag && !minimum.mainFunctionHasReturned && minimum.allGroupTimersExpired,"last group wait clears round-active at7s but the spawning function still waits its own second")
  _=minimum.step(1){_ in false};expect(minimum.mainFunctionHasReturned && minimum.totals.attempts==14,"the main source spawning function returns at8s without a fabricated extra group")
  var overlapRoll=0
  func overlappingRandom()->Double {defer{overlapRoll+=1};return overlapRoll%4==3 ? 0:overlapRoll%4==2 ? 0.75:1.0.nextDown}
  var overlap=try! TimedAttackWaves(round:1,random:overlappingRandom),events=[TimedAttackWaves.Attempt]()
  _=overlap.step(3){events.append($0);return true}
  expect(events.map(\.time)==[0,0.7,1,1.4,1.7,2,2.1,2.4,2.7,2.8,3],"overlapping threads interleave independently at their real start/deadline times")
  expect(events.prefix(10).map(\.group)==[0,0,1,0,1,2,0,1,2,0],"a newer front never replaces a still running previous group")
  expect(overlap.groups.allSatisfy{$0.side == .east} && overlapRoll==28,"four planning draws per group preserve duration-duration-side-gap order")
  _=overlap.step(5){_ in true}
  expect(overlap.mainFunctionHasReturned && !overlap.allGroupTimersExpired && overlap.pendingAttemptCount>0,"source main-return and last parallel-thread expiry remain distinct")
  let later=overlap.step(10){_ in true}
  expect(later.attempts>0 && overlap.pendingAttemptCount==0 && overlap.allGroupTimersExpired,"late live threads are represented after main return instead of being discarded")
  for milliseconds in [700.0,1400,2100,2800] {
   let group=TimedAttackWaves.Group(index:0,side:.north,startMilliseconds:0,durationMilliseconds:milliseconds,nextGroupMilliseconds:1000)
   expect(group.attemptCount==Int(milliseconds/700),"strict deadline\(milliseconds)ms excludes an attempt exactly on the boundary")
  }
  var calls=0
  var full=try! TimedAttackWaves(round:8,random:{calls+=1;return 0.5})
  let planDraws=calls,rejected=full.step(5){_ in false},remaining=full.pendingAttemptCount
  expect(rejected.attempts>0 && rejected.rejected==rejected.attempts && full.totals.admitted==0,"full AI admission consumes each failed timed attempt without reserving a future enemy")
  var admitted=[TimedAttackWaves.Attempt]();_=full.step(0.7){admitted.append($0);return true}
  expect(admitted.allSatisfy{$0.time>5} && full.pendingAttemptCount<remaining && calls==planDraws,"freeing capacity admits only future attempts; no old catch-up burst or new planning randomness")
  let clock=full.clock,pending=full.pendingAttemptCount,total=full.totals,next=full.nextAttemptAt
  _=full.step(120,paused:true){_ in fatalError("Paused admission")}
  for dt in [0.0,-1,Double.nan,Double.infinity,Double.greatestFiniteMagnitude] {_=full.step(dt){_ in fatalError("Invalid-time admission")}}
  expect(full.clock==clock && full.pendingAttemptCount==pending && full.totals==total && full.nextAttemptAt==next,"pause and invalid elapsed time preserve timers and cannot manufacture a burst")
  full.cancel();let cancelled=full.step(100){_ in fatalError("Cancelled admission")}
  expect(full.isCancelled && full.pendingAttemptCount==0 && full.nextAttemptAt==nil && cancelled.attempts==0,"explicit reset or game end removes all pending group work")
  for bucket in 0..<4 {
   var draw=0;let plan=try! TimedAttackWaves(round:1,random:{defer{draw+=1};return draw%4==2 ? Double(bucket)/4:0})
   expect(plan.groups.allSatisfy{$0.side == [.north,.south,.west,.east][bucket]},"source direction bucket\(bucket) maps to its real cardinal front")
  }
  // Independent timestamp list oracle: enumerate each thread, then merge; no production heap reuse.
  for round in [1,5,9,40,41,81] {for seed in 0..<12 {
   func plan()->TimedAttackWaves {
    var state=UInt64(seed+1)
    return try! TimedAttackWaves(round:round,random:{state=state&*6364136223846793005&+1442695040888963407;return Double(state>>11)/Double(UInt64.max>>11)})
   }
   var coarse=plan(),fine=plan(),actual=[TimedAttackWaves.Attempt](),subdivided=[TimedAttackWaves.Attempt](),oracle=[TimedAttackWaves.Attempt]()
   for group in coarse.groups {
    var offset=0,ordinal=0
    while Double(offset)<group.durationMilliseconds {
     oracle.append(.init(group:group.index,ordinal:ordinal,side:group.side,time:(group.startMilliseconds+Double(offset))/1000));offset+=700;ordinal+=1
    }
   }
   oracle.sort{$0.time != $1.time ? $0.time<$1.time:$0.group<$1.group}
   while coarse.clock<=coarse.lastGroupEndsAt+1 {_=coarse.step(1.0/30){actual.append($0);return true}}
   while fine.clock<=fine.lastGroupEndsAt+1 {_=fine.step(1.0/60){subdivided.append($0);return true}}
   expect(actual==oracle && actual==subdivided && coarse.pendingAttemptCount==0 && fine.totals==coarse.totals,"round\(round)/seed\(seed) matches independent merged-thread oracle at30and60Hz without lost/replayed attempts")
  }}
  print("\(passed) timed attack-wave checks passed;archived local timers and planning,not yet production admission/clear/boss integration or original engine/network acceptance")
 }
}
