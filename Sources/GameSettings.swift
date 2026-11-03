import Foundation

enum CameraMode:String,Codable,CaseIterable {
    case following, overview
    var title:String {self == .following ? "Mitführend":"Feste Übersicht"}
}
enum CameraZoom:Int,Codable,CaseIterable {
    case close, normal, wide
    var title:String {self == .close ? "Nah":self == .normal ? "Normal":"Weit"}
    var factor:Double {self == .close ? 0.86:self == .normal ? 1:1.22}
}
enum PlayerColor:String,Codable,CaseIterable {
    case green,blue,orange,pink,white
    var title:String {switch self {case .green:return "Grün";case .blue:return "Blau";case .orange:return "Orange";case .pink:return "Pink";case .white:return "Weiß"}}
    var tint:Int {switch self {case .green:return 0xb7e676;case .blue:return 0x78c8ff;case .orange:return 0xffb363;case .pink:return 0xf3a1df;case .white:return 0xe9f4ff}}
}
struct GameSettings:Codable,Equatable {
    var godMode=false
    // Diagnostic framing overrides only; the player always gets the automatic standard camera.
    // These are deliberately absent from saved preferences and from the settings menu.
    var cameraMode:CameraMode = .following
    var zoom:CameraZoom = .normal
    var brighter=false
    var soundEnabled=true
    var effectsVolume=80,musicVolume=60
    var playerColor:PlayerColor = .green
    var playerTwoColor:PlayerColor = .blue,playerThreeColor:PlayerColor = .orange,playerFourColor:PlayerColor = .pink
    init() {}
    enum CodingKeys:String,CodingKey {case godMode,brighter,soundEnabled,playerColor,effectsVolume,musicVolume,playerTwoColor,playerThreeColor,playerFourColor}
    init(from decoder:Decoder)throws {
        let c=try decoder.container(keyedBy:CodingKeys.self)
        godMode=(try? c.decodeIfPresent(Bool.self,forKey:.godMode)) ?? false
        brighter=(try? c.decodeIfPresent(Bool.self,forKey:.brighter)) ?? false
        soundEnabled=(try? c.decodeIfPresent(Bool.self,forKey:.soundEnabled)) ?? true
        effectsVolume=max(0,min(100,(try? c.decodeIfPresent(Int.self,forKey:.effectsVolume)) ?? 80))
        musicVolume=max(0,min(100,(try? c.decodeIfPresent(Int.self,forKey:.musicVolume)) ?? 60))
        playerColor=(try? c.decodeIfPresent(PlayerColor.self,forKey:.playerColor)) ?? .green
        playerTwoColor=(try? c.decodeIfPresent(PlayerColor.self,forKey:.playerTwoColor)) ?? .blue
        playerThreeColor=(try? c.decodeIfPresent(PlayerColor.self,forKey:.playerThreeColor)) ?? .orange
        playerFourColor=(try? c.decodeIfPresent(PlayerColor.self,forKey:.playerFourColor)) ?? .pink
    }
    var teamColors:[PlayerColor] {
        var used=[PlayerColor]()
        for preferred in [playerColor,playerTwoColor,playerThreeColor,playerFourColor] {
            used.append(used.contains(preferred) ? PlayerColor.allCases.first(where:{!used.contains($0)})!:preferred)
        }
        return used
    }
    func color(for slot:Int)->PlayerColor {teamColors[max(0,min(3,slot))]}
    mutating func adjustColor(slot:Int,delta:Int) {
        guard (0..<4).contains(slot) else{return}
        var colors=teamColors;let old=colors[slot],all=PlayerColor.allCases
        let index=all.firstIndex(of:old)!,choice=all[(index+(delta<0 ? all.count-1:1))%all.count]
        if let other=colors.firstIndex(of:choice) {colors[other]=old}
        colors[slot]=choice
        playerColor=colors[0];playerTwoColor=colors[1];playerThreeColor=colors[2];playerFourColor=colors[3]
    }
    static let key="local.nick.arcade.settings.v1"
    static func decode(_ data:Data?)->GameSettings {
        guard let data,let settings=try? JSONDecoder().decode(GameSettings.self,from:data) else{return GameSettings()}
        return settings
    }
    static func load(_ defaults:UserDefaults?)->GameSettings {decode(defaults?.data(forKey:key))}
    func save(_ defaults:UserDefaults?) {if let data=try? JSONEncoder().encode(self){defaults?.set(data,forKey:Self.key)}}
    mutating func adjustAudio(row:Int,delta:Int) {
        let step=delta<0 ? -20:20
        if row==0 {soundEnabled.toggle()}
        if row==1 {effectsVolume=max(0,min(100,effectsVolume+step))}
        if row==2 {musicVolume=max(0,min(100,musicVolume+step))}
    }
    mutating func adjust(row:Int,delta:Int) {
        func next<T:Equatable>(_ values:[T],_ current:T)->T {
            let index=values.firstIndex(of:current) ?? 0
            return values[(index+(delta<0 ? values.count-1:1))%values.count]
        }
        switch row {
        case 0:godMode.toggle()
        case 1:brighter.toggle()
        case 3:playerColor=next(PlayerColor.allCases,playerColor)
        default:break
        }
    }
}

