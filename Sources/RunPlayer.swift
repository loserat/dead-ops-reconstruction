import Foundation

/// Personal run state. The arena, enemies, projectiles and clocks remain owned once by GameCore.
final class RunPlayer {
    let slot:Int
    let navigation=ArenaNavigation(),silverbackNavigation=ArenaNavigation(clearance:0.9)
    let teddyNavigation=(0..<6).map{_ in ArenaNavigation()}
    var fate:FateKind? = nil
    var fatePending=false
    var missedFate=false
    var dogWounds:Int = 0
    var dogRecoveryClock=0.0
    var barrelWounds=0,martyrWounds=0,barrelRecoveryClock=0.0
    var trainingHits:Int = 0
    var trainingBonusLives:Int = 0
    var lives:Int = 3
    var dashes:Int = 2
    var bombs:Int = 1
    var score:Int = 0
    var multiplier:Int = 1
    var multiplierCharge:Double = 0
    var heroElevation:Double = 0
    var heroFallSpeed:Double = 0
    var hero:V2 = .zero
    var facing:V2 = V2(x:0,y:-1)
    var teddyRemaining:Double = 0
    var shieldBarrelRemaining:Double = 0
    var shieldBarrels:[ShieldBarrel] = []
    var departingShieldBarrels:[DepartingShieldBarrel] = []
    var monkeys:[MonkeyDecoy] = []
    var sentries:[SentryTurret] = []
    var vehicle:VehicleState? = nil
    var weapon:PickupKind? = nil
    var weaponReserve:Double = 0
    var invulnerable:Double = 0
    var dashTime:Double = 0
    var boostDirection=V2.zero,boostStepDuration=0.0
    var bodyShield:BodyShield?,shieldContactThisStep=false
    var boots:Double = 0
    var chickens:[ChickenCompanion] = []
    var orbShields:[OrbShield] = []
    var electricArcs:[ElectricArc] = []
    var flyingOrbs:[FlyingOrb] = []
    var orbRetirement=TeslaOrbRetirement()
    var tesla=TeslaDischarge()
    var orbRemaining:Double = 0
    var pendingMartyrBlast:DeferredBlast = .none,pendingBarrelBlast:DeferredBlast = .none
    var pendingHoundBite=false
    var martyrDamagePending:Bool {get{pendingMartyrBlast != .none}set{pendingMartyrBlast = newValue ? .lethal:.none}}
    var barrelDamagePending:Bool {get{pendingBarrelBlast != .none}set{pendingBarrelBlast = newValue ? .lethal:.none}}
    var shotClock:Double = 0
    var contactClock:Double = 0
    var nextLifeAt:Int = 200_000
    var deaths:Int = 0
    var collectedLives:Int = 0
    var isDown=false,reviveRemaining=0.0,donationCooldown=0.0
    var respawnRemaining:Double?
    var sponsoredRespawn=false
    var hasRecoveryProcess=false,recoveryWatchActive=false,donationSearchActive=false
    var lifeWatchRemaining=RecoveryRules.creditInterval,donationPollRemaining=RecoveryRules.searchInterval
    var recoverySeconds:Double {respawnRemaining ?? reviveRemaining}
    var donationsGiven=0,donationsReceived=0
    init(slot:Int){self.slot=slot}
    func reset(){
        fate = nil
        fatePending=false
        missedFate=false
        dogWounds = 0
        dogRecoveryClock = 0
        barrelWounds=0;martyrWounds=0;barrelRecoveryClock=0
        trainingHits = 0
        trainingBonusLives = 0
        lives = 3
        dashes = 2
        bombs = 1
        score = 0
        multiplier = 1
        multiplierCharge = 0
        heroElevation = 0
        heroFallSpeed = 0
        hero = .zero
        facing = V2(x:0,y:-1)
        teddyRemaining = 0
        shieldBarrelRemaining = 0
        shieldBarrels = []
        departingShieldBarrels = []
        monkeys = []
        sentries = []
        vehicle = nil
        weapon = nil
        weaponReserve = 0
        invulnerable = 0
        dashTime = 0
        boostDirection = .zero;boostStepDuration=0
        bodyShield=nil;shieldContactThisStep=false
        boots = 0
        chickens = []
        orbShields = []
        electricArcs = []
        flyingOrbs = [];orbRetirement=TeslaOrbRetirement()
        orbRemaining = 0
        tesla = TeslaDischarge()
        martyrDamagePending = false
        barrelDamagePending = false
        pendingHoundBite=false
        shotClock = 0
        contactClock = 0
        nextLifeAt = 200_000
        deaths = 0
        collectedLives = 0
        isDown=false;reviveRemaining=0;donationCooldown=0;respawnRemaining=nil;sponsoredRespawn=false
        hasRecoveryProcess=false;recoveryWatchActive=false;donationSearchActive=false
        lifeWatchRemaining=RecoveryRules.creditInterval;donationPollRemaining=RecoveryRules.searchInterval
        donationsGiven=0;donationsReceived=0
    }
}

