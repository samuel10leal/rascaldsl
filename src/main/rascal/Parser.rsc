module Parser
import Syntax;
import AST;
import ParseTree;
import Node;
import String;

public start[Program] parseProgram(loc l) = parse(#start[Program], l);
public start[Program] parseProgram(str s, loc src) = parse(#start[Program], s, src);

public P implodeProgram(Tree cst) {
  list[Top] tops = [];
  // Módulos (func y data)
  for (/ (Module) ` <FuncDef f> ` := cst) tops += tFunc(implodeFunc(f));
  for (/ (Module) ` <DataDef d> ` := cst) tops += tData(implodeData(d));
  // Sentencias sueltas
  for (/ (Stmt) s := cst) tops += tStmt(implodeStmt(s));
  return program(tops);
}

private Func implodeFunc((FuncDef) ` <FuncHeader h> <Block b> end <Identifier n> `) {
  str name = "<n>";
  list[str] ps = [];
  if (/ (Params) ` <ParamList pl> ` := h) {
    for (/ (Identifier) id := pl) ps += "<id>";
  }
  list[Stmt] body = implodeBlock(b);
  return func(name, ps, body);
}

private Data implodeData((DataDef) ` <Identifier n> = data with <OpList ops> <nl> <{FuncDef} fdefs> end <Identifier _> `) {
  list[FieldDecl] fields = [];
  for (/ (OpName) ` <Identifier id> : <Type ty> ` := ops) {
    fields += field("<id>", implodeType(ty));
  }
  list[Func] methods = [ implodeFunc(f) | f <- fdefs ];
  return dataDef("<n>", fields, methods);
}

private list[Stmt] implodeBlock((Block) ` do <nl> <{Stmt} ss> end `)
  = [ implodeStmt(s) | s <- ss ];

public Stmt implodeStmt(Stmt s) {
  if (/ (Stmt) ` <DeclVars d> <nl> ` := s) {
    return sDecl(implodeType(d.ty), implodeVarList(d.vars));
  }

  if (/ (Stmt) ` <Assign a> <nl> ` := s)
    return sAssign(implodeLV(a.lv), implodeExpr(a.e));

  if (/ (Stmt) ` for <Identifier v> <Range r> <Block b> ` := s) {
    return sForInRange("<v>", implodeExpr(r.arg[0]), implodeExpr(r.arg[1]), implodeBlock(b));
  }

  if (/ (Stmt) ` <IfExpr i> <nl> ` := s)
    return sIf(implodeExpr(i.arg[0]), implodeExpr(i.arg[1]), implodeExpr(i.arg[2]));

  if (/ (Stmt) ` <CondExpr c> <nl> ` := s)
    return sExpr(implodeCond(c));

  if (/ (Stmt) ` <Expr e> <nl> ` := s)
    return sExpr(implodeExpr(e));

  return sExpr(eLit(VNull()));
}

private LV implodeLV(LValue lv) {
  if (/ (LValue) ` <Identifier i> ` := lv) return lvId("<i>");
  if (/ (LValue) ` <LValue base> . <Identifier f> ` := lv) return lvField(implodeLV(base), "<f>");
  if (/ (LValue) ` <LValue base> $ <Identifier f> ` := lv) return lvDollar(implodeLV(base), "<f>");
  return lvId("?");
}

public Exp implodeExpr(Expr e) {
  // Literales
  if (/ (Literal) ` <Number n> ` := e)   return eLit(VNum(toReal("<n>")));
  if (/ (Literal) ` <Boolean b> ` := e)  return eLit(VBool("<b>" == "true"));
  if (/ (Literal) ` <Char c> ` := e)     return eLit(VChar(stripDelimiters("<c>")));
  if (/ (Literal) ` <String s> ` := e)   return eLit(VStr(stripDelimiters("<s>")));

  // Primarios
  if (/ (Expr) ` <Identifier i> ` := e)  return eVar("<i>");
  if (/ (Expr) ` ( <Expr x> ) ` := e)    return implodeExpr(x);
  if (/ (TupleLit) ` tuple ( <Expr a> , <Expr b> ) ` := e)
    return eTuple(implodeExpr(a), implodeExpr(b));
  if (/ (SequenceLit) ` sequence ( <{Expr} xs> ) ` := e)
    return eSeq([ implodeExpr(x) | x <- xs ]);
  if (/ (StructLit) ` struct <Identifier t> ( <StructFields fs> ) ` := e) {
    map[str, Exp] fields = ();
    for (/ (StructField) ` <Identifier f> : <Expr ex> ` := fs) {
      fields += ("<f>" : implodeExpr(ex));
    }
    return eStruct("<t>", fields);
  }

  // LValue lectura
  if (/ (Expr) ` <LValue lv> ` := e)     return eGet(implodeLV(lv));

  // Unarios
  if (/ (Expr) ` - <UnaryExpr u> ` := e)   return eUnary("-", implodeExpr(u));
  if (/ (Expr) ` neg <UnaryExpr u> ` := e) return eUnary("neg", implodeExpr(u));

  // Binarios (orden aproximado)
  if (/ (Expr) ` <Expr l> +  <Expr r> ` := e) return eBin(implodeExpr(l), "+",  implodeExpr(r));
  if (/ (Expr) ` <Expr l> -  <Expr r> ` := e) return eBin(implodeExpr(l), "-",  implodeExpr(r));
  if (/ (Expr) ` <Expr l> *  <Expr r> ` := e) return eBin(implodeExpr(l), "*",  implodeExpr(r));
  if (/ (Expr) ` <Expr l> /  <Expr r> ` := e) return eBin(implodeExpr(l), "/",  implodeExpr(r));
  if (/ (Expr) ` <Expr l> %  <Expr r> ` := e) return eBin(implodeExpr(l), "%",  implodeExpr(r));
  if (/ (Expr) ` <Expr l> ** <Expr r> ` := e) return eBin(implodeExpr(l), "**", implodeExpr(r));

  if (/ (Expr) ` <Expr l> <  <Expr r> ` := e) return eBin(implodeExpr(l), "<",  implodeExpr(r));
  if (/ (Expr) ` <Expr l> >  <Expr r> ` := e) return eBin(implodeExpr(l), ">",  implodeExpr(r));
  if (/ (Expr) ` <Expr l> <= <Expr r> ` := e) return eBin(implodeExpr(l), "<=", implodeExpr(r));
  if (/ (Expr) ` <Expr l> >= <Expr r> ` := e) return eBin(implodeExpr(l), ">=", implodeExpr(r));
  if (/ (Expr) ` <Expr l> <> <Expr r> ` := e) return eBin(implodeExpr(l), "<>", implodeExpr(r));
  if (/ (Expr) ` <Expr l> and <Expr r> ` := e) return eBin(implodeExpr(l), "and", implodeExpr(r));
  if (/ (Expr) ` <Expr l> or  <Expr r> ` := e) return eBin(implodeExpr(l), "or",  implodeExpr(r));

  // Llamada simple: id(args)
  if (/ (Call) ` <PrimaryNoCall t> ( <[ArgList]> ) ` := e) {
    if (/ (Identifier) id := t) {
      list[Exp] args = [];
      if (/ (ArgList) al := e) 
        for (/ (Expr) ex := al) 
          args += implodeExpr(ex);
      return eCall("<id>", args);
    }
  }

  return eLit(VNull());
}

private Exp implodeCond(CondExpr c) {
  // Reducción simple del 'cond': ((X and a1)?b1 : ((X and a2)?b2 : ...))
  list[<Exp,Exp>] pairs = [];
  for (/ (CondClause) ` <Expr a> -> <Expr b> ` := c) 
    pairs += <implodeExpr(a), implodeExpr(b)>;

  if (size(pairs) == 0) 
    return eLit(VNull());

  Exp guard = implodeExpr(c.arg[0]);
  Exp acc = eLit(VNull());
  for (int i <- [size(pairs)-1 .. 0]) {
    <Exp pa, Exp pb> = pairs[i];
    acc = eBin(eBin(guard, "and", pa), "?", pb); // '?' entendido por el evaluador
  }
  return acc;
}

private list[str] implodeVarList(VarList vars)
  = [ "<id>" | / (Identifier) id := vars ];

private TypeAnn implodeType(Type t) {
  if (/ (Type) ` Int ` := t)    return tNumber();
  if (/ (Type) ` Bool ` := t)   return tBool();
  if (/ (Type) ` Char ` := t)   return tChar();
  if (/ (Type) ` String ` := t) return tString();
  if (/ (Type) ` sequence < <Type el> > ` := t)
    return tSequence(implodeType(el));
  if (/ (Type) ` tuple ( <Type l> , <Type r> ) ` := t)
    return tTuple(implodeType(l), implodeType(r));
  if (/ (Type) ` <Identifier id> ` := t)
    return tStruct("<id>");
  return tUnknown("<t>");
}

private str stripDelimiters(str raw) = substring(raw, 1, size(raw) - 1);