/// A closer, damped tracking view. These values approximate the supplied video, not original engine constants.
struct CameraRig {
    private(set) var center=V2.zero
    private var zoomEnvelope=CameraZoomEnvelope()
    var scale:Double {zoomEnvelope.scale}
    private var lastHero=V2.zero, initialized=false
    private var lastOrientation:ArenaViewOrientation = .normal
    mutating func update(hero:V2,settings:GameSettings,aspect:Double,dt:Double,snap:Bool=false,movement:V2 = .zero,subject:CameraSubject?=nil,elevation:Double=0,orientation:ArenaViewOrientation = .normal) {
        guard hero.x.isFinite,hero.y.isFinite,elevation.isFinite else{return}
        let aspect=GameCameraProjection.aspect(aspect),dt=dt.isFinite ? max(0,dt):0
        let follows=settings.cameraMode == .following
        let teleport=(hero-lastHero).length>4
        let lead=initialized && !snap && !teleport && movement.x.isFinite && movement.y.isFinite ? movement.unit*min(0.28,movement.length*0.065):.zero
        let target=follows ? hero*GameCameraProjection.followFraction+lead:.zero
        let aspectCompensation=max(1,(16.0/9)/max(0.5,aspect))
        let targetScale=(follows ? GameCameraProjection.followingScale:GameCameraProjection.overviewScale)*settings.zoom.factor*aspectCompensation
        let snapZoom = !initialized || snap || teleport || orientation != lastOrientation
        if snapZoom {center=target;initialized=true}
        else {
            let blend=1-exp(-6*max(0,dt))
            center=center+(target-center)*blend
        }
        lastHero=hero
        lastOrientation=orientation
        var requiredScale=targetScale
        if let subject {
            let fit=min(1,GameCameraProjection.aspect(aspect)/(16.0/9))
            requiredScale=max(requiredScale,GameCameraProjection.requiredScale([subject],center:center,elevation:elevation,aspect:aspect,top:0.56*fit,bottom:0.64*fit,orientation:orientation))
        }
        zoomEnvelope.update(requiredScale:requiredScale,dt:dt,snap:snapZoom)
    }
}

enum MenuAction:Equatable {case none, start, resume, startTeam(Int,Bool),teamColor(Int,Int),setting(Int,Int),audioSetting(Int,Int),musicTrack(Int)}
struct GameMenu {
    private(set) var settingsOpen=false,audioOpen=false,teamOpen=false
    private(set) var teamCount=2,teamKeyboard=false,teamAllowsKeyboard=false
    private(set) var selected=0
    private var lastPhase:RunPhase?
    func visible(_ phase:RunPhase)->Bool {phase == .title || phase == .paused || phase == .gameOver || phase == .checkpointComplete}
    var teamColorStart:Int {teamAllowsKeyboard ? 3:2}
    var teamBackRow:Int {teamColorStart+teamCount}
    static let soundRow=2,settingsBackRow=4
    var count:Int {teamOpen ? teamBackRow+1:audioOpen ? 5:settingsOpen ? 5:lastPhase == .paused ? 2:3}
    mutating func sync(_ phase:RunPhase) {
        if lastPhase != phase {selected=0;settingsOpen=false;audioOpen=false;teamOpen=false;lastPhase=phase}
    }
    mutating func openSettings(phase:RunPhase) {sync(phase);settingsOpen=true;audioOpen=false;teamOpen=false;selected=0}
    mutating func handle(_ supplied:Controls,phase:RunPhase,allowKeyboard:Bool=false,availableControllers:Int=0)->MenuAction {
        sync(phase)
        guard visible(phase) else{return .none}
        var input=supplied
        if let point=input.menuPoint {
            let spacing=teamOpen ? 42.0:50.0
            guard point.x.isFinite,point.y.isFinite,(260...1020).contains(point.x),
                  let row=(0..<count).first(where:{abs(point.y-(452-Double($0)*spacing))<=(teamOpen ? 20:24)}) else{return .none}
            input.menuRow=row;input.accept=true
        }
        if input.openSettings {openSettings(phase:phase);return .none}
        if input.back || input.pause {
            if teamOpen {teamOpen=false;selected=2;return .none}
            if audioOpen {audioOpen=false;selected=Self.soundRow;return .none}
            if settingsOpen {settingsOpen=false;selected=1;return .none}
            if phase == .paused {return .resume}
        }
        if input.menuY != 0 {selected=(selected+input.menuY+count)%count}
        if let row=input.menuRow {guard row>=0 && row<count else{return .none};selected=row}
        if teamOpen {
            let delta=input.menuX<0 ? -1:1
            if selected==teamBackRow && input.accept {teamOpen=false;selected=2;return .none}
            if selected==0 && input.accept {return .startTeam(teamCount,teamKeyboard)}
            if input.accept || input.menuX != 0 {
                if selected==1 {teamCount=2+(teamCount-2+(delta<0 ? 2:1))%3;selected=min(selected,count-1)}
                else if teamAllowsKeyboard && selected==2 {teamKeyboard.toggle()}
                else if (teamColorStart..<teamBackRow).contains(selected) {return .teamColor(selected-teamColorStart,delta)}
            }
        }else if audioOpen {
            if selected==4 && input.accept {audioOpen=false;selected=Self.soundRow;return .none}
            if input.accept || input.menuX != 0 {
                if selected==3 {return .musicTrack(input.menuX<0 ? -1:1)}
                if selected<3 {return .audioSetting(selected,input.menuX<0 ? -1:1)}
            }
        }else if settingsOpen {
            if selected==Self.soundRow {if input.accept {audioOpen=true;selected=0};return .none}
            if selected==Self.settingsBackRow && input.accept {settingsOpen=false;selected=1;return .none}
            if selected<Self.settingsBackRow && (input.accept || input.menuX != 0) {return .setting(selected,input.menuX<0 ? -1:1)}
        } else if input.accept {
            if selected==1 {settingsOpen=true;selected=0;return .none}
            if selected==2 {
                teamAllowsKeyboard=allowKeyboard;teamKeyboard=allowKeyboard && availableControllers<2
                teamCount=2;teamOpen=true;selected=0;return .none
            }
            return phase == .paused ? .resume:.start
        }
        return .none
    }
}
