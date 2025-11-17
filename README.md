## rascaldsl — Mini‑lenguaje en Rascal

Este repositorio contiene una implementación educativa de un mini‑lenguaje escrita en Rascal. Incluye la gramática concreta, un parser que convierte el árbol de parseo en un AST, utilidades parciales para evaluación y un ejemplo mínimo de `main`.

Contenido principal
- `src/main/rascal/Syntax.rsc` — definición de la gramática (tokens, layout, producciones, precedencias).
- `src/main/rascal/Parser.rsc` — parseo y transformación del parse tree (CST) a AST (funciones públicas: `parseProgram`, `implodeProgram`).
- `src/main/rascal/Eval.rsc` — funciones auxiliares del intérprete: operadores binarios, builtins mínimos (`print`, `len`), `show`, y manejo básico de LValues/Env.
- `src/main/rascal/Main.rsc` — ejemplo de punto de entrada `main` muy sencillo.
- `src/main/rascal/AST.rsc` — descripciones de tipos y constructores del AST (usar para ver contratos exactos de nodos `P`, `Exp`, `Stmt`, `Value`, etc.).

---

## Descripción detallada por módulo

### `Main.rsc`

Propósito
- Punto de entrada de ejemplo: `int main(int testArgument=0)` imprime y retorna `testArgument`.

Notas
- Ejemplo mínimo, útil para comprobar la integración o paquetes ejecutables.

### `Syntax.rsc`

Propósito
- Define la gramática concreta del lenguaje: layout (espacios, comentarios), nueva línea explícita, literales, identificadores, sentencias, expresiones y precedencias.

Puntos importantes
- `start syntax Program = { Module | Stmt }+;` — el programa es una lista de módulos o sentencias.
- Maneja `FuncDef`, `DataDef`, `DeclVars`, `Assign`, `ForStmt`, `IfExpr`, `CondExpr`, `Expr` y constructos compuestos: `struct`, `sequence`, `tuple`.
- Precedencias: `or`, `and`, relaciones, suma, multiplicación, potencia, unarios y primarios.
- Lexemas: `Number`, `Char`, `String`, `Boolean`, `Identifier` y `Reserved` (palabras reservadas).

Observaciones
- La gramática separa explícitamente el token `NL` para soportar bloques multilinea y plataformas Windows/Unix.

### `Parser.rsc`

Propósito
- Parsear entrada (desde fichero o cadena) y convertir el árbol de parseo (CST) al AST del lenguaje usando los constructores del módulo `AST`.

API pública
- `public start[Program] parseProgram(loc l)` — parsea un archivo.
- `public start[Program] parseProgram(str s, loc src)` — parsea desde una cadena con ubicación.
- `public P implodeProgram(Tree cst)` — convierte el `Tree` del parser a la representación AST (`Program`).

Comportamiento
- `implodeProgram` extrae `FuncDef` y `DataDef` y transforma sentencias sueltas en nodos `tStmt(...)`.
- `implodeFunc` extrae nombre, parámetros y cuerpo; produce `func(name, params, body)`.
- `implodeData` recoge nombres de constructores y crea `dataDef(name, ctors)`.
- `implodeStmt` mapea `DeclVars`, `Assign`, `for` en `Range`, `if`, `cond` y expresiones a nodos `Stmt` del AST.
- `implodeExpr` convierte literales, variables, tuplas, secuencias, llamadas simples y operadores binarios/unarios a `Exp`.
- El `cond` se reduce a una expresión anidada que utiliza un operador ternario sintético `?` (interpretado por `Eval`).

Limitaciones del parser
- Las llamadas complejas y targets no‑identifier pueden no estar totalmente cubiertos: el caso simple `id(args)` es tratado para `Call`.

### `Eval.rsc`

Propósito
- Utilidades y lógica parcial del intérprete: operadores, builtins, lectura/escritura simple de variables y conversión a cadena (`show`).

Funciones clave
- `callBuiltin(str name, list[Value] args)` — builtins implementados: `print`, `len`.
- `bin(str op, Value a, Value b)` — operaciones numéricas (`+ - * / % **`), comparaciones (`< > <= >= <>`) y booleanas (`and`, `or`). Implementa `?` ternario sintetizado.
- `setLV(LV lv, Value v, Env env)` y `getLV(LV lv, Env env)` — sólo `lvId` está soportado; accesos por campos no implementados.
- `lookup`, `toInt`, `asBool` — auxiliares de entorno y conversión.
- `show(Value v)` — serialización a `str` para valores numéricos, booleanos, strings, tuplas, secuencias y structs.

Limitaciones
- No hay manejo de asignaciones a campos (`.` o `$`) en `setLV`.
- `callBuiltin` es mínimo; no hay manejo de errores robusto (en muchos casos se retorna `VNull()` en vez de lanzar excepciones con ubicación).

---

## Contratos y ejemplos de uso

Parsear un archivo y obtener AST (ejemplo en Rascal REPL):

```rascal
import Parser;
loc src = |file:///C:/ruta/al/proyecto/examples/programa.alu|;
Tree cst = Parser::parseProgram(src);
P programAst = Parser::implodeProgram(cst);
```

Parsear desde cadena:

```rascal
import Parser;
str code = "x = 1 + 2";
loc src = |file:///C:/ruta/al/proyecto/examples/programa.alu|;
Tree cst = Parser::parseProgram(code, src);
P programAst = Parser::implodeProgram(cst);
```

Mostrar un `Value` con `Eval` (ejemplo conceptual):

```rascal
import Eval;
Value v = VNum(42);         // según constructores en AST.rsc
println(Eval::show(v));     // imprime "42" (según implementación)
```

> Nota: los constructores `VNum`, `VSeq`, `VStruct`, `P`, `LV`, `Exp`, `Stmt` provienen de `AST.rsc`. Revisa `AST.rsc` para los nombres y formas exactas.

---

## Limitaciones, casos frontera y recomendaciones

Limitaciones importantes
- Accesos/assignación a campos (p. ej. `a.b` o `a$b`) no soportados para escritura en `Eval`.
- Builtins mínimos (`print`, `len`) — añadir conversiones y utilidades mejorará la experiencia.
- Falta manejo de errores con `loc` y mensajes claros: hoy muchas operaciones devuelven `VNull()` en vez de informar la causa.

