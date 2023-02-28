module CIRCUS-SYNTAX
  imports SET
  imports LIST
  imports CIRCUS-EXPRESSIONS
  imports CIRCUS-UTILE
    
  //A Program consist of a sequence of Circus paragraphs
  syntax CircusSpec ::= CircusPars
  //CircusPars is one or more Circus paragraphs
  syntax CircusPars ::= CircusPar | CircusPar CircusPars

  //A Circus paragraph might be:
  //Zed paragraph,
  //channel declaration (CompleteCDecl)
  //channel or name set declarations, taking set expressions
  //process declaration (ProcDecl)
  //the special internal keyword :run to execute the main process
  syntax CircusPar ::=
    ZParagraph
    | CompleteCDecl
    | "chanset" Id "==" SetExp [strict(2)]
    | "nameset" Id "==" SetExp [strict(2)]    
    | ProcDecl
    | ":run" Id

  //For declarations, we take identifiers and, optionally
  //a type. We reuse this pattern for channels and 
  //general (schemas or actions) variable declarations
  syntax Type ::= "Int"
  syntax SimpleDecl ::= Id | Id ":" Type
  syntax CompleteCDecl ::= "channel" MultiDecl
  syntax MultiDecl ::= List{SimpleDecl, ","}
  
  //The declaration of a process may take an Id for the name
  //and a complete process definition (ProcDef)
  //or just an action paragraph (Action)
  //if the second variant is used, a macro will
  //transform it into a complete process declaration
  //containing only the provided Action as 
  //the anonymous action
  syntax ProcDecl ::= "process" Id "^=" ProcDef
                     |"process" Id "^=" Action

  //A complete process definition is surrounded
  //by the keywords begin/end, and comprehends a
  //sequence of process paragraphs PPars and
  //an anonymous action after the "@" symbol
  syntax ProcDef ::= 
      "begin" PPars  "@" Action "end"
    | "begin" "@" Action "end"

  //A process paragraph is either a Zed paragraph
  //or a named action declaration  
  syntax PPar ::= ZParagraph | Id "^=" Action
  syntax PPars ::= PPar | PPar PPars
  
  //Z Paragraph, including named schema declaration  
  syntax ZParagraph ::= Id "==" SchemaExp 
                      | "state" Id "==" Schema
                      | "state" Schema   
                      
  //Z Schema syntax
  syntax SchemaExp ::= Schema
  syntax Schema ::= "[" MultiDecl "]"
                  | "[" MultiDecl "|" BoolExp "]"  
                      

  //The action paragraphs are complex non-terminals:
  //it holds the whole CSP grammar (communications 
  //and composition operators) plus the Circus
  //add-ons, such as variable assignment and
  //references to schemas
 
  syntax Action ::=
    Id //references to named actions and schemas
    | Schema
    |"Skip" | "Stop" | "Chaos" //basic action
    | "(" Action ")" [bracket]
    > Comm "->" Action //prefixed communication
    | "var" Id "@" Action //var declaration
    >  BoolExp "&" Action //guarded action
    |  BoolExp "g" Action [strict(1)] //internal guarded action    
    | "u" Id "@" Action //anonymous recursive action
    > left:
      Action "/H" SetExp [strict(2)] //channel hiding
    | Action ";" Action   //sequential composition
    | Action "[]" Action  //external choice
    | Action "|-|" Action //internal choice
    | Action "[|" SetExp "|" SetExp "|" SetExp "|]" Action [strict(2,3,4)]
    | Action "[|" SetExp "|]" Action  [strict(2)]
    | Action "|||" Action //parallel compositions and interleave
    > Command //general command as var assignment

  //Prefix for communication, including input,
  //output and event synchronization
  syntax Comm ::= Id 
    | Id "?" Id 
    | Id "!" Exp [strict(2)] 
    | Id "??" Exp //internal use to produce trace output
  
  //Circus and internal use commands
  syntax Command ::= 
    Id ":=" Exp [strict(2)] //variable assignment
    //| "if" GActions "fi"    //guarded actions variation
    | "end" Id              //variable termination
    | InternalCommand

  syntax InternalCommand ::=
      "choice" Set          //internal use choice construction
    | "par" List "," Set "," Set "," Set //internal use parallel construction
    | "hide" Int Set        //internal use hide construction
    | "proc" Int            //internal use process inclusion construction
    | "state" BoolExp [strict] //internal use state validation command
    | "schema" BoolExp [strict]//internal use schema validation command

  //Guarded actions syntax variation
  //syntax GActions ::= BoolExp "-->" Action
  //  | BoolExp "-->" Action "[]" GActions


  //As values (Val), we define all the sorts we
  //need to consider as computation results
  //This is also assigned to KResult, meaning
  //that a computation heated by strictness
  //marks will be cooled when one of the
  //Val sorts is reached
  syntax Val ::= Int | Set | Bool    

