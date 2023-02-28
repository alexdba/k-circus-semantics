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
  /*syntax Exp ::= Int
    | "(" Exp ")" [bracket]
    | Exp "+" Exp [seqstrict] //addition
    | Id*/
    
  syntax Exp ::= Int |  Id
               | "(" Exp ")"             [bracket]
               > left:
                 Exp "*" Exp             [strict, left]
               | Exp "/" Exp             [strict, left]
               | Exp "%" Exp             [strict, left]
               > left:
                 Exp "+" Exp             [strict, left]
               | Exp "-" Exp             [strict, left]
               
  syntax BoolExp ::=  Bool
               | "(" BoolExp ")"         [bracket]
               > Exp "<" Exp             [strict, non-assoc]
               | Exp "<=" Exp            [strict, non-assoc]
               | Exp ">" Exp             [strict, non-assoc]
               | Exp ">=" Exp            [strict, non-assoc]
               | Exp "==" Exp            [strict, non-assoc]
               | Exp "!=" Exp            [strict, non-assoc]
               > "not" BoolExp           [strict]
               > left:
                 BoolExp "&&" BoolExp    [strict(1), left]
               | BoolExp "||" BoolExp    [strict(1), left]


  syntax Type ::= "sync" | "int"    
    
  syntax CommaIds ::= List{Id, ","}
    
  syntax Program ::= CircusPars
  syntax CircusPars ::= CircusPar | CircusPar CircusPars
  syntax CircusPar ::= ZParagraph
    | CompleteCDecl
    | "chanset" Id "==" CSExp [strict(2)]
    | ProcDecl
    | ":run" Id //choose the main process

  syntax SimpleDecl ::= Id | Id ":" Type
//  syntax MultiDecl ::= SimpleDecl | SimpleDecl "," MultiDecl
  syntax CompleteCDecl ::= "channel" MultiDecl
  syntax MultiDecl ::= List{SimpleDecl, ","}

  syntax CSExp ::= Set | Set CSExp | "{||}" | "{|" CommaIds "|}" | Id | CSExp "U" CSExp | CSExp "T" CSExp | CSExp "/E" CSExp
  syntax NSExp ::= "{}" | "{" Id "}" | Id | NSExp "U" NSExp | NSExp "T" NSExp | NSExp "/E" NSExp
  
  syntax ProcDecl ::= "process" Id "^=" ProcDef
  syntax ProcDef ::= 
//    "begin" "state" SchemaExp PPars  "@" ParAction "end"
//    | "begin" "state" SchemaExp  "@" ParAction "end"
     "begin" PPars  "@" ParAction "end"
    | "begin" "@" ParAction "end"

    
  syntax PPar ::= ZParagraph | Id "^=" ParAction | "nameset" Id "==" NSExp
  syntax PPars ::= PPar | PPar PPars  

  syntax ParAction ::= CSPAction | SchemaExp
  syntax CSPAction ::=  "Skip" | "Stop" | "Chaos"
    | "(" Action ")"               [bracket]  
    | Command    
    > Comm "->" Action [right]
    | "var" Id "@" Action
    >  BoolExp "&" Action [strict(1)]
    //| "u" Id "@" Action
    > left:
      Action "/H" CSExp [strict(2)]
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
    | "hide" Int Set    
    | "return"

    
  syntax GActions ::= Pred "-->" Action | Pred "-->" Action "[]" GActions

  
  syntax Action ::= SchemaExp | Command | Id | CSPAction

//-------------------------------------
  syntax SchemaExp ::= Schema
  syntax Schema ::= "[" MultiDecl "]"
                  | "[" MultiDecl "|" BoolExp "]"  
  
  syntax ZParagraph ::= Id "==" SchemaExp 
                      | "state" SchemaExp
                      | "state" BoolExp [strict]
  
  syntax ZExp ::= "zexp"Exp
  syntax Pred  ::= "pred" Id
  syntax Decl ::= Id

  
  syntax Val ::= Int | Set | Bool

endmodule


module CIRCUS
  imports CIRCUS-SYNTAX

  syntax KResult ::= Val

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
          <state> .Map </state>
          <inv> .K </inv>
          <stack> .List </stack>
          <sync>false</sync>
          <const>true</const>
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
      <deadlock> .Set </deadlock>
      <tempset> .Set </tempset>
      <tr> .K </tr>
    </top>

  syntax KItem ::= "undefined"

  //Operational semantics according to RR1567

