"""بررسی داده‌های بازی و قابل‌حل‌بودن در ۶۰ ثانیه (بدون نیاز به Godot):  python3 tools/validate_data.py"""
import json, re, os, sys, heapq, math
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
src = open(os.path.join(ROOT, 'scripts', 'data.gd'), encoding='utf-8').read()
body = src.split('const DATA =', 1)[1]
D = json.loads(body)                       # فایل باید JSON معتبر باشد
bad = 0; total = 0
def chk(name, cond, extra=''):
    global bad, total; total += 1; bad += (not cond)
    if not cond: print('  ✗ ' + name + ((' — ' + str(extra)) if extra != '' else ''))

W, H = D['grid']['w'], D['grid']['h']; C = D['cell']
solid = [[True] * W for _ in range(H)]
room_of = [[None] * W for _ in range(H)]
for r in D['rooms']:
    for y in range(r['y'], r['y'] + r['h']):
        for x in range(r['x'], r['x'] + r['w']):
            solid[y][x] = False; room_of[y][x] = r['id']
door_cells = {tuple(d['cell']): d for d in D['doors']}
for (x, y) in door_cells: solid[y][x] = False
obst = set()
for o in D['obstacles']:
    for y in range(o['y'], o['y'] + o['h']):
        for x in range(o['x'], o['x'] + o['w']):
            chk(f'مانع داخل اتاق: {o["kind"]}@{x},{y}', room_of[y][x] is not None)
            solid[y][x] = True; obst.add((x, y))
hide_cells = set()
for h in D['hides']:
    x, y = h['cell']; chk(f'کمین داخل اتاق: {h["id"]}', room_of[y][x] is not None and (x, y) not in obst)
    solid[y][x] = True; hide_cells.add((x, y))

def free(c): return 0 <= c[0] < W and 0 <= c[1] < H and not solid[c[1]][c[0]]
points = {}
for p in D['pickups']: points[p['id']] = tuple(p['cell'])
for n in D['notes']: points[n['id']] = tuple(n['cell'])
points['fusebox'] = tuple(D['levers']['fusebox']); points['panel'] = tuple(D['levers']['panel'])
points['core'] = tuple(D['cores']['pos']); points['secret'] = tuple(D['secret']['cell'])
points['spawn'] = tuple(D['player']['spawn']); points['enemy'] = tuple(D['enemy']['spawn'])
used = {}
for k, c in points.items():
    chk(f'نقطه {k} روی خانه‌ی آزاد است', free(c), c)
    chk(f'نقطه {k} با نقطه دیگر هم‌پوشانی ندارد', c not in used, (used.get(c), k)); used[c] = k
for p in D['patrol']: chk(f'نقطه گشت {p} آزاد است', free(tuple(p)))
for d in D['doors']:
    x, y = d['cell']; up, dn = (x, y - 1), (x, y + 1)
    chk(f'در {d["id"]} دو طرفش خانه‌ی آزاد دارد', free(up) and free(dn) or (free((x - 1, y)) and free((x + 1, y))))

def neigh4(c):
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        n = (c[0] + dx, c[1] + dy)
        if free(n): yield n, 1.0
def neigh8(c):
    for dx in (-1, 0, 1):
        for dy in (-1, 0, 1):
            if dx == 0 and dy == 0: continue
            n = (c[0] + dx, c[1] + dy)
            if not free(n): continue
            if dx and dy and not (free((c[0] + dx, c[1])) and free((c[0], c[1] + dy))): continue
            yield n, math.hypot(dx, dy)
def dijk(src, nb=neigh8):
    dist = {src: 0.0}; pq = [(0.0, src)]
    while pq:
        d, c = heapq.heappop(pq)
        if d > dist[c]: continue
        for n, w in nb(c):
            nd = d + w
            if nd < dist.get(n, 1e9): dist[n] = nd; heapq.heappush(pq, (nd, n))
    return dist
reach = dijk(points['spawn'], neigh4)
for k, c in points.items(): chk(f'{k} از نقطه شروع قابل دسترسی است', c in reach or k == 'enemy' and c in reach)
for h in D['hides']:
    c = tuple(h['cell']); chk(f'کمین {h["id"]} قابل دسترسی است', any(n in reach for n, _ in neigh4(c)) or any((c[0] + dx, c[1] + dy) in reach for dx in (-1, 0, 1) for dy in (-1, 0, 1)))
for r in D['rooms']:
    cells = [(x, y) for y in range(H) for x in range(W) if room_of[y][x] == r['id'] and free((x, y))]
    chk(f'همه‌ی خانه‌های اتاق «{r["name"]}» قابل دسترسی‌اند', all(c in reach for c in cells), [c for c in cells if c not in reach][:3])