endmodule


module CIRCUS
  imports CIRCUS-SYNTAX

  syntax KResult ::= Val

  configuration
    <top>
      <nextid> 1 </nextid>          //Last generated fresh int value
      <ch> .Map </ch>               //Map of channel names to types
      <nset> .Map </nset>           //Map of named sets to actual sets
      <procstrs>                    //Bag to store process structures
        <procstr multiplicity="*">
          <pmodel> .K </pmodel>     //The name given in the proc. definition
          <pact> .Map </pact>       //Map of action names to definitions
          <psch> .Map </psch>       //Map of schema names to definitions
          <pdef> .K </pdef>         //The whole process definition text
          <pstate> .Map </pstate>   //A map from state var names to types
          <pinv> .K </pinv>         //The state constraint          
        </procstr>
      </procstrs>
      <deadlock> .Set </deadlock>   //Set with ids of deadlocked processes
      <tempset> .Set </tempset>     //Used for converting circus set to K sets
      <procs>                       //Configuration for each running action
        <proc color="green" multiplicity="*">
          <model> .K </model>       //The declared name for the process
          <k>$PGM:K</k>             //The K Cell -- The computation cell
          <id>0</id>                //An unique integer reference
          <alt>0</alt>              //Id to the alternative of an ext. choice
          <parent>0</parent>        //Reference to the proc. which spawned
          <env> .Map </env>         //A map from var names to symbolic values
          <postenv> .Map </postenv> //Like env but used in schemas decor. vars.
          <stack> .List </stack>    //Stack of environments for nested scopes
          <sync>false</sync>        //Flag a process waiting an initial exec.
          <const>true</const>       //The constraint as in the OPS
          <temp> .K </temp>         //Auxiliary K manipulation
        </proc>
      </procs>
      <inits>                       //Set of initials waiting for resolution
        <init multiplicity="*">
          <iresp> 0 </iresp>        //The current responsible for the initial
          <iev> .K </iev>           //The communication event
          <from> .Set </from>       //References to all concerning processes
          <ialt> .Set </ialt>       //Reference to alternatives for ext. choice       
        </init>
      </inits>
      <oks>                         //Set of notifications of solved initials
        <ok multiplicity="*">
          <oev> .K </oev>           //The resolved communication event
          <to> .Set </to>           //References to the concerning processes
        </ok>
      </oks>
      <spectr> .K </spectr>         //The specification trace           
      <tr> .K </tr>                 //The observable output CS trace
    </top>

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
  //process reaches a finished successful execution configuration. 
  rule //LAST SKIP OK
    <id>0</id>
    <k>Skip => .</k>
    <tr>... . => Skip </tr>   
    
  //rule //LAST SKIP OK
  //  <k>. => Skip</k>

    
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
    </inits>
    [transition]
    
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
    <k> C:Id ? V:Id ~> A:Action => A ~> end V  ...</k> 
    <model> PModel:Id </model>
    <procstr>...
      <pmodel> PModel </pmodel>
      <pstate> St </pstate>
    ...</procstr> 
    <env> Env => Env[V <- ?W:Int] </env>
    <const> Const => Const andBool (?W ==Int Val) </const>
    <sync> true => false </sync>
    <id>PId:Int</id>
    <oks>...
      <ok>
        <oev>C:Id ! Val:Int</oev>
        <to>... SetItem(PId) => .Set ...</to>
      </ok>
    ...</oks>  
    <stack> . => ListItem(Env) ... </stack>
    requires (notBool (V in (keys(St))))        
    
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
    <spectr>... . => C </spectr>
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
        <iev>C:Id ? N:Id</iev>  
        <from>FSet</from>
      </init> => .Bag) 
    ... </inits>
    <oks>... 
      (.Bag => <ok> <oev>C ! ?V:Int</oev> <to>FSet -Set Kill</to> </ok>)
    ... </oks>
    <tr>... . => C ?? (?V) </tr>
    <spectr>... . => C ?? N </spectr>
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
    <spectr>... . => C ! E </spectr>    
    <deadlock>Kill => Kill Alt</deadlock>
    requires notBool (size(FSet -Set Kill) ==Int 0)
    
  rule //EXECUTE HIDDEN EV (OPS 32)
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
    
    
  rule //EXECUTE HIDDEN OUTPUT (OPS 32)
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
  
   rule //NO STATE WRITING STRUCTURAL
    <k> A1:Action [|CS:Set|] A2:Action 
      => A1:Action [|.Set|CS|.Set|] A2:Action ... </k> [structural]      

   rule //START PAR ACTIONS (OPS 25)
    <k> A1:Action [|X1:Set|CSet:Set|X2:Set|] A2:Action 
      => par ListItem(L +Int 1) ListItem(L +Int 2), CSet,X1,X2 ... </k>
    <nextid> L => L +Int 2 </nextid>
    <id> ParId </id>
    <model> PModel:Id </model>
    <const> Const </const>
    <env> Env </env>
    (.Bag => 
      <proc>...
        <k> A1 </k>
        <model> PModel </model>
        <parent> ParId </parent>
        <id> (L +Int 1) </id>
        <alt> (L +Int 2) </alt>
        <const> Const </const>        
        <env> Env </env>
      ...</proc>
      <proc>...
        <k> A2 </k>
        <model> PModel </model>        
        <parent> ParId </parent>        
        <id> (L +Int 2) </id>
        <alt> (L +Int 1) </alt>
        <const> Const </const>        
        <env> Env </env>
      ...</proc>)    


  rule //CLEAN FINISHED PARALLELS (OPS 26)
    (<proc>...
      <id>LId:Int</id>
      <k> Skip </k>
      <parent>PId:Int</parent>
      <const> LConst </const>
      <env> LEnv </env>
    ...</proc> => .Bag )
    (<proc>...
      <id>RId:Int</id>
      <k> Skip </k>      
      <parent>PId:Int</parent>
      <const> RConst </const>
      <env> REnv </env>      
    ...</proc> => .Bag )
    <proc>...
      <id>PId</id>
      <const> Const => Const andBool LConst andBool RConst </const>
      <env> Env => 
        updateMap(Env, 
          removeAll(LEnv, keys(LEnv) -Set X1)
          removeAll(REnv, keys(REnv) -Set X2)
        )
        </env>
      <k> par ListItem(LId) ListItem(RId),
        CSet:Set, X1:Set, X2:Set => Skip ...</k>
    ...</proc>
 
