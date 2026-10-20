"""Writes the free tool pages (public/<tool>/index.html, public/tools/index.html), sitemap.xml and robots.txt.
Shared look and maths: public/tools/tools.css and tools.js. Edit here, then re-run."""
import json, os
ROOT=os.path.join(os.path.dirname(os.path.abspath(__file__)),"..","public")  # run: python3 scripts/gen-tools.py
SITE="https://usedigitaldash.vercel.app"
TOOLS=[("grade-calculator","Grade calculator","Weighted average, letter grade and GPA"),
       ("final-grade-calculator","Final grade calculator","What you need on the final"),
       ("pomodoro-timer","Pomodoro timer","25-minute focus sessions with breaks"),
       ("bmi-calculator","BMI calculator","BMI, category and healthy weight"),
       ("calorie-calculator","Calorie calculator","Maintenance calories, and whether to cut or bulk")]
def head(slug,title,desc,ld):
    url=f"{SITE}/{slug}" if slug else f"{SITE}/tools"
    return f'''<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
<title>{title}</title>
<meta name="description" content="{desc}">
<link rel="canonical" href="{url}">
<meta name="theme-color" content="#1B1B1B">
<meta property="og:type" content="website">
<meta property="og:title" content="{title}">
<meta property="og:description" content="{desc}">
<meta property="og:url" content="{url}">
<meta property="og:image" content="{SITE}/brand/og.png">
<meta name="twitter:card" content="summary_large_image">
<link rel="icon" type="image/png" sizes="32x32" href="/brand/favicon-32.png">
<link rel="apple-touch-icon" href="/digital-dash-apple-180.png">
<script src="/i18n/i18n.js"></script>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>
<link href="https://fonts.googleapis.com/css2?family=Big+Shoulders+Display:wght@800;900&family=Bricolage+Grotesque:opsz,wght@12..96,400;12..96,600;12..96,700&display=swap" rel="stylesheet">
<link rel="stylesheet" href="/tools/tools.css">
<script type="application/ld+json">{json.dumps(ld,ensure_ascii=False)}</script>
</head>
<body>
<a class="skip" href="#main">Skip to content</a>
<header class="nav"><div class="wrap">
  <a class="brand" href="/" aria-label="Digital Dash home"><span class="mk" aria-hidden="true"></span><span class="bt">Digital Dash</span></a>
  <a class="more" href="/tools">Free tools</a>
  <nav aria-label="Free tools"><ul>{"".join(f'<li><a href="/{s}"{" aria-current=page" if s==slug else ""}>{n}</a></li>' for s,n,_ in TOOLS)}</ul></nav>
  <label class="lang"><span class="sr">Language</span><select data-lang></select></label>
  <a class="btn pri small" href="/digital-dash.html">Open app</a>
</div></header>
<main id="main">
'''
def foot(slug):
    rel="".join(f'<a href="/{s}"><b>{n}</b><span>{d}</span></a>' for s,n,d in TOOLS if s!=slug)
    return f'''<section class="wrap prose" aria-labelledby="more-h" style="max-width:none"><h2 id="more-h">More free tools</h2><div class="related">{rel}</div></section>
</main>
<footer><div class="wrap"><span class="mk" aria-hidden="true"></span><span>© <span id="yr"></span> Digital Dash</span><nav aria-label="Footer"><a href="/tools">All free tools</a><a href="/">Home</a><a href="/digital-dash.html">Open app</a><a href="/digital-dash-privacy.html">Privacy</a></nav></div></footer>
<script src="/tools/tools.js"></script>
'''
def ld(slug,name,desc,faq):
    return [{"@context":"https://schema.org","@type":"WebApplication","name":name,"url":f"{SITE}/{slug}","description":desc,"applicationCategory":"EducationalApplication" if "grade" in slug or "pomodoro" in slug else "HealthApplication","operatingSystem":"Any","offers":{"@type":"Offer","price":"0","priceCurrency":"USD"}},
            {"@context":"https://schema.org","@type":"FAQPage","mainEntity":[{"@type":"Question","name":q,"acceptedAnswer":{"@type":"Answer","text":a}} for q,a in faq]}]
def faqhtml(faq): return "".join(f"<details><summary>{q}</summary><p>{a}</p></details>" for q,a in faq)
def save(title,text,btn,extra=""):
    return f'''<div class="save" role="region" aria-label="Save this in Digital Dash"><b>{title}</b><p>{text}</p><div class="go">{extra}<button type="button" class="btn pri" id="save">{btn}</button></div></div>'''
def page(slug,title,desc,eyebrow,h1,lead,tool,prose,faq,script):
    name=next(n for s,n,_ in TOOLS if s==slug)
    html=head(slug,title,desc,ld(slug,name,desc,faq))+f'''<div class="wrap hero"><span class="eyebrow">{eyebrow}</span><h1>{h1}</h1><p>{lead}</p></div>
<div class="wrap tool">{tool}</div>
<article class="wrap prose">{prose}<h2>Questions</h2>{faqhtml(faq)}</article>
'''+foot(slug)+f"<script>\n{script}\n</script>\n</body>\n</html>\n"
    os.makedirs(f"{ROOT}/{slug}",exist_ok=True);open(f"{ROOT}/{slug}/index.html","w").write(html)

