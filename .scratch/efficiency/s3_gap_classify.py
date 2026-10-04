import json, collections, datetime, os
proj = json.load(open(r'C:\Users\Administrator\AppData\Local\Temp\opencode\all123.json', encoding='utf-8-sig'))
# also add non-123 project files
extra=[]
for root,dirs,files in os.walk(r'C:\Project\永劫无间'):
    if any(x in root for x in ('\\.git','\\.video-tools')): continue
    for f in files:
        p=os.path.join(root,f)
        try: extra.append(datetime.datetime.fromtimestamp(os.path.getmtime(p)))
        except OSError: pass
P = sorted(datetime.datetime.strptime(r['wt'],'%Y-%m-%d %H:%M:%S') for r in proj)
PE = sorted(extra)
ALL = sorted(P+PE)
def bisect_count(a,b):
    import bisect
    return bisect.bisect_left(ALL,b)-bisect.bisect_left(ALL,a)

d = json.load(open(r'C:\Users\Administrator\AppData\Local\Temp\opencode\ts_raw.json', encoding='utf-8-sig'))
tasks = collections.OrderedDict()
for r in d: tasks.setdefault(r['task'], []).append(r)
for t, rows in tasks.items():
    rows.sort(key=lambda r: r['wt'])
    print('#'*118); print('TASK', t)
    tot=(datetime.datetime.strptime(rows[-1]['wt'],'%Y-%m-%d %H:%M:%S')-datetime.datetime.strptime(rows[0]['wt'],'%Y-%m-%d %H:%M:%S')).total_seconds()
    idle=0.0; other=0.0
    for a,b in zip(rows,rows[1:]):
        ta=datetime.datetime.strptime(a['wt'],'%Y-%m-%d %H:%M:%S'); tb=datetime.datetime.strptime(b['wt'],'%Y-%m-%d %H:%M:%S')
        g=(tb-ta).total_seconds()
        if g<=20*60: continue
        n=bisect_count(ta,tb)
        cls = 'TRUE-IDLE' if n<=2 else 'CROSS-TASK BUSY'
        if n<=2: idle+=g
        else: other+=g
        print(f'  {g/60:7.1f}min  {cls:15s} nfiles_project={n:5d}  {a["wt"]} -> {b["wt"]}')
    print(f'  >> idle>20min total {idle/3600:.2f}h ({100*idle/tot:.1f}%), cross-task {other/3600:.2f}h ({100*other/tot:.1f}%)')
