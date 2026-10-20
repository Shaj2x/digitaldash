"""Builds public/i18n/<lang>.json from scripts/i18n/.

scripts/i18n/en.json holds the English text: "strings" (exact text) and "patterns" (text with
values: {0}, {1}… for any text, {n}, {m}, {k} for numbers). Each scripts/i18n/<lang>.txt has one line
per entry, "<number>|<translation>" (a tab also works), numbered from 1 through the strings and then on through the
patterns, then the "extra" list. Missing numbers fall back to English. A pattern's translation must use the same placeholders.
Add new English text at the END of a list so existing numbers stay put, then add its line to every
language. Run: python3 scripts/build-i18n.py"""
import json, os, re, hashlib, sys
HERE=os.path.dirname(os.path.abspath(__file__));OUT=os.path.join(HERE,"..","public","i18n")
en=json.load(open(os.path.join(HERE,"i18n","en.json")))
# numbering: strings, then patterns, then "extra" (added later; an entry with {placeholders} is a pattern)
ENTRIES=[(t,False) for t in en["strings"]]+[(t,True) for t in en["patterns"]]+[(t,bool(re.search(r"\{\w+\}",t))) for t in en.get("extra",[])]
NS=sum(1 for _,isp in ENTRIES if not isp);NP=len(ENTRIES)-NS
ok=True
for f in sorted(os.listdir(os.path.join(HERE,"i18n"))):
    if not f.endswith(".txt"):continue
    lang=f[:-4];tr={}
    for ln,line in enumerate(open(os.path.join(HERE,"i18n",f),encoding="utf-8"),1):
        line=line.rstrip("\n")
        if not line.strip():continue
        m=re.match(r"^(\d+)[\t|](.*)$",line)
        if not m:print(f"{f}:{ln}: not '<number>|<text>'");ok=False;continue
        tr[int(m.group(1))]=m.group(2).strip()
    s={};p=[];missing=[]
    for j,(t,isp) in enumerate(ENTRIES,1):
        x=tr.get(j)
        if not x:missing.append(j);continue
        if not isp:s[t]=x;continue
        a=sorted(re.findall(r"\{\w+\}",t));b=sorted(re.findall(r"\{\w+\}",x))
        if a!=b:print(f"{f}: #{j} placeholders {b} should be {a}: {x}");ok=False;continue
        p.append([t,x])
    extra=[k for k in tr if k>len(ENTRIES)]
    if extra:print(f"{f}: numbers past the end: {extra[:10]}");ok=False
    d={"s":s,"p":p};d["v"]=hashlib.sha1(json.dumps(d,sort_keys=True,ensure_ascii=False).encode()).hexdigest()[:10]
    json.dump(d,open(os.path.join(OUT,lang+".json"),"w",encoding="utf-8"),ensure_ascii=False,separators=(",",":"))
    print(f"{lang}: {len(s)}/{NS} strings, {len(p)}/{NP} patterns"+(f", missing {missing[:15]}{'…' if len(missing)>15 else ''}" if missing else ""))
sys.exit(0 if ok else 1)
