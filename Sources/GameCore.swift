import Foundation

struct V2: Equatable {
    var x: Double = 0, y: Double = 0
    static let zero = V2()
    static func +(a: V2, b: V2) -> V2 { V2(x:a.x+b.x,y:a.y+b.y) }
    static func -(a: V2, b: V2) -> V2 { V2(x:a.x-b.x,y:a.y-b.y) }
    static func *(a: V2, b: Double) -> V2 { V2(x:a.x*b,y:a.y*b) }
    var length: Double { hypot(x,y) }
    var unit: V2 { length > 0.0001 ? self * (1/length) : .zero }
}
/// The visual shoreline and playable boundary share one rounded-rectangle footprint.
enum IslandLayout {
    static let width=11.6, depth=7.6, exponent=4.0
    static func edge(angle:Double,scale:Double=1)->V2 {
        let c=cos(angle),s=sin(angle)
        let ripple=1+0.020*sin(angle*7)+0.013*cos(angle*13)+0.009*sin(angle*37)
        return V2(x:(c<0 ? -1:1)*pow(abs(c),2/exponent)*width*scale*ripple,
                  y:(s<0 ? -1:1)*pow(abs(s),2/exponent)*depth*scale*ripple)
    }
    static func contains(_ p:V2,margin:Double=0)->Bool {
        pow(abs(p.x)/(width-margin),exponent)+pow(abs(p.y)/(depth-margin),exponent)<1
    }
    static func clamped(_ p:V2)->V2 {
        let q=pow(abs(p.x)/(width-0.65),exponent)+pow(abs(p.y)/(depth-0.65),exponent)
        return q>1 ? p*(1/pow(q,1/exponent)):p
    }
}
enum RunPhase { case title, playing, cleared, bonusRoom, paused, gameOver, checkpointComplete, loopReturn,transition }
enum PickupKind: Int, CaseIterable { case treasure, gem, life, dash, bomb, spread, ray, rocket, orb, chicken, boots, deathMachine, grenade, flamethrower, tank, helicopter, teddy, barrelShield, monkey, turret }
enum FoeKind {case zombie,prisoner,crawler,villager,engineer,sasquatch,martyr,hound}
struct Foe { var id:Int; var p:V2; var hp:Double; var speed:Double; var gait:Double;var elevation=0.0,fallSpeed=0.0;var kind:FoeKind = .zombie;var behaviorClock=0.0;var lungeDirection=V2.zero;var enraged=false;var arrival:EnemyArrival?=nil;var burning=0.0;var homeEntrance:Int?=nil,retreatEntrance:Int?=nil;var scoreFactor=1;var environmentKill=false;var creditSlot:Int?=nil,burningOwner:Int?=nil;var referenceVitality:ReferenceVitality?=nil;var flameAfterburn:FlameAfterburn?=nil;var teslaMarked=false,teslaContacted=false;var launchedByContact=false }
struct Shot { var id:Int; var p:V2; var v:V2; var ttl:Double; var damage:Double; var kind:PickupKind?; var height:Double=0.53;var verticalSpeed=0.0;var hitIDs:Set<Int>=[];var bounces=0;var piercing=true;var explosionDamage=8.0;var targetHeight:Double?=nil;var ownerSlot=0 }
struct Pickup { var id:Int; var p:V2; var kind:PickupKind; var ttl:Double = 14;var loot:LootAppearance?=nil;var persistent=false;var gemUnits:Int?=nil;var lifetime:PickupLifetime = .custom;var age=0.0;var popup:PickupPopup?=nil
    var sourcePowerupTimeout:Bool {
        get {lifetime.steady != nil}
        set {lifetime=newValue ? .source(for:kind):.custom}
    }
    var readyForContact:Bool {age+1e-9>=max(lifetime.contactDelay,popup == nil ? 0:PickupPopup.contactDelay)}
    var hasNoTimeout:Bool {persistent || lifetime == .untilCleanup}
    var expiryWarning:Bool {!hasNoTimeout && sourcePowerupTimeout && ttl<=SourcePowerupTimeout.blinkDuration}
    func opacity(clock:Double)->Double {
        if hasNoTimeout {return 1}
        if let steady=lifetime.steady {return SourcePowerupTimeout.opacity(remaining:ttl,steady:steady)}
        return ttl<3 && Int(clock*6)%2==0 ? 0.45:1
    }
}
struct Effect { var id:Int; var p:V2; var ttl:Double; var size:Double; var color:Int;var height:Double?=nil }
struct Controls { var move=V2.zero; var aim=V2.zero; var dash=false; var bomb=false; var accept=false; var pause=false; var back=false; var openSettings=false; var systemPause=false; var menuX=0; var menuY=0; var menuRow:Int?=nil; var menuPoint:V2?=nil }

