import Foundation
@main struct RecoveryChecks {
 static func main(){
  setbuf(stdout,nil);var passed=0
  func expect(_ value:Bool,_ message:String){guard value else{fatalError(message)};passed+=1;print("PASS \(message)")}
  func game(_ count:Int=2)->GameCore {
   let g=GameCore();g.reset(playerCount:count);g.foes=[];g.pickups=[]
   g.combatSpawningHeld=true
   for p in g.players {p.invulnerable=0;p.lives=0}
   return g
  }
  func hit(_ g:GameCore,_ slot:Int=0){g.withPlayer(slot){g.invulnerable=0;g.playerRoster.current.bodyShield=nil;g.vehicle=nil;g.loseLife()}}
  let solo=game(1);solo.lives=3
  for remaining in [2,1,0] {
   hit(solo);expect(solo.players[0].isDown && solo.players[0].respawnRemaining==2 && solo.lives==remaining+1,"reserve is held during the two-second return");solo.stepTeamRecovery(2);expect(solo.phase == .playing && solo.lives==remaining && solo.isPlayerActive && solo.players[0].bodyShield?.remaining==RecoveryRules.fullShield,"a reserve-funded death restores the body, including the final zero-reserve body")
  }
  hit(solo);expect(solo.phase == .gameOver && solo.lives==0 && solo.deaths==4 && solo.players[0].isDown,"three initial spare lives allow four bodies, then one terminal death")
  let ending=solo.gameOverSequence!.clock;hit(solo)
  expect(solo.deaths==4 && solo.gameOverSequence!.clock==ending,"terminal damage cannot consume another body or restart the ending")
  let zero=game(1);zero.invulnerable=99;zero.step(0.01,input:Controls(move:V2(x:1,y:0)))
  expect(zero.hero.x>0 && zero.phase == .playing && zero.lives==0,"zero reserves still permit actual movement and a live combat step")
  let gift=game();gift.players[0].lives=1;hit(gift,1)
  expect(gift.players[1].isDown && gift.players[1].respawnRemaining==nil && gift.players[1].donationCooldown==0 && gift.players[0].lives==1,"donation starts with an unfunded sixty-second wait rather than an immediate debit");gift.stepTeamRecovery(5)
  expect(gift.phase == .playing && gift.players.map(\.isDown)==[false,false] && gift.players.map(\.lives)==[0,0],"one donor reserve restores a teammate after search link flight and funded return without killing the zero-reserve donor")
  expect(gift.players[0].donationsGiven==1 && gift.players[1].donationsReceived==1 && abs(gift.players[1].donationCooldown-61)<0.000001 && gift.players[1].bodyShield?.remaining==RecoveryRules.fullShield,"one automatic donation records separate source and recipient cooldowns and full respawn protection")
  let rewards = !gift.directedLifeRewards.isEmpty && gift.directedLifeRewards.allSatisfy{$0.targetSlot==0 && ($0.kind == .bomb || $0.kind == .dash)}
  expect(rewards && gift.players[0].vehicle==nil && gift.players[0].bombs==1 && gift.players[1].vehicle==nil && gift.players[1].bombs==1 && gift.players[1].dashes==2,"compensation targets the donor as physical eligible drops while neither player receives instant equipment")
  expect(gift.players.allSatisfy{$0.score==0 && $0.collectedLives==0} && gift.activePlayerSlot==0,"donation creates no score no collected-life pickup and no leaked actor selection")
  let wait=game();hit(wait,0)
  expect(wait.phase == .playing && wait.players[0].isDown && wait.players[0].reviveRemaining==60 && !wait.players[1].isDown,"one surviving current body keeps an out-of-reserves teammate's run alive")
  hit(wait,0);expect(wait.players[0].deaths==1 && wait.players[0].reviveRemaining==60,"repeated damage to a waiting player neither kills nor resets their countdown")
  wait.stepTeamRecovery(59.5);expect(wait.players[0].isDown && abs(wait.players[0].reviveRemaining-0.5)<0.000001,"waiting does not restore the player before sixty combat seconds")
  wait.stepTeamRecovery(0.5)
  expect(!wait.players[0].isDown && wait.players[0].reviveRemaining==0 && wait.players[0].lives==0 && wait.players[0].bodyShield?.remaining==RecoveryRules.fullShield,"countdown expiry restores one current body without manufacturing a reserve")
  let wipe=game();hit(wipe,0);hit(wipe,1)
  expect(wipe.phase == .gameOver && wipe.players.allSatisfy(\.isDown) && wipe.players.allSatisfy{$0.deaths==1},"the run ends when the final surviving body falls")
  wipe.stepTeamRecovery(999);expect(wipe.players.allSatisfy(\.isDown) && wipe.phase == .gameOver,"a completed team defeat cannot self-resurrect sixty seconds later")
  let cooled=game();cooled.players[0].lives=3;hit(cooled,1)
  cooled.stepTeamRecovery(5);hit(cooled,1)
  expect(cooled.players[1].isDown && abs(cooled.players[1].donationCooldown-61)<0.000001 && cooled.players[0].donationsGiven==1,"a recipient cannot immediately take a second life inside its sixty-five-second transfer cooldown")
  cooled.stepTeamRecovery(1)
  expect(cooled.players[1].isDown && abs(cooled.players[1].donationCooldown-60)<0.000001 && abs(cooled.players[1].reviveRemaining-59)<0.000001 && !cooled.players[1].donationSearchActive,"automatic recovery and role cooldown advance independently after a busy transfer attempt")
  cooled.stepTeamRecovery(59)
  expect(!cooled.players[1].isDown && abs(cooled.players[1].donationCooldown-1)<0.000001 && cooled.players[0].donationsGiven==1,"a rejected busy attempt finishes through free recovery without a hidden later donation")
  hit(cooled,1);cooled.stepTeamRecovery(3)
  expect(cooled.players[1].isDown && abs((cooled.players[1].respawnRemaining ?? -1)-2)<0.000001,"a new eligible death searches and transports its second life before scheduling the funded return");cooled.stepTeamRecovery(2)
  expect(!cooled.players[1].isDown && cooled.players[0].donationsGiven==2 && abs(cooled.players[1].donationCooldown-61)<0.000001 && cooled.players[0].lives==1,"a newly eligible transfer spends exactly one reserve and restores the waiting recipient")
  expect(!cooled.tryDonateLife(to:1) && !cooled.tryDonateLife(to:-1) && !cooled.tryDonateLife(to:99) && cooled.players[0].lives==1,"active or invalid recipients cannot spend any donor reserve")
  let ranked=game(4);ranked.players[0].lives=1;ranked.players[1].lives=3;ranked.players[2].lives=3;hit(ranked,3);ranked.stepTeamRecovery(2)
  expect(ranked.players.map(\.lives)==[1,2,3,0] && ranked.players[1].donationsGiven==1,"source donor choice uses most reserves then first slot order at the delayed debit")
  let statue=game(3);hit(statue,0);hit(statue,1);statue.withPlayer(2){statue.apply(.life)};statue.stepTeamRecovery(4)
  expect(statue.players.map(\.isDown)==[false,false,false] && statue.players.map(\.lives)==[0,0,1] && statue.players.allSatisfy{$0.collectedLives==1},"one team statue restores both waiting bodies and grants the survivor one spare")
  expect(statue.players[0].donationsReceived==0 && statue.players[2].vehicle==nil && statue.players[2].bombs==1,"a statue revival is not a donation and grants no donor reward")
  let score=game();hit(score,0);score.score=199999;score.award(200001);score.award(0);score.stepTeamRecovery(2);score.players[1].hero=score.players[0].hero;score.players[1].heroElevation=score.players[0].heroElevation;score.collectDirectedRewards()
  expect(score.players[0].isDown && score.players[0].lives==0 && score.players[0].collectedLives==0 && score.players[1].lives==2,"two personal score statues award their actual living collector instead of remotely restoring the downed score owner")
  expect(score.nextLifeAt==600000 && score.players[1].nextLifeAt==200000,"recovery does not merge personal extra-life thresholds")
  let round=game();hit(round,1);round.players[1].donationCooldown=42;round.phase = .cleared;round.startNextCombatRound()
  expect(round.round==2 && !round.players[1].isDown && round.players[1].reviveRemaining==0 && round.players[1].lives==0 && round.layout.walkable(round.players[1].hero),"starting a new combat round restores a waiting teammate at a walkable point")
  expect(round.players[1].donationCooldown==42 && round.players[0].donationsGiven==0 && round.players[1].score==0,"round-boundary return preserves donation cooldown and creates no reward or score")
  let frozen=game();hit(frozen,0);frozen.players[0].donationCooldown=60
  for phase in [RunPhase.paused,.title,.loopReturn,.checkpointComplete] {frozen.phase=phase;frozen.stepTeamRecovery(999)}
  expect(frozen.players[0].reviveRemaining==60 && frozen.players[0].donationCooldown==60 && frozen.players[0].isDown,"pause, menus and loop cutscenes cannot advance recovery clocks")
  frozen.phase = .playing
  for dt in [-1.0,.nan,.infinity] {frozen.stepTeamRecovery(dt)}
  expect(frozen.players[0].reviveRemaining==60 && frozen.players[0].donationCooldown==60,"invalid recovery deltas neither expire waits nor extend cooldowns")
  let over=game(1);hit(over);over.apply(.life)
  expect(over.phase == .gameOver && over.players[0].isDown,"a late direct reward cannot revive an ended solo run")
  let protected=game();protected.withPlayer(0){protected.apply(.tank)};hit(protected,1)
  protected.withPlayer(0){protected.invulnerable=0;protected.loseLife()}
  expect(!protected.players[0].isDown && protected.players[0].deaths==0,"vehicle protection preserves the final active teammate")
  let god=game();god.godMode=true;for _ in 0..<4 {hit(god,0)}
  expect(god.phase == .playing && god.players[0].trainingHits==4 && god.displayedLives == -4 && !god.players[0].isDown && god.players[1].donationsGiven==0,"virtual Godmode losses below zero never enter team wait or trigger donations")
  let fate=game();fate.fate = .friendship;fate.restoreFateBenefits();fate.lives=1;fate.apply(.ray);fate.apply(.orb);hit(fate);fate.stepTeamRecovery(2)
  expect(fate.isPlayerActive && fate.chickens.count==1 && fate.chickens[0].permanent && fate.weapon==nil && fate.orbShields.isEmpty,"zero-reserve respawn restores permanent Fate support while removing temporary equipment")
  expect(LifeDonationReward.allCases.enumerated().allSatisfy{LifeDonationReward.choose(Double($0.offset)/4)==$0.element} && LifeDonationReward.choose(1) == .boosts,"all four donation reward branches have bounded selection intervals")
  expect(LifeDonationReward.choose(.nan) == .bombs && LifeDonationReward.choose(-1) == .bombs && LifeDonationReward.choose(.greatestFiniteMagnitude) == .boosts,"invalid or extreme reward probes cannot index outside the reward table")
  let equip=game();equip.bombs=8;equip.dashes=7;equip.grantDonationReward(.bombs);equip.grantDonationReward(.boosts);equip.stepTeamRecovery(1.3);equip.collectDirectedRewards()
  expect(equip.bombs==9 && equip.dashes==9 && equip.players[1].bombs==1 && equip.players[1].dashes==2,"three nuke/four boost donation bundles respect each owner's cap of nine")
  equip.grantDonationReward(.tank);equip.stepTeamRecovery(1.3);equip.collectDirectedRewards();expect(equip.vehicle?.kind == .tank && equip.vehicle?.remaining==20,"tank compensation follows the real vehicle grant path")
  equip.vehicle=nil;equip.fate = .fortitude;equip.grantDonationReward(.helicopter);equip.stepTeamRecovery(1.3);equip.collectDirectedRewards()
  expect(equip.vehicle?.kind == .helicopter && equip.vehicle?.remaining==40,"Hind compensation retains the donor's Fortitude duration")
  let clean=game();hit(clean,0);clean.players[1].donationsGiven=4;clean.reset()
  expect(clean.players.count==2 && clean.players.allSatisfy{!$0.isDown && $0.reviveRemaining==0 && $0.donationCooldown==0 && $0.donationsGiven==0 && $0.donationsReceived==0 && $0.lives==3},"new runs clear waiting bodies, donation histories and both recovery clocks for every slot")
  print("\(passed) reserve-life/team-recovery checks passed;not a playable cooperative loop or hardware acceptance")
 }
}
