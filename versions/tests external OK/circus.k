/*///
This is a tentative to write syntax and semantics to circus in K
the command line to build it and run a pretty-printed example is:
  $rm -rf circus-kompiled/ && kompile circus.k && krun \
  teste.circus   | xmllint --format -

K-framework used to test was a nightly built version 4
*///

module CIRCUS-SYNTAX
imports SET
imports LIST
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
//  syntax SimpleCDecls ::= List{SimpleCDecl, ","}    
  syntax SimpleCDecl ::= Id | Id ":" ZExp
  syntax MultiCDecl ::= SimpleCDecl | SimpleCDecl "," MultiCDecl
  syntax CompleteCDecl ::= "channel" MultiCDecl

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
    | Action "[|" CSExp "|]" Action  [strict(2)]
    | Action "|||" Action    

  //syntax CParameters ::= List {CParameter, ""}
  //By now, only one parameter at a time
  //syntax Comm ::= Id CParameter | Id  
  //syntax CParameter ::= "?" Id | "?" Id ":" Pred | "!" Exp [strict]  | "." Exp
  syntax Comm ::= Id | Id "?" Id | Id "!" Exp [strict(2)] | Id "??" Exp
  
  
  
  syntax Command ::= Id ":=" Exp [strict(2)]
    | "if" GActions "fi"
    | "end" Id
    | "choice" Set
    | "par" List Set
    | "return"

    
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
          <k>$PGM:K</k>
          <act> .Map </act>
          <id>0</id>
          <alt>0</alt>
          <parent>0</parent>
          <env> .Map </env>
          <stack> .List </stack>
          <sync>false</sync>
        </proc>
      </procs>
          <inits>
            <init multiplicity="*">
              <iresp> 0 </iresp>
              <iev> .K </iev>
              <from> .Set </from>
              <ialt> .Set </ialt>              
            </init>
          </inits>
          <oks>
            <ok multiplicity="*">
              <oev> .K </oev>
              <to> .Set </to>
            </ok>
          </oks>      
      <nextid> 1 </nextid>
      <ch> .Map </ch>
      <chset> .Map </chset>
      <procref> .Map </procref> 
      <kill> .Set </kill>
      <tempset> .Set </tempset>
      <tr> .K </tr>
    </top>

  syntax KItem ::= "undefined"

  //Operational semantics according to RR1567

  // Var assignment (OPS 6)
  rule <k> V:Id := E:Exp => Skip ... </k>
    <env> Env => Env[V <- E] </env>
  when isKResult(E)

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
    <ch> ... C |-> _ ... </ch>
    <tr> ... . => ListItem(C) ListItem("!") ListItem(E) </tr>    
    when isKResult(E)  //not sure why, but it enforces the strictness
  //RULE OK FOR SINGLE PROC
  */
  
  
      
  //rule <sync>Sync</sync>
  //  <id>PId:Int</id><alt>PAlt:Int</alt>    
  //  when isKResult(E)  //not sure why, but it enforces the strictness
  //    andBool (PId ==Int PAlt)         
  
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
    <ch> ... C |-> _ ... </ch>
    <tr> ... . => ListItem(C) ListItem("?") ListItem(?V) </tr>*/
    
  /*///Labeled output synchronization (OPS 14)
    For events (channel name), check it against the
    the channel declarations and, if it is correct, output it    
  *///
  //rule <k> C:Id => . ...</k>
  //  <ch> ... C |-> _ ... </ch>
  //  <tr> ... . => ListItem(C)  </tr>
  //RULE OK FOR SINGLE PROCESS  
  

  rule //LAST SKIP OK
    <id>0</id>
    <k>Skip => .</k>
    <tr>... . => Skip </tr>
    
    