# ---------------- grade calculator ----------------
page("grade-calculator","Grade Calculator: Weighted Average, Letter Grade and GPA · Digital Dash",
 "Free weighted grade calculator. Enter your grades and weights to get your average, letter grade and GPA, and see what you need on the rest of the course. US, Ontario and Western scales.",
 "Free tool","Grade calculator","Add each assignment, test or exam with its weight. Your average, letter grade and GPA update as you type, and you can see exactly what you need on the rest of the course.",
 '''<section class="card" aria-labelledby="in-h"><h2 id="in-h">Your grades</h2>
  <div class="seg" id="type" role="group" aria-label="Grade type"><button type="button" data-v="pct" aria-pressed="true">Percent</button><button type="button" data-v="letter" aria-pressed="false">Letters</button><button type="button" data-v="pts" aria-pressed="false">Points</button></div>
  <div class="rows" id="rows"></div>
  <p><button type="button" class="btn small" id="add">+ Add a row</button></p>
  <div class="fields"><label>Grading scale<select id="scale"><option value="us">Standard (US)</option><option value="on">Ontario (U of T style)</option><option value="western">Western University</option></select></label></div>
  <h2 style="margin-top:22px" id="plan-h">What do I need?</h2>
  <div class="fields" role="group" aria-labelledby="plan-h"><label>Goal for the course<input id="goal" placeholder="e.g. 85 or A-" inputmode="text"></label><label id="rem-l">Weight still to come (%)<input id="rem" placeholder="auto" inputmode="decimal"></label></div>
 </section>
 <section class="card out" aria-labelledby="out-h" aria-live="polite"><h2 id="out-h">Result</h2><div id="out"><p class="muted">Enter a grade to see your average.</p></div>
  '''+save("Save this in Digital Dash","Keep this course with your tasks and planner, and update it as marks come in.","Save as a course",'<label class="sr" for="cname">Course name</label><input id="cname" maxlength="32" placeholder="Course name, e.g. ES 1050">')+'''</section>''',
 '''<h2>How the grade calculator works</h2>
 <p><strong>Percent grades</strong> are averaged by weight. Each grade is multiplied by its weight, the results are added up, and the total is divided by the sum of the weights you've entered. If you leave every weight blank, each grade counts the same.</p>
 <div class="formula">average = (grade₁ × weight₁ + grade₂ × weight₂ + …) ÷ (weight₁ + weight₂ + …)</div>
 <p><strong>Points</strong> add up what you earned and divide by what was possible, for example 42/50 and 18/20 make 60/70, or 85.7%. <strong>Letters</strong> are averaged using GPA points (or the middle of each range on scales without GPA) and turned back into a letter.</p>
 <h2>What you need on the rest</h2>
 <p>If your current average covers part of the course and R% is still to come, the grade you need on the remaining work is:</p>
 <div class="formula">needed = (goal − average × (100 − R) ÷ 100) ÷ (R ÷ 100)</div>
 <p>By default R is whatever weight you haven't entered yet, so if your rows add up to 60%, the calculator assumes 40% is left.</p>''',
 [("How do I calculate my weighted grade?","Multiply each grade by its weight, add the results, then divide by the total weight you've entered. For example 80% on an assignment worth 30% and 90% on a midterm worth 30% gives (80×30 + 90×30) ÷ 60 = 85%."),
  ("What if my weights don't add up to 100?","That's fine. Your average is based on the weights entered so far, and the rest is treated as still to come when you plan what you need."),
  ("Which grading scale should I use?","Standard (US) uses A 93+, A- 90 and so on. Ontario (U of T style) uses A+ 90, A 85, A- 80. Western University uses A+ 90, A 80, B 70, C 60, D 50. Pick the one your school uses."),
  ("Is my data saved?","Your grades stay in this browser tab. Use Save as a course to keep them in Digital Dash, which works offline and can sync if you sign in.")],
 r'''const {num,pct,SCALES,letter,grades,$,esc,seg,saveToApp}=DD;
let g={type:"pct",scale:"us",rows:[{n:"Assignments",g:"",w:"30"},{n:"Midterm",g:"",w:"30"},{n:"",g:"",w:""}],goal:"",rem:""};
const HEAD={pct:["Grade (%)","Weight (%)"],letter:["Letter","Weight (%)"],pts:["Points earned","Points possible"]};
function rows(){$("#rows").innerHTML=g.rows.map((r,i)=>`<div class="row" data-i="${i}"><label>Name<input data-f="n" value="${esc(r.n)}" placeholder="e.g. Quiz ${i+1}"></label><label>${HEAD[g.type][0]}<input data-f="g" value="${esc(r.g)}" placeholder="${g.type==="letter"?"B+":g.type==="pts"?"42":"85"}" inputmode="${g.type==="letter"?"text":"decimal"}"></label><label>${HEAD[g.type][1]}<input data-f="w" value="${esc(r.w)}" placeholder="${g.type==="pts"?"50":"20"}" inputmode="decimal"></label><button type="button" class="x" data-del="${i}" aria-label="Remove row ${i+1}">×</button></div>`).join("");
  $("#rem-l").firstChild.textContent=g.type==="pts"?"Points still to come":"Weight still to come (%)";$("#goal").disabled=$("#rem").disabled=g.type==="letter";}
function out(){const o=grades(g),sc=SCALES[g.scale];let h="";
  if(o.pct==null&&o.gpa==null){h=`<p class="muted">Enter a grade to see your average.</p>`;}
  else{h=`<div class="big"><b>${o.pct!=null?pct(o.pct):o.L[0]}</b>${o.L?`<span>${o.pct!=null?o.L[0]:""}${sc.gpa&&o.gpa!=null?` · GPA ${o.gpa.toFixed(2)}`:""}</span>`:""}</div>
    <ul class="list"><li><span>Graded parts</span><b>${o.n}</b></li>${o.sw!=null?`<li><span>Weight entered</span><b>${pct(o.sw)}</b></li>`:""}${g.type==="pts"?`<li><span>Points</span><b>${o.earned} / ${o.poss}</b></li>`:""}</ul>
    ${o.skipped?`<p class="note">${o.skipped} row${o.skipped>1?"s were":" was"} skipped because ${g.type==="pts"?"points possible is missing":"the weight is missing"}.</p>`:""}`;
    if(o.need!=null){const n=o.need;h+=`<h2 style="margin:20px 0 6px;font-size:22px">To finish with ${pct(o.goal)}</h2><div class="big"><b>${n<=0?"0%":pct(n)}</b><span>needed on the remaining ${g.type==="pts"?o.R+" points":pct(o.R)}</span></div>
      <p class="note">${n<=0?"You've already locked it in, even with zero on the rest.":n>100?`That's over 100%, so it's out of reach. The best you can finish with is ${pct(o.best)}.`:`Doing that keeps you on track. Getting 100% on the rest would give you ${pct(o.best)}.`}</p>`;}
    h+=`<details><summary>${esc(sc.name)} scale</summary><table><thead><tr><th>Letter</th><th class="n">From</th>${sc.gpa?'<th class="n">GPA</th>':""}</tr></thead><tbody>${sc.rows.map(x=>`<tr class="${o.L&&o.L[0]===x[0]?"hi":""}"><td>${x[0]}</td><td class="n">${x[1]}%</td>${sc.gpa?`<td class="n">${x[2].toFixed(1)}</td>`:""}</tr>`).join("")}</tbody></table></details>`;}
  $("#out").innerHTML=h;}
$("#rows").addEventListener("input",e=>{const f=e.target.dataset.f;if(!f)return;g.rows[+e.target.closest(".row").dataset.i][f]=e.target.value;out();});
$("#rows").addEventListener("click",e=>{const b=e.target.closest("[data-del]");if(!b)return;g.rows.splice(+b.dataset.del,1);if(!g.rows.length)g.rows.push({n:"",g:"",w:""});rows();out();});
$("#add").addEventListener("click",()=>{g.rows.push({n:"",g:"",w:""});rows();out();$("#rows .row:last-child input").focus();});
seg($("#type"),v=>{g.type=v;rows();out();});
$("#scale").addEventListener("change",e=>{g.scale=e.target.value;out();});
$("#goal").addEventListener("input",e=>{g.goal=e.target.value;out();});$("#rem").addEventListener("input",e=>{g.rem=e.target.value;out();});
$("#save").addEventListener("click",()=>{const name=$("#cname").value.trim();if(!name){$("#cname").focus();$("#cname").placeholder="Give the course a name first";return;}
  if(!g.rows.some(r=>r.g||r.w)){$("#rows input[data-f=g]").focus();return;}saveToApp("grades",Object.assign({course:name},g),"grades");});
rows();out();''')

