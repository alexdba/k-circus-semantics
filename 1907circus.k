/*///
This is a tentative to write syntax and semantics to circus in K
the command line to build it and run a pretty-printed example is:
  $rm -rf circus-kompiled/ && kompile circus.k && krun \
  teste.circus   | xmllint --format -

K-framework used to test was a nightly built version 4
*///

module CIRCUS-SYNTAX
//@ Arithmetic Syntax
  syntax Exp ::= Int
    | "(" Exp ")" [bracket]
    | Exp "+" Exp [seqstrict] //addition
    | Exp "*" Exp [seqstrict] //multiplication
    | Exp "/" Exp [seqstrict] //division
    | Id
    
    
  syntax CommaIds ::= List{Id, ","}
    
  syntax Program ::= CircusPars
  syntax CircusPars ::= CircusPar | CircusPar CircusPars
  syntax CircusPar ::= ZParagraph
    | CompleteCDecl
    | "chanset" Id "==" CSExp
    | ProcDecl
  syntax CompleteCDecl ::= "channel" SimpleCDecl
  syntax SimpleCDecl ::= Id | Id ":" ZExp
//  failed to parse multiple channels on single line  
//  syntax SimpleCDecls ::= List{SimpleCDecl, ";"}
  syntax CSExp ::= "{||}" | "{|" CommaIds "|}" | Id | CSExp "U" CSExp | CSExp "T" CSExp | CSExp "\\" CSExp
  syntax NSExp ::= "{}" | "{" Id "}" | Id | NSExp "U" NSExp | NSExp "T" NSExp | NSExp "\\" NSExp
  
  syntax ProcDecl ::= "process" Id "^=" ProcDef
  syntax ProcDef ::= 
    "begin" "state" SchemaExp PPars  "@" ParAction "end"
    | "begin" "state" SchemaExp  "@" ParAction "end"    
    | "begin" PPars  "@" ParAction "end"
    | "begin" "@" ParAction "end"

    
  syntax PPar ::= ZParagraph | Id "^=" ParAction | "nameset" Id "==" NSExp
  syntax PPars ::= PPar | PPar PPars  

  syntax ParAction ::= CSPAction | SchemaExp
  syntax CSPAction ::= "Skip" | "Stop" | "Chaos"
    | Command
    | Comm "->" Action
    | "(" Action ")"               [bracket]
    | Pred "&" Action
    | "u" Id "@" Action
    | Action "\\" CSExp
    | Action ";" Action [left]
    | Action "[]" Action
    | Action "|-|" Action
    | Action "[|" NSExp "|" CSExp "|" NSExp "|]" Action

  //syntax CParameters ::= List {CParameter, ""}
  //By now, only one parameter at a time
  //syntax Comm ::= Id CParameter | Id  
  //syntax CParameter ::= "?" Id | "?" Id ":" Pred | "!" Exp [strict]  | "." Exp
  syntax Comm ::= Id | Id "?" Id | Id "!" Exp [strict(2)]
  
  
  syntax Command ::= Id ":=" Exp [strict(2)]
    | "if" GActions "fi"
    | "var" Decl "@" Action
  syntax GActions ::= Pred "-->" Action | Pred "-->" Action "[]" GActions

  
  syntax Action ::= SchemaExp | Command | Id | CSPAction

//-------------------------------------
  syntax SchemaExp ::= Id
  syntax ZParagraph ::= Exp
  syntax ZExp ::= Exp
  syntax Pred  ::= Id
  syntax Decl ::= Id
  syntax SetExpr ::= "int" | "nat" 

endmodule


