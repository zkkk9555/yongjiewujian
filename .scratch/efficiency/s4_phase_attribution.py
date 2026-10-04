# -*- coding: utf-8 -*-
import json, os, re, collections, datetime, bisect
out=open(r'C:\Users\Administrator\AppData\Local\Temp\opencode\phase2.txt','w',encoding='utf-8')
def P(*a): print(*a,file=out)
root=r'C:\Project\永劫无间'
allrec=[]
for r,dirs,fs in os.walk(root):
    dirs[:]=[x for x in dirs if x not in ('.git','.video-tools','node_modules')]
    for f in fs:
        p=os.path.join(r,f)
        try: allrec.append(datetime.datetime.fromtimestamp(os.path.getmtime(p)))
        except OSError: pass
ALL=sorted(set(allrec))
# active clusters: consecutive events <= 20 min apart
clusters=[]; cs=ALL[0]; ce=ALL[0]
for t in ALL[1:]:
    if (t-ce).total_seconds()<=1200: ce=t
    else: clusters.append((cs,ce)); cs=t; ce=t
clusters.append((cs,ce))
P(f'project-wide active clusters (gap<=20min): {len(clusters)}')
P('')
d=json.load(open(r'C:\Users\Administrator\AppData\Local\Temp\opencode\ts_raw.json',encoding='utf-8-sig'))
tasks=collections.OrderedDict()
for r in d: tasks.setdefault(r['task'],[]).append(r)
def cat(rel):
    n=os.path.basename(rel); rl=rel.lower()
    if n.startswith('source_probe') or n.startswith('source_baseline') or n.startswith('proxy_build'): return 'A 预检+素材探测+代理'
    if n.startswith('transcribe') or n.startswith('source.srt') or n.startswith('source_transcript') or 'scenes\\' in rl or n.startswith('rms_') or n.startswith('audio_') or n.startswith('extract_') or n.startswith('frame_calib'): return 'B 转写/抽帧/音频/场景(机器)'
    if re.match(r'(seg|bridge|gap)\w*',n) and ('scan_report' in n or 'notes' in n or 'verify_report' in n or 'band_report' in n or 'checkpoint' in n or 'adjudication' in n or 'operable_frame' in n): return 'C 分段扫描(看图判读)'
    if n.startswith('combat_episodes_v') or n.startswith('cut_list_v') or n.startswith('merge_decision') or n.startswith('program_map_v') or n.startswith('validate_v') or n.startswith('v6_audit_amendment') or n.startswith('timeline_manifest') or n=='markers.csv' or n.endswith('.otio') or n=='premiere.xml': return 'D 时间线合成/合并裁决'
    if n.startswith('adversarial_brief') or n.startswith('adversarial_briefing') or n.startswith('make_adv_ctx') or n.startswith('scanner_brief'): return 'E 审片派工(写单)'
    if n.startswith('adversarial_') or n.startswith('selfaudit') or n.startswith('accept') or n.startswith('reverify') or n.startswith('adjudicate') or n.startswith('freeze_gate') or n.startswith('freeze_kit') or n.startswith('deleted_audit') or n.startswith('tail_') or n.startswith('struct') or n.startswith('tie1') or n.startswith('rescue') or n.startswith('start5') or n.startswith('ui_census') or n.startswith('ui_instance') or n.startswith('media_filters') or n.startswith('axis_verify') or n.startswith('source_loudness') or n.startswith('final_probe'): return 'F 审片/对抗/验收(多路报告)'
    if n.startswith('patch_to_v') or n.startswith('patch_spec_v') or n.startswith('bump_timeline') or n.startswith('delaudit') or n.startswith('verify_axis') or n.startswith('prove_v') or n.startswith('fix_') or n.startswith('axis_proof') or n.startswith('amend') or n.startswith('issue_list') or n.startswith('v3_problem') or n.startswith('recheck') or n.startswith('qa_gate_axis_defect'): return 'G 返工/补丁/复验'
    if ('review-v' in n and (n.endswith('.srt') or n.endswith('.stats.json'))) or n.startswith('caption_filter_audit') or n.startswith('subtitle_span') or n.startswith('subtitle_map') or n.startswith('map_captions') or n.startswith('srt_crosscheck'): return 'H 字幕外挂映射'
    if n.startswith('master_render') or n.startswith('render_master') or n.startswith('render_wrapper') or n.startswith('render_4k') or n.startswith('verify_master') or n.startswith('master_verify') or n.startswith('master_axis') or n.startswith('master_offset') or n.startswith('master_shift') or n.startswith('master_slip') or n.startswith('master_align') or n.startswith('master_alignment') or n.startswith('delivery_4k') or n.startswith('ledger_entry'): return 'I 4K渲染+对齐取证+验收'
    if n.startswith('cleanup_log'): return 'J 收尾清理'
    if n.startswith('qa_gate') or n.startswith('accept_B') or n.startswith('segment_survey'): return 'K 门禁'
    return 'L 其他(工具脚本/台账/台账)'
