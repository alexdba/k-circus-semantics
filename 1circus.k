module CIRCUS-SYNTAX

//reused from IMP example
  syntax AExp  ::= Int | Id
   | AExp "/" AExp              [left, strict]
   > AExp "+" AExp              [left, strict]
   | "(" AExp ")"               [bracket]
  syntax BExp  ::= Bool
   | AExp "<=" AExp             [seqstrict, latex({#1}\leq{#2})]
   | AExp "==" AExp             [seqstrict, latex({#1}\leq{#2})]   
   | "!" BExp                   [strict]
   > BExp "&&" BExp             [left, strict(1)]
   | "(" BExp ")"               [bracket]
                 

  syntax Program ::= CircusPar | Program CircusPar
  syntax CircusPar ::= "channel" CDecl | ProcDecl
  syntax CDecl ::= SimpleCDecl | SimpleCDecl "," CDecl
  syntax SimpleCDecl ::= ChannelName | ChannelName ":" Id
  syntax ChannelName ::= Id
  syntax VarName ::= Id
  syntax VarDecl ::= VarName | VarName "," VarDecl
  syntax ProcDecl ::= "process" Id "^=" ProcDef
  syntax ProcDef ::= "begin" ProcBody "@" ParAction "end"
  syntax PPar ::= SchemaDef | ActionDef
  syntax ActionName ::= Id
  syntax ActionDef ::= ActionName "^=" CSPAction
  syntax PPars ::= List{PPar,""}
  syntax ProcBody ::= PPars
                    | "state" SchemaDef PPars
  syntax SchemaName ::= Id
  syntax SchemaDef ::= SchemaName "==" "[" SchemaStr "]"
  syntax SchemaStr ::= SchemaHeader "|" SchemaExp | SchemaExp
  syntax SchemaHeader ::= List{SchemaInclude, ""}
  syntax SchemaInclude ::= SchemaName | "D" SchemaName
                        | SchemaName "'"
  syntax SchemaExp ::= Exp | Exp "," SchemaExp


  syntax ParAction ::= CSPAction | SchemaDef
  syntax CSPAction ::= "Skip" | "Stop"
                     | Comm "->" CSPAction
                     | Pred "&" CSPAction
                     | "u" Id "@" Action
                     | Action ";" Action
                     | Action "[]" Action
                     | Action "|-|" Action
  syntax Comm ::= ChannelName | ChannelName CParameter
  syntax CParameter ::= "?" VarName
                      | "?" VarName ":" Pred
                      | "!" VarName
                      | "." CParameter
  syntax Pred ::= BExp //for now
  syntax Exp ::= BExp | AExp
  syntax Action ::= Command | ActionName | CSPAction  //for now
  syntax Command ::= VarName ":=" Exp
                    | "var" VarDecl "@" Action
                    
                    
                       
  //syntax CircusPars ::= List{CircusPar,""}
endmodule

module CIRCUS
  imports CIRCUS-SYNTAX
endmodule
