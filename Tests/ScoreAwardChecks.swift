import Foundation
@main struct ScoreAwardChecks {
 static func main() {
  setbuf(stdout,nil);var passed=0
  func expect(_ ok:Bool,_ text:String){guard ok else{print("FAIL \(text)");exit(1)};passed+=1;print("PASS \(text)")}
  func fixture(_ count:Int=1)->GameCore {
   let g=GameCore();g.reset(playerCount:count);g.combatSpawningHeld=true;g.foes=[];g.pickups=[]
   for p in g.players {p.hero=g.layout.clamped(V2(x:-6+Double(p.slot)*4,y:-2));p.heroElevation=g.layout.height(p.hero);p.invulnerable=999}
   return g
  }
  expect(ScoreRules.extraLifeInterval==200000 && ScoreRules.ordinaryKill==100 && ScoreRules.bossKill==30000,"source score constants distinguish ordinary enemies,bosses and200000point thresholds")
  let exact=fixture();exact.score=199999;_=exact.takeAudioEvents();exact.award(1)
  expect(exact.score==200000 && exact.nextLifeAt==400000 && exact.lives==3 && exact.collectedLives==0,"crossing exact score threshold advances the account but grants no imaginary immediate reserve")
  expect(exact.directedLifeRewards.count==1 && exact.directedLifeRewards[0].personalLife && exact.directedLifeRewards[0].targetSlot==0 && exact.directedLifeRewards[0].kind == .life,"actual score pipeline creates one tagged personal statue above the correct role")
  expect(exact.directedLifeRewards[0].elevation==exact.heroElevation+8 && !exact.directedLifeRewards[0].landed,"personal score statue starts physically above its owner")
  expect(exact.scoreLifeStatus(for:0)=="LEBENSSTATUE IM ANFLUG" && !exact.takeAudioEvents().contains(.life),"in-flight HUD status is honest and life sound waits for an actual collection")
  exact.collectDirectedRewards();expect(exact.lives==3 && exact.directedLifeRewards.count==1,"a brand new high statue cannot be collected at birth")
  exact.advanceDirectedRewards(0.39);exact.collectDirectedRewards()
  expect(exact.lives==3 && exact.directedLifeRewards.count==1,"score statue observes the physical warmup and height gates")
  let before=exact.directedLifeRewards[0].p;exact.hero.x+=2;exact.advanceDirectedRewards(0.3)
  expect(exact.directedLifeRewards[0].p==exact.hero && exact.directedLifeRewards[0].p != before && !exact.directedLifeRewards[0].landed,"falling personal statue really follows the target's current movement")
  exact.advanceDirectedRewards(0.61);exact.collectDirectedRewards()
  expect(exact.lives==4 && exact.collectedLives==1 && exact.directedLifeRewards.isEmpty && exact.scoreLifeStatus(for:0)==nil,"actual touching collector receives one personal reserve and removes the pending statue")
  expect(exact.takeAudioEvents().filter{$0 == .life}.count==1 && exact.message=="EXTRA-LEBEN","actual personal statue collection emits one normal life cue and clear acknowledgement")
  exact.collectDirectedRewards();expect(exact.lives==4 && exact.collectedLives==1,"already collected personal statue cannot award again")
  let large=fixture();large.award(600001)
  expect(large.score==600001 && large.nextLifeAt==400000 && large.directedLifeRewards.count==1 && large.lives==3,"large score transaction processes exactly one source if instead of an invented while-loop")
  large.step(0.3,input:Controls());expect(large.nextLifeAt==400000 && large.directedLifeRewards.count==1,"ordinary elapsed frames cannot silently process additional crossed score thresholds")
  large.award(0);expect(large.nextLifeAt==600000 && large.directedLifeRewards.count==2,"following explicit score transaction can process the next still-crossed threshold")
  large.award(0);expect(large.nextLifeAt==800000 && large.directedLifeRewards.count==3,"third transaction advances its own threshold without rewriting banked points")
  large.award(0);expect(large.directedLifeRewards.count==3 && large.nextLifeAt==800000,"transaction below next threshold creates no extra award")
  let solo=fixture();solo.score=199999;solo.award(1);solo.step(1.3,input:Controls())
  expect(solo.lives==4 && solo.directedLifeRewards.isEmpty,"real combined GameCore step falls and collects a score statue through ordinary world recovery updates")
  let team=fixture(2);team.withPlayer(1){team.score=199999;team.award(1)}
  expect(team.players.map(\.lives)==[3,3] && team.players.map(\.nextLifeAt)==[200000,400000] && team.directedLifeRewards[0].targetSlot==1,"personal threshold and spawn target remain isolated to the scorer")
  team.advanceDirectedRewards(1.3);team.players[0].hero=team.players[1].hero;team.collectDirectedRewards()
  expect(team.players.map(\.lives)==[4,3] && team.players.map(\.collectedLives)==[1,0] && team.directedLifeRewards.isEmpty,"another actual collector may intercept the personal statue and receives only their own life")
  expect(team.activePlayerSlot==0 && team.players[1].nextLifeAt==400000,"interception cannot transfer the scorer's threshold or leak temporary actor selection")
  let own=fixture(4);own.withPlayer(2){own.score=199999;own.award(1)};own.advanceDirectedRewards(1.3);own.collectDirectedRewards()
  expect(own.players.map(\.lives)==[3,3,4,3],"unintercepted personal statue raises only its actual owner's reserve among four roles")
  let all=fixture(4);all.apply(.life)
  expect(all.players.allSatisfy{$0.lives==4} && all.directedLifeRewards.isEmpty,"ordinary non-directed life statue still gives a team-wide life without personal-score semantics")
  let caps=fixture(2);caps.players[0].lives=9;caps.players[1].lives=1;caps.score=199999;caps.award(1)
  expect(caps.directedLifeRewards.count==1 && caps.nextLifeAt==400000,"full scorer reserve still creates its genuine physical threshold statue")
  caps.advanceDirectedRewards(1.3);caps.players[1].hero=caps.players[0].hero;caps.players[0].hero.x-=3;caps.collectDirectedRewards()
  expect(caps.players.map(\.lives)==[9,2],"a teammate may use the capped scorer's landed personal statue without team-wide duplicate lives")
  let training=fixture();training.godMode=true;training.lives=9;training.trainingHits=12;training.score=199999;training.award(1)
  expect(training.displayedLives == -3 && training.trainingBonusLives==0,"Godmode counter does not pre-credit a statue that is still falling")
  training.advanceDirectedRewards(1.3);training.collectDirectedRewards()
  expect(training.displayedLives == -2 && training.lives==9 && training.trainingBonusLives==1,"actual personal statue repairs one Godmode minus-life while real reserves stay capped")
  let pause=fixture();pause.score=199999;pause.award(1);pause.step(0,input:Controls(pause:true));let held=pause.directedLifeRewards[0]
  pause.step(10,input:Controls())
  expect(pause.directedLifeRewards[0].fallClock==held.fallClock && pause.lives==3,"real pause cannot finish a physical score award behind the menu")
  pause.step(0,input:Controls(accept:true));pause.step(1.3,input:Controls())
  expect(pause.lives==4 && pause.directedLifeRewards.isEmpty,"real resume continues the same physical score award once")
  let transit=fixture();transit.award(200000);transit.phase = .cleared;transit.clearClock=3;transit.prepareArenaExits()
  transit.requestArenaExit(transit.availableExits.first!);let transitPosition=transit.hero,bombs=transit.bombs
  transit.step(1.3,input:Controls(move:V2(x:1,y:0),bomb:true))
  expect(transit.phase == .transition && transit.lives==4 && transit.directedLifeRewards.isEmpty && transit.hero==transitPosition && transit.bombs==bombs,"physical score statue may complete during a real frozen-input fade instead of being stranded at the exit")
  let stored=fixture();stored.score=199999;stored.award(1);stored.advanceDirectedRewards(1.3);let drop=stored.directedLifeRewards[0]
  stored.hero.x+=3;stored.advanceDirectedRewards(1000)
  expect(stored.directedLifeRewards.count==1 && stored.directedLifeRewards[0].p==drop.p && stored.directedLifeRewards[0].landed,"landed score statue has no ordinary timeout and stops following its target")
  expect(stored.scoreLifeStatus(for:0)=="LEBENSSTATUE BEREIT","personal HUD distinguishes a waiting landed statue from one still in flight")
  stored.round=5;stored.beginRound();stored.advanceDirectedRewards(1)
  expect(stored.visibleDirectedRewards.isEmpty && stored.directedLifeRewards.count==1,"landed score reward remains attached to its own previous map rather than teleporting into another arena")
  stored.round=1;stored.beginRound();stored.hero=drop.p;stored.heroElevation=stored.layout.height(drop.p);stored.collectDirectedRewards()
  expect(stored.lives==4 && stored.directedLifeRewards.isEmpty,"returning to the own map can collect the physically retained personal statue")
  let bundle=fixture();bundle.makeDirectedReward(for:0,kind:.life);bundle.makeDirectedReward(for:0,kind:.life,personalLife:true);bundle.advanceDirectedRewards(1.3)
  expect(bundle.visibleRewardBundles.count==2 && bundle.visibleRewardBundles.allSatisfy{$0.count==1},"landed personal and team-life statues with identical models cannot merge their different effects")
  let sibling=fixture();sibling.award(200000);sibling.award(200000);sibling.advanceDirectedRewards(1.3)
  expect(sibling.visibleRewardBundles.count==1 && sibling.visibleRewardBundles[0].count==2,"same-effect landed score statues may share one silhouette while retaining two logical pickups")
  let boss=fixture(2);boss.round=40;boss.beginRound();boss.fixtureSilverbacks();boss.players[1].score=190000;boss.players[1].multiplier=3
  boss.withPlayer(1){boss.damageSilverback(99999,id:boss.silverbacks[0].id)};boss.stepSilverback(0)
  expect(boss.players[1].score==280000 && boss.players[0].score==0 && boss.players[1].nextLifeAt==400000,"actual boss death credits30000basepoints times the lethal player's personal multiplier")
  expect(boss.players.allSatisfy{$0.lives==3} && boss.directedLifeRewards.filter{$0.personalLife && $0.targetSlot==1}.count==1,"boss score threshold creates its physical personal award without an immediate life or teammate bonus")
  let count=boss.directedLifeRewards.count;boss.stepSilverback(0)
  expect(boss.players[1].score==280000 && boss.directedLifeRewards.count==count,"repeated boss death frames cannot duplicate score or pending personal statues")
  let aborted=fixture();aborted.award(200000);aborted.reset()
  expect(aborted.directedLifeRewards.isEmpty && aborted.score==0 && aborted.nextLifeAt==200000,"new game clears pending score statues and thresholds")
  let ended=fixture();ended.award(200000);ended.finishTeamRun()
  expect(ended.phase == .gameOver && ended.directedLifeRewards.isEmpty,"actual finished run removes its uncollected score rewards")
  print("\(passed) score award checks passed;source30000boss/one-threshold transactions/physical personal life/actual collector/HUD/pause/map retention;own drop scale,original damage and hardware remain open")
 }
}