///////////////////////////////////////////////////////   
//////////////////STRUCTURAL CLEANING//////////////////
///////////////////////////////////////////////////////
  /*
  The rules in this section have structural purposes,
  like cleaning the initial/ok/sync tree structures
  or marking end of successful executions.
  There is absolutely no relation between them and the OPS
  **************************************************/    
  rule //CLEAR EMPTY OKS (IT WORKS ONLY ON K4, not on beta) 
      <oks>
       (<ok>... <to>.Set</to> ...</ok> => .Bag)
      ...</oks>
  rule // REMOVE INITS FROM DEAD PROCESSES
    <deadlock>Kill</deadlock>
    <inits>...
      (<init>... <from> From </from> ...</init> => .Bag)
    ...</inits>
    requires (From <=Set Kill)

  rule // REMOVE DEAD PROCESSES
    <deadlock> ... SetItem(PId) ... </deadlock>
    <procs>...
      <proc>...
        <id>PId</id>
      ...</proc> => .Bag
    ...</procs>
    
  /*rule // REMOVE DEADLOCKED HIDING HUBS
    <deadlock> ... SetItem(CId) ... </deadlock>
    <procs>...
      <proc>...
        <k> hide CId _:Set ...</k>
      ...</proc> => .Bag
    ...</procs>    */

  rule // REMOVE ORPHANS
    <deadlock>
      Kill SetItem(PId:Int) => SetItem(PId) Kill SetItem(Orphan) 
    </deadlock>
    <procs>...
      <proc>...
        <id>Orphan:Int</id>
        <parent>PId</parent>
      ...</proc> => .Bag
    ...</procs>      

  //Put a Skip in the end of the trace when the top level 
  //process reachesa finished successful execution configuration. 
  rule //LAST SKIP OK
    <id>0</id>
    <k>Skip => .</k>
    <tr>... . => Skip </tr>   
    
/////////////////////////////////////////////////////////       
//////////////////START OBSERVABLE COMM//////////////////
/////////////////////////////////////////////////////////
  /*
    When a communication is in the top of the K cell,
    the process will hold until it is ready to be executed.
    Taking this into consideration, once a communication is
    reached, no trace progress is instantly produced:
    we put the process on hold, using the <sync> flag,
    and we create an "initial", containing the
    required observable action <iev>,
    the id of the current process as the responsible <iresp>
    and also as a subscriber <from> of the outcome of
    such initial.
    This duplication is necessary since the initial will be
    forwarded to the top levels of the synchronization tree,
    and the current responsible for such initial will change
    after each forwarding step. Other subscribers may be
    added to the set <from>.
  **************************************************/

  rule //START EV (OPS 9 implicit)
    <k> C:Id ... </k>
    <sync> false => true </sync>
    <id>PId:Int</id>
    <ch> ... C |-> _ ... </ch>
    <inits>...
    .Bag => <init> 
              <iresp>PId</iresp>
              <iev>C</iev>
              <from>SetItem(PId)</from>
              <ialt> .Set </ialt>
            </init>
    </inits> [transition]
    
  rule //START INPUT (OPS 10)
    <k> C:Id ? V:Id ... </k>
    <sync> false => true </sync>
    <id>PId:Int</id>
    <ch> ... C |-> _ ... </ch>
    <inits>...
    .Bag => <init>
              <iresp>PId</iresp>
              <iev>C ? V</iev>
              <from>SetItem(PId)</from>
              <ialt> .Set </ialt> 
            </init>
    </inits>
    [transition]    

  /*///Labeled var output communication (OPS 9)
    For an output suffixed by an expression, first we heat
    the expression until a result (Int) is found.  
    The original rule requires a symbolic output.
  *///       
  rule //START OUTPUT (OPS 9)
    <k> C:Id ! E:Exp ... </k>   
    <sync> false => true </sync>
    <id>PId:Int</id>
    <ch> ... C |-> _ ... </ch>
    <inits>...
    .Bag => <init> 
              <iresp>PId</iresp>
              <iev>C:Id ! E:Exp</iev>
              <from>SetItem(PId)</from>
              <ialt> .Set </ialt> 
            </init>
    </inits>
    when isKResult(E)  //not sure why, but it enforces the strictness
    [transition]