//////////////////STRUCTURAL CLEANING//////////////////    
  rule //CLEAR EMPTY OKS (IT WORKS ONLY ON K4, not on beta) 
      <oks>
       (<ok>... <to>.Set</to> ...</ok> => .Bag)
      ...</oks>
  rule // REMOVE INITS FROM DEAD PROCESSES
    <kill>Kill</kill>
    <inits>...
      (<init>... <from> From </from> ...</init> => .Bag)
    ...</inits>
    requires (From <=Set Kill)

  rule // REMOVE DEAD PROCESSES
    <kill> ... SetItem(PId) ... </kill>
    <procs>...
      <proc>...
        <id>PId</id>
      ...</proc> => .Bag
    ...</procs>

  rule // REMOVE ORPHANS
    <kill> Kill SetItem(PId:Int) => SetItem(PId) Kill SetItem(Orphan) </kill>
    <procs>...
      <proc>...
        <id>Orphan:Int</id>
        <parent>PId</parent>
      ...</proc> => .Bag
    ...</procs>      
    
       
//////////////////START OBSERVABLE COMM//////////////////
  rule //START EV
    <k> C:Id ... </k>
    <sync> false => true </sync>
    <id>PId:Int</id>
    <ch> ... C |-> _ ... </ch>
    <inits>...
    .Bag => <init> <ialt> .Set </ialt> <iresp>PId</iresp>
              <iev>C</iev>  <from>SetItem(PId)</from>
            </init>
    </inits> [transition]
    
  rule //START INPUT
    <k> C:Id ? V:Id ... </k>
    <sync> false => true </sync>
    <id>PId:Int</id>
    <ch> ... C |-> _ ... </ch>
    <inits>...
    .Bag => <init> <ialt> .Set </ialt> <iresp>PId</iresp>
              <iev>C ? V</iev>  <from>SetItem(PId)</from>
            </init>
    </inits>
    [transition]    
    
  rule //START OUTPUT
    <k> C:Id ! E:Exp ... </k>
    <sync> false => true </sync>
    <id>PId:Int</id>
    <ch> ... C |-> _ ... </ch>
    <inits>...
    .Bag => <init> <ialt> .Set </ialt> <iresp>PId</iresp>
              <iev>C:Id ! E:Exp</iev>  <from>SetItem(PId)</from>
            </init>
    </inits>
    when isKResult(E)  //not sure why, but it enforces the strictness
    [transition]
    
//////////////////PROCEED OBSERVABLE COMM//////////////////
    
  rule //PROCEED EV OK
    <k> C:Id => . ... </k>
    <sync> true => false </sync>
    <id>PId:Int</id>
    <ch> ... C |-> _ ... </ch>
    <oks>... (<ok> <oev>C:Id</oev>  <to>... SetItem(PId) => .Set ...</to> </ok>) ... </oks>
    
  rule //PROCEED INPUT OK
    <k> C:Id ? V:Id  => var V @ V := Val  ...</k> 
    <sync> true => false </sync>
    <id>PId:Int</id>
    <ch> ... C |-> _ ... </ch>
    <oks>... (<ok> <oev>C:Id ! Val:Exp</oev>  <to>... SetItem(PId) => .Set ...</to> </ok>) ... </oks>            
    
  rule //PROCEED OUTPUT OK
    <k> C:Id ! E:Exp => . ... </k>
    <sync> true => false </sync>
    <id>PId:Int</id>
    <ch> ... C |-> _ ... </ch>
    <oks>... (<ok> <oev>C:Id ! E:Exp</oev>  <to>... SetItem(PId) => .Set ...</to> </ok>) ... </oks>    
    
  
