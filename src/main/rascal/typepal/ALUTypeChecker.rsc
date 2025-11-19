module typepal::ALUTypeChecker
import AST;
import List;
import Map;
import Set;

public void typeCheck(P program) {
  map[str, map[str, TypeAnn]] structs = collectStructs(program.items);
  map[str, TypeAnn] env = ();
  for (Top top <- program.items) {
    switch (top) {
      case tStmt(Stmt s):
        env = checkStmt(s, env, structs);
      case tFunc(Func f):
        checkFunction(f, structs);
      case tData(Data _):
        ;
    }
  }
}

private map[str, map[str, TypeAnn]] collectStructs(list[Top] items) {
  map[str, map[str, TypeAnn]] defs = ();
  for (Top top <- items) {
    switch (top) {
      case tData(Data d):
        if (d.name in defs) {
          throw "Tipo de datos <d.name> definido múltiples veces";
        }
        map[str, TypeAnn] fields = ();
        for (FieldDecl fd <- d.fields) {
          switch (fd) {
            case field(str fname, TypeAnn fType):
              if (fname in fields) {
                throw "Campo <fname> duplicado en <d.name>";
              }
              fields += (fname : fType);
          }
        }
        defs += (d.name : fields);
    }
  }
  for (<str typeName, map[str, TypeAnn] fieldMap> <- defs) {
    for (<str _, TypeAnn fieldType> <- fieldMap) {
      assertTypeDefined(fieldType, defs);
    }
  }
  return defs;
}

private void checkFunction(Func f, map[str, map[str, TypeAnn]] structs) {
  switch (f) {
    case func(str _, list[str] params, list[Stmt] body):
      map[str, TypeAnn] env = ();
      for (str param <- params) {
        env += (param : tUnknown("param <param>"));
      }
      for (Stmt stmt <- body) {
        env = checkStmt(stmt, env, structs);
      }
  }
}

private map[str, TypeAnn] checkStmt(Stmt s, map[str, TypeAnn] env, map[str, map[str, TypeAnn]] structs) {
  switch (s) {
    case sDecl(TypeAnn typ, list[str] ids):
      assertTypeDefined(typ, structs);
      for (str id <- ids) {
        if (id in env) {
          throw "Variable <id> ya declarada";
        }
        env += (id : typ);
      }
      return env;
    case sAssign(LV lv, Exp e):
      TypeAnn targetType = inferLVType(lv, env, structs);
      TypeAnn valueType = inferExpr(e, env, structs);
      ensureCompatible(valueType, targetType, "asignación");
      return env;
    case sForInRange(str v, Exp fromE, Exp toE, list[Stmt] body):
      ensureNumeric(inferExpr(fromE, env, structs), "'from' del for");
      ensureNumeric(inferExpr(toE, env, structs), "'to' del for");
      map[str, TypeAnn] loopEnv = env + (v : tNumber());
      for (Stmt stmt <- body) {
        loopEnv = checkStmt(stmt, loopEnv, structs);
      }
      return env;
    case sIf(Exp c, Exp th, Exp el):
      ensureBoolean(inferExpr(c, env, structs), "condición del if");
      TypeAnn thenType = inferExpr(th, env, structs);
      TypeAnn elseType = inferExpr(el, env, structs);
      ensureCompatible(thenType, elseType, "ramos del if");
      return env;
    case sExpr(Exp e):
      inferExpr(e, env, structs);
      return env;
  }
}