///////////////////////////////////////////////////////////      
//////////////////PROCEED OBSERVABLE COMM//////////////////
///////////////////////////////////////////////////////////  
  /*
  The following rules concern processes that are
  on hold by the sync flag and waits for the outcome of
  an initial for performing the communication lying in 
  the top of its K cell.
  The resolution of an initial results in the production
  of an "ok" notification.
  Once existing one of those notifications:
    a) addressed (<to>) to the process 
    b) and matching the communication on hold (<oev>)
  we allow the process to continue:
    a) releasing the sync flag
    b) executing the comm in the top of the <k> cell
    c) removing the process itself from the set of <to> targets.  
  The ok notification is not removed, as there might be other
  targets in the <to> set.
  If the set became empty, a cleaning rule will remove it afterwards.
  **************************************************/
    
  rule //PROCEED EV OK (OPS 9 implicit)
    <k> C:Id => . ... </k>
    <sync> true => false </sync>
    <id>PId:Int</id>
    <oks>... 
      <ok>
        <oev>C:Id</oev>
        <to>... SetItem(PId) => .Set ...</to>
      </ok>
    ... </oks>


  /*/// Labeled input communication (OPS 10)
    For an input suffixed by a var name
    It causes a new variable declaration 
    The type is not treated yet, just for integers
    The rule only converts it to a var declaration
    with the given name followed by the corresponding
    assignment with the given value
  *///    
  rule //PROCEED INPUT OK (OPS 10)
    <k> C:Id ? V:Id  => var V @ V := Val  ...</k> 
    <sync> true => false </sync>
    <id>PId:Int</id>
    <oks>...
      <ok>
        <oev>C:Id ! Val:Exp</oev>
        <to>... SetItem(PId) => .Set ...</to>
      </ok>
    ...</oks>            
    
  rule //PROCEED OUTPUT OK (OPS 9)
    <k> C:Id ! E:Exp => . ... </k>
    <sync> true => false </sync>
    <id>PId:Int</id>
    <oks>... 
      <ok>
        <oev>C:Id ! E:Exp</oev>
        <to>... SetItem(PId) => .Set ...</to>
      </ok>
    ...</oks>    
    
///////////////////////////////////////////////////////////  
//////////////////EXECUTE TRACE OBSERVABLE COMM////////////
///////////////////////////////////////////////////////////
  /*
  When an initial is under the responsibility of the top
  level process (<id>0</id>) it is time to resolve it,
  i.e., to perform the observable action.

  Simple events synchronizations and outputs are just 
  appended to the trace as requested by the process node
  that posted it. For input, a symbolic value is produced
  and assigned to the name in the event.
 
  The solving of an initial generates an <ok> notification
  which is addressed <to> to all subscriber processes,
  as presented in the <from> set of the initial. We remove
  the targets that are known to be deadlocked: by subtracting
  the set <deadlocks> from the subscribers <from> set.
  
  If the initial is involved in an external choice, i.e.,
  it has a non-empty set of alternatives <alt> attached,
  it means that all the processes in this alternative set
  will also become deadlocked. So we add their ids in the
  <deadlock> set.
  
  Extra - Hiding:
  This section also covers a secondary situation: when an
  initial reaches an hiding hub and is recognized as 
  non-observable, e.g., the channel of the initial is in
  the hiding set of such hiding hub. In such case, the
  initial is treated as solved, but no trace output is produced.  

  *******************************************************/

  rule //EXECUTE EV (OPS 9 implicit)
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
    <deadlock>Kill => Kill Alt</deadlock>
    requires notBool (size(FSet -Set Kill) ==Int 0)
    

  /*
  Create a new symbolic value and forward it to the subscribing
  processes as an ok notification with an input
  */
  rule //EXECUTE INPUT (OPS 10)
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
    <deadlock>Kill => Kill Alt</deadlock>
    requires (notBool (size(FSet -Set Kill) ==Int 0))    

  rule //EXECUTE OUTPUT (OPS 9)
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
    <deadlock>Kill => Kill Alt</deadlock>
    requires notBool (size(FSet -Set Kill) ==Int 0)
    
  rule //EXECUTE HIDDEN EV (OPS 31)
    <proc>...
      <k>  hide CId:Int HSet:Set  ... </k>
      <id> PId:Int </id>
    ...</proc>
    <inits> 
      (<init>...
        <iresp>CId</iresp>
        <ialt>Alt</ialt>
        <iev>C:Id</iev>  
        <from>FSet</from>
      </init> => .Bag) 
    ... </inits>
    <oks>... 
      (.Bag => <ok> <oev>C</oev> <to>FSet -Set Kill</to> </ok>)
    ... </oks>
    <deadlock>Kill => Kill Alt</deadlock>
    requires notBool (size(FSet -Set Kill) ==Int 0) andBool (C in HSet)    
    
    
  rule //EXECUTE HIDDEN OUTPUT (OPS 31)
    <proc>...
      <k>  hide CId:Int HSet:Set  ... </k>
      <id> PId:Int </id>
    ...</proc>
    <inits> 
      (<init>...
        <iresp>CId</iresp>
        <ialt>Alt</ialt>
        <iev>C:Id ! E:Exp</iev>  
        <from>FSet</from>
      </init> => .Bag) 
    ... </inits>
    <oks>... 
      (.Bag => <ok> <oev>C ! E</oev> <to>FSet -Set Kill</to> </ok>)
    ... </oks>
    <deadlock>Kill => Kill Alt</deadlock>
    requires notBool (size(FSet -Set Kill) ==Int 0) andBool (C in HSet)    

