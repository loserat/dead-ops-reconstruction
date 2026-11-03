import SceneKit
import simd

// The existing articulated model uses one immutable mesh and seven independent joints per enemy.
struct EnemySkinGeometry {
    let geometry:SCNGeometry,weights:SCNGeometrySource,indices:SCNGeometrySource
    let inverseBind:[NSValue]
    let inputVertices:Int,inputTriangles:Int
    static func bones(_ model:SCNNode)->[SCNNode]{
        let spine=model.childNode(withName:"human-spine",recursively:false)!
        let left=model.childNode(withName:"leftLeg",recursively:false)!
        let right=model.childNode(withName:"rightLeg",recursively:false)!
        return [spine,left,left.childNode(withName:"human-knee",recursively:false)!,
                right,right.childNode(withName:"human-knee",recursively:false)!,
                spine.childNode(withName:"player-arm-left",recursively:false)!,
                spine.childNode(withName:"player-arm-right",recursively:false)!]
    }
    init(model:SCNNode){
        let bones=Self.bones(model),rootInverse=simd_inverse(model.simdWorldTransform)
        inverseBind=bones.map{NSValue(scnMatrix4:SCNMatrix4(simd_inverse(rootInverse * $0.simdWorldTransform)))}
        let boneMap=Dictionary(uniqueKeysWithValues:bones.enumerated().map{(ObjectIdentifier($0.element),$0.offset)})
        var vertices=[SCNVector3](),normals=[SCNVector3](),uv=[CGPoint](),boneIndex=[UInt16]()
        var materials=[SCNMaterial](),triangles=[[UInt32]](),materialSlots=[ObjectIdentifier:Int]()
        var totalTriangles=0
        SCNTransaction.flush()
        model.enumerateChildNodes{node,_ in
            guard let original=node.geometry else{return}
            var ancestor:SCNNode?=node,bone:Int?
            while let candidate=ancestor {
                if let found=boneMap[ObjectIdentifier(candidate)]{bone=found;break}
                ancestor=candidate.parent
            }
            precondition(bone != nil,"Every visible enemy part must have an existing animated bone")
            let positions=original.sources(for:.vertex).first!
            let normal=original.sources(for:.normal).first!
            let texture=original.sources(for:.texcoord).first
            precondition(positions.vectorCount>0 && normal.vectorCount==positions.vectorCount)
            func value(_ attr:SCNGeometrySource,_ vertex:Int,_ component:Int)->Float{
                precondition(attr.usesFloatComponents)
                let offset=attr.dataOffset+vertex*attr.dataStride+component*attr.bytesPerComponent
                return attr.data.withUnsafeBytes{bytes in
                    if attr.bytesPerComponent==4{return bytes.loadUnaligned(fromByteOffset:offset,as:Float.self)}
                    precondition(attr.bytesPerComponent==8)
                    return Float(bytes.loadUnaligned(fromByteOffset:offset,as:Double.self))
                }
            }
            let transform=rootInverse * node.simdWorldTransform
            let normalTransform=simd_transpose(simd_inverse(simd_float3x3(
                SIMD3(transform.columns.0.x,transform.columns.0.y,transform.columns.0.z),
                SIMD3(transform.columns.1.x,transform.columns.1.y,transform.columns.1.z),
                SIMD3(transform.columns.2.x,transform.columns.2.y,transform.columns.2.z))))
            let offset=UInt32(vertices.count)
            for i in 0..<positions.vectorCount{
                let p=transform * SIMD4<Float>(value(positions,i,0),value(positions,i,1),value(positions,i,2),1)
                let n=normalTransform * SIMD3<Float>(value(normal,i,0),value(normal,i,1),value(normal,i,2))
                vertices.append(SCNVector3(p.x,p.y,p.z));normals.append(SCNVector3(n.x,n.y,n.z))
                uv.append(texture.map{CGPoint(x:Double(value($0,i,0)),y:Double(value($0,i,1)))} ?? .zero)
                boneIndex.append(UInt16(bone!))
            }
            for (elementIndex,element) in original.elements.enumerated(){
                precondition(element.primitiveType == .triangles,"Preserve triangle winding explicitly")
                let material=original.materials[elementIndex % original.materials.count]
                let key=ObjectIdentifier(material),slot:Int
                if let existing=materialSlots[key]{slot=existing}
                else{slot=materials.count;materialSlots[key]=slot;materials.append(material);triangles.append([])}
                let count=element.primitiveCount*3
                element.data.withUnsafeBytes{bytes in
                    for i in 0..<count{
                        let index:UInt32
                        switch element.bytesPerIndex{
                        case 1:index=UInt32(bytes.loadUnaligned(fromByteOffset:i,as:UInt8.self))
                        case 2:index=UInt32(bytes.loadUnaligned(fromByteOffset:i*2,as:UInt16.self))
                        case 4:index=bytes.loadUnaligned(fromByteOffset:i*4,as:UInt32.self)
                        default:preconditionFailure("Unsupported index format")
                        }
                        precondition(index<positions.vectorCount);triangles[slot].append(index+offset)
                    }
                }
                totalTriangles+=element.primitiveCount
            }
        }
        inputVertices=vertices.count;inputTriangles=totalTriangles
        let elements=triangles.map{values->SCNGeometryElement in
            let data=values.withUnsafeBytes{Data($0)}
            return SCNGeometryElement(data:data,primitiveType:.triangles,primitiveCount:values.count/3,bytesPerIndex:4)
        }
        geometry=SCNGeometry(sources:[SCNGeometrySource(vertices:vertices),SCNGeometrySource(normals:normals),SCNGeometrySource(textureCoordinates:uv)],elements:elements)
        geometry.materials=materials
        let one=Array(repeating:Float(1),count:vertices.count)
        weights=SCNGeometrySource(data:one.withUnsafeBytes{Data($0)},semantic:.boneWeights,vectorCount:vertices.count,usesFloatComponents:true,componentsPerVector:1,bytesPerComponent:4,dataOffset:0,dataStride:4)
        indices=SCNGeometrySource(data:boneIndex.withUnsafeBytes{Data($0)},semantic:.boneIndices,vectorCount:vertices.count,usesFloatComponents:false,componentsPerVector:1,bytesPerComponent:2,dataOffset:0,dataStride:2)
    }
    func install(on model:SCNNode,replacingRigidBody:Bool=true){
        // Immutable buffers are shared; each instance has its own skinner and named bone nodes.
        model.childNode(withName:"human-skinned-mesh",recursively:false)?.removeFromParentNode()
        if replacingRigidBody{model.enumerateChildNodes{node,_ in node.geometry=nil}}
        let mesh=SCNNode(geometry:geometry);mesh.name="human-skinned-mesh"
        let skin=SCNSkinner(baseGeometry:geometry,bones:Self.bones(model),boneInverseBindTransforms:inverseBind,boneWeights:weights,boneIndices:indices)
        skin.baseGeometryBindTransform=SCNMatrix4Identity;skin.skeleton=model
        mesh.skinner=skin;model.addChildNode(mesh)
    }
}