//////////////////EXECUTE TRACE OBSERVABLE COMM////////////

  rule //EXECUTE EV 
    <id>0</id> 
    <inits> 
      (<init>...
        <iresp>0</iresp>
        <ialt>Alt</ialt>
        <iev>C:Id</iev>  
        <from>FSet</from>
      </init> => .Bag) 
    ... </inits>
    <oks>... 
      (.Bag => <ok> <oev>C</oev> <to>FSet -Set Kill</to> </ok>)
    ... </oks>
    <tr>... . => C </tr>
    <kill>Kill => Kill Alt</kill>
    requires notBool (size(FSet -Set Kill) ==Int 0)
    
  rule //EXECUTE INPUT
    <id>0</id> 
    <inits> 
      (<init>...
        <iresp>0</iresp>
        <ialt>Alt</ialt>
        <iev>C:Id ? _</iev>  
        <from>FSet</from>
      </init> => .Bag) 
    ... </inits>
    <oks>... 
      (.Bag => <ok> <oev>C ! ?V:Int</oev> <to>FSet -Set Kill</to> </ok>)
    ... </oks>
    <tr>... . => C ?? (?V) </tr>
    <kill>Kill => Kill Alt</kill>
    requires (notBool (size(FSet -Set Kill) ==Int 0))    

  rule //EXECUTE OUTPUT
    <id>0</id> 
    <inits> 
      (<init>...
        <iresp>0</iresp>
        <ialt>Alt</ialt>
        <iev>C:Id ! E:Exp</iev>  
        <from>FSet</from>
      </init> => .Bag) 
    ... </inits>
    <oks>... 
      (.Bag => <ok> <oev>C ! E</oev> <to>FSet -Set Kill</to> </ok>)
    ... </oks>
    <tr>... . => C ! E </tr>
    <kill>Kill => Kill Alt</kill>
    requires notBool (size(FSet -Set Kill) ==Int 0)
    

//////////////////PAR COMPOSITION FWD AND SYNC   ////////////
    
  rule //FORWARD PAR NO SYNC EVENT
    <proc>...
      <id>CId:Int</id>
      <parent>PId:Int</parent>
    ...</proc>
    <proc>...
      <id>PId</id>
      <k> par _:List CSet:Set ... </k>
    ...</proc>
    <inits>... 
      <init>...<iresp>CId => PId</iresp> <iev>C:Id ...</iev>...</init>
    ... </inits> 
    requires notBool (C in CSet)
    
  rule //FORWARD PAR NO SYNC INPUT
    <proc>...
      <id>CId:Int</id>
      <parent>PId:Int</parent>
    ...</proc>
    <proc>...
      <id>PId</id>
      <k> par _:List CSet:Set ... </k>
    ...</proc>
    <inits>... 
      <init>...<iresp>CId => PId</iresp> <iev>C:Id ? _</iev>...</init>
    ... </inits> 
    requires notBool (C in CSet)    
    
  rule //FORWARD PAR NO SYNC OUPUT
    <proc>...
      <id>CId:Int</id>
      <parent>PId:Int</parent>
    ...</proc>
    <proc>...
      <id>PId</id>
      <k> par _:List CSet:Set ... </k>
    ...</proc>
    <inits>... 
      <init>...<iresp>CId => PId</iresp> <iev>C:Id ! _</iev>...</init>
    ... </inits> 
    requires notBool (C in CSet)    
    
   
  rule //SYNC EQ EV
    <proc>...
      <id>LId:Int</id>
      <parent>PId:Int</parent>
    ...</proc>
    <proc>...
      <id>RId:Int</id>
      <parent>PId:Int</parent>
    ...</proc>    
    <proc>...
      <id>PId</id>
      <k> par ParList:List CSet:Set ... </k>
    ...</proc>
    <inits>... 
      <init>... <iresp>LId => PId</iresp> <iev>C:Id ...</iev> <ialt> LAlt => LAlt RAlt </ialt>
        <from> LFrom => LFrom RFrom </from>  
      ...</init>
      (<init>... <iresp>RId</iresp> <iev>C ...</iev> <ialt> RAlt </ialt> <from>RFrom</from> ... </init> => .Bag)
    ... </inits> 
    requires (C in CSet)
    
  rule //SYNC EQ INPUT
    <proc>...
      <id>LId:Int</id>
      <parent>PId:Int</parent>
    ...</proc>
    <proc>...
      <id>RId:Int</id>
      <parent>PId:Int</parent>
    ...</proc>    
    <proc>...
      <id>PId</id>
      <k> par ParList:List CSet:Set ... </k>
    ...</proc>
    <inits>... 
      <init>... <iresp>LId => PId</iresp> <iev>C:Id ? _</iev> <ialt> LAlt => LAlt RAlt </ialt>
        <from> LFrom => LFrom RFrom </from>  
      ...</init>
      (<init>... <iresp>RId</iresp> <iev>C ? _</iev> <ialt> RAlt </ialt> <from>RFrom</from> ... </init> => .Bag)
    ... </inits> 
    requires (C in CSet)    
    

  rule //SYNC EQ OUTPUT
    <proc>...
      <id>LId:Int</id>
      <parent>PId:Int</parent>
    ...</proc>
    <proc>...
      <id>RId:Int</id>
      <parent>PId:Int</parent>
    ...</proc>    
    <proc>...
      <id>PId</id>
      <k> par ParList:List CSet:Set ... </k>
    ...</proc>
    <inits>... 
      <init>... <iresp>LId => PId</iresp> <iev>C:Id ! E:Exp</iev> <ialt> LAlt => LAlt RAlt </ialt>
        <from> LFrom => LFrom RFrom </from>  
      ...</init>
      (<init>... <iresp>RId</iresp> <iev>C ! E</iev> <ialt> RAlt </ialt> <from>RFrom</from> ... </init> => .Bag)
    ... </inits> 
    requires (C in CSet)
    
   
  rule //SYNC INPUT OUTPUT
    <proc>...
      <id>LId:Int</id>
      <parent>PId:Int</parent>
    ...</proc>
    <proc>...
      <id>RId:Int</id>
      <parent>PId:Int</parent>
    ...</proc>    
    <proc>...
      <id>PId</id>
      <k> par ParList:List CSet:Set ... </k>
    ...</proc>
    <inits>... 
      <init>... <iresp>LId => PId</iresp> <iev>C:Id ! E:Exp</iev> <ialt> LAlt => LAlt RAlt </ialt>
        <from> LFrom => LFrom RFrom </from>  
      ...</init>
      (<init>... <iresp>RId</iresp> <iev>C:Id ? _</iev> <ialt> RAlt </ialt> <from>RFrom</from> ... </init> => .Bag)
    ... </inits> 
    requires (C in CSet)    
    

