module Syntax


layout Layout = (Space | Comment)*;
lexical Space   = [\ \t\r]+;
lexical Comment = @category="Comment" "#" ![\n]* $;


lexical NL = "\r\n" | "\n";
syntax Newline  = NL;

// ========= Tipos =========
syntax Type
  = "Int"
  | "Bool"
  | "Char"
  | "String"
  | Identifier         
  | Type "[" "]"        
  | "(" Type ")"        
  ;

// ========= Programa / Módulos =========
syntax Program = (Module | Stmt)+;
start syntax Program = Program;
syntax Module = FuncDef | DataDef;

// ========= Sentencias y bloques =========
syntax Stmt
  = DeclVars Newline
  | Assign Newline
  | ForStmt
  | IfExpr Newline
  | CondExpr Newline
  | Expr Newline
  ;

syntax Block = 'do' { Stmt } 'end';

// ========= Declaraciones / Asignaciones / LValue =========
syntax DeclVars = ids: Identifier { "," Identifier } ":" Type;

syntax Assign   = lv: LValue '=' e: Expr;
syntax LValue   = base: Identifier { '.' Identifier | '$' Identifier };

// ========= Funciones =========
syntax FuncDef     = header: FuncHeader body: Block 'end' name: Identifier;
syntax FuncHeader  = name: Identifier '=' 'function' '(' Params ')';
syntax Params      = [ ParamList ];
syntax ParamList   = Identifier { ',' Identifier };

syntax ArgList     = Expr { ',' Expr };

// ========= Tipos algebraicos (esqueleto) =========
syntax DataDef = name: Identifier '=' 'data' 'with' OpList Newline { FuncDef } 'end' Identifier;
syntax OpList  = OpName { ',' OpName };
syntax OpName  = Identifier;

// ========= Literales compuestos =========
syntax StructLit    = 'struct' '(' StructFields ')';
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
syntax IfExpr = 'if' Expr Newline 'then' Expr Newline 'else' Expr Newline 'end';

syntax CondExpr   = 'cond' Expr 'do' Newline CondClause { Newline CondClause } Newline 'end';
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
| "with" | "yielding" | "and" | "or" | "neg" | "true" | "false";