/// Selection is scoped to one synchronous simulation operation; never shared with the input thread.
final class PlayerRoster {
    private(set) var players=[RunPlayer(slot:0)],selected=0,configuredCount=1
    var current:RunPlayer { @inline(__always) get {players[selected]} }
    func reset(count:Int?=nil){
        if let count {configuredCount=max(1,min(4,count))}
        while players.count>configuredCount {players.removeLast()}
        while players.count<configuredCount {players.append(RunPlayer(slot:players.count))}
        selected=0
        for player in players {player.reset()}
        // Keep navigation caches across attempts, as the previous single-player implementation did.
    }
    @discardableResult
    func withPlayer<T>(_ slot:Int,_ operation:()throws->T)rethrows->T? {
        guard players.indices.contains(slot) else{return nil}
        if selected==slot {return try operation()}
        let previous=selected;selected=slot
        defer{selected=players.indices.contains(previous) ? previous:0}
        return try operation()
    }
}
extension GameCore {
    var players:[RunPlayer] {playerRoster.players}
    var playerCount:Int {playerRoster.players.count}
    var activePlayerSlot:Int {playerRoster.selected}
    @discardableResult
    func withPlayer<T>(_ slot:Int,_ operation:()throws->T)rethrows->T? {try playerRoster.withPlayer(slot,operation)}
    var navigation:ArenaNavigation {playerRoster.current.navigation}
    var silverbackNavigation:ArenaNavigation {playerRoster.current.silverbackNavigation}
    var teddyNavigation:[ArenaNavigation] {playerRoster.current.teddyNavigation}
    func grantTeamLife(){
        guard phase == .playing || phase == .cleared || phase == .bonusRoom || phase == .transition else{return}
        pendingLifeAwards.append(TeamLifeAward());advanceTeamLifeAwards()
    }
    var fate:FateKind? {
        @inline(__always) _read {let player=playerRoster.current;yield player.fate}
        @inline(__always) _modify {let player=playerRoster.current;yield &player.fate}
    }
    var dogWounds:Int {
        @inline(__always) _read {let player=playerRoster.current;yield player.dogWounds}
        @inline(__always) _modify {let player=playerRoster.current;yield &player.dogWounds}
    }
    var trainingHits:Int {
        @inline(__always) _read {let player=playerRoster.current;yield player.trainingHits}
        @inline(__always) _modify {let player=playerRoster.current;yield &player.trainingHits}
    }
    var trainingBonusLives:Int {
        @inline(__always) _read {let player=playerRoster.current;yield player.trainingBonusLives}
        @inline(__always) _modify {let player=playerRoster.current;yield &player.trainingBonusLives}
    }
    var lives:Int {
        @inline(__always) _read {let player=playerRoster.current;yield player.lives}
        @inline(__always) _modify {let player=playerRoster.current;yield &player.lives}
    }
    var dashes:Int {
        @inline(__always) _read {let player=playerRoster.current;yield player.dashes}
        @inline(__always) _modify {let player=playerRoster.current;yield &player.dashes}
    }
    var bombs:Int {
        @inline(__always) _read {let player=playerRoster.current;yield player.bombs}
        @inline(__always) _modify {let player=playerRoster.current;yield &player.bombs}
    }
    var score:Int {
        @inline(__always) _read {let player=playerRoster.current;yield player.score}
        @inline(__always) _modify {let player=playerRoster.current;yield &player.score}
    }
    var multiplier:Int {
        @inline(__always) _read {let player=playerRoster.current;yield player.multiplier}
        @inline(__always) _modify {let player=playerRoster.current;yield &player.multiplier}
    }
    var multiplierCharge:Double {
        @inline(__always) _read {let player=playerRoster.current;yield player.multiplierCharge}
        @inline(__always) _modify {let player=playerRoster.current;yield &player.multiplierCharge}
    }
    var heroElevation:Double {
        @inline(__always) _read {let player=playerRoster.current;yield player.heroElevation}
        @inline(__always) _modify {let player=playerRoster.current;yield &player.heroElevation}
    }
    var heroFallSpeed:Double {
        @inline(__always) _read {let player=playerRoster.current;yield player.heroFallSpeed}
        @inline(__always) _modify {let player=playerRoster.current;yield &player.heroFallSpeed}
    }
    var hero:V2 {
        @inline(__always) _read {let player=playerRoster.current;yield player.hero}
        @inline(__always) _modify {let player=playerRoster.current;yield &player.hero}
    }
    var facing:V2 {
        @inline(__always) _read {let player=playerRoster.current;yield player.facing}
        @inline(__always) _modify {let player=playerRoster.current;yield &player.facing}
    }
    var teddyRemaining:Double {
        @inline(__always) _read {let player=playerRoster.current;yield player.teddyRemaining}
        @inline(__always) _modify {let player=playerRoster.current;yield &player.teddyRemaining}
    }
    var shieldBarrelRemaining:Double {
        @inline(__always) _read {let player=playerRoster.current;yield player.shieldBarrelRemaining}
        @inline(__always) _modify {let player=playerRoster.current;yield &player.shieldBarrelRemaining}
    }
    var shieldBarrels:[ShieldBarrel] {
        @inline(__always) _read {let player=playerRoster.current;yield player.shieldBarrels}
        @inline(__always) _modify {let player=playerRoster.current;yield &player.shieldBarrels}
    }
    var departingShieldBarrels:[DepartingShieldBarrel] {
        @inline(__always) _read {let player=playerRoster.current;yield player.departingShieldBarrels}
        @inline(__always) _modify {let player=playerRoster.current;yield &player.departingShieldBarrels}
    }
    var monkeys:[MonkeyDecoy] {
        @inline(__always) _read {let player=playerRoster.current;yield player.monkeys}
        @inline(__always) _modify {let player=playerRoster.current;yield &player.monkeys}
    }
    var sentries:[SentryTurret] {
        @inline(__always) _read {let player=playerRoster.current;yield player.sentries}
        @inline(__always) _modify {let player=playerRoster.current;yield &player.sentries}
    }
    var vehicle:VehicleState? {
        @inline(__always) _read {let player=playerRoster.current;yield player.vehicle}
        @inline(__always) _modify {let player=playerRoster.current;yield &player.vehicle}
    }
    var weapon:PickupKind? {
        @inline(__always) _read {let player=playerRoster.current;yield player.weapon}
        @inline(__always) _modify {let player=playerRoster.current;yield &player.weapon}
    }
    var weaponReserve:Double {
        @inline(__always) _read {let player=playerRoster.current;yield player.weaponReserve}
        @inline(__always) _modify {let player=playerRoster.current;yield &player.weaponReserve}
    }
    var invulnerable:Double {
        @inline(__always) _read {let player=playerRoster.current;yield player.invulnerable}
        @inline(__always) _modify {let player=playerRoster.current;yield &player.invulnerable}
    }
    var dashTime:Double {
        @inline(__always) _read {let player=playerRoster.current;yield player.dashTime}
        @inline(__always) _modify {let player=playerRoster.current;yield &player.dashTime}
    }
    var boots:Double {
        @inline(__always) _read {let player=playerRoster.current;yield player.boots}
        @inline(__always) _modify {let player=playerRoster.current;yield &player.boots}
    }
    var chickens:[ChickenCompanion] {
        @inline(__always) _read {let player=playerRoster.current;yield player.chickens}
        @inline(__always) _modify {let player=playerRoster.current;yield &player.chickens}
    }
    var orbShields:[OrbShield] {
        @inline(__always) _read {let player=playerRoster.current;yield player.orbShields}
        @inline(__always) _modify {let player=playerRoster.current;yield &player.orbShields}
    }
    var electricArcs:[ElectricArc] {
        @inline(__always) _read {let player=playerRoster.current;yield player.electricArcs}
        @inline(__always) _modify {let player=playerRoster.current;yield &player.electricArcs}
    }
    var flyingOrbs:[FlyingOrb] {
        @inline(__always) _read {let player=playerRoster.current;yield player.flyingOrbs}
        @inline(__always) _modify {let player=playerRoster.current;yield &player.flyingOrbs}
    }
    var orbRemaining:Double {
        @inline(__always) _read {let player=playerRoster.current;yield player.orbRemaining}
        @inline(__always) _modify {let player=playerRoster.current;yield &player.orbRemaining}
    }
    var martyrDamagePending:Bool {
        @inline(__always) _read {let player=playerRoster.current;yield player.martyrDamagePending}
        @inline(__always) _modify {let player=playerRoster.current;yield &player.martyrDamagePending}
    }
    var barrelDamagePending:Bool {
        @inline(__always) _read {let player=playerRoster.current;yield player.barrelDamagePending}
        @inline(__always) _modify {let player=playerRoster.current;yield &player.barrelDamagePending}
    }
    var shotClock:Double {
        @inline(__always) _read {let player=playerRoster.current;yield player.shotClock}
        @inline(__always) _modify {let player=playerRoster.current;yield &player.shotClock}
    }
    var contactClock:Double {
        @inline(__always) _read {let player=playerRoster.current;yield player.contactClock}
        @inline(__always) _modify {let player=playerRoster.current;yield &player.contactClock}
    }
    var nextLifeAt:Int {
        @inline(__always) _read {let player=playerRoster.current;yield player.nextLifeAt}
        @inline(__always) _modify {let player=playerRoster.current;yield &player.nextLifeAt}
    }
    var deaths:Int {
        @inline(__always) _read {let player=playerRoster.current;yield player.deaths}
        @inline(__always) _modify {let player=playerRoster.current;yield &player.deaths}
    }
    var collectedLives:Int {
        @inline(__always) _read {let player=playerRoster.current;yield player.collectedLives}
        @inline(__always) _modify {let player=playerRoster.current;yield &player.collectedLives}
    }
}