/// Repeating forty-round stages. Original timing and balance remain unverified; see Reference/coverage.json.
final class GameCore {
    let playerRoster=PlayerRoster()
    var silverbacks:[Silverback]=[],silverbackStarted=false,bossArenaCleared=false
    var bossArrivalClock:BossArrivalClock?,sourceBossDead=false,bossFrameBirths:[Int:Double]=[:]
    var silverback:Silverback? {
        get {silverbacks.first}
        set {if let boss=newValue {if silverbacks.isEmpty {silverbacks=[boss]}else{silverbacks[0]=boss}}else{silverbacks=[]}}
    }
    var loopReturn:LoopReturn?,bossVictory:BossVictory?
    var advancingBossVictory=false
    var rareLifeTimer:RareLifeTimer?
    var sourceLoot:SourceLootDirector?
    var collectedWorldFunds=0,collectedRoomFunds=0
    var combatSpawnFlow:CombatSpawnFlow?,retiringSpawnFlows:[CombatSpawnFlow]=[]
    let raiderNavigation=ArenaNavigation(clearance:0.75)
    var treasureRaider:TreasureRaider?,raiderVisited=false,raidsSeen=0,treasuresStolen=0
    var nextRaidRound=5,raidScheduleSeed:UInt64=18273
    var electricTraps:[ElectricTrap]=[],hazardObstacles:[ArenaObstacle]=[],hazardKind:ArenaKind?
    var hazardClock=0.0,hazardRevision=0,hazardRequestedCount=0,hazardSeed:UInt64=86753
    var layout:ArenaLayout {
        var l=ArenaLayout.forRound(round);l.bonusRoom=sideRoom?.kind;l.hazardRevision=hazardRevision
        let active=sideRoom==nil && hazardKind==l.kind
        l.runtimeTraps=active ? electricTraps:[];l.runtimeObstacles=active ? hazardObstacles:l.staticObstacles
        return l
    }
    var sideRoom:SideRoomState?,sideRoomOffer:SideRoomOffer?
    var visitedSideRoomRounds:Set<Int>=[],environmentRevision=0
    var bonusViewFlip=false
    var fateRoomVisited=false
    var fateEntryEvaluatedRound:Int?
    var fateRoom:FateRoomState?
    var pendingLifeAwards:[TeamLifeAward]=[]
    var lifeTransfers:[LifeTransfer]=[],directedLifeRewards:[DirectedLifeReward]=[]
    private var audioEvents:[AudioQueuedEvent]=[]
    private var defeatPresentations:[DefeatPresentation]=[]
    func takeDefeatPresentations()->[DefeatPresentation] {
        let result=defeatPresentations;defeatPresentations.removeAll(keepingCapacity:true);return result
    }
    func emitAudio(_ cue:AudioCue,at position:V2?=nil) {
        let event=AudioQueuedEvent(cue:cue,position:position)
        if audioEvents.count<32 {audioEvents.append(event);return}
        if let index=audioEvents.indices.min(by:{audioEvents[$0].cue.priority<audioEvents[$1].cue.priority}),audioEvents[index].cue.priority<cue.priority {
            audioEvents.remove(at:index);audioEvents.append(event)
        }
    }
    func takeAudioEvents()->[AudioCue] {let cues=audioEvents.map(\.cue);audioEvents=[];return cues}
    func takeSpatialAudioFrame(centerX:Double=0,centerY:Double=0,halfWidth:Double=11,halfDepth:Double=8)->SpatialAudioFrame {
        let events=audioEvents;audioEvents=[]
        return SoundSpace.frame(events,centerX:centerX,centerY:centerY,halfWidth:halfWidth,halfDepth:halfDepth,sign:viewOrientation.sign)
    }
    var godMode=false,usedGodMode=false
    var displayedLives:Int {godMode ? lives-trainingHits+trainingBonusLives:lives}
    var phase:RunPhase = .title
    var gameOverSequence:GameOverSequence?
    var resumePhase:RunPhase = .playing
    var round=1
    var foes:[Foe]=[], shots:[Shot]=[], pickups:[Pickup]=[], effects:[Effect]=[]
    var flameJets:[FlameJet]=[]
    var orb:Double {
        get {orbRemaining}
        set {if newValue<=0 {retireOrbs()} else if orbShields.isEmpty {grantOrbs(duration:newValue)} else {orbRemaining=newValue}}
    }
    var chicken:Double {
        get {chickens.map(\.ttl).max() ?? 0}
        set {if newValue<=0 {chickens=[]} else if chickens.isEmpty {addChicken(duration:newValue)} else {for i in chickens.indices {chickens[i].ttl=newValue}}}
    }
    var barrels:[FlamingBarrel]=[],barrelClock=2.0
    var bulls:[Bull]=[],stampede:StampedeDirector?
    var bullClock:Double {get{stampede?.wait ?? 0}set{stampede?.setWait(newValue)}}
    var roundClock=0.0,clearClock=0.0
    var message=""
    var messageTime=0.0,elapsed=0.0
    var arenaExits:[ArenaExit]=[],arenaTransit:ArenaTransit?
    var previousExitSide:EntrySide = .east,lastMagicExitRound=0,lastArmoryExitRound:Int?,exitSeed:UInt64=1
    private var nextID=0
    private var seed:UInt64=12345
    private var prePause:RunPhase = .playing
    var collectingPlayerDamage=false
    func id()->Int { nextID += 1; return nextID }
    func random()->Double { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return Double(seed >> 11)/Double(UInt64.max >> 11) }
    func reset(playerCount:Int?=nil) {
        defeatPresentations.removeAll(keepingCapacity:true)
        combatSpawnFlow=nil;retiringSpawnFlows=[]
        playerRoster.reset(count:playerCount)
        rareLifeTimer=RareLifeTimer(baseWait:240+random()*300)
        sourceLoot=SourceLootDirector(random:{self.random()});collectedWorldFunds=0;collectedRoomFunds=0
        bonusViewFlip=false;clearElectricHazards();hazardSeed=seed ^ 86753
        arenaExits=[];arenaTransit=nil;previousExitSide = .east;lastMagicExitRound=0;lastArmoryExitRound=nil;exitSeed=seed ^ 74693
        gameOverSequence=nil;pendingLifeAwards=[];lifeTransfers=[];directedLifeRewards=[]
        audioEvents=[];loopReturn=nil;bossVictory=nil;advancingBossVictory=false;treasureRaider=nil;raiderVisited=false;raidsSeen=0;treasuresStolen=0;nextRaidRound=5;raidScheduleSeed=seed ^ 18273;vehicle=nil;clearCarriedSupport();monkeys=[];sentries=[]
        fate=nil;fateRoomVisited=false;fateEntryEvaluatedRound=nil;fateRoom=nil;sideRoom=nil;sideRoomOffer=nil;visitedSideRoomRounds=[];environmentRevision+=1
        silverback=nil;silverbackStarted=false;martyrDamagePending=false;barrels=[];barrelClock=2;barrelDamagePending=false;bulls=[];stampede=nil;dogWounds=0;round=1; lives=3; dashes=2; bombs=1; score=0; multiplier=1;multiplierCharge=0; nextLifeAt=200_000
        hero = .zero;heroElevation=0;heroFallSpeed=0; facing=V2(x:0,y:-1); foes=[]; shots=[]; pickups=[]; effects=[]
        weapon=nil; flameJets=[];weaponReserve=0; invulnerable=2; dashTime=0; boots=0; orb=0; chicken=0
        electricArcs=[];flyingOrbs=[]
        deaths=0;collectedLives=0;trainingHits=0;trainingBonusLives=0;usedGodMode=godMode;elapsed=0;phase = .playing;forEachPlayer{hero=teamPosition(.zero,slot:activePlayerSlot);invulnerable=2};beginRound()
    }
    func beginRound() {
        defeatPresentations.removeAll(keepingCapacity:true)
        clearTeslaTargets()
        restoreWaitingTeamAtRoundStart()
        emitAudio(.round);treasureRaider=nil;raiderVisited=false;prepareRaidSchedule()
        silverback=nil;silverbackStarted=false;bossArrivalClock=nil;sourceBossDead=false;bossFrameBirths=[:];martyrDamagePending=false;barrels=[];barrelClock=2;barrelDamagePending=false;bulls=[];stampede=nil;roundClock=0;shotClock=0;bossArenaCleared=false
        guard prepareCombatSpawning() else{return}
        prepareStampede()
        prepareElectricHazards()
        arenaExits=[];sideRoomOffer=nil;forEachPlayer{cancelBoost();shotClock=0;clearDeferredPlayerDamage();dashes=max(dashes,fate == .feet ? 3:1);restoreFateBenefits();hero=layout.clamped(hero,clearance:vehicle?.kind == .tank ? 0.65:0.29);heroElevation=flying ? max(3.1,layout.height(hero)+1.2):layout.height(hero);heroFallSpeed=0;repositionCompanions();deployStowedSupport()};announce(loopIndex>0 ? "\(layout.kind.title) · RUNDE \(round) · DURCHGANG \(loopIndex+1)":round==34 ? "RUNDE 34 · WHO CRIED WOLF?":round==30 ? "RUNDE 30 · ABOMINABLE MARTYRS":round==25 ? "RUNDE 25 · FISH IN A BARREL":round==22 ? "RUNDE 22 · DOWNPOUR":round==17 ? "RUNDE 17 · STAMPEDE!":round==13 ? "RUNDE 13 · CREEPY CRAWLERS":"\(layout.kind.title) · RUNDE \(round)")
    }
    func announce(_ text:String) { message=text;messageTime=2.4 }
    func inside(_ p:V2, margin:Double=0.5)->Bool {layout.contains(p,margin:margin)}
    func clamp(_ p:V2)->V2 {layout.clamped(p)}
    func apply(_ kind:PickupKind,at location:V2?=nil,loot:LootAppearance?=nil,gemUnits:Int?=nil) {
        emitAudio(kind == .life ? .life:.pickup)
        switch kind {
        case .treasure,.gem:collectLoot(kind,appearance:loot,gemUnits:gemUnits)
        case .life: grantTeamLife();announce("EXTRA-LEBEN")
        case .dash: dashes=min(9,dashes+1);announce("BOOST +1")
        case .bomb: bombs=min(9,bombs+1);announce("BOMBE +1")
        case .spread,.ray,.rocket,.deathMachine,.grenade,.flamethrower:
            if kind == .deathMachine && fate == .firepower {announce("FEUERKRAFT BLEIBT AKTIV");break}
            weapon=kind;weaponReserve=50*pickupDurationFactor;shotClock=0
            for i in chickens.indices {chickens[i].shotClock=0}
            announce(WeaponProfile.forPickup(kind).title)
        case .teddy:teddyRemaining=20*pickupDurationFactor;announce("TEDDY · GEGNER ZURÜCKDRÄNGEN")
        case .barrelShield:grantBarrelShield();announce("FASS-SCHUTZ")
        case .monkey:addMonkey(at:location ?? hero);announce("AFFENBOMBE")
        case .turret:addSentry(at:location ?? hero);announce("SELBSTSCHUSSANLAGE")
        case .tank:beginVehicle(.tank)
        case .helicopter:beginVehicle(.helicopter)
        case .orb: grantOrbs(duration:40*pickupDurationFactor);announce("ELEKTRO-SCHUTZ")
        case .chicken: addChicken(duration:40*((effectiveFate == .fortitude || effectiveFate == .friendship) ? 2:1));announce("VERSTÄRKUNG")
        case .boots: if fate != .feet {boots=10*pickupDurationFactor};announce("TEMPO-BOOST")
        }
    }
    func loseLife(allowAfterRound:Bool=false) {
        guard (phase == .playing || (allowAfterRound && phase == .cleared)), isPlayerActive,vehicle==nil,!damageProtected else{return}
        emitAudio(.hurt);clearPlayerWounds()
        if godMode {
            trainingHits+=1;usedGodMode=true;invulnerable=3
            effects.append(Effect(id:id(),p:hero,ttl:0.6,size:1.4,color:1))
            announce("−1 VIRTUELLES LEBEN · GODMODE")
            return
        }
        playerRoster.current.tesla.cancelPlanning()
        spillLostMultiplier(at:hero)
        playerRoster.current.bodyShield=nil;playerRoster.current.shieldContactThisStep=false
        clearCarriedSupport();deaths += 1;multiplier=fate == .fortitude ? 2:1;multiplierCharge=0;flameJets.removeAll{$0.ownerSlot==activePlayerSlot};weapon=nil;weaponReserve=0;orb=0;chicken=0;boots=0
        effects.append(Effect(id:id(),p:hero,ttl:0.6,size:1.4,color:1))
        // The HUD counts spare lives: zero still leaves the current body playable.
        playerRoster.current.isDown=true
        if lives>0 || playerRoster.current.sponsoredRespawn {queueReserveRespawn();announce("RÜCKKEHR IN 2 S");return}
        lives=0;startUnfundedRecovery()
        if !hasRecoverablePlayer {finishTeamRun()}
        else {announce("SPIELER \(activePlayerSlot+1) · WIEDERKEHR IN 60 S")}
    }
    func kill(_ foe:Foe, drops:Bool=true,canDamageHero:Bool=true) {
        if defeatPresentations.count==DefeatedBodyMotion.eventLimit {defeatPresentations.removeFirst()}
        defeatPresentations.append(DefeatPresentation(id:foe.id,position:foe.p,elevation:foe.elevation,launched:foe.launchedByContact))
        let slot=foe.creditSlot.flatMap{players.indices.contains($0) ? $0:nil} ?? activePlayerSlot
        withPlayer(slot){killCredited(foe,drops:drops,canDamageHero:canDamageHero)}
    }
    private func killCredited(_ foe:Foe,drops:Bool,canDamageHero:Bool) {
        if foe.kind == .hound {effects.append(Effect(id:id(),p:foe.p,ttl:0.28,size:0.9,color:5,height:foe.elevation+0.25))}
        if foe.kind == .martyr {detonateMartyr(foe,canDamageHero:canDamageHero)}
        if !foe.environmentKill {award(ScoreRules.ordinaryKill*multiplier*foe.scoreFactor)};effects.append(Effect(id:id(),p:foe.p,ttl:0.35,size:0.55,color:0))
        // Ordinary equipment/treasure is supplied by independent source threads.
        // Martyr deaths and lost personal multiplier gems keep their explicit special paths.

    }
    func step(_ dt:Double,input:Controls) {step(dt,inputs:[input])}
    func step(_ dt:Double, inputs:[Controls]) {
        guard dt.isFinite,dt>=0 else{return}
        let input=systemControls(inputs)
        if phase == .gameOver,gameOverSequence?.finished==false {
            stepRetiringOrbs(dt)
            gameOverSequence?.step(dt,input:input);return
        }
        if input.systemPause {if phase == .playing || phase == .cleared || phase == .bonusRoom || phase == .loopReturn || phase == .transition {prePause=phase;phase = .paused};return}
        if input.pause, phase == .playing || phase == .cleared || phase == .bonusRoom || phase == .loopReturn || phase == .transition { prePause=phase;phase = .paused;return }
        if input.accept || input.pause {
            if phase == .title || phase == .gameOver || phase == .checkpointComplete {reset();return}
            if phase == .paused {phase=prePause;return}
        }
        if phase == .cleared,bossVictory != nil,!advancingBossVictory {stepBossVictory(dt,inputs:inputs);return}
        if phase == .transition {stepArenaTransit(dt);return}
        if phase == .loopReturn {stepLoopReturn(dt);return}
        if phase == .bonusRoom {stepSideRoom(dt,inputs:inputs);return}
        guard phase == .playing || phase == .cleared else{return}
        collectingPlayerDamage=true;defer{collectingPlayerDamage=false}
        elapsed+=dt;messageTime=max(0,messageTime-dt)
        forEachPlayer{playerRoster.current.boostStepDuration=0}
        var before=players.map(\.hero);let beforeHeights=players.map(\.heroElevation)
        forEachLivingPlayer {
            invulnerable=max(0,invulnerable-dt);stepVehicleClock(dt);boots=max(0,boots-dt)
            stepPlayerWoundRecovery(dt)
            before[activePlayerSlot]=hero
        }
        stepTeamRecovery(dt)
        if phase == .gameOver {return}
        effects=effects.compactMap{var e=$0;e.ttl-=dt;return e.ttl>0 ? e:nil}
        forEachLivingPlayer {moveCombatPlayer(dt,input:controls(for:activePlayerSlot,in:inputs))}
        if phase == .cleared {
            clearClock+=dt
            if tryTeamExit() {stepWorldLoot(dt);stepRareLifeTimer(dt);return}
        }
        let combatWindows=stepGameplaySpawns(dt);stepRetiringCombatSpawns(dt)
        stepRareLifeTimer(dt,activeWindows:combatWindows)
        forEachLivingPlayer {fireCombatPlayer(dt,input:controls(for:activePlayerSlot,in:inputs))}
        stepBurning(dt,at:elapsed)
        stepTesla(dt,at:elapsed)
        forEachPlayer {stepSupportPowers(dt);updateSupportNavigation(dt)}
        forEachLivingPlayer {navigation.update(layout:layout,target:hero,dt:dt)}
        let foeStarts=Dictionary(uniqueKeysWithValues:foes.map{($0.id,($0.p,$0.elevation))})
        stepCombatFoes(dt)
        forEachLivingPlayer {crushWithTank(from:before[activePlayerSlot],dt)}
        stepBarrels(dt);stepStampede(dt);stepSilverback(dt)
        if phase == .gameOver {return}
        forEachLivingPlayer {
            resolveShieldBarrelHits(dt);resolveOrbHits()
            resolveSilverbackContact()
            if isPlayerActive,!damageProtected {
                let touching=foes.filter{$0.hp>0 && ($0.p-hero).length<$0.contactRadius && abs($0.elevation-heroElevation)<0.65}
                if touching.contains(where:{$0.kind != .hound}),ordinaryContactAllowed {loseLife()}
                else if touching.contains(where:{$0.kind == .hound}) {houndHit()}
            }
        }
        if phase == .gameOver {return}
        stepElectricHazards(dt,from:before,heights:beforeHeights,foeStarts:foeStarts)
        if phase == .gameOver {return}
        stepWeaponShots(dt)
        if phase == .gameOver {return}
        resolveDefeatedFoes();resolveDeferredBlasts()
        if phase == .gameOver {return}
        shots.removeAll{$0.ttl<=0};stepWorldLoot(dt,activeWindows:combatWindows)
        forEachLivingPlayer {collectNearbyPickups()}
        collectDirectedRewards()
        stepTreasureRaider(dt)
        if phase == .gameOver {return}
        if phase == .playing && combatSpawnFlow?.takeDeathCheck()==true && foes.isEmpty && barrels.isEmpty {
            if bossRound {if !silverbackStarted {beginSilverbackEncounter()}else{clearSourceBossRoundIfReady()}}
            else {if stampede?.mode == .challenge {stampede?.stop()};phase = .cleared;clearClock=0;seedClearedTreasure();cleanupSourceRoundVehicles();prepareArenaExits();announce("RUNDE \(round) GESCHAFFT · WÄHLE EINEN WEG")}
        }
    }
}