//-----FORWARDING
    
  rule //FORWARD PAR NO SYNC EVENT (OPS 27, 28)
    <proc>...
      <id>CId:Int</id>
      <parent>PId:Int</parent>
    ...</proc>
    <proc>...
      <id>PId</id>
      <k> par _:List,CSet:Set,_:Set,_:Set ... </k>
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
      <k> par _:List,CSet:Set,_:Set,_:Set ...</k>
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
      <k> par _:List,CSet:Set,_:Set,_:Set ... </k>
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
      <k> par ParList:List,CSet:Set,_:Set,_:Set ... </k>
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
      <k> par ParList:List,CSet:Set,_:Set,_:Set ... </k>
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
      <k> par ParList:List,CSet:Set,_:Set,_:Set ... </k>
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
      <k> par ParList:List,CSet:Set,_:Set,_:Set ... </k>
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
    <model> PModel:Id </model>    
    <env> Env </env>
    <const> Const </const>
    (.Bag => 
      <proc>...
        <k> A1 </k>
        <model> PModel </model>        
        <parent>PId</parent>
        <env> Env </env>        
        <const> Const </const>
        <id> (L +Int 1) </id>
        <alt> (L +Int 2) </alt>
      ...</proc>
      <proc>...
        <k> A2 </k>
        <model> PModel </model>        
        <env> Env </env>
        <const> Const </const>
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
        <const> _ => Const </const>      
      ...</proc>
      (<proc> ...
        <id>P1:Int</id>
        <parent>PId</parent>
        <alt>AId:Int</alt>
        <k>Skip</k>
        <env> Env </env>
        <const> Const </const>        
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

   rule //CHANNEL HIDING START (OPS 31,32,33)
    <k>  A:Action /H CSet:Set => hide (L +Int 1) CSet ... </k>
    <nextid> L => L +Int 1 </nextid>
    <id> ParId </id>
    <model> PModel:Id </model>    
    <env> Env </env>
    <const> Const </const>
    (.Bag => 
      <proc>...
        <k> A </k>
        <model> PModel </model>        
        <parent> ParId </parent>
        <id> (L +Int 1) </id>
        <alt> (L +Int 1) </alt>
        <env> Env </env>
        <const> Const </const>
      ...</proc>)
      
   rule //CHANNEL HIDING END (OPS 33)
    <k>  hide CId:Int CSet:Set => Skip ... </k>
    <id> ParId </id>
    <env> _ => Env </env>
    <const> _ => Const </const>
    (<proc>...
        <k> Skip </k>
        <id>CId</id>
        <parent> ParId </parent>
        <env> Env </env>
        <const> Const </const>
      ...</proc> => .Bag)

  /*
  A hiding hub is ok to forward, i.e., take responsibility of
  any initial from its child that doesn't concern a hidden channel.
  */      
  rule //FORWARD HIDING NOT HIDDEN EVENT (OPS 31)
    <proc>...
      <k>  hide CId:Int HSet:Set  ... </k>
      <id> PId:Int </id>
    ...</proc>
    <inits>... 
      <init>...
        <iresp>CId => PId</iresp>
        <iev>C:Id</iev>
      ...</init>
    ... </inits> 
    requires notBool (C in HSet)

  rule //FORWARD HIDING NOT HIDDEN OUTPUT (OPS 31)
    <proc>...
      <k>  hide CId:Int HSet:Set  ... </k>
      <id> PId:Int </id>
    ...</proc>
    <inits>... 
      <init>...
        <iresp>CId => PId</iresp>
        <iev>C:Id ! _</iev>
      ...</init>
    ... </inits> 
    requires notBool (C in HSet)     
    
  rule //FORWARD HIDING NOT HIDDEN INPUT (OPS 31)
    <proc>...
      <k>  hide CId:Int HSet:Set  ... </k>
      <id> PId:Int </id>
    ...</proc>
    <inits>... 
      <init>...
        <iresp>CId => PId</iresp>
        <iev>C:Id ? _</iev>
      ...</init>
    ... </inits> 
    requires notBool (C in HSet)     


    
///////////////////////////////////////////////////////////////////////////    
    
  rule //PROCESS INCLUSION START
    <k> P:Id => proc (L +Int 1)  ...</k>
    <id>PId</id>
    (.Bag => <proc>...
      <id> (L +Int 1) </id>
      <model> P </model>
      <parent>PId</parent>
      <k> B </k>
    ...</proc>)
    <nextid> L => L +Int 1 </nextid>
    <procstr>...
      <pmodel> P </pmodel>
      <pdef> B </pdef>
    ...</procstr>    
    
   rule //PROCESS INCLUSION END
    <k>  proc CId:Int => Skip ... </k>
    <id> ParId </id>
    <const> Const => Const andBool NewConst </const>
    (<proc>...
        <k> Skip </k>
        <id>CId</id>
        <parent> ParId </parent>
        <const> NewConst </const>
      ...</proc> => .Bag)   

  rule //FORWARD INCLUDED PROCESS
    <proc>...
      <k>  proc CId:Int ... </k>
      <id> PId:Int </id>
    ...</proc>
    <inits>... 
      <init>...
        <iresp>CId => PId</iresp>
      ...</init>
    ... </inits>    


///////////////////////////////////////////////////////
//////////////////STATE AND SCHEMA EVALUATION//////////
///////////////////////////////////////////////////////

  //Rule for schemas (No OPS)
  //The schema is loaded from the stored process
  //structure using the name references and placed
  //in the computation cell. Also, a fresh post
  //environment is initialized containing a copy
  //of the current environment. This post environment
  //is used for manipulating the decorated variables
  //in the post condition boolean expression
  //The name of the schema is saved in the temp cell
  //so it can be output to the specification trace
  //in the case of its  successful application.
  rule 
    <k> A:Id => B ...</k>
    <model> PModel:Id </model>
    <procstr>...
      <pmodel> PModel </pmodel>
      <psch>... A |-> B ...</psch>
    ...</procstr>  
    <env> Env </env>
    <postenv> _ => Env </postenv>
    <temp> _ => A </temp>

  //Process each identifier declared in the schema
  //until the list is empty. Each identifier gets
  //a new symbolic value in the post environment
  //so it can be manipulated by the post condition
  //boolean expression
  rule
    <k> [ (V:Id , M:MultiDecl => M) | B:BoolExp ] ...</k>
    <postenv> Env => Env[V <- ?W:Int] </postenv>    
   
  //After all the declaration part is treated
  //it is just a matter of evaluating the boolean
  //post condition. For that, we replace the usual
  //syntatic construction of the schema for the internal
  //trigger "schema BoolExp"
  rule
    <k> [ .MultiDecl | B:BoolExp ] => schema B...</k>
  
  //The actual schema application
  //after the preparation of the postenv with the
  //schema declared variables, we are able to evaluate
  //the boolean expression containing the decorated (x')
  //variables. If the evaluation holds, we add it
  //to the current constraint.
  //The schema name is output to the spectr.
  //At last, we leave a state invariant evaluation
  //in the top of the computation cell to be ensure
  //it was not broken by the new state assignments
  rule <k> schema B => state Inv ~> Skip ...</k>
    <model> PModel:Id </model>
    <procstr>...
      <pmodel> PModel </pmodel>
      <pinv> Inv:BoolExp </pinv>
    ...</procstr>     
    <const> Const => Const andBool B </const>
    <env> _ => PostEnv </env>
    <postenv> PostEnv => .Map </postenv>
     <temp> Temp => . </temp>
     <spectr>... . => Temp </spectr>    
  requires Const andBool B
  
  
  //Rewriting of the special syntax required for
  //state schemas: the state schema is evaluated right
  //after being declared.
  rule <k> state I:Id == S:Schema => I == S ~> state S ...</k> [structural]
  
  //Add each declared state variable to the env and state maps
  rule <k> state [ (V:Id , M:MultiDecl => M) | B:BoolExp ] ...</k>
    <env>... .Map =>  V |-> ?W:Int ...</env>
    <model> PModel:Id </model>
    <procstr>...
      <pmodel> PModel </pmodel>
      <pstate>... .Map => V |-> "int" ...</pstate>
    ...</procstr>     

  //After all var declaration is cleared, we trigger
  //the checking of the invariant boolean expression
  rule <k> state [ .MultiDecl | B:BoolExp ] => state B ...</k>
    <model> PModel:Id </model>
    <procstr>...
      <pmodel> PModel </pmodel>
      <pinv> _ => B </pinv>
    ...</procstr>     
    
  //State invariant checking
  //The invariant is solved by syntax strictness
  //and the result is conjuncted with the constraint
  rule <k> state B:Bool => . ...</k>  
    <const> Const => Const andBool B </const>
    requires Const andBool B


///////////////////////////////////////////////////////
//////////////////NON OBSERVABLE PROGRESS//////////////
///////////////////////////////////////////////////////
  /*
  Var assignment (OPS 6)
  When assigning to a state variable, we enforce the
  subsequent rechecking of the state invariable
  */
  rule // State assignment (OPS 6)
    <k> V := E:Int => state Inv ~> Skip ... </k>
    <model> PModel:Id </model>
    <procstr>...
      <pmodel> PModel </pmodel>
        <pstate> ... V |-> _ ... </pstate>
        <pinv> Inv:BoolExp </pinv>
    ...</procstr>     
    <env>... V |-> (_ => ?W:Int) ...</env>
    <const> Const => Const andBool (?W ==Int E) </const>
    <spectr>... . => V := E </spectr>     


  rule // Local var assignment (OPS 6)
    <proc>...
      <k> V:Id := E:Int => Skip ... </k>
      <model> PModel:Id </model>
      <procstr>...
        <pmodel> PModel </pmodel>
        <pstate> St </pstate>
      ...</procstr> 
      <env> Env => Env[V <- ?W:Int] </env>
      <const> Const => Const andBool (?W ==Int E) </const>
    ...</proc>
    <spectr>... . => V := E </spectr> 
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
  rule 
    <k> var V:Id @ A:Action => A ~> end V ...</k> 
    <env> Env => Env[V <- ?W:Int] </env>
    <stack> . => ListItem(Env) ... </stack>    
    //<spectr>... . => var V </spectr>     


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
  When a variable is finalized we finalize the whole scope:
  the scope which was stacked before the current one does not
  contain the recently ended variable.
  The old environment is then popped and replaces the current
  environment. Nevertheless, any value changed in the discarded
  environment is updated into the popped one.
  This redundancy is necessary since we allow the nested scope
  of variables with the same name.
  *///
  rule 
    <k> end V:Id => . ... </k>
    <env> 
      RetEnv => updateMap(Env, removeAll(RetEnv, SetItem(V)))
    </env>
    <stack> ListItem(Env) => .List ... </stack>
    <spectr>... . => end V </spectr>      
  
  
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
  rule <k> G:Bool g A:Action => A ... </k>
     <const> Const => Const andBool G </const>
     <temp> Temp => . </temp>
     <spectr>... . => Temp </spectr>
  requires Const andBool G
  
  //Store original guard expression to produce
  //spec trace if the guard suceed
  rule <k> G:BoolExp & A:Action => G g A  ... </k>
    <temp> _ => G </temp> 
    
    
///////////////////////////////////////////////////////
/////////MISCELLANEOUS STRUCTURAL RULES//////////////// 
///////////////////////////////////////////////////////    


  //Rule for named actions (No OPS)
  //The rule gets the action body from the stored
  //process structure using the name references and
  //put it in the computation cell for execution
  rule
    <k> A:Id => (B)  ...</k>
    <model> PModel:Id </model>
    <procstr>...
      <pmodel> PModel </pmodel>
      <pact>... A |-> B ...</pact>
    ...</procstr>  
  
  
  //fix process paragraph order
  rule <k> begin @ Pa:Action end =>  Pa ... </k>
  rule <k> begin P:PPars  @ A:Action end => P ~> A ... </k>

  //recursive actions
  rule
    <k> u N:Id @ A:Action => N ... </k>
    <model> PModel:Id </model>    
    <procstr>...
      <pmodel> PModel </pmodel>
      <pact> LMap => LMap[N <- A] </pact>
    ...</procstr>
    
  //load process schemas
  rule
    <k>  N:Id == S:SchemaExp  => . ... </k>
    <model> PModel:Id </model>    
    <procstr>...
      <pmodel> PModel </pmodel>
      <psch> LMap => LMap[N <- S] </psch>
    ...</procstr>      
  
  //load process named actions
  rule
    <k>  N:Id ^= A:Action => . ... </k>
    <model> PModel:Id </model>    
    <procstr>...
      <pmodel> PModel </pmodel>
      <pact> LMap => LMap[N <- A] </pact>
    ...</procstr>
    

  //process "processing" :)
  //the old version let PD in the cell
  rule
    <k> process P:Id ^= PD:ProcDef  => . ...</k>
      <procstrs>...
        (.Bag => <procstr>...
          <pmodel> P </pmodel>
          <pdef> PD </pdef>
      ...</procstr>)   
    ...</procstrs>

  /////////////MACROS//////////
    
  //Macro to predicate-less schemas
  rule  [ M:MultiDecl ] => [ M | true ] [macro]
  //Macro to single action process
  rule  process P:Id ^= A:Action 
     => process P ^= begin @ A end [macro] 
  /////////////////////////////////     


  //Skip all the set processing and use the so called shallow embedding
  rule <k> {| Xi:Id, Xs:CommaIds |} => {| Xs |} ... </k> 
    <tempset> ... . => SetItem(Xi) </tempset>
  rule <k> {| .CommaIds |} => TempSet ... </k> 
    <tempset> TempSet => .Set </tempset>
  //Channel name set   
  rule <k>chanset CSName:Id == CSet:Set => . ... </k>
    <nset>... .Map => CSName |-> CSet </nset>
  //Variable name set  
  rule <k>nameset NSName:Id == NSet:Set => . ... </k>
    <nset>... .Map => NSName |-> NSet </nset>
  //Named set retriving  
  rule <k> NSetId:Id => CSet ...</k>
    <nset>... NSetId |-> CSet:Set ...</nset>
  
  //process and store (get rid of) typed and untyped channels
  rule <k> channel C:Id : Ty:Type => . ...</k>
    <ch> ... .Map => C |-> Ty ...</ch>
  rule <k> channel C:Id => . ...</k>
    <ch> ... .Map => C |-> "sync" ...</ch>

  //channel declaration de-sugaring
  rule channel S1:SimpleDecl, S2:SimpleDecl, M:MultiDecl =>
      channel S1 channel S2, M


  //sequential processing of circus paragraphs
  rule P1:CircusPar P2:CircusPars => P1 ~> P2 [structural]
  rule P1:PPar P2:PPars => P1 ~> P2 [structural]  

  //load a stored process into the k computation cell
  rule <k> :run ProcId:Id => Proc ... </k>
       <model> _ => ProcId </model>
       <procstr>...
          <pmodel> ProcId </pmodel>
          <pdef> Proc </pdef>
       ...</procstr>
  
  //Variable retrieving from environment
  rule <k> X:Id => I:Int ...</k>
    <env>... X |-> I:Int ...</env>

  //Decorated var retrieving from post environment
  rule <k> X:Id ' => I ...</k>
    <postenv>... X |-> I ...</postenv>    
    
endmodule

module CIRCUS-UTILE
  //A simple useful list of comma-separated identifiers 
  syntax CommaIds ::= List{Id, ","}
endmodule

module CIRCUS-EXPRESSIONS
  imports SET
  imports LIST
  imports CIRCUS-UTILE  
    
  syntax Exp ::= Int |  Id  | Id "'"
               | "(" Exp ")"             [bracket]
               > left:
                 Exp "*" Exp             [strict, left]                 
               | Exp "/" Exp             [strict, left]
               | Exp "mod" Exp             [strict, left]
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
                 BoolExp "&&" BoolExp    [strict(1,2), left]
               | BoolExp "||" BoolExp    [strict(1,2), left]
               
  syntax SetExp ::= Set | Id 
    | "(" SetExp ")"     [bracket]
    | "{||}"
    | "{|" CommaIds "|}"  
    > left:
      SetExp "U" SetExp  [seqstrict]
    | SetExp "T" SetExp  [seqstrict]
    | SetExp "/E" SetExp [seqstrict]               
               
  rule I1 + I2 => I1 +Int I2
  rule I1 - I2 => I1 -Int I2
  rule I1 * I2 => I1 *Int I2
  rule I1 / I2 => I1 /Int I2 requires I2 =/=K 0
  rule I1 mod I2 => I1 %Int I2 requires I2 =/=K 0

  rule I1 < I2 => I1 <Int I2
  rule I1 <= I2 => I1 <=Int I2
  rule I1 > I2 => I1 >Int I2
  rule I1 >= I2 => I1 >=Int I2

  rule V1:Int == V2:Int => V1 ==Int V2
  rule V1:Int != V2:Int => V1 =/=Int V2
    
  rule E1:Bool && E2:Bool => E1 andBool E2
  rule E1:Bool || E2:Bool => E1 orBool E2               
         
  rule S1:Set U S2:Set => S1 S2
  rule S1:Set T S2:Set => intersectSet(S1,S2)
  rule S1:Set /E S2:Set => S1 -Set S2         
endmodule
