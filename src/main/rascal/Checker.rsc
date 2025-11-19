module Checker

import Syntax;
import ParseTree;
import IO;


extend analysis::typepal::TypePal;

// =====================
//  Tipos del lenguaje
// =====================

data AType
  = intType()
  | boolType()
  | charType()
  | stringType()
  | seqType(AType elem)   
  | unknownType()         
  ;


str prettyAType(intType())        = "Int";
str prettyAType(boolType())       = "Bool";
str prettyAType(charType())       = "Char";
str prettyAType(stringType())     = "String";
str prettyAType(seqType(AType t)) = "<prettyAType(t)>[]";
str prettyAType(unknownType())    = "<?>";


// =====================
//  Roles de nombres
// =====================

data IdRole
  = varId()     
  | funcId()    
  | dataId()    
  ;


private AType typeFromSyntax(Type t) {
  switch (t) {
    case (Type) `Int`    : return intType();
    case (Type) `Bool`   : return boolType();
    case (Type) `Char`   : return charType();
    case (Type) `String` : return stringType();
    case (Type) `<Type elem> [ ]` : return seqType(typeFromSyntax(elem));
    case (Type) `<Identifier name>` : {
      
      return unknownType();
    }
  }
  return unknownType();
}


// =====================
//  Punto de entrada
// =====================


public void checkProgram(Tree pt) {
  
  Tree root = pt;
  if (root has top) {
    root = root.top;
  }

  Collector c = newCollector("alu", root);

  
  collect(root, c);

  TModel tm = newSolver(root, c.run()).run();

  
  for (Message m <- tm.messages) {
    println(m);
  }

  
  if (tm.reportedErrors()) {
    throw "El programa tiene errores de tipos (ver mensajes arriba).";
  }
}


// =====================
//  Colector principal
// =====================


void collect(Tree root, Collector c) {
  visit (root) {
    case DeclVars d:      collectDeclVars(d, c);
    case Assign a:        collectAssign(a, c);
    case Expr e:          collectExpr(e, c);
    case Literal lit:     collectLiteral(lit, c);
  }
}


// =====================
//  Declaraciones
// =====================


void collectDeclVars(DeclVars d, Collector c) {
  AType tau = typeFromSyntax(d.type);

  
  for (/ (Identifier) ` <Identifier id> ` := d) {
    
    c.define("<id>", varId(), d, defType(tau));
  }
}


// =====================
//  Asignaciones
// =====================


void collectAssign(Assign a, Collector c) {
  
  if ((LValue) ` <Identifier id> ` := a.lv) {
    
    c.use("<id>", { varId() });
  }

  
  collectExpr(a.e, c);

  
  c.calculate("assignment", a, [a.lv, a.e],
    AType (Solver s) {
      AType tLv = s.getType(a.lv);
      AType tE  = s.getType(a.e);

      s.requireUnify(tLv, tE,
        error(a,
          "Tipo incompatible en asignación: no se puede asignar un %t a algo de tipo %t",
          tE, tLv)
      );

      return tLv;
    });
}


// =====================
//  Expresiones
// =====================

