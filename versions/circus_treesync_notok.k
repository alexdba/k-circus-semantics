/*///
This is a tentative to write syntax and semantics to circus in K
the command line to build it and run a pretty-printed example is:
  $rm -rf circus-kompiled/ && kompile circus.k && krun \
  teste.circus   | xmllint --format -

K-framework used to test was a nightly built version 4
*///

module CIRCUS-SYNTAX
imports SET
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
    | "chanset" Id "==" CSExp [strict(2)]
    | ProcDecl
    | ":run" Id //choose the main process
  syntax CompleteCDecl ::= "channel" SimpleCDecl
  syntax SimpleCDecl ::= Id | Id ":" ZExp
//  failed to parse multiple channels on single line  
//  syntax SimpleCDecls ::= List{SimpleCDecl, ";"}
  syntax CSExp ::= Set | Set CSExp | "{||}" | "{|" CommaIds "|}" | Id | CSExp "U" CSExp | CSExp "T" CSExp | CSExp "\\" CSExp
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
  syntax CSPAction ::=  "Skip" | "Stop" | "Chaos"
    | "(" Action ")"               [bracket]  
    | Command    
    > Comm "->" Action [right]
    | "var" Decl "@" Action
    //>  Pred "&" Action
    //| "u" Id "@" Action
    > left:
      Action "\\" CSExp
    | Action ";" Action [left]
    | Action "[]" Action
    | Action "|-|" Action
    | Action "[|" NSExp "|" CSExp "|" NSExp "|]" Action
    | Action "[|" CSExp "|]" Action    [strict(2)]

  //syntax CParameters ::= List {CParameter, ""}
  //By now, only one parameter at a time
  //syntax Comm ::= Id CParameter | Id  
  //syntax CParameter ::= "?" Id | "?" Id ":" Pred | "!" Exp [strict]  | "." Exp
  syntax Comm ::= Id | Id "?" Id | Id "!" Exp [strict(2)]
  
  
  
  syntax Command ::= Id ":=" Exp [strict(2)]
    | "if" GActions "fi"
    | "end" Id
    | "wait" Int Int
    | "par" Set
    
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

  syntax KResult ::= Int | Set

  configuration
    <top>
      <procs>
        <proc color="green" multiplicity="*"> 
          <main> false </main>
          <k>$PGM:K</k>
          <parent>0</parent>
          <id>0</id>
          <alt>0</alt>
          
          <leafs>
          <leaf multiplicity="*">
            <left> true </left>
            <cid> 0 </cid>
            <sync> .List </sync>
          </leaf>
          </leafs>
              
          <env> .Map </env>
          <store> .Map </store>
          <syncset> .Set </syncset>
          
          <ok> .Map </ok>
          <in> .Map </in>
          
          <tr> .List </tr>
        </proc>
      </procs>
      <nextloc> 0 </nextloc>
      <nextid> 1 </nextid>
      <ch> .Map </ch>
      <chset> .Map </chset>
      <procref> .Map </procref>      
      <tempset> .Set </tempset>
    </top>

  syntax KItem ::= "undefined"

  //Operational semantics according to RR1567
  
  // Var assignment (OPS 6)
  rule <k> V:Id := E:Exp => Skip ... </k>
    <nextloc> L => L +Int 1 </nextloc>
    <env> Env => Env[V <- L] </env>
    <store>... .Map => L |->  E ...</store>
    
  //Comm output (OPS 9,10,14)
  //Insted of processing it all, I just break it into comm
  //followed by the action. The comm is handled by the next
  //k rule named "labeled ouput progress", the action goes
  //on by itself
  rule <k> C:Comm -> A:Action => C ~> A ...</k>  
  
  // Once in the top of k cell, the communication is computed
  // according the following rules:
  
 
   
  /*///Labeled var output communication (OPS 9)
    For an output suffixed by an expression, first we heat
    the expression until a result (Int) is found.  
    The original rule requires a symbolic output 
  *///   
  /*rule <k> C:Id ! E:Exp  => .  ...</k>
    <main>true</main>    
    <ch> ... C |-> _ ... </ch>
    <tr> ... . => ListItem(C) ListItem("!") ListItem(E) </tr>
    when isKResult(E)  //not sure why, but it enforces the strictness
*/
            
        

  
  /*/// Labeled input communication (OPS 10)
    For an input suffixed by a var name
    It causes a new variable declaration 
    The type is not treated yet, just for integers
    The rule only converts it to a var declaration
    with the given name followed by the corresponding
    assignement with the given value
    It produces an output
  *///
  /*rule <k> C:Id ? V:Id  => var V @ V := (?V:Int)  ...</k> 
    <syncset> SyncSet </syncset>
    <ch> ... C |-> _ ... </ch>
    <tr> ... . => ListItem(C) ListItem("?") ListItem(?V) </tr>
    when (boolNot (C in SyncSet))*/
    
    
  /*///Labeled output synchronization (OPS 14)
    For events (channel name), check it against the
    the channel declarations and, if it is correct, output it    
  *///
  //rule <k> C:Id => . ...</k>
  //  <ch> ... C |-> _ ... </ch>
  //  <tr> ... . => ListItem(C)  </tr>
  
  rule <proc>...
      <k> C:Id  ...</k>
      <ch> ... C |-> _ ... </ch>
      <in> ... C |-> L => C |-> (L +Int 1)  ...</in>
    ...</proc>
    requires (notBool (C in Out))

  rule <proc>...
    <k> C:Id => . ...</k>
    <ch> ... C |-> _ ... </ch>
    <in> ... C |-> L => C |-> (L +Int 1) ...  </in>
    <ok> ... C |-> K => C |-> (K +Int 1) ... </ok>  
    ...</proc>

  rule  <proc>...
      <main> true </main>
      <in>... C |-> L  ...</in>
      <ok>... C |-> K => C |-> (K +Int 1)</ok>
      <tr> ... . => ListItem(C)  </tr>
    ...</proc>
    requires (L >Int 0)


  rule 
    <proc>...
      <id> PId </id>
      <k> par S:Set ... </k>
      <in> Out => Out SetItem(C) </in>
    ...</proc>
    <proc>...
      <parent> PId </parent>
      <in>... SetItem(C) ...</in>
    ...</proc>
    requires (notBool (C in Out))    
    
  rule
    <ch>Ch</ch> 
    <procs>...
      <proc>
      ...
        <id> PId </id>
        <k> par S:Set ... </k>
        <out> POut SetItem(C)  => POut .Set  </out>
        <in> PIn SetItem(C) => PIn .Set </in>
      ...
      </proc>
      <proc>...
        <parent> PId </parent>