private TypeAnn inferExpr(Exp e, map[str, TypeAnn] env, map[str, map[str, TypeAnn]] structs) {
  switch (e) {
    case eLit(Value v):
      return inferLiteralType(v);
    case eVar(str name):
      if (!(name in env)) {
        throw "Variable <name> no declarada";
      }
      return env[name];
    case eGet(LV lv):
      return inferLVType(lv, env, structs);
    case eUnary(str op, Exp inner):
      TypeAnn operandType = inferExpr(inner, env, structs);
      if (op == "-") {
        ensureNumeric(operandType, "operador unario -");
        return tNumber();
      }
      if (op == "neg") {
        ensureBoolean(operandType, "operador neg");
        return tBool();
      }
      return tUnknown("unario <op>");
    case eBin(Exp left, BinOp op, Exp right):
      TypeAnn lt = inferExpr(left, env, structs);
      TypeAnn rt = inferExpr(right, env, structs);
      if (op == "+" || op == "-" || op == "*" || op == "/" || op == "%" || op == "**") {
        ensureNumeric(lt, "operador <op>");
        ensureNumeric(rt, "operador <op>");
        return tNumber();
      }
      if (op == "<" || op == ">" || op == "<=" || op == ">=" || op == "<>") {
        ensureNumeric(lt, "comparación <op>");
        ensureNumeric(rt, "comparación <op>");
        return tBool();
      }
      if (op == "and" || op == "or") {
        ensureBoolean(lt, "operador <op>");
        ensureBoolean(rt, "operador <op>");
        return tBool();
      }
      if (op == "?") {
        ensureBoolean(lt, "guardia de '?'.");
        return rt;
      }
      return tUnknown("binario <op>");
    case eTuple(Exp a, Exp b):
      return tTuple(inferExpr(a, env, structs), inferExpr(b, env, structs));
    case eSeq(list[Exp] xs):
      return inferSequence(xs, env, structs);
    case eStruct(str typeName, map[str, Exp] fields):
      return inferStruct(typeName, fields, env, structs);
    case eCall(str name, list[Exp] args):
      return inferCall(name, args, env, structs);
  }
}

private TypeAnn inferLiteralType(Value v) {
  if (VNum?(v)) return tNumber();
  if (VBool?(v)) return tBool();
  if (VChar?(v)) return tChar();
  if (VStr?(v)) return tString();
  if (VNull?(v)) return tNull();
  if (VTuple?(v)) return tTuple(tUnknown("tuple-left"), tUnknown("tuple-right"));
  if (VSeq?(v)) return tSequence(tUnknown("seq"));
  if (VStruct?(v)) return tStruct("anon");
  return tUnknown("literal");
}

private TypeAnn inferSequence(list[Exp] xs, map[str, TypeAnn] env, map[str, map[str, TypeAnn]] structs) {
  if (size(xs) == 0) {
    return tSequence(tUnknown("empty"));
  }
  TypeAnn first = inferExpr(xs[0], env, structs);
  for (int i <- [1 .. size(xs)-1]) {
    TypeAnn current = inferExpr(xs[i], env, structs);
    ensureCompatible(current, first, "elemento <i> de la secuencia");
  }
  return tSequence(first);
}

private TypeAnn inferStruct(str typeName, map[str, Exp] fields, map[str, TypeAnn] env, map[str, map[str, TypeAnn]] structs) {
  if (!(typeName in structs)) {
    throw "Tipo estructurado <typeName> no existe";
  }
  map[str, TypeAnn] expected = structs[typeName];
  set[str] provided = { fieldName | <fieldName, Exp _> <- fields };
  for (str fieldName <- provided) {
    if (!(fieldName in expected)) {
      throw "Campo <fieldName> no definido en <typeName>";
    }
    TypeAnn valueType = inferExpr(fields[fieldName], env, structs);
    ensureCompatible(valueType, expected[fieldName], "campo <fieldName> de <typeName>");
  }
  set[str] requiredFields = { fname | <fname, TypeAnn _> <- expected };
  for (str required <- requiredFields) {
    if (!(required in provided)) {
      throw "Campo obligatorio <required> ausente en <typeName>";
    }
  }
  return tStruct(typeName);
}

private TypeAnn inferCall(str name, list[Exp] args, map[str, TypeAnn] env, map[str, map[str, TypeAnn]] structs) {
  if (name == "print") {
    for (Exp arg <- args) {
      inferExpr(arg, env, structs);
    }
    return tVoid();
  }
  if (name == "len") {
    if (size(args) != 1) {
      throw "len espera exactamente 1 argumento";
    }
    TypeAnn argType = inferExpr(args[0], env, structs);
    if (tSequence?(argType)) {
      return tNumber();
    }
    throw "len solo acepta secuencias";
  }
  for (Exp arg <- args) {
    inferExpr(arg, env, structs);
  }
  return tUnknown("call <name>");
}

private TypeAnn inferLVType(LV lv, map[str, TypeAnn] env, map[str, map[str, TypeAnn]] structs) {
  switch (lv) {
    case lvId(str name):
      if (!(name in env)) {
        throw "Variable <name> no declarada";
      }
      return env[name];
    case lvField(LV base, str field):
      return inferFieldAccess(base, field, env, structs);
    case lvDollar(LV base, str field):
      return inferFieldAccess(base, field, env, structs);
  }
}