///////////////////////////////////////////////////////////////////
/////PAR COMPOSITIONS:  FORWARDING AND SYNCING OF INITIALS ////////
///////////////////////////////////////////////////////////////////
  /*
  When a parallel composition reaches the top of the K cell,
  two new parallel K cells are spawned into children actions,
  each one containing the action of each side of the 
  original composition.
  
  The context of each new K cell complies all the 
  configuration elements from <proc>, as the 
  environment and the state. So, both new procs gets a copy
  of the current environment and state.
  Once spawned, they are free to execute independently until
  an observable event is reached and an initial is posted.
  
  The initials are threated differently inside a parallel
  composition: if a channel that is in the sync set is 
  concerned, we need to guarantee the synchronization.
  Since the channel is to be synchronized, an initial of
  a child only goes to the responsibility of the parent
  when it is matched by an second initial from the other
  side of the composition. When this happens,
  both initials are combined into a single one, holding
  both children ids as subscribers in the <from> set.
   
  We have rules to: simple forwarding of no synced initials,
  synchronization of events, inputs, outputs and the
  synchronization by matching inputs and outputs in the
  same channel. In the latter case, the value outputted
  by one side is taken as input in the other side.
  
  A parallel composition ends when both of its sides, i.e.,
  both children actions, reach a final Skip.
  
  
  ***************************************************************/

   //Just rewrite an interleave into a par
   //composition w/ empty sync set
   rule //INTERLEAVE STRUCTURAL
    <k> A1:Action ||| A2:Action 
      => A1:Action [|.Set|] A2:Action ... </k> [structural]

   rule //START PAR ACTIONS (OPS 25)
    <k> A1:Action [|CSet:Set|] A2:Action 
      => par ListItem(L +Int 1) ListItem(L +Int 2) CSet ... </k>
    <nextid> L => L +Int 2 </nextid>
    <id> ParId </id>
    <env> Env </env>
    <state> State </state>
    (.Bag => 
      <proc>...
        <k> A1 </k>
        <parent> ParId </parent>
        <id> (L +Int 1) </id>
        <alt> (L +Int 2) </alt>
        <env> Env </env>
        <state> State </state>
      ...</proc>
      <proc>...
        <k> A2 </k>
        <parent> ParId </parent>        
        <id> (L +Int 2) </id>
        <alt> (L +Int 1) </alt>
        <env> Env </env>
        <state> State </state>        
      ...</proc>)    


  rule //CLEAN FINISHED PARALLELS (OPS 26)
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
 
