import json, collections, datetime
d = json.load(open(r'C:\Users\Administrator\AppData\Local\Temp\opencode\ts_raw.json', encoding='utf-8-sig'))
tasks = collections.OrderedDict()
for r in d:
    tasks.setdefault(r['task'], []).append(r)
for t, rows in tasks.items():
    rows.sort(key=lambda r: r['wt'])
    print('='*110)
    print('TASK', t)
    span0 = datetime.datetime.strptime(rows[0]['wt'], '%Y-%m-%d %H:%M:%S')
    span1 = datetime.datetime.strptime(rows[-1]['wt'], '%Y-%m-%d %H:%M:%S')
    total = (span1-span0).total_seconds()
    print(f'  SPAN {rows[0]["wt"]} -> {rows[-1]["wt"]} = {total/3600:.2f} h')
    gaps=[]
    for a,b in zip(rows, rows[1:]):
        ta=datetime.datetime.strptime(a['wt'],'%Y-%m-%d %H:%M:%S'); tb=datetime.datetime.strptime(b['wt'],'%Y-%m-%d %H:%M:%S')
        g=(tb-ta).total_seconds()
        if g> 20*60:
            gaps.append((g,a,b))
    gaps.sort(key=lambda x:-x[0])
    gtot=sum(g[0] for g in gaps)
    print(f'  gaps >20min: {len(gaps)}  summing {gtot/3600:.2f} h = {100*gtot/total:.1f}% of span')
    for g,a,b in gaps:
        print(f'   {g/60:7.1f} min  {a["wt"]} [{a["rel"][:60]}]  ->  {b["wt"]} [{b["rel"][:60]}]')
