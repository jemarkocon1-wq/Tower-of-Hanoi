/*
  TOH.pl — Tower of Hanoi: French Mythology Edition
  -------------------------------------------------
  Requirements:
    - SWI-Prolog 9.x
    - Built-in HTTP and persistency libraries

  Run in VS Code terminal:
    swipl -q -s TOH.pl

  Then open:
    http://localhost:8080

  Stop the server with Ctrl+C.

  Notes:
    - This is a self-contained, single-file starter game.
    - Creature artwork/audio can be added to an assets folder later.
    - Browser audio starts after the first user interaction.
*/

:- use_module(library(http/thread_httpd)).
:- use_module(library(http/http_dispatch)).
:- use_module(library(http/http_json)).
:- use_module(library(http/http_parameters)).
:- use_module(library(http/json)).
:- use_module(library(persistency)).
:- use_module(library(date)).
:- use_module(library(lists)).
:- use_module(library(apply)).

:- persistent
    score(id:atom, player:atom, mode:atom, seconds:integer,
          moves:integer, completed_at:atom).

:- http_handler(root(.), home, []).
:- http_handler(root(api/health), health, []).
:- http_handler(root(api/leaderboard), leaderboard, []).
:- http_handler(root(api/scores), save_score, [method(post)]).

:- dynamic server_started/1.

server_port(8080).
database_file('scores.db').

start_server :-
    ( server_started(_) ->
        format('TOH server is already running.~n')
    ; database_file(DB),
      db_attach(DB, []),
      server_port(Port),
      http_server(http_dispatch, [port(Port)]),
      assertz(server_started(Port)),
      format('~nTower of Hanoi is running!~n'),
      format('Open http://localhost:~w in your browser.~n', [Port]),
      format('Press Ctrl+C to stop the server.~n~n'),
      thread_get_message(_)  
    ).

:- initialization(start_server, main).

home(_Request) :-
    html_page(HTML),
    format('Content-type: text/html; charset=UTF-8~n~n'),
    format('~s', [HTML]).

health(_Request) :-
    reply_json_dict(_{status: ok, application: "Tower of Hanoi - French Mythology Edition"}).

leaderboard(_Request) :-
    findall(
        _{player: Player, mode: Mode, seconds: Seconds,
          moves: Moves, completed_at: Date},
        score(_, Player, Mode, Seconds, Moves, Date),
        Scores
    ),
    sort_scores(Scores, Sorted),
    reply_json_dict(_{scores: Sorted}).

save_score(Request) :-
    catch(
        ( http_read_json_dict(Request, Data),
          validate_score(Data, Player, Mode, Seconds, Moves),
          get_time(Now),
          format_time(atom(Date), '%Y-%m-%d %H:%M:%S', Now),
          flag(toh_score_id, Id, Id+1),
          format(atom(IdAtom), '~w', [Id]),
          with_mutex(toh_scores,
              assert_score(IdAtom, Player, Mode, Seconds, Moves, Date)),
          reply_json_dict(_{saved: true, message: "Score saved"})
        ),
        Error,
        ( message_to_string(Error, Message),
          reply_json_dict(_{saved: false, error: Message},
                          [status(400)])
        )
    ).

validate_score(Data, Player, Mode, Seconds, Moves) :-
    _{player: Player0, mode: Mode0, seconds: Seconds,
      moves: Moves} :< Data,
    atom_string(Player, Player0),
    atom_string(Mode, Mode0),
    string_length(Player0, NameLength),
    NameLength > 0,
    NameLength =< 30,
    memberchk(Mode, [easy, medium, hard, extreme]),
    integer(Seconds), Seconds >= 0, Seconds =< 86400,
    integer(Moves), Moves >= 1, Moves =< 100000,
    !.
validate_score(_, _, _, _, _) :-
    throw(error(domain_error(valid_score, submitted_data), _)).

sort_scores(Scores, Sorted) :-
    predsort(compare_score, Scores, Sorted).

compare_score(Order, A, B) :-
    get_dict(mode, A, ModeA),
    get_dict(mode, B, ModeB),
    get_dict(seconds, A, TimeA),
    get_dict(seconds, B, TimeB),
    get_dict(moves, A, MovesA),
    get_dict(moves, B, MovesB),
    ( ModeA @< ModeB -> Order = (<)
    ; ModeA @> ModeB -> Order = (>)
    ; compare(Order0, TimeA, TimeB),
      ( Order0 == (=) -> compare(Order, MovesA, MovesB)
      ; Order = Order0
      )
    ).