# ---------------- final grade calculator ----------------
page("final-grade-calculator","Final Grade Calculator: What Do I Need on My Final? · Digital Dash",
 "Find out exactly what you need on your final exam to get the grade you want. Enter your current grade, your goal and how much the final is worth.",
 "Free tool","What do I need on my final?","Enter your grade right now, the grade you want, and how much the final is worth. You'll see the score you need, and what you'd finish with for every result.",
 '''<section class="card" aria-labelledby="in-h"><h2 id="in-h">Your course</h2>
  <div class="fields"><label>Current grade (%)<input id="cur" placeholder="e.g. 82" inputmode="decimal"></label><label>Grade you want<input id="want" placeholder="e.g. 85 or A" inputmode="text"></label><label>Final is worth (%)<input id="w" placeholder="e.g. 40" inputmode="decimal"></label></div>
  <div class="fields" style="margin-top:12px"><label>Letter grades use<select id="scale"><option value="us">Standard (US)</option><option value="on">Ontario (U of T style)</option><option value="western">Western University</option></select></label></div>
 </section>
 <section class="card out" aria-labelledby="out-h" aria-live="polite"><h2 id="out-h">You need</h2><div id="out"><p class="muted">Fill in all three to see what you need.</p></div>
  '''+save("Save this in Digital Dash","Keep it in the grade calculator next to your courses and exam dates.","Save to my grade calculator")+'''</section>''',
 '''<h2>How it's worked out</h2>
 <p>Your current grade covers everything except the final. If the final is worth w% of the course, then:</p>
 <div class="formula">needed on the final = (grade you want − current grade × (1 − w)) ÷ w</div>
 <p>For example, with 82% now, a goal of 85% and a final worth 40%: (85 − 82 × 0.6) ÷ 0.4 = <strong>89.5%</strong>.</p>
 <p>If the answer is 0 or less, you've already locked in your goal. If it's over 100%, the goal is out of reach, and the table shows the best you can finish with.</p>''',
 [("How do I calculate what I need on my final?","Take the grade you want, subtract your current grade times the share of the course that's already done, then divide by the final's weight. With 82% now, an 85% goal and a 40% final: (85 − 82 × 0.6) ÷ 0.4 = 89.5%."),
  ("What if I need more than 100%?","Then that goal can't be reached with the final alone. The calculator shows the best grade you can still finish with, so you can set a realistic target."),
  ("Can I use a letter grade as my goal?","Yes. Type a letter like A- and it uses that letter's cutoff on the scale you choose (Standard US, Ontario or Western)."),
  ("Does my current grade need to be exact?","Use the grade your school shows for the course so far. If parts are still unmarked, the answer will shift once they are.")],
 r'''const {pct,finalNeed,$,saveToApp}=DD;
function out(){const f=finalNeed($("#cur").value,$("#want").value,$("#w").value,$("#scale").value);
  if(!f){$("#out").innerHTML=`<p class="muted">Fill in all three to see what you need.</p>`;return;}
  const n=f.need,rows=[];for(let s=100;s>=40;s-=10)rows.push(s);
  $("#out").innerHTML=`<div class="big"><b>${n<=0?"0%":pct(n)}</b><span>on the final for ${pct(f.want)}</span></div>
   <p class="note">${n<=0?"You've already locked it in. Even a zero on the final gets you there.":n>100?`That's more than 100%, so it's out of reach. A perfect final would give you ${pct(f.best)}.`:`A perfect final would give you ${pct(f.best)}; a zero would leave you at ${pct(f.worst)}.`}</p>
   <table style="margin-top:12px"><caption class="sr">Final course grade for each final exam score</caption><thead><tr><th>If you get</th><th class="n">You finish with</th></tr></thead><tbody>${rows.map(s=>`<tr><td>${s}% on the final</td><td class="n">${pct(f.cur*(1-f.p/100)+s*f.p/100)}</td></tr>`).join("")}</tbody></table>`;}
["#cur","#want","#w"].forEach(s=>$(s).addEventListener("input",out));$("#scale").addEventListener("change",out);
$("#save").addEventListener("click",()=>{if(!finalNeed($("#cur").value,$("#want").value,$("#w").value,$("#scale").value)){$("#cur").focus();return;}
  saveToApp("final",{cur:$("#cur").value,want:$("#want").value,w:$("#w").value,scale:$("#scale").value},"grades");});
out();''')

