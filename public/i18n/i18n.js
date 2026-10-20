/* Digital Dash languages. Loaded first on every page (app, home, tool pages).
   The pages are written in English; this swaps text in place using a dictionary keyed by the English
   text (public/i18n/<lang>.json, built by scripts/build-i18n.py from scripts/i18n/). Patterns handle
   text with values in it ("Edit {0}", "{n} sessions"); whatever has no translation stays English.
   Dates use the chosen language. The dictionary is kept in localStorage so later visits (and offline)
   translate before the first paint. Changing language reloads the page. Mark user content
   translate="no" so it's never touched. */
(()=>{
const LANGS=[["en","English"],["es","Español"],["fr","Français"],["pt","Português"],["de","Deutsch"],["it","Italiano"],["vi","Tiếng Việt"],["hi","हिन्दी"],["zh","中文"],["ja","日本語"],["ko","한국어"]];
const KEY="dd.lang",ls={get(k){try{return localStorage.getItem(k);}catch(e){return null;}},set(k,v){try{localStorage.setItem(k,v);}catch(e){}}};
let lang=ls.get(KEY);
if(!LANGS.some(l=>l[0]===lang)){const nav=(navigator.languages||[navigator.language||"en"]).map(x=>String(x).toLowerCase().split("-")[0]);lang=nav.find(x=>LANGS.some(l=>l[0]===x))||"en";}
const LOC={zh:"zh-CN",pt:"pt-BR"},locale=LOC[lang]||lang;
const api={lang,locale,langs:LANGS,set(l){if(!LANGS.some(x=>x[0]===l))return;ls.set(KEY,l);location.reload();},t:s=>s,ready:Promise.resolve()};
window.DDI18N=api;document.documentElement.lang=lang;
/* any <select data-lang> becomes a language picker */
const pick=()=>document.querySelectorAll("select[data-lang]").forEach(s=>{if(s.options.length)return;s.setAttribute("translate","no");
  s.innerHTML=LANGS.map(([k,n])=>`<option value="${k}"${k===lang?" selected":""}>${n}</option>`).join("");s.addEventListener("change",()=>api.set(s.value));});
if(document.readyState==="loading")document.addEventListener("DOMContentLoaded",pick);else pick();
if(lang==="en")return;

/* dates: code that doesn't name a locale gets the chosen language */
["toLocaleDateString","toLocaleTimeString","toLocaleString"].forEach(m=>{const o=Date.prototype[m];Date.prototype[m]=function(l,opt){return o.call(this,l===undefined?locale:l,opt);};});

let S=null,P=[];const cache=new Map();
const esc=s=>s.replace(/[.*+?^${}()|[\]\\]/g,"\\$&"),NUM=/^[nmk]$/;
function load(d){S=d.s||{};P=(d.p||[]).map(([en,tr])=>{const names=[];
  const re=new RegExp("^"+esc(en).replace(/\\\{(\w+)\\\}/g,(m,k)=>{names.push(k);return NUM.test(k)?"(\\d[\\d,.]*)":"(.+?)";})+"$");return {re,names,tr};});cache.clear();}
function tr(t){
  if(!S||!t||!/\p{L}{2}/u.test(t))return null;
  if(cache.has(t))return cache.get(t);
  let r=Object.prototype.hasOwnProperty.call(S,t)?S[t]:null;
  if(r==null)for(const p of P){const m=t.match(p.re);if(!m)continue;
    r=p.tr.replace(/\{(\w+)\}/g,(x,k)=>{const i=p.names.indexOf(k);if(i<0)return x;const v=m[i+1];return NUM.test(k)?v:(tr(v)??v);});break;}
  if(cache.size>4000)cache.clear();cache.set(t,r);return r;
}
api.t=s=>tr(String(s))??s;

/* the page: text nodes and a few attributes; each remembers its English so re-renders are caught */
const SKIP="script,style,textarea,input,code,pre,[translate=no],.notranslate";
const done=new WeakMap(),ATTR=["placeholder","aria-label","title","alt"];
function txt(n){
  const v=n.nodeValue;if(!v||done.get(n)===v)return;const pe=n.parentElement;if(!pe||pe.closest(SKIP))return;
  if(pe.isContentEditable&&pe.contains(document.activeElement))return; /* never change text someone is typing in */
  const t=v.trim(),r=tr(t);if(r==null||r===t){done.set(n,v);return;}
  const out=v.replace(t,r);done.set(n,out);n.nodeValue=out;
}
function attrs(el){
  if(el.closest&&el.closest("[translate=no]"))return;
  let rec=done.get(el);
  for(const a of ATTR){const v=el.getAttribute(a);if(!v)continue;if(rec&&rec[a]===v)continue;const r=tr(v.trim());
    if(r!=null&&r!==v.trim()){rec=rec||{};rec[a]=r;done.set(el,rec);el.setAttribute(a,r);}}
}
function walk(root){
  if(root.nodeType===3){txt(root);return;}if(root.nodeType!==1)return;
  if(root.matches(SKIP)&&!root.matches("input,textarea"))return;
  attrs(root);root.querySelectorAll&&root.querySelectorAll("[placeholder],[aria-label],[title],[alt]").forEach(attrs);
  const w=document.createTreeWalker(root,NodeFilter.SHOW_TEXT);let n;while((n=w.nextNode()))txt(n);
}
const mo=new MutationObserver(ms=>{if(!S)return;for(const m of ms){
  if(m.type==="characterData")txt(m.target);else if(m.type==="attributes")attrs(m.target);else m.addedNodes.forEach(walk);}});
function start(){if(document.body)walk(document.body);mo.observe(document.documentElement,{subtree:true,childList:true,characterData:true,attributes:true,attributeFilter:ATTR});}

const CK="dd.i18n."+lang;let cached=null;try{cached=JSON.parse(ls.get(CK)||"null");}catch(e){}
if(cached&&cached.s){load(cached);start();}
api.ready=fetch(`/i18n/${lang}.json`,{cache:"no-cache"}).then(r=>r.ok?r.json():null).then(d=>{if(!d||!d.s)return;
  if(!cached||cached.v!==d.v){ls.set(CK,JSON.stringify(d));const first=!S;load(d);if(first)start();else if(document.body)walk(document.body);}}).catch(()=>{});
})();