//-----FORWARDING
    
  rule //FORWARD PAR NO SYNC EVENT (OPS 27, 28)
    <proc>...
      <id>CId:Int</id>
      <parent>PId:Int</parent>
    ...</proc>
    <proc>...
      <id>PId</id>
      <k> par _:List CSet:Set ... </k>
    ...</proc>
    <inits>... 
      <init>...
        <iresp>CId => PId</iresp>
        <iev>C:Id ...</iev>
      ...</init>
    ... </inits> 
    requires notBool (C in CSet)
    
  rule //FORWARD PAR NO SYNC INPUT (OPS 27, 28)
    <proc>...
      <id>CId:Int</id>
      <parent>PId:Int</parent>
    ...</proc>
    <proc>...
      <id>PId</id>
      <k> par _:List CSet:Set ... </k>
    ...</proc>
    <inits>... 
      <init>...
        <iresp>CId => PId</iresp>
        <iev>C:Id ? _</iev>
      ...</init>
    ... </inits> 
    requires notBool (C in CSet)    
    
  rule //FORWARD PAR NO SYNC OUPUT (OPS 27, 28)
    <proc>...
      <id>CId:Int</id>
      <parent>PId:Int</parent>
    ...</proc>
    <proc>...
      <id>PId</id>
      <k> par _:List CSet:Set ... </k>
    ...</proc>
    <inits>... 
      <init>...
        <iresp>CId => PId</iresp>
        <iev>C:Id ! _</iev>
      ...</init>
    ... </inits> 
    requires notBool (C in CSet)    
    
   
  rule //SYNC EQ EV (OPS 29)
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
      <init>...
        <iresp>LId => PId</iresp>
        <iev>C:Id ...</iev>
        <ialt> LAlt => LAlt RAlt </ialt>
        <from> LFrom => LFrom RFrom </from>  
      ...</init>
      (<init>...
        <iresp>RId</iresp>
        <iev>C ...</iev>
        <ialt> RAlt </ialt>
        <from>RFrom</from>
      ... </init> => .Bag)
    ... </inits> 
    requires (C in CSet)
    
  rule //SYNC EQ INPUT (OPS 30)
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
      <init>... 
        <iresp>LId => PId</iresp>
        <iev>C:Id ? _</iev>
        <ialt> LAlt => LAlt RAlt </ialt>
        <from> LFrom => LFrom RFrom </from>  
      ...</init>
      (<init>... 
        <iresp>RId</iresp>
        <iev>C ? _</iev>
        <ialt> RAlt </ialt>
        <from>RFrom</from>
      ... </init> => .Bag)
    ... </inits> 
    requires (C in CSet)    
    

  rule //SYNC EQ OUTPUT (OPS 29)
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
      <init>...
        <iresp>LId => PId</iresp>
        <iev>C:Id ! E:Exp</iev>
        <ialt> LAlt => LAlt RAlt </ialt>
        <from> LFrom => LFrom RFrom </from>  
      ...</init>
      (<init>...
        <iresp>RId</iresp>
        <iev>C ! E</iev>
        <ialt> RAlt </ialt>
        <from>RFrom</from>
      ... </init> => .Bag)
    ... </inits> 
    requires (C in CSet)
    
   
  rule //SYNC INPUT OUTPUT (OPS 29)
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
      <init>...
        <iresp>LId => PId</iresp>
        <iev>C:Id ! E:Exp</iev>
        <ialt> LAlt => LAlt RAlt </ialt>
        <from> LFrom => LFrom RFrom </from>  
      ...</init>
      (<init>...
        <iresp>RId</iresp>
        <iev>C:Id ? _</iev>
        <ialt> RAlt </ialt>
        <from>RFrom</from>
      ... </init> => .Bag)
    ... </inits> 
    requires (C in CSet) 
    
       
    
///////////////////////////////////////////////////////////
//////////////////EXTERNAL CHOICE START AND FWD////////////
///////////////////////////////////////////////////////////
  /*
  When an observable event is an initial of any of the sides of
  an external choice, this two rules (left and right)
  forwards the initial to the upper levels, marking it with the
  id of the opposite side as the choice alternative.
  As soon as the initial is resolved, i.e., performed or hidden,
  the process which required it continues and all the marked
  alternatives deadlocks.
  We use a list of alternatives, since multiple nested external
  choices might trigger the continuation or deadlock of several
  processes by the very same initial.
  */
    
  rule //EXTCH FWD LEFT AND RIGHT (OPS 23,24)
    <proc>...
      <id>PId</id>
      <k> choice Set ... </k>
    ...</proc>
    <proc>...
      <id>CId</id>
      <parent>PId</parent>
      <alt>AId</alt>
    ...</proc>    
    <inits>... 
      <init>...
        <iresp>CId => PId</iresp>
        <ialt>... .Set => SetItem(AId) ...</ialt>
      ... </init>
    ... </inits>   
    
