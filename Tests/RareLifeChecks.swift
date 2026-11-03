import Foundation
@main struct RareLifeChecks {
 static func main(){
  setbuf(stdout,nil);var passed=0
  func expect(_ ok:Bool,_ why:String){guard ok else{print("FAIL \(why)");exit(1)};passed+=1;print("PASS \(why)")}
  var timer=RareLifeTimer(baseWait:240),spawned=0
  timer.step(239,activeAt:{_ in true},reserves:{3},random:{0},spawn:{spawned+=1})
  expect(spawned==0 && timer.remaining==5 && timer.stage == .base,"240s rare-life base interval cannot expire before its last five-second wait")
  timer.step(1,activeAt:{_ in true},reserves:{3},random:{0},spawn:{spawned+=1})
  expect(timer.stage == .reserves && timer.remaining==30,"base expiry samples actual team reserves for a separate ten-seconds-per-life delay")
  timer.step(29,activeAt:{_ in true},reserves:{0},random:{0},spawn:{spawned+=1})
  expect(spawned==0 && timer.remaining==5,"later reserve changes do not rewrite the already sampled thirty-second delay")
  timer.step(1,activeAt:{_ in true},reserves:{0},random:{0.5},spawn:{spawned+=1})
  expect(spawned==1 && timer.drops==1 && timer.stage == .base && timer.remaining==390,"270s emits one life then starts a fresh sampled base interval")
  var inactive=RareLifeTimer(baseWait:240)
  inactive.step(1000,activeAt:{_ in false},reserves:{3},random:{0},spawn:{fatalError("inactive drop")})
  expect(inactive.remaining==240 && inactive.drops==0,"inactive rounds only retry every five seconds and do not consume the base wait")
  var crossing=RareLifeTimer(baseWait:240)
  crossing.step(2,activeAt:{_ in true},reserves:{3},random:{0},spawn:{})
  crossing.step(3,activeAt:{_ in false},reserves:{3},random:{0},spawn:{})
  expect(crossing.remaining==235,"a five-second wait begun in combat finishes and subtracts once after combat stops")
  crossing.step(20,activeAt:{_ in false},reserves:{3},random:{0},spawn:{})
  expect(crossing.remaining==235,"later inactive retries cannot subtract additional active waits")
  var fractional=RareLifeTimer(baseWait:241),fractionalDrops=0
  fractional.step(244.9,activeAt:{_ in true},reserves:{0},random:{0},spawn:{fractionalDrops+=1})
  expect(fractionalDrops==0,"fractional base waits round up through actual five-second source waits")
  fractional.step(0.1,activeAt:{_ in true},reserves:{0},random:{0},spawn:{fractionalDrops+=1})
  expect(fractionalDrops==1,"zero team reserves add no fabricated extra delay after the rounded base interval")
  for reserves in [0,1,3,9,36] {
   var t=RareLifeTimer(baseWait:240),count=0;let due=240+Double(reserves)*10
   t.step(due-0.001,activeAt:{_ in true},reserves:{reserves},random:{1},spawn:{count+=1})
   expect(count==0,"reserve sum\(reserves) cannot spawn before its source-dependent deadline")
   t.step(0.001,activeAt:{_ in true},reserves:{reserves},random:{1},spawn:{count+=1})
   expect(count==1 && t.remaining==540,"reserve sum\(reserves) adds its own complete delay then resamples the upper base range")
  }
  let before=timer.clock,remaining=timer.remaining
  for dt in [0.0,-1,Double.nan,Double.infinity] {timer.step(dt,activeAt:{_ in true},reserves:{0},random:{0},spawn:{fatalError("invalid life time")})}
  expect(timer.clock==before && timer.remaining==remaining,"invalid or empty steps cannot advance the standalone life thread")
  let g=GameCore();g.reset(playerCount:4);g.round=81;g.beginRound();g.foes=[];g.pickups=[]
  g.players.forEach{$0.lives=0};g.rareLifeTimer=RareLifeTimer(baseWait:240)
  g.stepRareLifeTimer(240,combatStartClock:0)
  expect(g.pickups.count==1 && g.pickups[0].kind == .life && g.pickups[0].ttl==SourcePowerupTimeout.lifetime && g.pickups[0].sourcePowerupTimeout && g.players.allSatisfy{$0.lives==0},"production rare timer creates one physical source-expiry statue without directly awarding reserves")
  let clock=g.rareLifeTimer!.clock;g.beginRound()
  expect(g.rareLifeTimer!.clock==clock && g.rareLifeTimer!.drops==1,"ordinary round starts retain the global extra-life thread instead of seeding per-round milestones")
  g.reset();expect(g.rareLifeTimer!.drops==0 && g.rareLifeTimer!.clock==0,"a genuinely new run replaces the global extra-life timer")
  expect(SourcePowerupTimeout.lifetime==12+15*0.6+10*0.35+15*0.2,"source life expiry includes all forty local waits after the initial twelve seconds")
  var start=12.0
  for index in 0..<40 {
   let duration=index<15 ? 0.6:index<25 ? 0.35:0.2,sample=start+duration/2
   expect(SourcePowerupTimeout.opacity(remaining:27.5-sample)==(index%2==0 ? 1:0),"actual timeout flash\(index) follows its original alternating visibility and local wait")
   start+=duration
  }
  expect(SourcePowerupTimeout.opacity(remaining:27.5)==1 && SourcePowerupTimeout.opacity(remaining:15.5)==1 && SourcePowerupTimeout.opacity(remaining:14.9)==0,"first source flash remains visible and hiding starts only at12.6s")
  expect(SourcePowerupTimeout.opacity(remaining:0)==0 && SourcePowerupTimeout.opacity(remaining:.nan)==0,"expired or invalid source timers cannot produce a visible stale statue")
  g.combatSpawningHeld=true;g.pickups=[]
  var life=g.worldPickup(id:g.id(),p:g.hero,kind:.life,ttl:27.5);life.sourcePowerupTimeout=true;g.pickups=[life]
  g.stepPickupLifetimes(12.9)
  expect(g.pickups.count==1 && SourcePowerupTimeout.opacity(remaining:g.pickups[0].ttl)==0,"a flashing dark-phase statue remains a real collectible after the steady twelve seconds")
  let lives=g.lives;g.collectNearbyPickups()
  expect(g.pickups.isEmpty && g.lives==lives+1,"the production collector can claim a temporarily hidden statue exactly once")
  life.ttl=27.5;g.pickups=[life];g.stepPickupLifetimes(27.499)
  expect(g.pickups.count==1,"physical expiry cannot remove the life before all forty waits finish")
  g.stepPickupLifetimes(0.002);expect(g.pickups.isEmpty,"physical expiry finally removes the life after the complete27.5s local lifetime")
  print("\(passed) rare life checks passed;archived timer/gating/reserve sampling and physical production drop;own map positions and engine-clock precision unverified")
 }
}