# ---------------- pomodoro timer ----------------
page("pomodoro-timer","Pomodoro Timer: Free Online Focus Timer · Digital Dash",
 "A free online Pomodoro timer. 25 minutes of focus, 5-minute breaks and a longer break every four sessions, with a gentle chime. Works on your phone and computer.",
 "Free tool","Pomodoro timer","Work in focused blocks with short breaks between them. Press Start, put your phone down, and let the chime tell you when to rest.",
 '''<section class="card" aria-labelledby="t-h" style="text-align:center"><h2 id="t-h" class="sr">Timer</h2>
  <div class="seg" id="len" role="group" aria-label="Session length" style="justify-content:center"><button type="button" data-v="25,5" aria-pressed="true">25 / 5</button><button type="button" data-v="50,10" aria-pressed="false">50 / 10</button><button type="button" data-v="90,20" aria-pressed="false">90 / 20</button></div>
  <p id="phase" style="margin:6px 0 0;font:800 16px/1 var(--display);letter-spacing:.14em;text-transform:uppercase">Focus</p>
  <div id="time" role="timer" aria-live="off" style="font:900 clamp(88px,18vw,168px)/1 var(--display);font-variant-numeric:tabular-nums;margin:6px 0 10px">25:00</div>
  <div style="height:6px;border-radius:3px;background:color-mix(in srgb,var(--ink) 14%,transparent);overflow:hidden;margin:0 auto 18px;max-width:420px"><i id="bar" style="display:block;height:100%;width:0;background:var(--ink);transition:width 1s linear"></i></div>
  <div style="display:flex;gap:10px;justify-content:center;flex-wrap:wrap"><button type="button" class="btn pri" id="go" style="min-width:140px">Start</button><button type="button" class="btn" id="skip">Skip</button><button type="button" class="btn" id="reset">Reset</button></div>
  <p class="note" id="count" aria-live="polite">Session 1 of 4 before a long break</p>
  <label style="display:inline-flex;grid-auto-flow:column;align-items:center;gap:8px;margin-top:10px;font-weight:600"><input type="checkbox" id="snd" checked style="width:20px;min-height:20px"> Chime when time's up</label>
 </section>
 <section class="card out" aria-labelledby="out-h"><h2 id="out-h">Today</h2><div id="today" aria-live="polite"><p class="muted">No sessions yet. Press Start.</p></div>
  '''+save("Save this in Digital Dash","Get these timers with study music, a session log, study rooms with friends and a weekly recap.","Add these timers to my dashboard")+'''</section>''',
 '''<h2>What is the Pomodoro technique?</h2>
 <p>It's a simple way to study or work: focus on one thing for <strong>25 minutes</strong>, take a <strong>5-minute break</strong>, and after four sessions take a longer <strong>15 to 30 minute break</strong>. Short, fixed blocks make it easier to start and harder to drift.</p>
 <h2>Tips that make it work</h2>
 <ul><li>Pick one task before you press Start, and write down distractions instead of acting on them.</li><li>Get up during breaks. Don't spend them on your phone.</li><li>If 25 minutes feels too short for deep work, try 50 / 10 or 90 / 20.</li></ul>''',
 [("How long is a Pomodoro?","The classic Pomodoro is 25 minutes of focus followed by a 5-minute break. After four, take a longer break of 15 to 30 minutes."),
  ("Does the timer keep running if I switch tabs?","Yes. It counts from the real clock, so it stays accurate in a background tab, and the chime plays when the time is up."),
  ("Can I change the length?","Yes. Choose 25 / 5, 50 / 10 or 90 / 20 here. In Digital Dash you can make your own timers from 10 seconds to 10 hours."),
  ("Is it free?","Yes. This timer and the full Digital Dash app are free to use.")],
 r'''const {$,seg,saveToApp}=DD;
let F=25,B=5,phase="focus",left=F*60,end=0,run=false,done=0,n=1,tick=0,ctx=null;const LONG=()=>Math.max(15,B*3);
const fmt=s=>`${Math.floor(s/60)}:${String(Math.floor(s%60)).padStart(2,"0")}`;
const total=()=>phase==="focus"?F*60:phase==="long"?LONG()*60:B*60;
function draw(){$("#time").textContent=fmt(left);$("#phase").textContent=phase==="focus"?"Focus":phase==="long"?"Long break":"Break";$("#bar").style.width=((1-left/total())*100).toFixed(1)+"%";
  $("#go").textContent=run?"Pause":left<total()?"Resume":"Start";document.title=(run?fmt(left)+" · ":"")+"Pomodoro Timer · Digital Dash";
  $("#count").textContent=phase==="focus"?`Session ${n} of 4 before a long break`:"Get up, stretch, drink some water";}
function chime(){if(!$("#snd").checked)return;try{ctx=ctx||new (window.AudioContext||window.webkitAudioContext)();[0,.18,.36].forEach((t,i)=>{const o=ctx.createOscillator(),g=ctx.createGain();o.type="sine";o.frequency.value=[784,988,1175][i];g.gain.setValueAtTime(0,ctx.currentTime+t);g.gain.linearRampToValueAtTime(.25,ctx.currentTime+t+.02);g.gain.exponentialRampToValueAtTime(.001,ctx.currentTime+t+.9);o.connect(g).connect(ctx.destination);o.start(ctx.currentTime+t);o.stop(ctx.currentTime+t+1);});}catch(e){}}
function next(){if(phase==="focus"){done++;$("#today").innerHTML=`<div class="big"><b>${done}</b><span>focus session${done>1?"s":""} · ${done*F} min</span></div>`;phase=n%4===0?"long":"break";if(n%4===0)n=0;n++;}else phase="focus";left=total();}
function loop(){if(!run)return;left=Math.max(0,(end-Date.now())/1000);if(left<=0){run=false;chime();next();draw();return;}draw();tick=setTimeout(loop,250);}
$("#go").addEventListener("click",()=>{if(ctx&&ctx.state==="suspended")ctx.resume();if(!ctx)try{ctx=new (window.AudioContext||window.webkitAudioContext)();}catch(e){}
  run=!run;if(run){end=Date.now()+left*1000;loop();}else{clearTimeout(tick);draw();}});
$("#skip").addEventListener("click",()=>{run=false;clearTimeout(tick);next();draw();});
$("#reset").addEventListener("click",()=>{run=false;clearTimeout(tick);phase="focus";left=F*60;draw();});
seg($("#len"),v=>{[F,B]=v.split(",").map(Number);run=false;clearTimeout(tick);phase="focus";left=F*60;draw();});
$("#save").addEventListener("click",()=>saveToApp("timer",{focus:F,brk:B},"focus"));
draw();''')

