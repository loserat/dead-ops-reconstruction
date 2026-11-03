import Foundation

// Physical source fronts shared by map layouts and timed admissions.
enum EntrySide:Int,CaseIterable {case north,east,south,west
    var opposite:EntrySide {EntrySide(rawValue:(rawValue+2)%4)!}
}
extension ArenaLayout {
    func enemyEntrySide(index:Int)->EntrySide {
        if kind == .island {return [.west,.north,.east,.south,.east,.south][((index%6)+6)%6]}
        if kind == .prison {return [.south,.south,.west,.east,.north,.south][((index%6)+6)%6]}
        return EntrySide(rawValue:((index%4)+4)%4)!
    }
    func entryCrossOffset(side:EntrySide)->Double {kind == .street && side == .west ? -2.5:kind == .urban && side == .east ? -2:0}
    /// Tall bodies use a high catwalk entrance instead of intersecting the low prison underpass.
    func entranceForBody(index:Int,height:Double)->Int {kind == .prison && height>1.45 && index>=2 ? index%2:index}
}