//        <id> CId:Int </id>
        <out> ... SetItem(C) ... </out>
        <in> ... .Set =>  SetItem(C) ... </in>
      ...</proc>
    ...</procs>
    when C in keys(Ch)
    
    

    
    
  /*/// Variable declaration (OPS 11)
    It declares a variable in the scope
    of the action A.
    In K, we don't use the keyword let, as in the OPS
    we keep track of the variables in the env container
  *///    
  rule <k> var V:Id @ A:Action => A ...</k> 
    <nextloc> L => L +Int 1 </nextloc>
    <env> Env => Env[V <- L] </env>
    <store>... .Map => L |-> undefined ...</store>


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
  rule <k> Skip ~> A:Action => A ... </k>
  rule <k> A1:Action ; A2:Action => A1 ~> A2 ... </k>


  /*/// Variable removal (OPS 13)
  "end X" rule
  *///
  //rule <k> Skip => . ... </k>
  //<env> Env => .Map </env>
  //can't do it yet  :(
  //the computation goes all the way, always
  

  
  /*/// Internal choice (OPS 16)
  Straightforward as it can be, c'est comme ci ou comme ??a
  The only utterly important point is to mark it as a transition
  so the k framework can backtrack it and try different solutions
  *///      
  rule <k> A1:Action |-| A2:Action => A1 ... </k> [transition]
  rule <k> A1:Action |-| A2:Action => A2 ... </k> [transition]  
  
  /*///External choice (OPS 18)
  Copy the environment into two new threads with fresh ids
  Put the current thread on hold, waiting for any of new threads
  Each new thread computes with each eaction of the choice
  The threads will block as soon as they reach an observable event
  */// 
   rule <k> A1:Action [] A2:Action => wait (L +Int 1) (L +Int 2) ... </k>
    <nextid> L => L +Int 2 </nextid>
    <id> ParId </id>
    <env> Env </env>
    <store> Store </store>
    (.Bag => 
      <proc>...
        <k> A1 </k>
        <parent> ParId </parent>
        <id> (L +Int 1) </id>
        <alt> (L +Int 2) </alt>
        <env> Env </env>
        <store> Store </store>
      ...</proc>
      <proc>...
        <k> A2 </k>
        <parent> ParId </parent>        
        <id> (L +Int 2) </id>
        <alt> (L +Int 1) </alt>
        <env> Env </env>
        <store> Store </store>        
      ...</proc>)
      
  /*/// External choice branch termination (OPS 19, 20)
  The thread waiting for the choice will continue
  As soon as one of them finishes with a clean Skip
  The environment is copied bach to the parent thread
  *///
  rule <k> wait P1:Int P2:Int => . ... </k> 
    <env> _ => Env </env>
    <store> _ => Store </store>
    <tr> ... . =>  Trace </tr>
      <proc> ...
        <id>P1</id>
        <k>Skip</k>
        <tr> Trace </tr>
        <env> Env </env>
        <store> Store </store>
      ...</proc>
   [transition] 
   //As both branches may finish at the same time,
   //it is marked as a transition for ND check
  

