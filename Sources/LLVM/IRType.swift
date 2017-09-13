#if !NO_SWIFTPM
import cllvm
#endif

/// An `IRType` is a type that is capable of lowering itself to an `LLVMTypeRef`
/// object for use with LLVM's C API.
public protocol IRType {
  /// Retrieves the underlying LLVM type object.
  func asLLVM() -> LLVMTypeRef
}

public extension IRType {
  /// Returns the special `null` value for this type.
  public func null() -> IRValue {
    return LLVMConstNull(asLLVM())
  }

  /// Returns the special LLVM `undef` value for this type.
  ///
  /// The `undef` value can be used anywhere a constant is expected, and
  /// indicates that the user of the value may receive an unspecified
  /// bit-pattern.
  public func undef() -> IRValue {
    return LLVMGetUndef(asLLVM())
  }

  /// Returns the special LLVM constant `null` pointer value for this type
  /// initialized to `null`.
  public func constPointerNull() -> IRValue {
    return LLVMConstPointerNull(asLLVM())
  }

  /// Returns the context associated with this type
  public var context: Context {
    return Context(llvm: LLVMGetTypeContext(asLLVM()))
  }
}

internal func convertType(_ type: LLVMTypeRef) -> IRType {
  let context = Context(llvm: LLVMGetTypeContext(type))
  switch LLVMGetTypeKind(type) {
  case LLVMVoidTypeKind: return VoidType(in: context)
  case LLVMFloatTypeKind: return FloatType(kind: .float, in: context)
  case LLVMHalfTypeKind: return FloatType(kind: .half, in: context)
  case LLVMDoubleTypeKind: return FloatType(kind: .double, in: context)
  case LLVMX86_FP80TypeKind: return FloatType(kind: .x86FP80, in: context)
  case LLVMFP128TypeKind: return FloatType(kind: .fp128, in: context)
  case LLVMPPC_FP128TypeKind: return FloatType(kind: .fp128, in: context)
  case LLVMLabelTypeKind: return LabelType(in: context)
  case LLVMIntegerTypeKind:
    let width = LLVMGetIntTypeWidth(type)
    return IntType(width: Int(width), in: context)
  case LLVMFunctionTypeKind:
    var params = [IRType]()
    let count = Int(LLVMCountParamTypes(type))
    let paramsPtr = UnsafeMutablePointer<LLVMTypeRef?>.allocate(capacity: count)
    defer { free(paramsPtr) }
    LLVMGetParamTypes(type, paramsPtr)
    for i in 0..<count {
      let ty = paramsPtr[i]!
      params.append(convertType(ty))
    }
    let ret = convertType(LLVMGetReturnType(type))
    let isVarArg = LLVMIsFunctionVarArg(type) != 0
    return FunctionType(argTypes: params, returnType: ret, isVarArg: isVarArg)
  case LLVMStructTypeKind:
    return StructType(llvm: type)
  case LLVMArrayTypeKind:
    let elementType = convertType(LLVMGetElementType(type))
    let count = Int(LLVMGetArrayLength(type))
    return ArrayType(elementType: elementType, count: count)
  case LLVMPointerTypeKind:
    let pointee = convertType(LLVMGetElementType(type))
    let addressSpace = Int(LLVMGetPointerAddressSpace(type))
    return PointerType(pointee: pointee, addressSpace: addressSpace)
  case LLVMVectorTypeKind:
    let elementType = convertType(LLVMGetElementType(type))
    let count = Int(LLVMGetVectorSize(type))
    return VectorType(elementType: elementType, count: count)
  case LLVMMetadataTypeKind:
    return MetadataType(llvm: type)
  case LLVMX86_MMXTypeKind:
    return X86MMXType(in: context)
  case LLVMTokenTypeKind:
    return TokenType(llvm: type)
  default: fatalError("unknown type kind for type \(type)")
  }
}
