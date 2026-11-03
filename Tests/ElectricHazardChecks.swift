import Foundation
@main struct ElectricHazardChecks {
 static func main() {
  setbuf(stdout,nil);var passed=0
  func expect(_ value:Bool,_ text:String) {if !value {print("FAIL \(text)");exit(1)};passed+=1;print("PASS \(text)")}
  let probe=ElectricTrap(p:.zero,offset:0,seed:51)
  expect(probe.state(at:0) == .warning && probe.state(at:0.499) == .warning && probe.state(at:0.5) == .safe,"initial half-second client pulse is harmless and returns green")
  expect(probe.state(at:10.499) == .safe && probe.state(at:10.5) == .warning && probe.state(at:11.699) == .warning && probe.state(at:11.7) == .active,"initial ten-second off interval precedes a full1.2second warning")
  var activeLengths=[Double](),safeLengths=[Double](),last=probe.state(at:11.7),start=11.7
  for i in 1...50000 {
   let t=11.7+Double(i)*0.01,state=probe.state(at:t)
   if state != last {if last == .active {activeLengths.append(t-start)};if last == .safe {safeLengths.append(t-start)};start=t;last=state}
  }
  expect(activeLengths.count>25 && activeLengths.allSatisfy{$0>=3.98 && $0<=10.02},"independent discharge periods stay within the archived4to10seconds across many cycles")
  expect(safeLengths.count>25 && safeLengths.allSatisfy{$0>=2.98 && $0<=6.02},"independent safe intervals stay within3to6seconds")
  expect(Set(activeLengths.map{Int($0*10)}).count>10 && Set(safeLengths.map{Int($0*10)}).count>10,"later cycles are variable instead of the old fixed11second loop")
  expect(probe.state(at:.nan) == .safe && probe.state(at:.infinity) == .safe,"nonfinite time cannot hang the hazard evaluator")
  expect(probe.contacts(V2(x:0.48,y:0),height:0,bodyRadius:0.29) && !probe.contacts(V2(x:0.50,y:0),height:0,bodyRadius:0.29),"source20unit trigger plus own actor hull has a narrow actual contact edge")
  expect(!probe.contacts(.zero,height:0.51,bodyRadius:0.29) && probe.contacts(.zero,height:0.5,bodyRadius:0.29),"mapped trigger height excludes another floor or airborne body")
  var firstCounts=Set<Int>(),lateCounts=Set<Int>(),positions=Set<String>()
  for seed in 1...120 {
   let g=GameCore();g.reset();g.hazardSeed=UInt64(seed);g.round=5;g.beginRound()
   firstCounts.insert(g.electricTraps.count)
   expect((1...2).contains(g.electricTraps.count) && g.electricTraps.count==g.hazardRequestedCount,"round5 seed\(seed) creates the source-based1or2physical posts")
   for trap in g.electricTraps {positions.insert(String(format:"%.3f,%.3f",trap.p.x,trap.p.y))}
   let geometry=g.layout
   expect(g.electricTraps.allSatisfy{trap in !geometry.walkable(trap.p) && abs(geometry.height(trap.p)-trap.elevation)<0.001},"round5 seed\(seed) collision and rendered origin share the generated post")
   g.round=80;g.beginRound();lateCounts.insert(g.electricTraps.count)
   expect((1...27).contains(g.electricTraps.count) && g.electricTraps.count==g.hazardRequestedCount,"round80 seed\(seed) scales count without keeping four fixed posts")
   expect(g.electricTraps.enumerated().allSatisfy{i,t in g.electricTraps.dropFirst(i+1).allSatisfy{($0.p-t.p).length>=0.23999}},"round80 seed\(seed) placement keeps the source minimum separation")
  }
  expect(firstCounts==[1,2] && lateCounts.count>20 && positions.count>150,"seeded worlds vary actual post count and jittered positions")
  for round in [1,4,41,44,81] {
   let g=GameCore();g.reset();g.round=round;g.beginRound()
   expect(g.electricTraps.isEmpty && g.layout.traps.isEmpty,"island round\(round) has no invented electrical hazard sites")
  }
  for round in stride(from:5,through:37,by:4) {
   let g=GameCore();g.reset();g.round=round;g.beginRound();let l=g.layout
   expect(!g.electricTraps.isEmpty && g.electricTraps.allSatisfy{trap in l.staticObstacles.allSatisfy{!$0.contains(trap.p,clearance:0.20)} && EntrySide.allCases.allSatisfy{(l.playerExit(on:$0)-trap.p).length>0.85}},"arena\(round) places hazards on clear map ground outside all exit triggers")
  }
  func fixture()->GameCore {
   let g=GameCore();g.reset();g.round=5;g.beginRound();g.foes=[];g.pickups=[];g.combatSpawningHeld=true;g.invulnerable=0;g.playerRoster.current.bodyShield=nil
   g.hero=g.electricTraps[0].p+V2(x:0.46,y:0);g.heroElevation=g.electricTraps[0].elevation;return g
  }
  let warning=fixture();warning.hazardClock=10.6;warning.step(0.02,input:Controls())
  expect(!warning.playerRoster.current.isDown && warning.lives==3,"red warning is not damaging at real narrow contact")
  let lethal=fixture();lethal.hazardClock=11.8;lethal.step(0.01,input:Controls())
  expect(lethal.playerRoster.current.isDown && lethal.lives==3,"real discharge queues the existing funded return rather than deducting life immediately")
  lethal.stepTeamRecovery(2)
  expect(!lethal.playerRoster.current.isDown && lethal.lives==2 && lethal.playerRoster.current.bodyShield != nil,"post death uses the real two-second body return and protection")
  let distant=fixture();distant.hero.x+=0.5;distant.hazardClock=11.8;distant.step(0.01,input:Controls())
  expect(!distant.playerRoster.current.isDown,"the old1.45unit invisible danger circle is removed")
  let elevated=fixture();elevated.heroElevation+=1;elevated.hazardClock=11.8;elevated.stepElectricHazards(0.01)
  expect(!elevated.playerRoster.current.isDown,"another height does not die to a post below it")
  for pickup in [PickupKind.tank,.helicopter] {
   let g=fixture();g.apply(pickup);g.hazardClock=11.8;g.stepElectricHazards(0.01)
   expect(!g.playerRoster.current.isDown && g.vehicle != nil,"\(pickup) keeps vehicle protection at a live post")
  }
  let training=fixture();training.godMode=true;training.hazardClock=11.8;training.stepElectricHazards(0.01);training.stepElectricHazards(0.01)
  expect(training.trainingHits==1 && training.deaths==0 && training.lives==3,"Godmode shows one virtual hazard loss per protection window")
  let credit=fixture();credit.hero=V2(x:0,y:-5);credit.hazardClock=11.8;let t=credit.electricTraps[0]
  credit.foes=[Foe(id:983000,p:t.p+V2(x:0.55,y:0),hp:999,speed:0,gait:0,creditSlot:0)]
  credit.step(0.01,input:Controls())
  expect(credit.foes.isEmpty && credit.score==0 && credit.pickups.isEmpty,"world trap kills do not invent player points or an owner-specific kill drop")
  let cleared=fixture();cleared.phase = .cleared;cleared.hazardClock=11.8;cleared.step(0.01,input:Controls())
  expect(cleared.playerRoster.current.isDown && cleared.hazardClock>11.8,"existing posts remain dangerous during treasure collection")
  let paused=fixture();paused.hazardClock=11.8;paused.step(0,input:Controls(pause:true));paused.step(20,input:Controls())
  expect(paused.hazardClock==11.8 && !paused.playerRoster.current.isDown,"pause freezes hazard time and damage")
  let changed=fixture();let oldIDs=changed.electricTraps.map(\.id),oldRevision=changed.hazardRevision;changed.beginRound()
  expect(changed.hazardClock==0 && changed.hazardRevision != oldRevision && changed.electricTraps.map(\.id) != oldIDs,"new round replaces the field and invalidates navigation on the same arena")
  changed.phase = .cleared;changed.enterSideRoom(SideRoomOffer(kind:.treasure,p:.zero))
  expect(changed.electricTraps.isEmpty && changed.layout.traps.isEmpty,"own separate safe bonus room removes the previous combat hazards")
  changed.reset()
  expect(changed.electricTraps.isEmpty && changed.hazardClock==0,"reset clears every previous post and clock")
  let audio=fixture();audio.hero=V2(x:0,y:-5);_=audio.takeAudioEvents();audio.hazardClock=10.49;audio.stepElectricHazards(0.02)
  let warnings=audio.takeAudioEvents();expect(!warnings.isEmpty && warnings.allSatisfy{$0 == .hazardWarning},"warning transition emits only its own synthesized cue")
  audio.hazardClock=11.69;audio.stepElectricHazards(0.02);let cues=audio.takeAudioEvents()
  expect(!cues.isEmpty && cues.allSatisfy{$0 == .hazardZap},"discharge onset emits a distinct cue at the actual active boundary")
  audio.stepElectricHazards(0.01)
  expect(audio.takeAudioEvents().isEmpty,"steady hazard state cannot replay its cue every frame")
  let sweep=ElectricTrap(p:.zero,offset:0,seed:9)
  expect(sweep.activeWindows(from:11.6,to:11.8).first?.lowerBound==11.7 && sweep.activeWindows(from:1,to:10).isEmpty,"contact windows clip a frame to actual active time instead of testing just its final state")
  expect(sweep.intersects(from:V2(x:-1,y:0),height:0,to:V2(x:1,y:0),height:0,bodyRadius:0.29),"fast movement across a post cannot skip its narrow contact area")
  expect(!sweep.intersects(from:V2(x:-1,y:0),height:1,to:V2(x:1,y:0),height:1,bodyRadius:0.29),"swept contact still excludes an actor crossing on another height")
  let moving=fixture();moving.hazardClock=11.8;let at=moving.electricTraps[0].p
  moving.hero=at+V2(x:1,y:0);moving.stepElectricHazards(0.05,from:[at-V2(x:1,y:0)],heights:[0])
  expect(moving.playerRoster.current.isDown,"the core resolves actual active swept player contact even with both endpoints outside")
  let safeTravel=fixture();safeTravel.hazardClock=11.6;let site=safeTravel.electricTraps[0].p
  safeTravel.hero=site+V2(x:2,y:0);safeTravel.stepElectricHazards(0.2,from:[site-V2(x:0.1,y:0)],heights:[0])
  expect(!safeTravel.playerRoster.current.isDown,"a path that passed the post before activation is not killed by a later active frame endpoint")
  let wound=GameCore();wound.reset();wound.round=34;wound.beginRound();wound.dogWounds=1;wound.playerRoster.current.dogRecoveryClock=5.5;wound.playerRoster.current.barrelWounds=1;wound.playerRoster.current.barrelRecoveryClock=5.5;wound.phase = .cleared;wound.prepareArenaExits();wound.clearClock=1
  wound.requestArenaExit(wound.availableExits.first(where:{$0.bonus==nil})!);wound.step(0.6,inputs:[])
  expect(wound.dogWounds==0 && wound.playerRoster.current.barrelWounds==0,"existing wound recovery really advances on the masked transition clock")
  let clusterPoints=[V2(x:-7.199846194750744,y:-4.010101341770042),V2(x:-7.094397119154305,y:-2.990716340259193),V2(x:-6.376968054349646,y:-4.112788272661104),V2(x:-6.855162572265365,y:-3.378905052619627)]
  var clustered=ArenaLayout(kind:.courtyard);clustered.runtimeTraps=[];clustered.runtimeObstacles=clustered.staticObstacles+clusterPoints.map{ArenaObstacle($0,radius:ElectricTrap.solidRadius,height:1.2)}
  let observed=V2(x:-7.18776849001354,y:-3.6186409562279396)
  let corrected=clustered.clamped(observed)
  expect(clustered.walkable(corrected,clearance:0.28) && (corrected-observed).length<0.5,"actual round29 regression resolves the union of adjacent post solids without an invalid one-frame body")
  for clearance in [0.29,0.65] {
   var valid=true,largest=0.0
   for x in -12...12 {for y in -12...12 {
    let p=V2(x:-7+Double(x)*0.08,y:-3.6+Double(y)*0.08),q=clustered.clamped(p,clearance:clearance)
    valid = valid && clustered.walkable(q,clearance:clearance-0.001);largest=max(largest,(q-p).length)
   }}
   print("CLUSTER-DIAGNOSTIC:clearance\(clearance),valid\(valid),largest\(largest)")
   expect(valid && largest<1.5,"clustered field resolves625footprint samples for clearance\(clearance) without leaving a foot or tank embedded")
  }
  let tiny=ArenaObstacle(.zero,radius:0.01)
  expect(!tiny.clearsSegment(from:V2(x:-0.06,y:0),to:V2(x:0.06,y:0),clearance:0),"continuous circle collision catches an obstacle between both clear endpoints")
  let rotated=ArenaObstacle(.zero,half:V2(x:0.02,y:1),angle:0.41)
  expect(!rotated.clearsSegment(from:V2(x:-2,y:0),to:V2(x:2,y:0),clearance:0.29) && rotated.clearsSegment(from:V2(x:-2,y:2),to:V2(x:2,y:2),clearance:0.29),"continuous rounded rectangle collision honors rotation and clear parallel passage")
  var pocket=ArenaLayout(kind:.courtyard);pocket.runtimeTraps=[]
  let ringPoints=[V2(x:-6.693607138766169,y:-3.6249171789935204),V2(x:-7.271552247386701,y:-3.109362944934416),V2(x:-6.7998592730709575,y:-4.235385956295528),V2(x:-7.256329854152388,y:-3.909551802955862),V2(x:-7.693339139794322,y:-4.172911237156397)]
  pocket.runtimeObstacles=pocket.staticObstacles+ringPoints.map{ArenaObstacle($0,radius:ElectricTrap.solidRadius,height:1.2)}
  func insidePocket(_ p:V2)->Bool {
   let a=ringPoints[0],b=ringPoints[1],c=ringPoints[3]
   func cross(_ u:V2,_ v:V2)->Double {u.x*v.y-u.y*v.x}
   let signs=[cross(b-a,p-a),cross(c-b,p-b),cross(a-c,p-c)]
   return signs.allSatisfy{$0>=0} || signs.allSatisfy{$0<=0}
  }
  var noTunnel=true,pocketSamples=0
  for x in -12...12 {for y in -12...12 {
   let start=V2(x:-7.1+Double(x)*0.10,y:-3.6+Double(y)*0.10)
   guard pocket.walkable(start,clearance:0.29) else{continue}
   if insidePocket(start) {pocketSamples+=1}
   for ray in 0..<16 {
    let angle=Double(ray)*Double.pi/8,q=pocket.moved(start,by:V2(x:cos(angle),y:sin(angle))*0.14)
    noTunnel = noTunnel && insidePocket(start)==insidePocket(q) && pocket.walkable(q,clearance:0.28)
   }
  }}
  expect(noTunnel && pocketSamples>0,"round47 cluster cannot teleport a body through a thin solid overlap into an enclosed free pocket")
  var corridor=ArenaLayout(kind:.island);corridor.runtimeTraps=[]
  corridor.runtimeObstacles=corridor.staticObstacles+[-1.0,1].map{ArenaObstacle(V2(x:$0*0.405,y:0),radius:ElectricTrap.solidRadius)}
  let corridorNav=ArenaNavigation();var traveler=V2(x:0,y:2);let destination=V2(x:0,y:-2)
  for _ in 0..<900 {
   corridorNav.update(layout:corridor,target:destination,dt:1.0/60)
   let direction=corridorNav.direction(from:traveler,to:destination,layout:corridor)
   traveler=corridor.moved(traveler,by:direction*(6.4/60))
   if (traveler-destination).length<0.15 {break}
  }
  expect((traveler-destination).length<0.15 && corridor.walkable(traveler),"navigation routes around a57cm gap that its58cm body cannot traverse instead of aiming into it forever")
  let cached=ElectricTrap(p:.zero,offset:0,seed:903)
  _=cached.state(at:12000);let transitions=cached.timingTransitionsEvaluated
  for i in 1...1000 {_=cached.state(at:12000+Double(i)*0.001)}
  expect(cached.timingTransitionsEvaluated-transitions<10,"late frames reuse the current phase instead of replaying12000seconds of hazard history every time")
  let earlier=cached.state(at:11.8),fresh=ElectricTrap(p:.zero,offset:0,seed:903)
  expect(earlier==fresh.state(at:11.8) && cached.activeWindows(from:11.6,to:11.8)==fresh.activeWindows(from:11.6,to:11.8),"past-time diagnostic queries reset the cache deterministically without changing phase boundaries")
  for radius in [0.29,0.65] {
   var edgeMap=ArenaLayout(kind:.cave);edgeMap.runtimeTraps=[];edgeMap.runtimeObstacles=edgeMap.staticObstacles
   let nav=ArenaNavigation(clearance:radius),goal=V2(x:0,y:-4.7);var p=edgeMap.boundary(V2(x:-99,y:1.3767168973276003),clearance:radius)
   expect(edgeMap.walkable(p,clearance:radius),"a body touching the clamped cave boundary is valid at its exact clearance\(radius)")
   for _ in 0..<1200 {nav.update(layout:edgeMap,target:goal,dt:1.0/60);p=edgeMap.moved(p,by:nav.direction(from:p,to:goal,layout:edgeMap)*(6.4/60),clearance:radius);if (p-goal).length<0.15 {break}}
   expect((p-goal).length<0.15,"actual round13 wall contact can navigate away toward the exit for footprint\(radius)")
  }
  var tight=ArenaLayout(kind:.forest);tight.runtimeTraps=[]
  let tightPoints=[V2(x:-6.089025665755714,y:-3.145688808025294),V2(x:-5.827359034825392,y:3.7068923078917058),V2(x:6.981879678831862,y:3.4839006103351244),V2(x:-7.11417799449816,y:4.231709433805421),V2(x:-6.49202988562426,y:4.448340380048515),V2(x:5.96389167026853,y:-3.411038706456278),V2(x:-6.488636716741002,y:-4.215556707736223),V2(x:-5.689742664473523,y:-4.393784445954876)]
  tight.runtimeObstacles=tight.staticObstacles+tightPoints.map{ArenaObstacle($0,radius:ElectricTrap.solidRadius)}
  var walker=V2(x:-6.083852645626918,y:-4.280747625602963);let tightNav=ArenaNavigation(),tightGoal=V2(x:0,y:-6.3)
  for _ in 0..<1800 {tightNav.update(layout:tight,target:tightGoal,dt:1.0/60);walker=tight.moved(walker,by:tightNav.direction(from:walker,to:tightGoal,layout:tight)*(6.4/60));if (walker-tightGoal).length<0.15 {break}}
  expect((walker-tightGoal).length<0.15,"actual round74 narrow exterior cusp escapes along obstacle normals and reaches the physical exit")
  var allAngles=true
  for rotation in 0..<32 {
   let angle=Double(rotation)*Double.pi/16,axis=V2(x:cos(angle),y:sin(angle)),perp=V2(x:-axis.y,y:axis.x),center=V2(x:-3,y:-2)
   var map=ArenaLayout(kind:.island);map.runtimeTraps=[];map.runtimeObstacles=map.staticObstacles+[-1.0,1].map{ArenaObstacle(center+axis*($0*0.409),radius:0.12)}
   var p=center-perp*sqrt(0.41*0.41-0.409*0.409);let target=center+perp*2,nav=ArenaNavigation()
   for _ in 0..<1200 {nav.update(layout:map,target:target,dt:1.0/60);p=map.moved(p,by:nav.direction(from:p,to:target,layout:map)*(6.4/60));if (p-target).length<0.15 {break}}
   allAngles = allAngles && (p-target).length<0.15 && map.walkable(p,clearance:0.28)
  }
  expect(allAngles,"all32rotated nearly touching post pairs allow a body to leave the narrow exterior cusp without shrinking its hull")
  print("\(passed) electric hazard checks passed;archived counts/waits and own map sites/hulls/collision/placement retry;not original binary or hardware acceptance")
 }
}