module CIRCUS
  imports CIRCUS-SYNTAX

  syntax KResult ::= Int

  configuration
    <top>
      <procs>
        <proc color="green" multiplicity="*"> 
          <k>$PGM:K</k>
          <id>0</id>
        </proc>
      </procs>
      <env> .Map </env>
      <store> .Map </store>
      <ch> .Map </ch>
      <act> .Map </act>
      <procref> .Map </procref>
      <nextid> 0 </nextid>
      <nextloc> 0 </nextloc>
      <tr> .List </tr>
    </top>

  syntax KItem ::= "undefined"

  //Operational semantics according to RR1567
  
  // Var assignment (OPS 6)
  rule <k> V:Id := E:Int => Skip ... </k>
    <nextloc> L => L +Int 1 </nextloc>
    <env> Env => Env[V <- L] </env>
    <store>... .Map => L |-> E ...</store>
    
  //Comm output (OPS 9,10,14)
  //Insted of processing it all, I just break it into comm
  //followed by the action. The comm is handled by the next
  //k rule named "labeled ouput progress", the action goes
  //on by itself
  rule <k> C:Comm -> A:Action => C ~> A ...</k>  
  
  // Once in the top of k cell, the communication is computed
  // according the following rules:
   
  /*///Labeled var output progress (OPS 9)
    For an output suffixed by an expression, first we heat
    the expression until a result (Int) is found.  
    The original rule requires a symbolic output 
  *///
  rule <k> C:Id ! E:Int => .  ...</k> 
    <ch> ... C |-> _ ... </ch>
    <tr> ... . => ListItem(C) ListItem("!") ListItem(E) </tr>
  
  /*/// Labeled input progress (OPS 10)
    For an input suffixed by a var name
    It causes a new variable declaration 
    The type is not treated yet, just for integers
  *///
  rule <k> C:Id ? V:Id => .  ...</k> 
    <ch> ... C |-> _ ... </ch>
    <nextloc> L => L +Int 1 </nextloc>
    <env> Env => Env[V <- L] </env>
    <store>... .Map => L |-> ?V:Int ...</store>
    <tr> ... . => ListItem(C) ListItem("?") ListItem(?V) </tr>
    

  /*///Labeled output progress (OPS 14)
    For events (channel name), check it agains the
    the channel declarations and, if it is correct, output it    
  *///
  rule <k> C:Id => . ...</k>
    <ch> ... C |-> _ ... </ch>
    <tr> ... . => ListItem(C)  </tr>


  

  /*///Sequential composition (OPS 15)
    The original OPS rule would be translated as something like
      rule <k> Skip ; A:Action  => A ... </k>
    In K, it just doesnt make sense, so, in order to make it behaves
    like it should, I needed to make it left-associative (syntax)
    and "decompose" the composition into sequential steps:
      rule <k> A1:Action ; A2:Action => A1 ~> A2 ... </k>
    The problem is, after diving into A1, it goes all the way until
    the end of the action, leaving only the last Skip to be evaluated
    out of context, something like:
      <k> Skip ~> A2 </k>
    That's why it is necessary to give a null semantics to Skip, this way
    the k cell will not freeze:
      rule <k> Skip => . ... </k>
  *///
  rule <k> Skip => . ... </k>
  rule <k> A1:Action ; A2:Action => A1 ~> A2 ... </k>
  
  
  //------------------
  
  //fix process paragraph order
  rule <k> begin @ Pa:ParAction end => 
    Pa ... </k>

  //process "processing" :)
  rule <k> process P:Id ^= PD:ProcDef  => PD ...</k>
    <nextid> N => N +Int 1 </nextid>
    <procref>... .Map => P |-> N ...</procref>
//    (. => <proc> <k>PD</k> <id>N</id> </proc>)



  
  //process and store (get rid of) typed and untyped channels
  rule <k> channel C:Id : Tipo:Id => . ...</k>
    <ch> ... .Map => C |-> Tipo ...</ch>
  rule <k> channel C:Id => . ...</k>
    <ch> ... .Map => C |-> 0 ...</ch>

  //tried to desugar multiple channel declarations, failed :(
  //rule channel S:SimpleCDecl ; C:CDecl => channel S  channel C [macro]

  
  //sequential processing of circus paragraphs
  rule P1:CircusPar P2:CircusPars => P1 ~> P2 [structural]
  rule P1:PPar P2:PPars => P1 ~> P2 [structural]  
 

    
     

  
  
  rule I1:Int + I2:Int
  => I1 +Int I2
  rule I1:Int * I2:Int
  => I1 *Int I2  
  rule <k> X:Id => I ...</k> <env>... X |-> L ...</env>
       <store>... L |-> I ...</store>

endmodule
