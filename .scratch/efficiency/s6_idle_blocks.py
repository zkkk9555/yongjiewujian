# -*- coding: utf-8 -*-
import os, datetime
root=r'C:\Project\永劫无间'
allrec=[]
for r,dirs,fs in os.walk(root):
    dirs[:]=[x for x in dirs if x not in ('.git','.video-tools','node_modules')]
    for f in fs:
        p=os.path.join(r,f)
        try: allrec.append(datetime.datetime.fromtimestamp(os.path.getmtime(p)))
        except OSError: pass
ALL=sorted(set(allrec))
iv=[]; cs=ce=ALL[0]
for t in ALL[1:]:
    if (t-ce).total_seconds()<=1200: ce=t
    else: iv.append((cs,ce)); cs=ce=t
iv.append((cs,ce))
def act(t): return any(s<=t<=e for s,e in iv)
spans=[('861','2026-09-29 18:07:22','2026-10-01 03:35:10'),
       ('863','2026-09-30 12:53:53','2026-10-01 07:03:27'),
       ('864-att1','2026-09-30 12:54:26','2026-10-01 09:11:55'),
       ('864-att2','2026-10-01 12:44:03','2026-10-01 23:37:55')]
for n,a,b in spans:
    a=datetime.datetime.strptime(a,'%Y-%m-%d %H:%M:%S'); b=datetime.datetime.strptime(b,'%Y-%m-%d %H:%M:%S')
    print('='*100); print(n)
    blocks=[]; cur=a
    while cur<b:
        if not act(cur):
            st=cur
            while cur<b and not act(cur): cur+=datetime.timedelta(seconds=30)
            d=(cur-st).total_seconds()
            if d>20*60:
                night = st.hour>=22 or st.hour<8
                blocks.append((d,st,cur,night))
        else: cur+=datetime.timedelta(seconds=30)
    blocks.sort(key=lambda x:-x[0])
    for d,st,en,night in blocks:
        print(f'   {st:%m-%d %H:%M} -> {en:%m-%d %H:%M}  {d/60:7.1f} min ({d/3600:5.2f} h)  {"NIGHT" if night else "DAY  "}')
    print(f'   total idle blocks>20min: {sum(b[0] for b in blocks)/3600:.2f} h ;  NIGHT {sum(b[0] for b in blocks if b[3])/3600:.2f} h ; DAY {sum(b[0] for b in blocks if not b[3])/3600:.2f} h')
