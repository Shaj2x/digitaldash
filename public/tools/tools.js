/* Shared helpers for the free tool pages. The maths is the same as the app's (digital-dash.html):
   grade calculator = gcCalc/gcFinal, BMI and calories = bodyCalc/bodyPlans. Keep them in step. */
(()=>{
const ls={get(k){try{return localStorage.getItem(k);}catch(e){return null;}},set(k,v){try{localStorage.setItem(k,v);}catch(e){}}};
/* Theme: the visitor's own dashboard theme if they have one, else a look picked on the home page, else the default */
const SK={brand:["#1B1B1B","#232323","#2D2D2C","#EFEEE8","#A6A59E","#3A3A38","#EFEEE8","#1B1B1B"],dash:["#141220","#1C1A2B","#252236","#F1EEF8","#9C97B3","#2F2B45","#FFB547","#1A1405"],
  midnight:["#0B1226","#111A33","#18233F","#E4ECFF","#8A98BD","#243054","#6FD3FF","#081020"],ember:["#1D1418","#281B21","#33232A","#F6E7E1","#B39A9F","#44303A","#FF7A3D","#1D1418"],
  ledger:["#12241F","#18302A","#1F3A33","#EDE9DC","#9DB0A6","#2C4A41","#D2A94B","#14241F"],mono:["#000000","#0E0E0E","#1A1A1A","#FFFFFF","#9A9A9A","#2B2B2B","#FFFFFF","#000000"],
  chalk:["#E7EAE3","#F5F6F1","#DCE0D6","#1E241C","#535D4F","#C6CCBE","#3E6B2E","#F5F6F1"],sakura:["#F6EEF1","#FFFFFF","#EEDFE5","#2B1D24","#6A5460","#E2CDD6","#C2416F","#FFFFFF"]};
let skin=null;
try{const s=JSON.parse(ls.get("grindboard.v1")||"null");if(s&&s.settings&&SK[s.settings.skin])skin=s.settings.skin;}catch(e){}
if(!skin)try{const p=JSON.parse(ls.get("dd.pick")||"null");if(p&&SK[p.skin])skin=p.skin;}catch(e){}
if(skin){const h=document.documentElement,[bg,panel,panel2,ink,muted,line,acc,accInk]=SK[skin];
  Object.entries({"--bg":bg,"--panel":panel,"--panel2":panel2,"--ink":ink,"--muted":muted,"--line":line,"--accent":acc,"--accent-ink":accInk,"--bg2":`color-mix(in srgb,${bg} 90%,${ink})`}).forEach(([k,v])=>h.style.setProperty(k,v));
  const lum=parseInt(bg.slice(1,3),16)*.299+parseInt(bg.slice(3,5),16)*.587+parseInt(bg.slice(5,7),16)*.114;h.style.colorScheme=lum>128?"light":"dark";h.classList.add("themed");
  const tc=document.querySelector('meta[name="theme-color"]');if(tc)tc.content=bg;}

const num=v=>{v=String(v??"").trim().replace(/,/g,".").replace(/%$/,"").trim();if(!v)return null;const m=v.match(/^(-?\d+(?:\.\d+)?)\s*\/\s*(\d+(?:\.\d+)?)$/);if(m)return +m[2]?+m[1]/+m[2]*100:null;const n=Number(v);return Number.isFinite(n)?n:null;};
const r2=v=>Math.round(v*100)/100;
const pct=v=>v==null||!Number.isFinite(v)?"—":r2(v).toLocaleString(undefined,{maximumFractionDigits:2})+"%";

/* ---- grades (same as the app's gcCalc) ---- */
const SCALES={
  us:{name:"Standard (US)",gpa:true,rows:[["A+",97,4.0],["A",93,4.0],["A-",90,3.7],["B+",87,3.3],["B",83,3.0],["B-",80,2.7],["C+",77,2.3],["C",73,2.0],["C-",70,1.7],["D+",67,1.3],["D",63,1.0],["D-",60,0.7],["F",0,0]]},
  on:{name:"Ontario (U of T style)",gpa:true,rows:[["A+",90,4.0],["A",85,4.0],["A-",80,3.7],["B+",77,3.3],["B",73,3.0],["B-",70,2.7],["C+",67,2.3],["C",63,2.0],["C-",60,1.7],["D+",57,1.3],["D",53,1.0],["D-",50,0.7],["F",0,0]]},
  western:{name:"Western University",gpa:false,rows:[["A+",90],["A",80],["B",70],["C",60],["D",50],["F",0]]}};
const letter=(p,sc)=>{if(p==null)return null;const r=SCALES[sc].rows;for(const x of r)if(p>=x[1]-1e-9)return x;return r[r.length-1];};
const letterOfGpa=(g,sc)=>{const r=SCALES[sc].rows.filter(x=>x[2]!=null);for(const x of r)if(g>=x[2]-1e-9)return x;return r[r.length-1];};
const letterVal=(L,sc)=>{const r=SCALES[sc].rows,i=r.findIndex(x=>x[0].toLowerCase()===String(L).trim().toLowerCase());if(i<0)return null;if(SCALES[sc].gpa)return r[i][2];const hi=i?r[i-1][1]:100;return (r[i][1]+hi)/2;};
const goalPct=(v,sc)=>{v=String(v||"").trim();if(!v)return null;const L=SCALES[sc].rows.find(x=>x[0].toLowerCase()===v.toLowerCase());return L?L[1]:num(v);};
function grades(g){ /* g = {type:"pct"|"letter"|"pts", scale, rows:[{n,g,w}], goal, rem} */
  const sc=SCALES[g.scale];let out={n:0,skipped:0};
  if(g.type==="pts"){let e=0,p=0;g.rows.forEach(r=>{const a=num(r.g),b=num(r.w);if(a==null&&b==null)return;if(a==null||b==null||b<=0){out.skipped++;return;}e+=a;p+=b;out.n++;});out.earned=e;out.poss=p;out.pct=p?e/p*100:null;}
  else{const vals=g.rows.map(r=>({v:g.type==="letter"?(r.g?letterVal(r.g,g.scale):null):num(r.g),w:num(r.w)})).filter(x=>x.v!=null);
    const anyW=vals.some(x=>x.w!=null&&x.w>0);let sw=0,sv=0;
    vals.forEach(x=>{const w=anyW?(x.w!=null&&x.w>0?x.w:null):1;if(w==null){out.skipped++;return;}sw+=w;sv+=x.v*w;out.n++;});
    out.sw=anyW?sw:null;out.val=sw?sv/sw:null;
    if(g.type==="letter"){if(out.val!=null){if(sc.gpa){out.gpa=out.val;out.L=letterOfGpa(out.val,g.scale);}else{out.pct=out.val;out.L=letter(out.val,g.scale);}}}else out.pct=out.val;}
  if(out.pct!=null)out.L=out.L||letter(out.pct,g.scale);
  if(out.L&&sc.gpa&&out.gpa==null)out.gpa=out.L[2];
  const gp=goalPct(g.goal,g.scale);
  if(gp!=null&&out.pct!=null&&g.type!=="letter"){
    if(g.type==="pts"){const P=num(g.rem);if(P&&P>0){out.need=(gp/100*(out.poss+P)-out.earned)/P*100;out.R=P;out.best=(out.earned+P)/(out.poss+P)*100;}}
    else{let R=num(g.rem);if(R==null&&out.sw!=null&&out.sw<100)R=100-out.sw;if(R!=null&&R>0&&R<100){out.need=(gp-out.pct*(100-R)/100)/(R/100);out.R=R;out.best=out.pct*(100-R)/100+R;}}
    out.goal=gp;}
  return out;
}
function finalNeed(cur,want,w,sc){const c=num(cur),t=num(want)??goalPct(want,sc||"us"),p=num(w);if(c==null||t==null||p==null||p<=0||p>100)return null;
  return {need:(t-c*(1-p/100))/(p/100),want:t,cur:c,p,best:c*(1-p/100)+p,worst:c*(1-p/100)};}

/* ---- body (same as the app's bodyCalc) ---- */
const ACTS=[[1,"Basal metabolic rate (BMR)"],[1.2,"Sedentary: little or no exercise"],[1.375,"Light: exercise 1–3 times a week"],[1.465,"Moderate: exercise 4–5 times a week"],[1.55,"Active: daily exercise or intense exercise 3–4 times a week"],[1.725,"Very active: intense exercise 6–7 times a week"],[1.9,"Extra active: very intense exercise daily, or a physical job"]];
const BMI_CATS=[[0,16,"Severe thinness"],[16,17,"Moderate thinness"],[17,18.5,"Mild thinness"],[18.5,25,"Normal"],[25,30,"Overweight"],[30,35,"Obese class I"],[35,40,"Obese class II"],[40,99,"Obese class III"]];
function body(p){ /* p = {units, sex, age, ft, inch, cm, lb, kg, act, formula, bf} */
  const age=num(p.age),us=p.units==="us",h=us?((num(p.ft)||0)*12+(num(p.inch)||0))*2.54:num(p.cm),w=us?(num(p.lb)!=null?num(p.lb)*0.45359237:null):num(p.kg),bf=num(p.bf);
  const r={ok:!!(h>0&&w>0),h,w,age,us};if(!r.ok)return r;
  const m=h/100;r.bmi=w/(m*m);r.cat=(BMI_CATS.find(c=>r.bmi>=c[0]&&r.bmi<c[1])||BMI_CATS[7])[2];r.prime=r.bmi/25;r.pi=w/(m*m*m);r.lo=18.5*m*m;r.hi=25*m*m;
  r.needAge=!(age>=15&&age<=80);if(r.needAge)return r;
  if(p.formula==="k"){if(!(bf>0&&bf<70)){r.needBf=true;return r;}r.bmr=370+21.6*(1-bf/100)*w;}
  else if(p.formula==="r")r.bmr=p.sex==="f"?9.247*w+3.098*h-4.330*age+447.593:13.397*w+4.799*h-5.677*age+88.362;
  else r.bmr=10*w+6.25*h-5*age+(p.sex==="f"?-161:5);
  r.tdee=r.bmr*(+p.act||1.2);
  const fatHi=p.sex==="f"?32:25,fatLo=p.sex==="f"?20:12;let rec,why;
  if(bf>0&&bf<70&&r.bmi>=18.5){if(bf>fatHi){rec="cut";why=`At ${bf}% body fat you're above the usual healthy range for ${p.sex==="f"?"women (about 21–32%)":"men (about 8–25%)"}, so a steady cut makes sense.`;}
    else if(bf<fatLo){rec="bulk";why=`At ${bf}% body fat you're lean, so a slow lean bulk lets you add muscle without much fat.`;}
    else{rec="maintain";why=`At ${bf}% body fat you're in a healthy range, so eating at maintenance while training hard (a recomp) works well. Lean bulk if building muscle is the priority.`;}}
  else if(r.bmi<17){rec="bulk";why="Your BMI is below the healthy range, so eating above maintenance to gain weight is the priority.";}
  else if(r.bmi<18.5){rec="bulk";why="Your BMI is just under the healthy range (18.5–25), so a lean bulk is a good fit.";}
  else if(r.bmi<22){rec="bulk";why="Your BMI is in the healthy range with room to grow, so a slow lean bulk suits building muscle. Maintenance is also fine.";}
  else if(r.bmi<25){rec="maintain";why="Your BMI is in the healthy range, so eating at maintenance while training (a recomp) is a good default. Add your body fat % for a sharper call.";}
  else if(r.bmi<30){rec="cut";why="Your BMI is in the overweight range, so a steady cut is suggested. BMI can't tell muscle from fat: if you're very muscular, add your body fat % for a better answer.";}
  else{rec="cut";why="Your BMI is in the obese range, so a cut is suggested. Losing 1 lb (0.5 kg) a week is a sustainable pace; check with a doctor before bigger changes.";}
  r.rec=rec;r.why=why;return r;
}
function plans(r){const u=r.us?"lb":"kg",step=r.us?[0.5,1,2]:[0.25,0.5,1],cal=[250,500,1000];
  return [["cut3","Extreme weight loss",`${step[2]} ${u}/week`,-cal[2]],["cut2","Weight loss",`${step[1]} ${u}/week`,-cal[1]],["cut1","Mild weight loss",`${step[0]} ${u}/week`,-cal[0]],["maintain","Maintain weight","",0],["bulk1","Mild weight gain",`${step[0]} ${u}/week`,cal[0]],["bulk2","Weight gain",`${step[1]} ${u}/week`,cal[1]],["bulk3","Fast weight gain",`${step[2]} ${u}/week`,cal[2]]]
    .map(([k,l,rt,d])=>({k,l,rt,kcal:r.tdee+d,pct:(r.tdee+d)/r.tdee*100}));}

/* "Save this in Digital Dash": hand the numbers to the app on this site, which adds them (never replaces
   anything without Undo) the next time it opens. */
function saveToApp(kind,data,hash){ls.set("dd.import",JSON.stringify({kind,data,t:Date.now()}));location.href="/digital-dash.html"+(hash?"#"+hash:"");}

/* small helpers */
const $=s=>document.querySelector(s),esc=s=>String(s??"").replace(/[&<>"']/g,c=>({"&":"&amp;","<":"&lt;",">":"&gt;",'"':"&quot;","'":"&#39;"}[c]));
function seg(el,cb){el.addEventListener("click",e=>{const b=e.target.closest("button[data-v]");if(!b)return;el.querySelectorAll("button[data-v]").forEach(x=>x.setAttribute("aria-pressed",x===b));cb(b.dataset.v);});}
const yr=$("#yr");if(yr)yr.textContent=new Date().getFullYear();
window.DD={ls,num,r2,pct,SCALES,letter,goalPct,grades,finalNeed,ACTS,body,plans,saveToApp,$,esc,seg};
})();
