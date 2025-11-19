module Plugin

import ParseTree;
import util::Reflective;
import util::LanguageServer;
import Syntax;
import parser::ALUParser;
import eval::ALUEval;
import typepal::ALUTypeChecker;
import Checker;


PathConfig pcfg = getProjectPathConfig(|project://alu_rascal|);
Language aluLang = language(pcfg, "ALU", "alu", "plugin::ALUPlugin", "contribs");


data Command = runALU(Program p);


set[LanguageService] contribs() = {
  parser(start[Program] (str program, loc src) { 
    return parse(#start[Program], program, src); 
  }),
  lenses(rel[loc src, Command lens] (start[Program] p) { 
    return { <p.src, runALU(p.top, title="Run ALU program")> }; 
  }),
  executor(exec)
};



value exec(runALU(Program p)) {
  try {
    checkProgram(p);
    P ast = implodeProgram(p);
    typeCheck(ast);
    <Value res, Env env> = evalProgram(ast);
    println("Resultado: <show(res)>");
    return ("ok": true);
  }
  catch str msg: {
    println("Type error(s) detected:");
    println(msg);
    return ("ok": false);
  }
}


public void main() { registerLanguage(aluLang); }