void collectExpr(Expr e, Collector c) {
  
  if ((Expr) ` <Identifier i> ` := e) {
    c.use("<i>", { varId() });
    
    return;
  }

  
  if ((Expr) ` <Literal lit> ` := e) {
    collectLiteral(lit, c);
    return;
  }

  
  if ((Expr) ` ( <Expr inner> ) ` := e) {
    collectExpr(inner, c);
    return;
  }

  
  if ((SequenceLit) ` sequence ( <{Expr} xs> ) ` := e) {
    
    for (Expr x <- xs) {
      collectExpr(x, c);
    }

    
    c.calculate("sequence literal", e, xs,
      AType (Solver s) {
        if (size(xs) == 0) {
          
          return seqType(unknownType());
        }

        AType t0 = s.getType(xs[0]);

        for (Expr x <- xs) {
          AType tx = s.getType(x);
          s.requireUnify(t0, tx,
            error(x,
              "Todos los elementos de la secuencia deben ser del mismo tipo, "
              + "pero se encontró %t y %t", t0, tx)
          );
        }

        return seqType(t0);
      });

    return;
  }

  
  if ((Expr) ` - <UnaryExpr u> ` := e) {
    collectExpr(u, c);
    c.calculate("unary minus", e, [u],
      AType (Solver s) {
        AType tu = s.getType(u);
        s.requireTrue({tu} <= {intType()},
          error(e, "El operador '-' solo se puede aplicar a Int, no a %t", tu));
        return intType();
      });
    return;
  }

  if ((Expr) ` neg <UnaryExpr u> ` := e) {
    collectExpr(u, c);
    c.calculate("neg", e, [u],
      AType (Solver s) {
        AType tu = s.getType(u);
        s.requireTrue({tu} <= {boolType()},
          error(e, "El operador 'neg' solo se puede aplicar a Bool, no a %t", tu));
        return boolType();
      });
    return;
  }

  
  if ((Expr) ` <Expr l> +  <Expr r> ` := e) { numericBinOp(e, l, "+",  r, c); return; }
  if ((Expr) ` <Expr l> -  <Expr r> ` := e) { numericBinOp(e, l, "-",  r, c); return; }
  if ((Expr) ` <Expr l> *  <Expr r> ` := e) { numericBinOp(e, l, "*",  r, c); return; }
  if ((Expr) ` <Expr l> /  <Expr r> ` := e) { numericBinOp(e, l, "/",  r, c); return; }
  if ((Expr) ` <Expr l> %  <Expr r> ` := e) { numericBinOp(e, l, "%",  r, c); return; }
  if ((Expr) ` <Expr l> ** <Expr r> ` := e) { numericBinOp(e, l, "**", r, c); return; }

 
  if ((Expr) ` <Expr l> and <Expr r> ` := e) { boolBinOp(e, l, "and", r, c); return; }
  if ((Expr) ` <Expr l> or  <Expr r> ` := e) { boolBinOp(e, l, "or",  r, c); return; }

  
  if ((Expr) ` <Expr l> <  <Expr r> ` := e) { relBinOp(e, l, "<",  r, c); return; }
  if ((Expr) ` <Expr l> >  <Expr r> ` := e) { relBinOp(e, l, ">",  r, c); return; }
  if ((Expr) ` <Expr l> <= <Expr r> ` := e) { relBinOp(e, l, "<=", r, c); return; }
  if ((Expr) ` <Expr l> >= <Expr r> ` := e) { relBinOp(e, l, ">=", r, c); return; }
  if ((Expr) ` <Expr l> <> <Expr r> ` := e) { relBinOp(e, l, "<>", r, c); return; }

  // Si llega aquí, no imponemos restricciones de tipo específicas
}


// =====================
//  Literales
// =====================

void collectLiteral(Literal lit, Collector c) {
  if ((Literal) ` <Number n> ` := lit) {
    c.setType(lit, intType());
  }
  if ((Literal) ` <Boolean b> ` := lit) {
    c.setType(lit, boolType());
  }
  if ((Literal) ` <String s> ` := lit) {
    c.setType(lit, stringType());
  }
  // Podrías añadir Char si lo usas
}


// =====================
//  Auxiliares para ops
// =====================

void numericBinOp(Expr e, Expr l, str op, Expr r, Collector c) {
  // Primero recorremos sub-expresiones
  collectExpr(l, c);
  collectExpr(r, c);

  c.calculate("numeric op", e, [l, r],
    AType (Solver s) {
      AType tl = s.getType(l);
      AType tr = s.getType(r);

      s.requireTrue({tl, tr} <= {intType()},
        error(e, "El operador %q solo acepta Int, pero recibió %t y %t", op, tl, tr));

      return intType();
    });
}

void boolBinOp(Expr e, Expr l, str op, Expr r, Collector c) {
  collectExpr(l, c);
  collectExpr(r, c);

  c.calculate("bool op", e, [l, r],
    AType (Solver s) {
      AType tl = s.getType(l);
      AType tr = s.getType(r);

      s.requireTrue({tl, tr} <= {boolType()},
        error(e, "El operador lógico %q solo acepta Bool, pero recibió %t y %t", op, tl, tr));

      return boolType();
    });
}

void relBinOp(Expr e, Expr l, str op, Expr r, Collector c) {
  collectExpr(l, c);
  collectExpr(r, c);

  c.calculate("rel op", e, [l, r],
    AType (Solver s) {
      AType tl = s.getType(l);
      AType tr = s.getType(r);

      s.requireTrue({tl, tr} <= {intType()},
        error(e, "El operador relacional %q espera Int, pero recibió %t y %t", op, tl, tr));

      return boolType();
    });
}