# ---------------- BMI ----------------
BODY_FIELDS='''<div class="seg" id="units" role="group" aria-label="Units"><button type="button" data-v="us" aria-pressed="true">US units</button><button type="button" data-v="metric" aria-pressed="false">Metric</button></div>
  <div class="fields" id="f-us"><label>Height (ft)<input data-p="ft" placeholder="5" inputmode="numeric"></label><label>Height (in)<input data-p="inch" placeholder="10" inputmode="decimal"></label><label>Weight (lb)<input data-p="lb" placeholder="165" inputmode="decimal"></label></div>
  <div class="fields" id="f-metric" hidden><label>Height (cm)<input data-p="cm" placeholder="178" inputmode="decimal"></label><label>Weight (kg)<input data-p="kg" placeholder="75" inputmode="decimal"></label></div>'''
BODY_JS=r'''const P={units:"us",sex:"m",age:"",ft:"",inch:"",cm:"",lb:"",kg:"",act:1.465,formula:"m",bf:""};
document.querySelectorAll("[data-p]").forEach(i=>i.addEventListener("input",()=>{P[i.dataset.p]=i.value;out();}));
const fill=()=>document.querySelectorAll("[data-p]").forEach(i=>{i.value=P[i.dataset.p]??"";});
seg($("#units"),v=>{if(v===P.units)return;const n=DD.num;
  if(v==="metric"){const inch=(n(P.ft)||0)*12+(n(P.inch)||0);if(inch)P.cm=String(Math.round(inch*2.54));if(n(P.lb))P.kg=String(Math.round(n(P.lb)*0.45359237*10)/10);}
  else{if(n(P.cm)){const t=n(P.cm)/2.54;P.ft=String(Math.floor(t/12));P.inch=String(Math.round(t%12));if(P.inch==="12"){P.ft=String(+P.ft+1);P.inch="0";}}if(n(P.kg))P.lb=String(Math.round(n(P.kg)/0.45359237));}
  P.units=v;$("#f-us").hidden=v!=="us";$("#f-metric").hidden=v==="us";fill();out();});
const fmtW=v=>Math.round(v*10)/10;'''
page("bmi-calculator","BMI Calculator: Body Mass Index and Healthy Weight · Digital Dash",
 "Free BMI calculator in US or metric units. See your BMI, its category, the healthy weight range for your height, BMI Prime and Ponderal index.",
 "Free tool","BMI calculator","Enter your height and weight to see your body mass index, what it means, and the healthy weight range for your height.",
 '''<section class="card" aria-labelledby="in-h"><h2 id="in-h">Your details</h2>'''+BODY_FIELDS+'''
  <div class="fields" style="margin-top:12px"><label>Age (optional)<input data-p="age" placeholder="e.g. 20" inputmode="numeric"></label></div>
 </section>
 <section class="card out" aria-labelledby="out-h" aria-live="polite"><h2 id="out-h">Your BMI</h2><div id="out"><p class="muted">Enter your height and weight.</p></div>
  '''+save("Save this in Digital Dash","Track your bodyweight over time next to your workouts, and get calorie targets for cutting or bulking.","Save to my dashboard")+'''</section>''',
 '''<h2>How BMI is calculated</h2>
 <div class="formula">BMI = weight (kg) ÷ height (m)²  ·  in US units: 703 × weight (lb) ÷ height (in)²</div>
 <p>For adults, the World Health Organization groups BMI as: under 18.5 underweight (16 to 17 moderate thinness, under 16 severe), <strong>18.5 to 25 normal</strong>, 25 to 30 overweight, and 30 or more obese (classes I, II and III start at 30, 35 and 40).</p>
 <p><strong>BMI Prime</strong> is your BMI divided by 25, the top of the normal range, so 1.00 is the upper limit. The <strong>Ponderal index</strong> divides weight by height cubed, which suits very tall or short people a little better.</p>
 <h2>What BMI can't tell you</h2>
 <p>BMI doesn't separate muscle from fat, so athletes can read as overweight. For people under 20, doctors compare BMI with age and sex percentiles instead. Use it as a rough guide, not a diagnosis.</p>''',
 [("What is a healthy BMI?","For adults, a BMI from 18.5 to 25 is in the normal range. Under 18.5 is underweight, 25 to 30 overweight, and 30 or more obese."),
  ("How do I calculate BMI in pounds and inches?","Multiply your weight in pounds by 703, then divide by your height in inches squared. 165 lb at 5'10\" (70 in) is 703 × 165 ÷ 4,900 = 23.7."),
  ("Is BMI accurate for muscular people?","Not very. BMI only uses height and weight, so muscle counts the same as fat. Body fat percentage is a better measure if you lift."),
  ("Does BMI work for teenagers?","Under 20, BMI is compared against age and sex percentiles, so the adult categories are only a rough guide.")],
 r'''const {$,seg,body,saveToApp}=DD;
'''+BODY_JS+r'''
function out(){const r=body(P);if(!r.ok){$("#out").innerHTML=`<p class="muted">Enter your height and weight.</p>`;return;}
  const wu=P.units==="us"?"lb":"kg",wv=kg=>P.units==="us"?kg/0.45359237:kg,pos=Math.max(0,Math.min(1,(r.bmi-15)/25));
  const diff=r.bmi>25?`Losing ${fmtW(wv(r.w-r.hi))} ${wu} would bring you to a BMI of 25.`:r.bmi<18.5?`Gaining ${fmtW(wv(r.lo-r.w))} ${wu} would bring you to a BMI of 18.5.`:"You're in the healthy range.";
  $("#out").innerHTML=`<div class="big"><b>${r.bmi.toFixed(1)}</b><span>${r.cat}</span></div>
   <div class="bar" role="img" aria-label="BMI ${r.bmi.toFixed(1)} on a scale from 15 to 40. Healthy is 18.5 to 25."><i style="left:${(pos*100).toFixed(1)}%"></i><span style="left:0">15</span><span style="left:14%">18.5</span><span style="left:40%">25</span><span style="left:60%">30</span><span style="left:100%">40</span></div>
   <ul class="list"><li><span>Healthy weight for your height</span><b>${fmtW(wv(r.lo))} – ${fmtW(wv(r.hi))} ${wu}</b></li><li><span>BMI Prime</span><b>${r.prime.toFixed(2)}</b></li><li><span>Ponderal index</span><b>${r.pi.toFixed(1)} kg/m³</b></li></ul>
   <p class="note">${diff} ${r.age!=null&&r.age<20?"Under 20, BMI is compared with age percentiles, so treat the category as rough. ":""}BMI doesn't separate muscle from fat.</p>
   <p class="note"><a href="/calorie-calculator">See your calories, and whether to cut or bulk →</a></p>`;}
$("#save").addEventListener("click",()=>{if(!body(P).ok){$("[data-p=ft]").focus();return;}saveToApp("body",P,"bmi");});
out();''')