private TypeAnn inferFieldAccess(LV base, str field, map[str, TypeAnn] env, map[str, map[str, TypeAnn]] structs) {
  TypeAnn baseType = inferLVType(base, env, structs);
  if (tStruct?(baseType)) {
    str typeName = baseType.name;
    if (!(typeName in structs)) {
      throw "Tipo <typeName> no está definido";
    }
    map[str, TypeAnn] fieldTypes = structs[typeName];
    if (!(field in fieldTypes)) {
      throw "Campo <field> no existe en <typeName>";
    }
    return fieldTypes[field];
  }
  if (tUnknown?(baseType) || tNull?(baseType)) {
    return tUnknown("campo <field>");
  }
  throw "Acceso a campo <field> requiere struct, recibido <describeType(baseType)>";
}

private void ensureNumeric(TypeAnn t, str ctx) {
  if (!isNumeric(t)) {
    throw "Se esperaba numérico en <ctx>, encontrado <describeType(t)>";
  }
}

private void ensureBoolean(TypeAnn t, str ctx) {
  if (!isBoolean(t)) {
    throw "Se esperaba booleano en <ctx>, encontrado <describeType(t)>";
  }
}

private bool isNumeric(TypeAnn t)
  = tNumber?(t) || tUnknown?(t) || tNull?(t);

private bool isBoolean(TypeAnn t)
  = tBool?(t) || tUnknown?(t) || tNull?(t);

private void ensureCompatible(TypeAnn actual, TypeAnn expected, str ctx) {
  if (!typesCompatible(actual, expected)) {
    throw "Tipos incompatibles en <ctx>: esperado <describeType(expected)>, obtenido <describeType(actual)>";
  }
}

private bool typesCompatible(TypeAnn left, TypeAnn right) {
  if (tUnknown?(left) || tUnknown?(right)) return true;
  if (tNull?(left) || tNull?(right)) return true;
  if (tVoid?(left) && tVoid?(right)) return true;
  if (tNumber?(left) && tNumber?(right)) return true;
  if (tBool?(left) && tBool?(right)) return true;
  if (tChar?(left) && tChar?(right)) return true;
  if (tString?(left) && tString?(right)) return true;
  if (tStruct?(left) && tStruct?(right)) return left.name == right.name;
  if (tSequence?(left) && tSequence?(right)) return typesCompatible(left.elem, right.elem);
  if (tTuple?(left) && tTuple?(right))
    return typesCompatible(left.left, right.left) && typesCompatible(left.right, right.right);
  return false;
}

private void assertTypeDefined(TypeAnn t, map[str, map[str, TypeAnn]] structs)
  = assertTypeDefined(t, structs, {});

private void assertTypeDefined(TypeAnn t, map[str, map[str, TypeAnn]] structs, set[str] stack) {
  if (tStruct?(t)) {
    str typeName = t.name;
    if (!(typeName in structs)) {
      throw "Tipo <typeName> no está declarado";
    }
    if (typeName in stack) {
      return;
    }
    set[str] nextStack = stack + {typeName};
    map[str, TypeAnn] fieldTypes = structs[typeName];
    for (<str _, TypeAnn nestedType> <- fieldTypes) {
      assertTypeDefined(nestedType, structs, nextStack);
    }
    return;
  }
  if (tSequence?(t)) {
    assertTypeDefined(t.elem, structs, stack);
    return;
  }
  if (tTuple?(t)) {
    assertTypeDefined(t.left, structs, stack);
    assertTypeDefined(t.right, structs, stack);
  }
}

private str describeType(TypeAnn t) {
  if (tNumber?(t)) return "Int";
  if (tBool?(t)) return "Bool";
  if (tChar?(t)) return "Char";
  if (tString?(t)) return "String";
  if (tVoid?(t)) return "Void";
  if (tNull?(t)) return "Null";
  if (tStruct?(t)) return "Struct <t.name>";
  if (tSequence?(t)) return "Sequence<" + describeType(t.elem) + ">";
  if (tTuple?(t)) return "Tuple(" + describeType(t.left) + ", " + describeType(t.right) + ")";
  if (tUnknown?(t)) return "Unknown";
  return "<?>"; 
}
