module Syntax

// === Layout y saltos de línea (NO consumir '\n' en layout) ===
layout Layout = (Space | Comment)*;
lexical Space   = [\ \t\r]+;
lexical Comment = @category="Comment" "#" ![\n]* $;

// NL explícito (Windows/Unix) y no-terminal 'nl'
lexical NL = "\r\n" | "\n";
syntax nl  = NL;

// ========= Programa / Módulos =========
start syntax Program = { Module | Stmt }+;
syntax Module = FuncDef | DataDef;

// ========= Sentencias y bloques =========
syntax Stmt
  = DeclVars nl
  | Assign nl
  | ForStmt
  | IfExpr nl
  | CondExpr nl
  | Expr nl
  ;

syntax Block = 'do' nl { Stmt } 'end';

// ========= Declaraciones / Asignaciones / LValue =========
syntax DeclVars = ty: Type vars: VarList;
syntax VarList  = Identifier { "," Identifier };
syntax Assign   = lv: LValue '=' e: Expr;
syntax LValue   = base: Identifier { '.' Identifier | '$' Identifier };

// ========= Funciones =========
syntax FuncDef     = header: FuncHeader body: Block 'end' name: Identifier;
syntax FuncHeader  = name: Identifier '=' 'function' '(' Params ')';
syntax Params      = [ ParamList ];
syntax ParamList   = Identifier { ',' Identifier };
syntax ArgList     = Expr { ',' Expr };

// ========= Tipos algebraicos (esqueleto) =========
syntax DataDef = name: Identifier '=' 'data' 'with' OpList nl { FuncDef } 'end' Identifier;
syntax OpList  = OpName { ',' OpName };
syntax OpName  = Identifier ':' Type;

// ========= Tipos =========
syntax Type
  = BaseType
  | 'sequence' '<' Type '>'
  | 'tuple' '(' Type ',' Type ')'
  | Identifier
  ;

syntax BaseType = 'Int' | 'Bool' | 'Char' | 'String';

// ========= Literales compuestos =========
syntax StructLit    = 'struct' Identifier '(' StructFields ')';
syntax StructFields = StructField { ',' StructField };
syntax StructField  = Identifier ':' Expr;

syntax SequenceLit  = 'sequence' '(' [ ArgList ] ')';
syntax TupleLit     = 'tuple' '(' Expr ',' Expr ')';

// ========= For / Rango / Iteradores (mini) =========
syntax IteratorDef = 'iterator' '(' Identifier ')' 'yielding' '(' Identifier ')';
syntax Range       = 'from' Expr 'to' Expr; // Inclusivo
syntax InIterable  = Identifier | IteratorDef;

syntax ForStmt
  = 'for' Identifier Range Block
  | 'for' Identifier 'in' InIterable '(' Expr ')' Block
  ;

// ========= If y cond =========
syntax IfExpr = 'if' Expr nl 'then' Expr nl 'else' Expr nl 'end';

syntax CondExpr   = 'cond' Expr 'do' nl CondClause { nl CondClause } nl 'end';
syntax CondClause = Expr '->' Expr;

// ========= Expresiones (precedencias) =========
syntax Expr      = OrExpr;
syntax OrExpr    = left: AndExpr { 'or' right: AndExpr };
syntax AndExpr   = left: RelExpr { 'and' right: RelExpr };
syntax RelExpr   = left: AddExpr { ( '<' | '>' | '<=' | '>=' | '<>' ) right: AddExpr };
syntax AddExpr   = left: MulExpr { ( '+' | '-' ) right: MulExpr };
syntax MulExpr   = left: PowExpr { ( '*' | '/' | '%' ) right: PowExpr };
syntax PowExpr   = left: UnaryExpr { '**' right: UnaryExpr };
syntax UnaryExpr = ( 'neg' | '-' ) UnaryExpr | Primary;

syntax Primary
  = lit: Literal
  | id : Identifier
  | lv : LValue
  | par: '(' Expr ')'
  | st : StructLit
  | seq: SequenceLit
  | tup: TupleLit
  | call: Call
  | field: FieldAccess
  ;

syntax Call = target: PrimaryNoCall '(' [ ArgList ] ')';
syntax PrimaryNoCall = Identifier | LValue | '(' Expr ')';
syntax FieldAccess   = base: PrimaryNoCall ( '.' Identifier | '$' Identifier );

// ========= Léxicos =========
syntax Literal = number: Number | ch: Char | str: String | b: Boolean;
lexical Number  = [0-9]+ ('.'[0-9]+)?;
lexical Char    = "'" !['\n'] "'";
lexical String  = '"' !['"'\n]* '"';
lexical Boolean = 'true' | 'false';

lexical Identifier = [a-zA-Z] [a-zA-Z0-9\-]*;

keyword Reserved =
  "cond" | "do" | "data" | "end" | "for" | "from" | "then" | "function"
| "else" | "if" | "in" | "iterator" | "sequence" | "struct" | "to" | "tuple"
| "with" | "yielding" | "and" | "or" | "neg" | "true" | "false"
| "Int" | "Bool" | "Char" | "String";