html_page("<!doctype html>
<html lang=\"en\">
<head>
<meta charset=\"utf-8\">
<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">
<title>Tower of Hanoi — French Mythology</title>
<style>
:root{--bg:#100d19;--panel:#1b1628;--gold:#f4c66a;--cream:#f8e9c8;--muted:#b9aecb;--accent:#a66bff}
*{box-sizing:border-box}body{margin:0;color:var(--cream);font-family:Georgia,serif;background:radial-gradient(ellipse at 50% -20%,#57335e 0,#21182e 42%,#0c0a12 100%);min-height:100vh}
button,input{font:inherit}button{cursor:pointer;border:1px solid #87643d;background:linear-gradient(135deg,#5b3c69,#2b203b);color:#fff0d0;border-radius:12px;padding:11px 16px;transition:.2s}
button:hover{transform:translateY(-2px);box-shadow:0 0 18px #d99a5b66;border-color:var(--gold)}button:disabled{opacity:.4;cursor:not-allowed;transform:none}
header{text-align:center;padding:25px 15px 12px}h1{margin:0;color:var(--gold);font-size:clamp(28px,5vw,48px);text-shadow:0 3px 20px #ff9b4a66;letter-spacing:2px}
.subtitle{color:var(--muted);margin:8px 0 0}.wrap{max-width:1100px;margin:auto;padding:15px}
.panel{background:#1b1628dd;border:1px solid #71543d;border-radius:18px;padding:18px;box-shadow:0 15px 50px #0008}
.modes{display:grid;grid-template-columns:repeat(4,1fr);gap:12px;margin:14px 0 18px}
.mode{min-height:155px;text-align:left;position:relative;overflow:hidden;background:linear-gradient(150deg,#34243d,#171321);border-color:#725b4b}
.mode strong{display:block;color:var(--gold);font-size:19px;margin-bottom:8px}.mode .creature{font-size:38px;display:block;margin-bottom:7px}.mode small{color:#d1c1d6}.mode.active{outline:2px solid var(--gold);box-shadow:0 0 24px #d79d4b55}
#preview{min-height:54px;color:#d8c6e5;text-align:center;margin:4px 0 12px}
.controls{display:flex;flex-wrap:wrap;gap:9px;align-items:center;justify-content:center;margin:12px 0}
input{background:#110e19;color:white;border:1px solid #78618b;border-radius:9px;padding:10px;max-width:190px}
.stats{display:flex;justify-content:center;gap:22px;flex-wrap:wrap;color:var(--gold);font-size:18px;margin:12px}
.board{position:relative;display:grid;grid-template-columns:repeat(3,1fr);gap:16px;min-height:290px;padding:20px 12px 35px;overflow:hidden}
.board:before{content:\"\";position:absolute;bottom:24px;left:3%;right:3%;height:12px;border-radius:50%;background:linear-gradient(#d8a65b,#754322);box-shadow:0 5px 18px #000}
.tower{position:relative;display:flex;align-items:flex-end;justify-content:center;min-height:230px;border-radius:14px;background:linear-gradient(180deg,#ffffff08,#ffffff02);cursor:pointer}
.tower:after{content:\"\";position:absolute;bottom:0;width:13px;height:210px;background:linear-gradient(90deg,#754b2c,#d9a55e,#754b2c);border-radius:10px 10px 2px 2px;z-index:0}
.discs{position:absolute;bottom:12px;z-index:2;width:100%;display:flex;flex-direction:column-reverse;align-items:center;gap:4px}
.disc{height:25px;border-radius:9px;border:2px solid #ffe2a0;box-shadow:inset 0 3px 5px #fff6,0 3px 7px #0008;transition:transform .22s,filter .22s;cursor:pointer;z-index:3}
.disc.selected{transform:translateY(-18px);filter:brightness(1.35);box-shadow:0 0 18px var(--gold)}
.tower.selected-target{background:#e8c16b16;box-shadow:inset 0 0 25px #f3cb6c33}
.tower-label{position:absolute;bottom:-27px;color:#c7b5d6;font-size:13px;z-index:4}
.easy{--accent:#d7a36c}.medium{--accent:#4fbd77}.hard{--accent:#e75a36}.extreme{--accent:#f04a2f}
body.easy{background:radial-gradient(ellipse at 50% 0,#715044,#21192b 55%,#0b0910)}body.medium{background:radial-gradient(ellipse at 50% 0,#1e6949,#132a27 55%,#080e12)}body.hard{background:radial-gradient(ellipse at 50% 0,#a13d28,#32172b 55%,#0b0910)}body.extreme{background:radial-gradient(ellipse at 50% 0,#a02c1d,#35121c 55%,#09080c)}
.disc{background:linear-gradient(90deg,var(--accent),#f3c77a,var(--accent))}
.footer{text-align:center;color:#8e819e;font-size:12px;padding:18px}
#message{min-height:26px;text-align:center;color:#ffe3a0;font-size:18px}
#leaderboard{max-width:700px;margin:15px auto 0}table{width:100%;border-collapse:collapse}td,th{padding:8px;border-bottom:1px solid #51415e;text-align:left}
@media(max-width:760px){.modes{grid-template-columns:repeat(2,1fr)}.board{gap:5px;padding-left:2px;padding-right:2px}.disc{height:21px}.tower{min-height:220px}.panel{padding:12px}}
@media(max-width:420px){.modes{gap:7px}.mode{padding:10px;min-height:140px}.mode .creature{font-size:30px}}
</style>
</head>
<body class=\"easy\">
<header><h1>THE THREE ENCHANTED TOWERS</h1><p class=\"subtitle\">A Tower of Hanoi adventure through French mythology</p></header>
<main class=\"wrap\">
<section class=\"panel\">
<h2 style=\"text-align:center;color:#f4c66a;margin:0\">Choose Your Realm</h2>
<div class=\"modes\">
<button class=\"mode active\" data-mode=\"easy\"><span class=\"creature\">🐌</span><strong>Easy · Snail</strong><small>3 discs · 7 minimum moves</small></button>
<button class=\"mode\" data-mode=\"medium\"><span class=\"creature\">🐉</span><strong>Medium · Melusine</strong><small>4 discs · 15 minimum moves</small></button>
<button class=\"mode\" data-mode=\"hard\"><span class=\"creature\">🐻</span><strong>Hard · Malbete</strong><small>5 discs · 31 minimum moves</small></button>
<button class=\"mode\" data-mode=\"extreme\"><span class=\"creature\">🔥</span><strong>Extreme · Peluda</strong><small>6 discs · 63 minimum moves</small></button>
</div>
<div id=\"preview\">Hover over a realm to preview its puzzle. Select it to begin.</div>
<div class=\"controls\">
<input id=\"playerName\" maxlength=\"30\" placeholder=\"Player name\" value=\"Player 1\">
<button id=\"singleBtn\">Single Player</button>
<button id=\"duelBtn\">Two Player Duel</button>
<button id=\"howBtn\">How to Play</button>
<button id=\"leaderBtn\">Leaderboard</button>
</div>
<div class=\"stats\"><span>Time: <b id=\"timer\">00:00</b></span><span>Moves: <b id=\"moves\">0</b></span><span>Minimum: <b id=\"minimum\">7</b></span></div>
<div id=\"message\">Choose a mode, then start your adventure.</div>
<div class=\"board\" id=\"board\" aria-label=\"Tower of Hanoi game board\"></div>
<div class=\"controls\">
<button id=\"undoBtn\">Undo</button><button id=\"restartBtn\">Restart</button>
<button id=\"pauseBtn\">Pause</button><button id=\"soundBtn\">Sound: On</button>
<button id=\"menuBtn\">Main Menu</button>
</div>
<div id=\"leaderboard\"></div>
</section>
<p class=\"footer\">French Mythology Edition · Built with Vanilla JavaScript and SWI-Prolog</p>
</main>
<script>
const modes={
 easy:{discs:3,min:7,creature:'🐌',name:'Snail',preview:'A gentle enchanted realm with a peaceful puzzle.',tone:392},
 medium:{discs:4,min:15,creature:'🐉',name:'Melusine',preview:'Emerald waters shimmer around Melusine’s realm.',tone:494},
 hard:{discs:5,min:31,creature:'🐻',name:'Malbete',preview:'Embers rise as the mighty Malbete awakens.',tone:220},
 extreme:{discs:6,min:63,creature:'🔥',name:'Peluda',preview:'The Peluda guards a blazing and dangerous realm.',tone:164}
};
let mode='easy', towers=[[],[],[]], moves=0, selected=null, history=[];
let started=false, paused=false, finished=false, duel=false, duelPlayer=1;
let playerTimes=[], playerMoves=[], playerNames=['Player 1','Player 2'];
let elapsed=0, tickHandle=null, audioOn=true, audioCtx=null, previewTimer=null;
const $=id=>document.getElementById(id);
function minimum(n){return Math.pow(2,n)-1}
function resetBoard(){
 const n=modes[mode].discs;towers=[Array.from({length:n},(_,i)=>n-i),[],[]];
 moves=0;selected=null;history=[];elapsed=0;started=false;paused=false;finished=false;
 $('moves').textContent='0';$('timer').textContent='00:00';$('minimum').textContent=modes[mode].min;
 $('message').textContent='Select the top disc, then select a destination tower.';
 stopClock();render();
}
function render(){
 const board=$('board');board.innerHTML='';
 towers.forEach((stack,index)=>{
  const tower=document.createElement('div');tower.className='tower'+(selected===index?' selected-target':'');
  tower.dataset.tower=index;
  const discs=document.createElement('div');discs.className='discs';
  stack.forEach((size,i)=>{
   const disc=document.createElement('div');disc.className='disc'+(selected===index&&i===stack.length-1?' selected':'');
   disc.style.width=(25+size*10)+'%';disc.title='Disc '+size;
   disc.addEventListener('click',e=>{e.stopPropagation();chooseTower(index)});
   discs.appendChild(disc);
  });
  const label=document.createElement('div');label.className='tower-label';label.textContent=['Tower A','Tower B','Tower C'][index];
  tower.append(discs,label);tower.addEventListener('click',()=>chooseTower(index));board.appendChild(tower);
 });
}
function chooseTower(index){
 if(paused||finished)return;
 if(selected===null){
  if(!towers[index].length)return;
  selected=index;render();return;
 }
 if(selected===index){selected=null;render();return}
 const from=towers[selected],to=towers[index],disc=from[from.length-1];
 if(!disc)return;
 if(to.length&&to[to.length-1]<disc){$('message').textContent='Illegal move! A larger disc cannot cover a smaller disc.';playTone(110,.12);return}
 history.push(towers.map(t=>t.slice()));
 to.push(from.pop());moves++;$('moves').textContent=moves;selected=null;
 if(!started){started=true;startClock()}
 render();playTone(modes[mode].tone,.09);
 if(towers[2].length===modes[mode].discs)completeGame();
}
function startClock(){if(tickHandle)return;tickHandle=setInterval(()=>{if(started&&!paused&&!finished){elapsed++;$('timer').textContent=formatTime(elapsed)}},1000)}
function stopClock(){if(tickHandle){clearInterval(tickHandle);tickHandle=null}}
function formatTime(s){return String(Math.floor(s/60)).padStart(2,'0')+':'+String(s%60).padStart(2,'0')}
function playTone(freq,duration=.12){
 if(!audioOn)return;
 try{audioCtx=audioCtx||new(window.AudioContext||window.webkitAudioContext)();
  if(audioCtx.state==='suspended')audioCtx.resume();
  const osc=audioCtx.createOscillator(),gain=audioCtx.createGain();
  osc.type='sine';osc.frequency.value=freq;gain.gain.setValueAtTime(.055,audioCtx.currentTime);
  gain.gain.exponentialRampToValueAtTime(.001,audioCtx.currentTime+duration);
  osc.connect(gain);gain.connect(audioCtx.destination);osc.start();osc.stop(audioCtx.currentTime+duration);
 }catch(e){}
}
function completeGame(){
 finished=true;stopClock();playTone(700,.35);setTimeout(()=>playTone(900,.4),180);
 if(duel){
  playerTimes.push(elapsed);playerMoves.push(moves);
  if(duelPlayer===1){
   $('message').textContent=playerNames[0]+' finished in '+formatTime(elapsed)+'. Now '+playerNames[1]+' plays the same puzzle!';
   duelPlayer=2;setTimeout(()=>{resetBoard();started=false;$('playerName').value=playerNames[1];$('message').textContent=playerNames[1]+', your turn!';},1800);
  }else{
   const winner=playerTimes[0]===playerTimes[1]?'It is a tie!':(playerTimes[0]<playerTimes[1]?playerNames[0]+' wins!':playerNames[1]+' wins!');
   $('message').textContent=winner+' '+playerNames[0]+': '+formatTime(playerTimes[0])+' · '+playerNames[1]+': '+formatTime(playerTimes[1]);
   duel=false;duelPlayer=1;
  }
 }else{
  $('message').textContent='Victory! You solved the puzzle in '+formatTime(elapsed)+' with '+moves+' moves.';
  saveScore($('playerName').value.trim()||'Player 1',mode,elapsed,moves);
 }
}
async function saveScore(player,gameMode,seconds,moveCount){
 try{await fetch('/api/scores',{method:'POST',headers:{'Content-Type':'application/json'},body:JSON.stringify({player,mode:gameMode,seconds,moves:moveCount})})}catch(e){console.warn('Could not save score',e)}
}
function setMode(next){
 mode=next;document.body.className=mode;
 document.querySelectorAll('.mode').forEach(b=>b.classList.toggle('active',b.dataset.mode===mode));
 $('preview').textContent=modes[mode].creature+' '+modes[mode].name+': '+modes[mode].preview;
 resetBoard();
}
document.querySelectorAll('.mode').forEach(btn=>{
 btn.addEventListener('mouseenter',()=>{const m=modes[btn.dataset.mode];$('preview').textContent='Preview · '+m.creature+' '+m.name+' — '+m.preview+' ('+m.discs+' discs, '+m.min+' minimum moves).'});
 btn.addEventListener('focus',()=>{const m=modes[btn.dataset.mode];$('preview').textContent='Preview · '+m.creature+' '+m.name+' — '+m.preview;});
 btn.addEventListener('click',()=>setMode(btn.dataset.mode));
});
$('singleBtn').onclick=()=>{duel=false;playerNames[0]=$('playerName').value.trim()||'Player 1';resetBoard();$('message').textContent=playerNames[0]+', solve the puzzle!';playTone(440)};
$('duelBtn').onclick=()=>{
 const first=$('playerName').value.trim()||'Player 1';
 const second=prompt('Enter Player 2 name:','Player 2');if(!second||!second.trim())return;
 playerNames=[first,second.trim().slice(0,30)];playerTimes=[];playerMoves=[];duel=true;duelPlayer=1;resetBoard();
 $('undoBtn').disabled=true;$('restartBtn').disabled=true;$('message').textContent=playerNames[0]+' goes first. No undo or restart in duel mode.';
};
$('undoBtn').onclick=()=>{if(duel||!history.length||finished)return;towers=history.pop();moves--;selected=null;$('moves').textContent=moves;render()};
$('restartBtn').onclick=()=>{if(duel)return;resetBoard()};
$('pauseBtn').onclick=()=>{if(finished)return;paused=!paused;$('pauseBtn').textContent=paused?'Resume':'Pause';$('message').textContent=paused?'Game paused.':'Game resumed.'};
$('soundBtn').onclick=()=>{audioOn=!audioOn;$('soundBtn').textContent='Sound: '+(audioOn?'On':'Off');if(audioOn)playTone(500)};
$('menuBtn').onclick=()=>{duel=false;duelPlayer=1;$('undoBtn').disabled=false;$('restartBtn').disabled=false;resetBoard();$('message').textContent='Choose a mode, then start your adventure.'};
$('howBtn').onclick=()=>alert('Tower of Hanoi rules:\\n1. Move only one disc at a time.\\n2. Only move the top disc of a tower.\\n3. Never place a larger disc on a smaller disc.\\nMove every disc from Tower A to Tower C.');
$('leaderBtn').onclick=loadLeaderboard;
async function loadLeaderboard(){
 const box=$('leaderboard');box.innerHTML='<h3>Leaderboard</h3><p>Loading...</p>';
 try{
  const response=await fetch('/api/leaderboard');const data=await response.json();
  const rows=data.scores.filter(s=>s.mode===mode).slice(0,10);
  box.innerHTML='<h3>Leaderboard · '+mode.toUpperCase()+'</h3>';
  if(!rows.length){box.innerHTML+='<p>No scores yet. Be the first!</p>';return}
  const table=document.createElement('table');table.innerHTML='<tr><th>Player</th><th>Time</th><th>Moves</th><th>Date</th></tr>';
  rows.forEach(s=>{const tr=document.createElement('tr');[s.player,formatTime(s.seconds),s.moves,s.completed_at].forEach(v=>{const td=document.createElement('td');td.textContent=v;tr.appendChild(td)});table.appendChild(tr)});
  box.appendChild(table);
 }catch(e){box.textContent='Leaderboard is unavailable.'}
}
$('undoBtn').disabled=false;$('restartBtn').disabled=false;
resetBoard();
fetch('/api/health').catch(()=>{});
</script>
</body></html>").
