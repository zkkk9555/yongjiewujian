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
def stats(a,b):
    res={'act_n':0,'act_d':0,'idl_n':0,'idl_d':0}
    t=a
    while t<b:
        nxt=min(t+datetime.timedelta(seconds=30), b)
        seg=(nxt-t).total_seconds()
        act=any(s<=t<=e for s,e in iv)
        night = t.hour>=22 or t.hour<8
        if act: res['act_n' if night else 'act_d']+=seg
        else:   res['idl_n' if night else 'idl_d']+=seg
        t=nxt
    return res
spans=[('861','2026-09-29 18:07:22','2026-10-01 03:35:10'),
       ('863','2026-09-30 12:53:53','2026-10-01 07:03:27'),
       ('864-att1(discarded)','2026-09-30 12:54:26','2026-10-01 09:11:55'),
       ('864-att2(delivered)','2026-10-01 12:44:03','2026-10-01 23:37:55')]
print(f'{"task":22s} {"span":>7s} {"act":>7s} {"idle":>7s} | {"act-day":>8s} {"act-night":>10s} | {"IDLE-day":>9s} {"IDLE-night":>11s} {"IDLEday%":>9s}')
T={'span':0,'act_d':0,'act_n':0,'idl_d':0,'idl_n':0}
for n,a,b in spans:
    a=datetime.datetime.strptime(a,'%Y-%m-%d %H:%M:%S'); b=datetime.datetime.strptime(b,'%Y-%m-%d %H:%M:%S')
    sp=(b-a).total_seconds(); r=stats(a,b)
    act=r['act_d']+r['act_n']; idl=r['idl_d']+r['idl_n']
    for k in T: T[k]+= r[k] if k in r else sp
    print(f'{n:22s} {sp/3600:7.2f} {act/3600:7.2f} {idl/3600:7.2f} | {r["act_d"]/3600:8.2f} {r["act_n"]/3600:10.2f} | {r["idl_d"]/3600:9.2f} {r["idl_n"]/3600:11.2f} {100*r["idl_d"]/sp:8.1f}%')
sp=T['span']; act=T['act_d']+T['act_n']; idl=T['idl_d']+T['idl_n']
print(f'{"SUM (overlapping)":22s} {sp/3600:7.2f} {act/3600:7.2f} {idl/3600:7.2f} | {T["act_d"]/3600:8.2f} {T["act_n"]/3600:10.2f} | {T["idl_d"]/3600:9.2f} {T["idl_n"]/3600:11.2f} {100*T["idl_d"]/sp:8.1f}%')
# 864-att1 internal idles
iv2=[(datetime.datetime.strptime(a,'%Y-%m-%d %H:%M:%S'),datetime.datetime.strptime(b,'%Y-%m-%d %H:%M:%S')) for n,a,b in spans if n.startswith('864-att1')]
a,b=iv2[0]
import bisect
S=[x[0] for x in iv]; E=[x[1] for x in iv]
print('\n864-att1 idle blocks >45min:')
cur=a
while cur<b:
    act=any(s<=cur<=e for s,e in iv)
    if not act:
        st=cur
        while cur<b and not any(s<=cur<=e for s,e in iv): cur+=datetime.timedelta(seconds=30)
        d=(cur-st).total_seconds()
        if d>45*60: print(f'   {st:%m-%d %H:%M} -> {cur:%m-%d %H:%M}  {d/60:7.1f} min ({d/3600:.2f} h)')
    else: cur+=datetime.timedelta(seconds=30)