//////////////////EXTERNAL CHOICE INITIALS FORWARD////////////
    
  rule //EXTCH FWD LEFT
    <proc>...
      <id>PId</id>
      <k> choice SetItem(LId) SetItem(RId) ... </k>
    ...</proc>
    <inits>... 
      <init>... <iresp>RId => PId</iresp> <ialt>... .Set => SetItem(LId) ...</ialt>  ... </init>
    ... </inits>
  rule //EXTCH FWD RIGHT 
    <proc>...
      <id>PId</id>
      <k> choice SetItem(RId) SetItem(LId) ... </k>
    ...</proc>
    <inits>... 
      <init>... <iresp>RId => PId</iresp> <ialt>... .Set => SetItem(LId) ...</ialt>  ... </init>
    ... </inits>       
    



//------------------------
   rule <k> A1:Action ||| A2:Action => A1:Action [|.Set|] A2:Action ... </k> [structural]

   rule <k> A1:Action [|CSet:Set|] A2:Action => par ListItem(L +Int 1) ListItem(L +Int 2) CSet ... </k>
    <nextid> L => L +Int 2 </nextid>
    <id> ParId </id>
    <env> Env </env>
    (.Bag => 
      <proc>...
        <k> A1 </k>
        <parent> ParId </parent>
        <id> (L +Int 1) </id>
        <alt> (L +Int 2) </alt>
        <env> Env </env>
      ...</proc>
      <proc>...
        <k> A2 </k>
        <parent> ParId </parent>        
        <id> (L +Int 2) </id>
        <alt> (L +Int 1) </alt>
        <env> Env </env>
      ...</proc>)    


  rule //CLEAN FINISHED PARALLELS
    (<proc>...
      <id>LId:Int</id>
      <k> Skip </k>
      <parent>PId:Int</parent>
    ...</proc> => .Bag )
    (<proc>...
      <id>RId:Int</id>
      <k> Skip </k>      
      <parent>PId:Int</parent>
    ...</proc> => .Bag )
    <proc>...
      <id>PId</id>
      <k> par ListItem(LId) ListItem(RId) CSet:Set => Skip ... </k>
    ...</proc>


  /*/// Variable declaration (OPS 11)
    It declares a variable in the scope
    of the action A.
    In K, we don't use the keyword let, as in the OPS
    we keep track of the variables in the env container
  *///    
  rule <k> var V:Id @ A:Action => A ...</k> 
    <env> Env => Env[V <- undefined] </env>


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
  Straightforward as it can be, c'est comme ci ou comme ça
  The only utterly important point is to mark it as a transition
  so the k framework can backtrack it and try different solutions
  *///      
  rule <k> A1:Action |-| A2:Action => A1 ... </k> [transition]
  rule <k> A1:Action |-| A2:Action => A2 ... </k> [transition]  
  
  //External attempt
  rule <k> A1:Action [] A2:Action => choice SetItem(L +Int 1) SetItem(L +Int 2) ... </k>
    <nextid> L => L +Int 2 </nextid>
    <id>PId:Int</id>
    <env> Env </env>
    (.Bag => 
      <proc>...
        <k> A1 </k>
        <parent>PId</parent>
        <env> Env </env>        
        <id> (L +Int 1) </id>
        <alt> (L +Int 2) </alt>
      ...</proc>
      <proc>...
        <k> A2 </k>
        <env> Env </env>        
        <id> (L +Int 2) </id>
        <alt> (L +Int 1) </alt>
        <parent>PId</parent>        
      ...</proc>)
      
  rule 
    <procs>...
      <proc>...
        <id>PId:Int</id>
        <k> choice _ => Skip ... </k> 
        <env> _ => Env </env>
      ...</proc>
      (<proc> ...
        <id>P1:Int</id>
        <parent>PId</parent>
        <alt>AId:Int</alt>
        <k>Skip</k>
        <env> Env </env>
      ...</proc> => .Bag)
    ...</procs>
   <kill>... .Set => SetItem(AId) ...</kill>
   [transition]
   


  //Rule for named actions (No OPS)
  rule <k> A:Id => B ~> return  ...</k>
  <act> ... A |-> B ... </act>
  <env> Env => .Map </env>
  <stack> . => ListItem(Env) ... </stack>

  rule <k>  return => .  ...</k>
  <env> _ => Env </env>
  <stack> ListItem(Env) => .List ... </stack>  
  
  
  //------------------
  
  //fix process paragraph order
  rule <k> begin @ Pa:ParAction end =>  Pa ... </k>
  rule <k>  begin P:PPars  @ A:ParAction end => P ~> A ... </k>    
  //ok  
  
  //load process named actions
  rule <k>  N:Id ^= A:CSPAction => . ... </k>
    <act> ... .Map => N |-> A ... </act>
  //ok    

  //process "processing" :)
  //the old version let PD in the cell
  rule <k> process P:Id ^= PD:ProcDef  => . ...</k>
    <procref>... .Map => P |-> PD ...</procref>
  //ok    


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
  rule <k> channel C:Id : Type:Id => . ...</k>
    <ch> ... .Map => C |-> Type ...</ch>
  rule <k> channel C:Id => . ...</k>
    <ch> ... .Map => C |-> undefined ...</ch>
  //ok
  
  //tried to desugar multiple channel declarations, failed :(
  //TODO: update report
  rule channel S:SimpleCDecl , M:MultiCDecl => channel S  channel M [structural]


  //sequential processing of circus paragraphs
  rule P1:CircusPar P2:CircusPars => P1 ~> P2 [structural]
  rule P1:PPar P2:PPars => P1 ~> P2 [structural]  
  //ok

  //load a stored process into the k computation cell
  rule <k> :run ProcId:Id => Proc ... </k>
       <procref> ... ProcId |-> Proc ... </procref>
  //ok       

  
  
  rule I1:Int + I2:Int
  => I1 +Int I2
  rule I1:Int * I2:Int
  => I1 *Int I2  
  rule <k> X:Id => I ...</k> <env>... X |-> I ...</env>


endmodule