//------------------------

  rule //EXT CHOICE START (18)
    <k> A1:Action [] A2:Action
      => choice SetItem(L +Int 1) SetItem(L +Int 2) ... </k>
    <nextid> L => L +Int 2 </nextid>
    <id>PId:Int</id>
    <env> Env </env>
    <state> State </state>
    (.Bag => 
      <proc>...
        <k> A1 </k>
        <parent>PId</parent>
        <env> Env </env>        
        <state> State </state>
        <id> (L +Int 1) </id>
        <alt> (L +Int 2) </alt>
      ...</proc>
      <proc>...
        <k> A2 </k>
        <env> Env </env>
        <state> State </state>
        <id> (L +Int 2) </id>
        <alt> (L +Int 1) </alt>
        <parent>PId</parent>        
      ...</proc>)

  //Requires transition for the case both
  //sides reach Skip at the very same time, causing non-deteminism      
  rule //EXT CHOICE END BY SKIP (OPS 19,20)
    <procs>...
      <proc>...
        <id>PId:Int</id>
        <k> choice _ => Skip ... </k> 
        <env> _ => Env </env>
        <state> _ => State </state>        
      ...</proc>
      (<proc> ...
        <id>P1:Int</id>
        <parent>PId</parent>
        <alt>AId:Int</alt>
        <k>Skip</k>
        <env> Env </env>
        <state> State </state>        
      ...</proc> => .Bag)
    ...</procs>
   <deadlock>... .Set => SetItem(AId) ...</deadlock>
   [transition]



///////////////////////////////////////////////////////////
////////////////////////////CHANNEL HIDING/////////////////
///////////////////////////////////////////////////////////
   /*
   To profit from the underlying synchronization tree structure,
   for hiding, we create an intermediary level in the sync tree:
   the HIDING HUB.
   This extra node will be used to filter the initials that comes
   from the action under the hidden channel set.
   
   Filtering is achieved by forwarding initials from explicit channels
   and resolving the initials from hidden channels.
   The resolving is given in the respective section, 
   but the forwarding is treated here, as a simplistic rule that
   accepts the responsibility of any initial from the child
   since the channel is not in the hiding set.
   */

   rule //CHANNEL HIDING START (OPS 32,33,34)
    <k>  A:Action /H CSet:Set => hide (L +Int 1) CSet ... </k>
    <nextid> L => L +Int 1 </nextid>
    <id> ParId </id>
    <env> Env </env>
    <state> State </state>
    (.Bag => 
      <proc>...
        <k> A </k>
        <parent> ParId </parent>
        <id> (L +Int 1) </id>
        <alt> (L +Int 1) </alt>
        <env> Env </env>
        <state> State </state>
      ...</proc>)
      
   rule //CHANNEL HIDING END (OPS 33)
    <k>  hide CId:Int CSet:Set => Skip ... </k>
    <id> ParId </id>
    <env> _ => Env </env>
    <state> _ => State </state>
    (<proc>...
        <k> Skip </k>
        <id>CId</id>
        <parent> ParId </parent>
        <env> Env </env>
        <state> State </state>
      ...</proc> => .Bag)

  /*
  A hiding hub is ok to forward, i.e., take responsibility of
  any initial from its child that doesn't concern a hidden channel.
  */      
  rule //FORWARD HIDING NOT HIDDEN (OPS 32)
    <proc>...
      <k>  hide CId:Int HSet:Set  ... </k>
      <id> PId:Int </id>
    ...</proc>
    <inits>... 
      <init>...
        <iresp>CId => PId</iresp>
        <iev>C:Id ...</iev>
      ...</init>
    ... </inits> 
    requires notBool (C in HSet)      

