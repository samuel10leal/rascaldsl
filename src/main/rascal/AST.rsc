module AST

// Valores en tiempo de ejecución
data Value
= VNum(real n)
| VBool(bool b)
| VChar(str ch)
| VStr(str s)
| VTuple(Value a, Value b)
| VSeq(list[Value] xs)
| VStruct(map[str,Value] fields)
| VNull()
;

data TypeAnn
= tNumber()
| tBool()
| tChar()
| tString()
| tVoid()
| tNull()
| tStruct(str name)
| tSequence(TypeAnn elem)
| tTuple(TypeAnn left, TypeAnn right)
| tUnknown(str reason)
;

data FieldDecl = field(str name, TypeAnn typ);

// Árvores para statements y expresiones (subconjunto ejecutable)
data P = program(list[Top] items);


data Top = tStmt(Stmt s) | tFunc(Func f) | tData(Data d);


data Stmt
= sDecl(TypeAnn typ, list[str] ids)
| sAssign(LV lv, Exp e)
| sForInRange(str v, Exp fromE, Exp toE, list[Stmt] body)
| sIf(Exp c, Exp th, Exp el)
| sExpr(Exp e)
;


data LV = lvId(str name) | lvField(LV base, str field) | lvDollar(LV base, str field);


data Func = func(str name, list[str] params, list[Stmt] body);


data Data = dataDef(str name, list[FieldDecl] fields, list[Func] methods);


// Expresiones
public alias BinOp = str; // '+','-','*','/','%','**','<','>','<=','>=','<>','and','or'


data Exp
= eLit(Value v)
| eVar(str name)
| eGet(LV lv)
| eUnary(str op, Exp e)
| eBin(Exp l, BinOp op, Exp r)
| eTuple(Exp a, Exp b)
| eSeq(list[Exp] xs)
| eStruct(str typeName, map[str,Exp] fields)
| eCall(str name, list[Exp] args) // simplificado
;
