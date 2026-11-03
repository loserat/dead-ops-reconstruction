import Foundation
@main struct RespawnChecks {
 static func main(){
  var count=0
  func expect(_ yes:Bool,_ text:String){guard yes else{fatalError(text)};count+=1;print("PASS \(text)")}
  func game(_ n:Int=1)->GameCore {let g=GameCore();g.reset(playerCount:n);g.foes=[];g.pickups=[];g.combatSpawningHeld=true;for p in g.players{p.invulnerable=0;p.donationCooldown=999};return g}
  func hit(_ g:GameCore,_ slot:Int=0){g.withPlayer(slot){g.invulnerable=0;g.playerRoster.current.bodyShield=nil;g.loseLife()}}
  let own=game();own.hero=V2(x:4,y:1.5);own.apply(.ray);let point=own.hero,bombs=own.bombs,boost=own.dashes
  hit(own)
  expect(own.players[0].isDown && own.players[0].respawnRemaining==2 && own.lives==3 && own.hero==point,"reserve-funded death keeps its position and bank while scheduling a two-second body return")
  expect(own.phase == .playing && own.hasRecoverablePlayer && own.weapon==nil,"a pending solo return is a continuing run with lost temporary equipment")
  own.pickups=[Pickup(id:900001,p:point,kind:.bomb)]
  for _ in 0..<119 {own.step(1.0/60,input:Controls(move:V2(x:1,y:0),aim:V2(x:1,y:0),dash:true,bomb:true))}
  expect(own.players[0].isDown && own.hero==point && own.lives==3 && own.shots.isEmpty && own.bombs==bombs && own.dashes==boost && own.pickups.count==1,"119 real frames cannot move fire spend or collect with a dead pending body")
  own.step(1.0/60,input:Controls())
  expect(own.isPlayerActive && own.players[0].respawnRemaining==nil && own.lives==2 && own.hero==point && own.players[0].bodyShield?.remaining==RecoveryRules.fullShield,"the two-second boundary spends one reserve and restores the current world position")
  own.invulnerable=0;hit(own);own.stepTeamRecovery(0.5);let left=own.players[0].respawnRemaining!
  own.step(0,input:Controls(pause:true));own.step(7,input:Controls())
  expect(own.phase == .paused && own.players[0].respawnRemaining==left && own.lives==2,"pause freezes the short funded return and its unspent reserve")
  own.step(0,input:Controls(accept:true));own.stepTeamRecovery(1.5)
  expect(own.isPlayerActive && own.lives==1 && own.hero==point,"resume completes the same callback once without teleporting to spawn")
  let roof=game();roof.round=21;roof.beginRound();roof.hero=V2(x:-7,y:-1.3);roof.heroElevation=roof.layout.height(roof.hero);roof.invulnerable=0;let floor=roof.heroElevation
  hit(roof);roof.foes=[Foe(id:1,p:roof.hero+V2(x:1,y:0),hp:5,speed:0,gait:0),Foe(id:2,p:roof.layout.spawn,hp:5,speed:0,gait:0)];roof.stepTeamRecovery(2)
  expect(roof.hero==V2(x:-7,y:-1.3) && roof.heroElevation==floor && roof.foes.map(\.id)==[1,2] && roof.players[0].bodyShield != nil,"raised-floor return retains its body and nearby foes until the delayed narrow shield contact is actually resolved")
  let pair=game(2);for p in pair.players{p.lives=1};hit(pair);hit(pair,1)
  expect(pair.players.allSatisfy(\.isDown) && pair.phase == .playing && pair.hasRecoverablePlayer,"all current bodies may be dead while funded returns keep the team run alive")
  pair.stepTeamRecovery(2)
  expect(pair.players.allSatisfy{!$0.isDown && $0.lives==0},"both funded last reserves restore their own final bodies")
  hit(pair);hit(pair,1);expect(pair.phase == .gameOver && !pair.hasRecoverablePlayer,"only the final unfunded team defeat ends the run")
  func statue()->GameCore {
   let g=game(4);for p in g.players{p.lives=0;if p.slot>0{p.isDown=true;p.reviveRemaining=50}}
   g.grantTeamLife();return g
  }
  let award=statue()
  expect(award.players.map(\.lives)==[1,1,0,0] && award.players[1].respawnRemaining==2 && award.pendingLifeAwards.count==1,"ordinary team-life award waits at the first downed role before reaching later roles")
  award.stepTeamRecovery(2)
  expect(!award.players[1].isDown && award.players[1].lives==0 && award.players[2].respawnRemaining==2 && award.players[3].collectedLives==0,"after two seconds the next downed role receives its own life and callback")
  award.stepTeamRecovery(2)
  expect(!award.players[2].isDown && award.players[3].respawnRemaining==2 && award.players[3].lives==1,"the third waiting body starts after the second callback completes")
  award.stepTeamRecovery(2)
  expect(award.players.allSatisfy{!$0.isDown && $0.collectedLives==1} && award.players.map(\.lives)==[1,0,0,0] && award.pendingLifeAwards.isEmpty,"one team statue completes its roster after six seconds with exactly one award per role")
  let large=statue(),small=statue();large.stepTeamRecovery(6);for _ in 0..<360 {small.stepTeamRecovery(1.0/60)}
  expect(large.players.map(\.lives)==small.players.map(\.lives) && large.players.map(\.isDown)==small.players.map(\.isDown) && small.pendingLifeAwards.isEmpty,"staged callbacks agree for one large delta and360ordinary timer slices")
  let credit=game(2);for p in credit.players{p.lives=0};credit.players[0].lives=1;credit.players[0].donationCooldown=0;credit.players[1].donationCooldown=0;hit(credit,1);credit.stepTeamRecovery(3)
  expect(credit.players[1].isDown && credit.players[1].sponsoredRespawn && credit.players[0].lives==0,"a donation spends one donor reserve but schedules the recipient instead of reviving instantly")
  credit.withPlayer(1){credit.grantExtraLife()};credit.stepTeamRecovery(2)
  expect(!credit.players[1].isDown && credit.players[1].lives==1 && !credit.players[1].sponsoredRespawn,"a gifted return consumes its sponsorship and preserves an independently found reserve")
  let expiry=game(2);for p in expiry.players{p.lives=0};hit(expiry);expiry.players[0].reviveRemaining=0.5;expiry.grantExtraLife();expiry.stepTeamRecovery(0.5)
  expect(!expiry.players[0].isDown && expiry.players[0].lives==1 && expiry.players[0].respawnRemaining==nil,"an earlier free timer expiry cancels the funded wait without spending its reserve")
  let boundary=game(2);boundary.players[0].lives=1;boundary.players[1].lives=0;hit(boundary);hit(boundary,1);boundary.phase = .cleared;boundary.startNextCombatRound()
  expect(boundary.players[0].isDown && boundary.players[0].respawnRemaining==2 && !boundary.players[1].isDown,"round start restores only the zero-reserve waiting body while funded return keeps its delay")
  let entry=boundary.players[0].hero;boundary.stepTeamRecovery(2)
  expect(!boundary.players[0].isDown && boundary.players[0].hero==entry && boundary.players[0].lives==0,"a pending return follows the body's new arena placement after a round transition")
  let ended=statue();ended.finishTeamRun();let banks=ended.players.map(\.lives);ended.stepTeamRecovery(99)
  expect(ended.pendingLifeAwards.isEmpty && ended.phase == .gameOver && ended.players.map(\.lives)==banks,"game over cancels remaining shared awards and prevents late resurrection")
  let reset=statue();reset.reset()
  expect(reset.pendingLifeAwards.isEmpty && reset.players.allSatisfy{$0.respawnRemaining==nil && !$0.sponsoredRespawn && !$0.isDown},"new run removes all funded waits and staged life callbacks")
  print("\(count) respawn timing/position checks passed;source-based two-second lifecycle,own donation transit/pulse/tie ordering")
 }
}
