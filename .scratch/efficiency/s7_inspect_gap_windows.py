import os, datetime
root=r'C:\Project\永劫无间'
recs=[]
for r,dirs,fs in os.walk(root):
    dirs[:] = [x for x in dirs if x not in ('.git','.video-tools','node_modules','.venv')]
    for f in fs:
        p=os.path.join(r,f)
        try: recs.append((datetime.datetime.fromtimestamp(os.path.getmtime(p)), p.replace(root+'\\','')))
        except OSError: pass
recs.sort()
def win(a,b,label):
    print('='*100); print(label, a,'->',b)
    n=0
    for t,p in recs:
        if a<=t<=b:
            n+=1; print(f'   {t:%m-%d %H:%M:%S}  {p}')
    if n==0: print('   *** ZERO FILES ANYWHERE IN PROJECT ***')
    print('   n =',n)
win(datetime.datetime(2026,9,29,19,15,6),datetime.datetime(2026,9,30,3,5,22),'GAP-A 861 scan->scan')
win(datetime.datetime(2026,9,30,20,26,24),datetime.datetime(2026,10,1,1,36,19),'GAP-B 863 v4->v5')
win(datetime.datetime(2026,10,1,5,11,16),datetime.datetime(2026,10,1,6,46,55),'GAP-C 863 freeze->4K')
win(datetime.datetime(2026,10,1,18,30,26),datetime.datetime(2026,10,1,23,13,28),'GAP-D 864 freeze->4K')
win(datetime.datetime(2026,10,1,16,10,22),datetime.datetime(2026,10,1,17,41,32),'GAP-E 864 adversarial->adjudicate')
