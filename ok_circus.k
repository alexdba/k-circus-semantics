module CIRCUS-SYNTAX
//@ Arithmetic Syntax
  syntax Exp ::= Int
    | "(" Exp ")" [bracket]
    | Exp "+" Exp [seqstrict] //addition
    | Exp "*" Exp [seqstrict] //multiplication
    | Exp "/" Exp [seqstrict] //division
    | Id
    
  syntax ActName ::= Id    
  syntax ActDef ::= ActName "^=" Comms
//  syntax Action ::= Comms
  
  syntax ProcHeader ::= ActDef | ActDef ProcHeader
  
//  syntax ActCall ::= Id
  syntax Comm ::= String "!" Exp [strict(2)]
                | String "?" Id
//                | ActCall
                
  syntax Comms ::= Comm | Comm ";" Comms [seqstrict]
  syntax Prefix ::= Comm "->" Comm [seqstrict]

  syntax Strings ::= List{String, ","}
  syntax ChDecl ::= "channel" Strings | "channel" Strings ":" String
  syntax ChDecls ::= ChDecl | ChDecl | ChDecl ChDecls
  
  syntax MainAct ::= "@" Comms
  syntax Process ::= "process" Id "^=" "begin" ProcHeader MainAct "end"
                  |  "process" Id "^=" "begin" MainAct "end"

  syntax Circus ::= ChDecls Process

endmodule


module CIRCUS
  imports CIRCUS-SYNTAX

  syntax KResult ::= Int | Circus

  configuration
    <top>
      <td color="green" multiplicity="*"> 
        <k>$PGM:K</k>
        <id>0</id>
        <streams>
          <in color="magenta" > ListItem ("chan1") ListItem(3) </in>
          <out color="Fuchsia"> .List </out>
        </streams>
      </td>
      <env> .Map </env>
      <ch> .Map </ch>
      <act> .Map </act>    
    </top>

  rule <k> X:Id => I ...</k> <env>... X |-> I ...</env>

  rule <k> channel (C:String, Cs:Strings => Cs) : T:String ...</k>
    <ch> ... .Map => C |-> T ...</ch>
  rule <k> channel (C:String, Cs:Strings => Cs) ...</k>
    <ch> ... .Map => C |-> 0 ...</ch>    
    
  rule channel .Strings => . [structural]
  rule channel .Strings : String => . [structural]  

  rule <k> C:String ! E:Int => . ... </k>
  <out>... . => ListItem(C) ListItem(E)</out>

  rule <k> C:String ? I:Id => . ... </k>
  //<ch>... C |-> C ... </ch>
  <in> ListItem (C) ListItem(E:Int) => .List ...</in>
  <env> ... .Map => I |-> E ... </env>
  
  rule <k> I:ActName ^= A:Comms => . ...</k> <act>... .Map => I |-> A ... </act>


  rule <k> A:Comm ; B:Comms => A ~> B ... </k>   [structural]
  rule <k> process P:Id ^= begin C:MainAct end => C ...</k> [structural]
  rule <k> process P:Id ^= begin 
    PH:ProcHeader C:MainAct end => PH ~> C  ...</k> [structural]  
    
  rule <k> A:ChDecls B:Process => A ~> B ...</k>  [structural]  
  rule <k> A:ChDecl B:ChDecls => A ~> B ...</k>  [structural]    
  rule <k> A:ActDef B:ProcHeader => A ~> B ...</k> [structural]
  rule <k> @ B:Comms => B ...</k> [structural]  


  rule I1:Int + I2:Int
  => I1 +Int I2
  rule I1:Int * I2:Int
  => I1 *Int I2
  
  


endmodule
