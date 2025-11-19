module Eval
import IO;
import String;
import List;
import Map;
import Math;
import AST;

public alias Env = map[str, Value];


private Value callBuiltin(str name, list[Value] args) {
switch (name) {
case "print": { for (Value v <- args) println(show(v)); return VNull(); }
case "len": { if (size(args)==1 && VSeq?(args[0])) return VNum(size(args[0].xs)); }
}
return VNull();
}


private Value bin(str op, Value a, Value b) {
if (VNum?(a) && VNum?(b)) {
real x = a.n; real y = b.n;
if (op=="+") return VNum(x+y);
if (op=="-") return VNum(x-y);
if (op=="*") return VNum(x*y);
if (op=="/") return VNum(x/y);
if (op=="%") return VNum(x%y);
if (op=="**") return VNum(pow(x,y));
if (op=="<") return VBool(x<y);
if (op==">") return VBool(x>y);
if (op=="<=") return VBool(x<=y);
if (op==">=") return VBool(x>=y);
if (op=="<>") return VBool(x!=y);
}
if (VBool?(a) && VBool?(b)) {
if (op=="and") return VBool(a.b && b.b);
if (op=="or") return VBool(a.b || b.b);
}
// operador ternario sintetizado por el parser de cond: (guard and a) ? b
if (op=="?") return asBool(a) ? b : VNull();
return VNull();
}


private Env setLV(LV lv, Value v, Env env) {
switch (lv) {
case lvId(str name): return env + (name : v);
}
// Campos/`$` no implementados en el mini‑ejecutor (se pueden mapear contra VStruct)
return env;
}


private Value getLV(LV lv, Env env) {
switch (lv) {
case lvId(str name): return lookup(name, env);
}
return VNull();
}


private Value lookup(str n, Env env) = (n in env) ? env[n] : VNull();


private int toInt(Value v) = VNum?(v) ? toInt(v.n) : 0;
private bool asBool(Value v) = VBool?(v) ? v.b : (VNum?(v) ? v.n != 0 : false);


public str show(Value v) {
if (VNum?(v)) return "<v.n>";
if (VBool?(v)) return "<v.b>";
if (VChar?(v)) return v.ch;
if (VStr?(v)) return v.s;
if (VTuple?(v)) return "(<show(v.a)>, <show(v.b)>)";
if (VSeq?(v)) return "[" + intercalate(", ", [ show(x) | x <- v.xs ]) + "]";
if (VStruct?(v)) return "{" + intercalate(", ", [ k+":"+show(v.fields[k]) | k <- sort(keys(v.fields)) ]) + "}";
return "null";
}