//Idea to use holes.. failed!
//   rule <k> A1:Action [|CSet:Set|] A2:Action => A1 ~> #HOLE [|CSet|] A2 ...</k> [heat]
//   rule <k> A1:Action [|CSet:Set|] A2:Action => A2 ~> A1 [|CSet|] HOLE ...</k> [heat]
//   rule <k> A1:Action ~> HOLE [|CSet:Set|] A2:Action => A1 [|CSet|] A2 ...</k> [cool]
//   rule <k> A2:Action ~> A1:Action [|CSet:Set|] HOLE => A1 [|CSet|] A2 ...</k> [cool]   


   rule <k> A1:Action [|CSet:Set|] A2:Action => par (SetItem(L +Int 1) SetItem(L +Int 2)) ... </k>
    <nextid> L => L +Int 2 </nextid>
    <id> ParId </id>
    <env> Env </env>
    <store> Store </store>
    (.Bag => 
      <proc>...
        <k> A1 </k>
        <parent> ParId </parent>
        <id> (L +Int 1) </id>
        <alt> (L +Int 2) </alt>
        <env> Env </env>
        <store> Store </store>
      ...</proc>
      <proc>...
        <k> A2 </k>
        <parent> ParId </parent>        
        <id> (L +Int 2) </id>
        <alt> (L +Int 1) </alt>
        <env> Env </env>
        <store> Store </store>        
      ...</proc>)

    


  
  //------------------
  
  //fix process paragraph order
  rule <k> begin @ Pa:ParAction end => 
    Pa ... </k>

  //process "processing" :)
  //the old version let PD in the cell
  rule <k> process P:Id ^= PD:ProcDef  => . ...</k>
    <procref>... .Map => P |-> PD ...</procref>



//Skip all the set processing and use the so called shallow embedding
  rule <k> {| Xi:Id, Xs:CommaIds |} => {| Xs |} ... </k> 
    <tempset> ... . => SetItem(Xi) </tempset>
  rule <k> {| .CommaIds |} => TempSet ... </k> 
    <tempset> TempSet => .Set </tempset> 
  rule <k>chanset CSName:Id == CSet:Set => . ... </k>
    <chset>... .Map => CSName |-> CSet </chset>
  rule <k> CSetId:Id => CSet ...</k>
    <chset>... CSetId |-> CSet:Set ...</chset>    

  
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
 

  //load a stored process into the k computation cell
  rule <k> :run ProcId:Id => Proc ... </k>
       <main> _ => true </main>
       <id> _ => 1 </id>
       <procref> ... ProcId |-> Proc ... </procref>

  
  
  rule I1:Int + I2:Int
  => I1 +Int I2
  rule I1:Int * I2:Int
  => I1 *Int I2  
  rule <k> X:Id => I ...</k> <env>... X |-> L ...</env>
       <store>... L |-> I ...</store>
       

endmodule