# ---------------- calorie ----------------
page("calorie-calculator","Calorie Calculator: Maintenance Calories, Cut or Bulk · Digital Dash",
 "Free calorie calculator. Find your maintenance calories (TDEE) and BMR, see how much to eat to lose or gain weight, and get a cut, maintain or bulk suggestion with macros.",
 "Free tool","Calorie calculator","Find out how many calories you burn in a day, how much to eat to lose or gain weight, and whether cutting, maintaining or bulking suits you right now.",
 '''<section class="card" aria-labelledby="in-h"><h2 id="in-h">Your details</h2>'''+BODY_FIELDS+'''
  <div class="fields" style="margin-top:12px"><label>Age<input data-p="age" placeholder="15–80" inputmode="numeric"></label><label>Sex<select id="sex"><option value="m">Male</option><option value="f">Female</option></select></label><label>Body fat % (optional)<input data-p="bf" placeholder="e.g. 18" inputmode="decimal"></label></div>
  <div class="fields" style="margin-top:12px"><label>Activity<select id="act"></select></label></div>
  <div class="fields" style="margin-top:12px"><label>Formula<select id="formula"><option value="m">Mifflin-St Jeor</option><option value="r">Revised Harris-Benedict</option><option value="k">Katch-McArdle (needs body fat %)</option></select></label></div>
 </section>
 <section class="card out" aria-labelledby="out-h" aria-live="polite"><h2 id="out-h">Calories per day</h2><div id="out"><p class="muted">Enter your age, height and weight.</p></div>
  '''+save("Save this in Digital Dash","Keep your targets next to a gym log with your split, progress charts and a plate calculator.","Save to my dashboard")+'''</section>''',
 '''<h2>How your calories are worked out</h2>
 <p>First your <strong>BMR</strong>, the energy you burn at rest. The default Mifflin-St Jeor equation is:</p>
 <div class="formula">men: 10 × weight (kg) + 6.25 × height (cm) − 5 × age + 5<br>women: 10 × weight (kg) + 6.25 × height (cm) − 5 × age − 161</div>
 <p>Your <strong>maintenance calories</strong> (TDEE) are BMR times an activity factor from 1.2 (sedentary) to 1.9 (very active). About 3,500 kcal is a pound of fat, so eating 500 kcal under maintenance loses roughly 1 lb a week.</p>
 <h2>Cut, maintain or bulk?</h2>
 <p>With your body fat %, men over 25% or women over 32% are pointed to a cut, and men under 12% or women under 20% to a lean bulk. Without it, BMI is used: under 22 lean bulk, 22 to 25 maintain, 25 and over cut. Macros follow the plan: protein 2.2 g per kg on a cut and 1.8 otherwise, fat 25% of calories, carbs the rest.</p>
 <p>This is general guidance, not medical advice. Eating under 1,500 kcal (men) or 1,200 kcal (women) a day isn't recommended without a doctor.</p>''',
 [("How many calories should I eat to lose weight?","Eat about 500 kcal a day under your maintenance calories to lose about 1 lb (0.5 kg) a week. The table shows mild, normal and fast options."),
  ("What are maintenance calories?","The calories you burn in a day, also called TDEE. It's your BMR (calories at rest) times how active you are. Eating this much keeps your weight steady."),
  ("Should I cut or bulk?","If your body fat or BMI is high, cut first. If you're lean, a slow lean bulk adds muscle with little fat. In between, eating at maintenance while you train (a recomp) works well."),
  ("Which formula is most accurate?","Mifflin-St Jeor is accurate for most people. If you know your body fat percentage, Katch-McArdle accounts for muscle and is often closer.")],
 r'''const {$,seg,body,plans,ACTS,saveToApp,esc}=DD;
'''+BODY_JS+r'''
$("#act").innerHTML=ACTS.map(([v,l])=>`<option value="${v}"${v===1.465?" selected":""}>${esc(l)}</option>`).join("");
$("#sex").addEventListener("change",e=>{P.sex=e.target.value;out();});$("#act").addEventListener("change",e=>{P.act=+e.target.value;out();});$("#formula").addEventListener("change",e=>{P.formula=e.target.value;out();});
let plan="";
function out(){const r=body(P),o=$("#out");
  if(!r.ok||r.needAge){o.innerHTML=`<p class="muted">Enter your age (15 to 80), height and weight.</p>`;return;}
  if(r.needBf){o.innerHTML=`<p class="muted">Katch-McArdle needs your body fat %. Add it, or pick another formula.</p>`;return;}
  const ps=plans(r),floor=P.sex==="f"?1200:1500,k=v=>Math.round(v).toLocaleString(),map={cut:"cut2",maintain:"maintain",bulk:"bulk1"},pl=ps.find(x=>x.k===(plan||map[r.rec]))||ps[3];
  const prot=Math.round(r.w*(pl.k.startsWith("cut")?2.2:1.8)),fat=Math.round(pl.kcal*0.25/9),carb=Math.max(0,Math.round((pl.kcal-prot*4-fat*9)/4)),lab={cut:"Cut",maintain:"Maintain",bulk:"Bulk"};
  o.innerHTML=`<div class="big"><b>${k(r.tdee)}</b><span>kcal to maintain</span></div><ul class="list"><li><span>BMR (at rest)</span><b>${k(r.bmr)} kcal</b></li><li><span>BMI</span><b>${r.bmi.toFixed(1)} · ${r.cat}</b></li></ul>
   <table style="margin-top:12px"><thead><tr><th>Goal</th><th class="n">Per day</th><th class="n">Of maint.</th></tr></thead><tbody>${ps.map(x=>`<tr class="${x.k===pl.k?"hi":""}"><td>${x.l}${x.rt?` <span class="muted">${x.rt}</span>`:""}</td><td class="n">${k(x.kcal)}${x.kcal<floor&&x.kcal<r.tdee?" · low":""}</td><td class="n">${Math.round(x.pct)}%</td></tr>`).join("")}</tbody></table>
   <h2 style="margin:22px 0 6px;font-size:24px">Cut, maintain or bulk?</h2><div class="big"><b style="font-size:48px">${lab[r.rec]}</b><span>suggested</span></div><p class="note">${r.why}</p>
   <div class="seg" id="plan" role="group" aria-label="Your plan" style="margin-top:12px">${ps.map(x=>`<button type="button" data-v="${x.k}" aria-pressed="${x.k===pl.k}">${x.k==="maintain"?"Maintain":(x.k.startsWith("cut")?"Lose ":"Gain ")+x.rt.split(" ")[0]}</button>`).join("")}</div>
   <table><caption class="sr">Daily macros for ${k(pl.kcal)} kcal</caption><thead><tr><th>Macro (${k(pl.kcal)} kcal)</th><th class="n">Grams</th><th class="n">kcal</th></tr></thead><tbody><tr><td>Protein</td><td class="n">${prot} g</td><td class="n">${prot*4}</td></tr><tr><td>Fat</td><td class="n">${fat} g</td><td class="n">${fat*9}</td></tr><tr><td>Carbs</td><td class="n">${carb} g</td><td class="n">${carb*4}</td></tr></tbody></table>`;
  seg($("#plan"),v=>{plan=v;out();const b=$(`#plan [data-v="${v}"]`);if(b)b.focus();});}
$("#save").addEventListener("click",()=>{const r=body(P);if(!r.ok||r.needAge){$("[data-p=age]").focus();return;}saveToApp("body",Object.assign({},P,{plan}),"bmi");});
out();''')