///////////////////////////////////////////////////////
//////////////////NON OBSERVABLE PROGRESS//////////////
///////////////////////////////////////////////////////

  // State assignment attempt
  rule <k> V := E:Int => state Inv ~> Skip ... </k>
    <inv> Inv:BoolExp </inv>
    <state> ... V |-> _ ... </state>
    <env>... V |-> (?W:Int) ...</env>
    <const> Const => Const andBool (?W ==Int E) </const>


  // Var assignment (OPS 6)
  rule
    <proc>...
    <k> V:Id := E:Int => Skip ... </k>
    <state> St </state>
    <env> Env => Env[V <- ?W:Int] </env>
    <const> Const => Const andBool (?W ==Int E) </const>
    ...</proc>
    requires (notBool (V in (keys(St))))

  //Comm output (OPS 9,10,14)
  //Instead of processing it all, I just break it into comm
  //followed by the action. The comm is handled by the next
  //k rule named "labeled output progress", the action goes
  //on by itself
  rule <k> C:Comm -> A:Action => C ~> A ...</k>

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
    In K, it just doesn't make sense, so, in order to make it behaves
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
  Straightforward as it can be.
  The only utterly important point is to mark it as a transition
  so the k framework can backtrack it and try different solutions
  *///      
  rule <k> A1:Action |-| A2:Action => A1 ... </k> [transition]
  rule <k> A1:Action |-| A2:Action => A2 ... </k> [transition]  
  

  /*/// Guarded actions (OPS 17)
  After figuring a convenient configuration
  setup, we delegate the evaluation and
  tracking of guards to K framework,
  whom will rely in Z3
  *///
  rule <k> G:Bool & A:Action => A ... </k>
     <const> Const => Const andBool G </const>
  requires Const andBool G


  //Rule for named actions (No OPS)
  rule <k> A:Id => B ~> return  ...</k>
  <act> ... A |-> B ... </act>
  <env> Env => .Map </env>
  <stack> . => ListItem(Env) ... </stack>

  rule <k>  return => .  ...</k>
  <env> _ => Env </env>
  <stack> ListItem(Env) => .List ... </stack>  
  
  //State Stuff
  rule <k> state [ (V:Id , M:MultiDecl => M) | B:BoolExp ] ...</k>
    <env>... .Map =>  V |-> ?W:Int ...</env>
    <state>... .Map => V |-> "int" ...</state>

  rule <k> state [ .MultiDecl | B:BoolExp ] => state B ...</k>
    <inv> _ => B </inv>
  rule <k> state B:Bool => . ...</k>  
    <const> Const => Const andBool B </const>
    requires Const andBool B
  
  //------------------
  
  //fix process paragraph order
  rule <k> begin @ Pa:ParAction end =>  Pa ... </k>
  rule <k> begin P:PPars  @ A:ParAction end => P ~> A ... </k>
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
  
  rule  [ M:MultiDecl ] => [ M | true ] [macro]


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
  rule <k> channel C:Id : Ty:Type => . ...</k>
    <ch> ... .Map => C |-> Ty ...</ch>
  rule <k> channel C:Id => . ...</k>
    <ch> ... .Map => C |-> "sync" ...</ch>

  //TODO: update report
  rule channel S1:SimpleDecl, M:MultiDecl =>
      channel S1 channel M


  //sequential processing of circus paragraphs
  rule P1:CircusPar P2:CircusPars => P1 ~> P2 [structural]
  rule P1:PPar P2:PPars => P1 ~> P2 [structural]  

  //load a stored process into the k computation cell
  rule <k> :run ProcId:Id => Proc ... </k>
       <procref> ... ProcId |-> Proc ... </procref>
  

  rule <k> X:Id => I:Int ...</k>
    <env>... X |-> I:Int ...</env>
    
  rule I1 + I2 => I1 +Int I2
  rule I1 - I2 => I1 -Int I2
  rule I1 * I2 => I1 *Int I2
  rule I1 / I2 => I1 /Int I2 requires I2 =/=K 0
  rule I1 % I2 => I1 %Int I2 requires I2 =/=K 0

  rule I1 < I2 => I1 <Int I2
  rule I1 <= I2 => I1 <=Int I2
  rule I1 > I2 => I1 >Int I2
  rule I1 >= I2 => I1 >=Int I2

/*@ The equality and inequality constructs reduce to syntactic comparison
of the two argument values (which is what the equality on $K$ terms does). */

  rule V1:Int == V2:Int => V1 ==K V2
  rule V1:Int != V2:Int => V1 =/=K V2

/*@ The logical negation is clear, but the logical conjunction and disjunction
are short-circuited: */

  rule not E:Bool => notBool(E)
  rule true  && E => E
  rule false && _ => false
  rule true  || _ => true
  rule false || E => E    
    
    
    
endmodule
