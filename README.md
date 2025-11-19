## rascaldsl – Mini-lenguaje en Rascal

Este repositorio contiene una implementación educativa de un mini-lenguaje escrita en Rascal. Incluye la gramática concreta con anotaciones de tipo, un parser que convierte el árbol de parseo en un AST, utilidades parciales para evaluación y un ejemplo mínimo de `main`. A partir de esta iteración se incorpora un sistema de tipos inspirado en TypePal que valida los programas antes de ejecutarlos.

### Contenido principal

- `src/main/rascal/Syntax.rsc` – gramática concreta del lenguaje (tokens, layout, precedencias) y la sintaxis de anotaciones de tipo para valores y estructuras.
- `src/main/rascal/Parser.rsc` – parseo e implosión del árbol concreto a AST (`parseProgram`, `implodeProgram`).
- `src/main/rascal/AST.rsc` – definiciones de los constructores del AST, valores en tiempo de ejecución y la jerarquía `TypeAnn` usada por el verificador.
- `src/main/rascal/Eval.rsc` – utilidades básicas del intérprete (builtins `print`/`len`, operadores y `show` actualizado con `Char`).
- `src/main/rascal/typepal/ALUTypeChecker.rsc` – comprobador estático que aplica las reglas de tipo de la tercera entrega usando ideas de TypePal.
- `src/main/rascal/Main.rsc` – punto de entrada de ejemplo.

---

## Descripción detallada por módulo

### `Main.rsc`

Propósito
- Punto de entrada de ejemplo: `int main(int testArgument=0)` imprime y retorna `testArgument`.

Notas
- Ejemplo mínimo, útil para comprobar integraciones o empaquetado.

### `Syntax.rsc`

Propósito
- Define la gramática concreta del lenguaje: layout (espacios, comentarios), nueva línea explícita, literales, identificadores, sentencias, expresiones, precedencias **y reglas de tipos**.

Puntos importantes
- `start syntax Program = { Module | Stmt }+;` – el programa es una lista de módulos o sentencias.
- `DeclVars` exige un tipo (`Type`) seguido de una lista de identificadores. Los tipos admiten `Int`, `Bool`, `Char`, `String`, secuencias (`sequence<T>`), tuplas (`tuple<A,B>`) y nombres definidos por el usuario.
- `DataDef` conserva el esqueleto `name = data with ...` pero ahora cada `OpName` describe un campo tipado (`Identifier ':' Type`), lo que permite reutilizar la misma sintaxis para estructuras de datos.
- Se añadieron palabras reservadas para los tipos básicos y se mantiene el token `NL` explícito para soportar Windows/Unix.

### `Parser.rsc`

Propósito
- Parsear entrada (desde fichero o cadena) y convertir el árbol de parseo (CST) al AST (`AST.P`).

API pública
- `public start[Program] parseProgram(loc l)` – parsea un archivo.
- `public start[Program] parseProgram(str s, loc src)` – parsea desde una cadena con ubicación.
- `public P implodeProgram(Tree cst)` – convierte el `Tree` del parser a la representación AST (`Program`).

Comportamiento
- `implodeProgram` extrae `FuncDef` y `DataDef`, transformando sentencias sueltas en nodos `tStmt(...)`.
- `implodeFunc` extrae nombre, parámetros y cuerpo; produce `func(name, params, body)`.
- `implodeData` convierte cada campo de `data` en `FieldDecl` (nombre + `TypeAnn`) y conserva las funciones embebidas.
- `implodeStmt` reconoce `DeclVars` tipadas, asignaciones, `for`, `if`, `cond` y expresiones generales.
- `implodeExpr` soporta literales numéricos, booleanos, `Char`, `String`, tuplas, secuencias, structs, llamadas y operadores unarios/binarios. El `cond` se sigue reduciendo a un `?` ternario sintético.

### `AST.rsc`

Propósito
- Define las estructuras del AST y los valores utilizados en el intérprete.

Cambios destacados
- `Value` incluye `VChar` para modelar literales de caracteres.
- Se añadió `data TypeAnn` para representar las anotaciones (`tNumber`, `tBool`, `tChar`, `tString`, `tSequence`, `tTuple`, `tStruct`, `tVoid`, `tNull`, `tUnknown`).
- `Stmt` guarda el tipo declarado (`sDecl(TypeAnn, list[str])`).
- `Data` modela estructuras mediante `list[FieldDecl]` (campos tipados) y conserva los `Func` asociados.

### `Eval.rsc`

Propósito
- Utilidades y lógica parcial del intérprete: operadores, builtins, lectura/escritura simple de variables y conversión a cadena (`show`).

Funciones clave
- `callBuiltin(str name, list[Value] args)` – builtins implementados: `print`, `len`.
- `bin(str op, Value a, Value b)` – operadores numéricos/booleanos más el ternario `?`.
- `setLV`/`getLV`, `lookup`, `toInt`, `asBool`.
- `show(Value v)` soporta números, booleanos, chars, strings, tuplas, secuencias y structs.

Limitaciones conocidas
- La escritura en campos (`.`/`$`) sigue sin implementarse dentro del evaluador.
- Muchos errores retornan `VNull()` en vez de propagar excepciones con `loc`.

### `typepal/ALUTypeChecker.rsc`

Propósito
- Implementa un verificador estático alineado con TypePal: recorre el AST, valida declaraciones tipadas, verifica expresiones y estructuras y asegura que los campos usados en `struct` existan según las definiciones `data`.

Reglas principales
- Toda variable debe declararse con tipo antes de usarse; las reasignaciones deben respetar dicho tipo.
- Operadores aritméticos/booleanos sólo se aplican sobre operandos compatibles.
- Las estructuras (`data` + `struct`) se registran en un entorno; al construir un `struct` se exige que todos los campos existan y que los valores correspondan a su tipo declarado (nueva regla solicitada).
- `sequence` requiere elementos homogéneos; `tuple` preserva el tipo de cada componente.

Integración
- `typeCheck(P program)` se invoca desde `Plugin.rsc` antes de ejecutar el programa. Si se detecta un error, se lanza una excepción con un mensaje descriptivo.

---

## Contratos y ejemplos de uso

Parsear un archivo y obtener AST (ejemplo en Rascal REPL):

```rascal
import Parser;
loc src = |file:///C:/ruta/al/proyecto/examples/programa.alu|;
Tree cst = Parser::parseProgram(src);
P programAst = Parser::implodeProgram(cst);
```

Realizar la verificación de tipos explícitamente:

```rascal
import Parser;
import typepal::ALUTypeChecker;
loc src = |file:///C:/ruta/al/proyecto/examples/programa.alu|;
P ast = Parser::implodeProgram(Parser::parseProgram(src));
typeCheck(ast); // lanza excepción si el programa viola el sistema de tipos
```

Mostrar un `Value` con `Eval` (ejemplo conceptual):

```rascal
import Eval;
Value v = VChar("A");
println(Eval::show(v)); // imprime "A"
```

---

## Limitaciones y recomendaciones

- El evaluador sigue sin soportar escrituras en campos (`a.b = ...`), aunque el verificador garantiza que los accesos corresponden a estructuras válidas.
- Los parámetros de funciones se consideran `tUnknown`; añadir anotaciones de tipo en cabeceras permitiría reforzar la comprobación.
- El built-in `len` sólo acepta secuencias (no strings) y otros builtins no están tipados aún.
- Los mensajes de error no incluyen ubicaciones (`loc`); integrarlos mejoraría el diagnóstico.