# ---------------- hub ----------------
hub=head("", "Free Student Tools: Grade, Final, Pomodoro, BMI and Calorie Calculators · Digital Dash",
 "Free tools for students: a weighted grade calculator, a final exam calculator, a Pomodoro timer, and BMI and calorie calculators. No sign-up.",
 {"@context":"https://schema.org","@type":"CollectionPage","name":"Free student tools","url":f"{SITE}/tools"})+'''<div class="wrap hero"><span class="eyebrow">Free, no sign-up</span><h1>Free student tools</h1><p>Quick calculators and a focus timer, built into Digital Dash and free to use on their own.</p></div>
<section class="wrap prose" style="max-width:none;padding-top:0" aria-label="Tools"><div class="related">'''+"".join(f'<a href="/{s}"><b>{n}</b><span>{d}</span></a>' for s,n,d in TOOLS)+'''</div></section>
</main>
<footer><div class="wrap"><span class="mk" aria-hidden="true"></span><span>© <span id="yr"></span> Digital Dash</span><nav aria-label="Footer"><a href="/">Home</a><a href="/digital-dash.html">Open app</a><a href="/digital-dash-privacy.html">Privacy</a></nav></div></footer>
<script src="/tools/tools.js"></script>
</body>
</html>
'''
open(f"{ROOT}/tools/index.html","w").write(hub)
# sitemap + robots
urls=["", "tools"]+[s for s,_,_ in TOOLS]+["digital-dash-privacy.html"]
open(f"{ROOT}/sitemap.xml","w").write('<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n'+"".join(f"  <url><loc>{SITE}/{u}</loc></url>\n" for u in urls)+"</urlset>\n")
open(f"{ROOT}/robots.txt","w").write(f"User-agent: *\nAllow: /\nDisallow: /preview\n\nSitemap: {SITE}/sitemap.xml\n")
print("done")