grand=collections.Counter(); gspan=0.0; gidle=0.0
for t,rows in tasks.items():
    rows.sort(key=lambda r:r['wt'])
    for r in rows: r['T']=datetime.datetime.strptime(r['wt'],'%Y-%m-%d %H:%M:%S')
    t0,t1=rows[0]['T'],rows[-1]['T']
    span=(t1-t0).total_seconds()
    active=0.0
    agg=collections.Counter(); cnt=collections.Counter()
    for cs,ce in clusters:
        a=max(cs,t0); b=min(ce,t1)
        if b<=a: continue
        dur=(b-a).total_seconds(); active+=dur
        # weight by task files in this cluster by count
        sel=[r for r in rows if a<=r['T']<=b]
        if not sel:
            agg['Z 本任务无产出(在做别的任务)']+=dur; cnt['Z 本任务无产出(在做别的任务)']+=1; continue
        bycat=collections.Counter()
        for r in sel: bycat[cat(r['rel'])]+=1
        tot=sum(bycat.values())
        for c,k in bycat.items(): agg[c]+=dur*k/tot
    idle=span-active
    P('='*112)
    P(f'TASK {t}   span {t0:%m-%d %H:%M} -> {t1:%m-%d %H:%M} = {span/3600:.2f} h | 活跃 {active/3600:.2f} h ({100*active/span:.1f}%) | 纯静默 {idle/3600:.2f} h ({100*idle/span:.1f}%)')
    for c in sorted(agg,key=lambda k:-agg[k]):
        P(f'   {c:32s} {agg[c]/3600:6.2f} h  {100*agg[c]/active:5.1f}% of active  {100*agg[c]/span:5.1f}% of span')
    grand.update(agg); gspan+=span; gidle+=idle
P('='*112)
P(f'GRAND TOTAL span {gspan/3600:.2f} h  idle {gidle/3600:.2f} h ({100*gidle/gspan:.1f}%)  active {(gspan-gidle)/3600:.2f} h')
for c in sorted(grand,key=lambda k:-grand[k]):
    P(f'   {c:32s} {grand[c]/3600:6.2f} h  {100*grand[c]/(gspan-gidle):5.1f}% of active  {100*grand[c]/gspan:5.1f}% of span')
P('')
P('--- ACTIVE CLUSTERS >= 20 min, 09-29..10-02 ---')
for cs,ce in clusters:
    if (ce-cs).total_seconds()<1200: continue
    if ce<datetime.datetime(2026,9,29) or cs>datetime.datetime(2026,10,2): continue
    n=sum(1 for t2 in ALL if cs<=t2<=ce)
    tasks_in=collections.Counter(r['task'][:2] for t2,rows in tasks.items() for r in rows if cs<=r['T']<=ce)
    P(f'  {cs:%m-%d %H:%M} -> {ce:%m-%d %H:%M}  {(ce-cs).total_seconds()/60:6.1f} min  files={n:4d}  tasks={dict(tasks_in)}')
out.close()
print(open(r'C:\Users\Administrator\AppData\Local\Temp\opencode\phase2.txt',encoding='utf-8').read())