# ----- سازگاری یادداشت‌ها با رمزها -----
code = [None] * 4; lev = None; wires = None
for n in D['notes']:
    rv = n.get('reveals', {})
    for k, v in rv.get('code', {}).items(): code[int(k)] = v
    lev = rv.get('levers', lev); wires = rv.get('wires', wires)
chk('رمز ۴ رقمی از یادداشت‌ها کامل و درست دریافت می‌شود', code == D['code'], code)
chk('ترتیب دسته‌ها در یادداشت با ترتیب بازی یکی است', lev == D['levers_order'])
chk('نقشه سیم‌ها در یادداشت با بازی یکی است', wires == D['wire_slots'])
chk('رقم‌های رمز در متن یادداشت‌ها آمده‌اند', '۷' in D['notes'][1]['text'] and '۹' in D['notes'][4]['text'] and '۱' in D['notes'][6]['text'])
chk('شناسه‌ی یادداشت‌ها یکتا', len({n['id'] for n in D['notes']}) == len(D['notes']))
chk('هر سه سطح سختی موجود است', set(D['difficulty']) == {'easy', 'medium', 'hard'})
chk('چهار پایان تعریف شده است', set(D['endings']) == {'escape', 'truth', 'loop_end', 'secret'})
need = {'patrol_speed', 'chase_speed', 'vision', 'fov', 'hear_run', 'hear_walk', 'grace', 'learn', 'battery_drain', 'puzzle_pauses', 'detect_time', 'search_time', 'lose_time'}
chk('همه‌ی پارامترهای سختی کامل است', all(need <= set(v) for v in D['difficulty'].values()))
chk('سرعت دویدن بازیکن از تعقیب آسان/متوسط/سخت بیشتر است (فرار ممکن است)', D['player']['run'] > max(v['chase_speed'] for v in D['difficulty'].values()))
chk('هیچ سختی‌ای زمان حلقه را عوض نمی‌کند (۶۰ ثانیه)', D['loop_seconds'] == 60)

# ----- زمان‌سنجی مسیرها -----
exit_cell = (61, 12); door = {k: tuple(v['cell']) for k, v in ((d['id'], d) for d in D['doors'])}
def route(wps, speed, inter):
    t_cells = 0.0
    for a, b in zip(wps, wps[1:]):
        t_cells += dijk(a)[b] if False else dist_cache(a).get(b, 1e9)
    return t_cells * C / speed + inter
_c = {}
def dist_cache(a):
    if a not in _c: _c[a] = dijk(a)
    return _c[a]
def adj(c):
    best = None
    for dx in (-1, 0, 1):
        for dy in (-1, 0, 1):
            n = (c[0] + dx, c[1] + dy)
            if free(n) and (best is None or abs(dx) + abs(dy) < best[0]): best = (abs(dx) + abs(dy), n)
    return best[1]
P = lambda k: adj(points[k]) if not free(points[k]) else points[k]
run, walk = D['player']['run'], D['player']['walk']
spawn = points['spawn']
card, key, fuse, fb, pn = P('card'), P('key'), P('fuse'), P('fusebox'), P('panel')
d_start, d_guard, d_storage, d_sec, d_exit = door['d_start'], door['d_guard'], door['d_storage'], door['d_security'], door['d_exit']
doc1, doc2, doc3, core, secret = P('doc1'), P('doc2'), P('doc3'), P('core'), P('secret')
E1 = [spawn, card, d_start, d_guard, key, d_storage, fuse, fb, pn, exit_cell]
E2 = [spawn, card, d_start, d_guard, doc2, key, doc1 if False else P('doc1'), d_storage, fuse, fb, pn, d_sec, doc3, exit_cell]
E3 = [spawn, card, d_start, d_guard, key, d_storage, fuse, fb, pn, d_sec, core]
ES = [spawn, card, d_start, d_guard, key, d_storage, secret]
for name, wps, inter in (('پایان ۱ (فرار)', E1, 8.0), ('پایان ۲ (حقیقت)', E2, 11.0), ('پایان ۳ (پایان چرخه)', E3, 12.0), ('پایان مخفی', ES, 4.0)):
    tr, tw = route(wps, run, inter), route(wps, walk, inter)
    print(f'     {name}: دویدن {tr:.1f} ثانیه | راه‌رفتن {tw:.1f} ثانیه (شامل {inter:.0f} ثانیه تعامل)')
    chk(f'{name}: با دویدن در کمتر از ۵۰ ثانیه ممکن است', tr < 50, round(tr, 1))
print(f'\nنتیجه: {total - bad} از {total} بررسی موفق، مشکل: {bad}'); sys.exit(1 if bad else 0)
