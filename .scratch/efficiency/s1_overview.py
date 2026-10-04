import json, collections, datetime
d = json.load(open(r'C:\Users\Administrator\AppData\Local\Temp\opencode\ts_raw.json', encoding='utf-8-sig'))
tasks = collections.OrderedDict()
for r in d:
    tasks.setdefault(r['task'], []).append(r)
for t, rows in tasks.items():
    print('='*100)
    print('TASK', t, len(rows), 'files')
    ws = sorted(r['wt'] for r in rows)
    cs = sorted(r['ct'] for r in rows)
    print('  earliest ctime:', cs[0], ' latest ctime:', cs[-1])
    print('  earliest mtime:', ws[0], ' latest mtime:', ws[-1])
    # top-level dir buckets
    b = collections.Counter()
    bs = collections.defaultdict(lambda: [None,None,0])
    for r in rows:
        top = r['rel'].split('\\')[0]
        b[top]+=1
        if bs[top][0] is None or r['wt'] < bs[top][0]: bs[top][0]=r['wt']
        if bs[top][1] is None or r['wt'] > bs[top][1]: bs[top][1]=r['wt']
        bs[top][2]+=r['bytes']
    for top in sorted(b, key=lambda k: bs[k][0]):
        print(f'   {top:28s} n={b[top]:4d}  {bs[top][0]} -> {bs[top][1]}  {bs[top][2]/1e6:.2f} MB')
