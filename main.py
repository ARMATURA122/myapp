import math, json, os, random
from kivy.app import App
from kivy.clock import Clock
from kivy.graphics import Color, Rectangle, Ellipse, PushMatrix, PopMatrix, Rotate, Translate
from kivy.uix.widget import Widget
from kivy.uix.label import Label
from kivy.uix.button import Button
from kivy.uix.popup import Popup
from kivy.uix.boxlayout import BoxLayout

N, B, R = 10, 70, 18
P = B + R
SZ = N * P + R
COLS = [(1,.18,.33),(1,.58,0),(1,.84,.04),(.19,.82,.35),(.04,.52,1),(.75,.35,.95),(.95,.95,.97),(.11,.11,.12)]
NEO = [(0,.9,1),(1,.24,.95),(.49,1,.23),(1,.82,0),None]
UPN = [('eng','Двигатель',450),('tire','Шины',350),('nit','Нитро',300)]

def solid(x, z):
    if x < 3 or z < 3 or x > SZ - 3 or z > SZ - 3:
        return True
    u = (x - R) % P
    v = (z - R) % P
    return (u < B + 2 or u > P - 2) and (v < B + 2 or v > P - 2)

class Game(Widget):
    def __init__(self, app, **kw):
        super().__init__(**kw)
        self.app = app
        self.S = dict(cash=300, eng=0, tire=0, nit=0, color=0, spoil=1, neon=0)
        self.load()
        rnd = random.Random(7)
        self.cols = [[[(.15+rnd.random()*.25, .15+rnd.random()*.2, .25+rnd.random()*.3) for _ in range(4)] for _ in range(N)] for _ in range(N)]
        self.x = self.z = 5 * P + R / 2
        self.a = self.vx = self.vz = self.spd = self.dp = self.dtm = self.idle = 0
        self.nit = 100
        self.K = dict(l=0, r=0, g=0, b=0, h=0, n=0)
        self.tk = {}
        self.paused = False
        self.btn = {}
        self.msg = ''
        self.msgt = 0
        self.lb = {}
        for n in ('cash', 'spd', 'dr', 'toast', 'dist'):
            self.lb[n] = Label(font_size='20sp', bold=True)
            self.add_widget(self.lb[n])
        self.lb['spd'].font_size = '34sp'
        self.lb['dr'].color = (1, .82, 0, 1)
        self.lb['toast'].font_size = '26sp'
        self.bt = {}
        for k, t in dict(l='<', r='>', g='ГАЗ', b='Тормоз', h='Дрифт', n='Нитро').items():
            self.bt[k] = Label(text=t, font_size='20sp', bold=True)
            self.add_widget(self.bt[k])
        self.gb = Button(text='Гараж', size_hint=(None, None), size=(130, 56))
        self.gb.bind(on_release=self.garage)
        self.add_widget(self.gb)
        self.nb()
        self.say('Езжай к жёлтому маяку. Дрифт приносит деньги.', 4)
        self.bind(size=self.layout)
        Clock.schedule_interval(self.tick, 1 / 60)

    def path(self):
        return os.path.join(self.app.user_data_dir, 'save.json')

    def load(self):
        try:
            self.S.update(json.load(open(self.path())))
        except Exception:
            pass

    def save(self):
        try:
            json.dump(self.S, open(self.path(), 'w'))
        except Exception:
            pass

    def say(self, t, s=1.6):
        self.msg = t
        self.msgt = s

    def nb(self):
        while True:
            self.bx = random.randint(0, N) * P + R / 2
            self.bz = random.randint(0, N) * P + R / 2
            if math.hypot(self.bx - self.x, self.bz - self.z) > 160:
                break

    def layout(self, *a):
        W, H = self.size
        s = min(W, H) * .2
        g = 16
        self.btn = {'l': (g, g, s, s), 'r': (g*2+s, g, s, s), 'g': (W-g-1.5*s, g, 1.5*s, 2.4*s),
                    'b': (W-g*2-2.5*s, g, s, s*.75), 'h': (W-g*2-2.5*s, g*2+s*.75, s, s*.75),
                    'n': (W-g*2-2.5*s, g*3+s*1.5, s, s*.75)}
        for k, (x, y, w, h) in self.btn.items():
            self.bt[k].pos = (x, y)
            self.bt[k].size = (w, h)
        for n, (x, y, w, h, al) in dict(cash=(g, H-50, 300, 40, 'left'), spd=(g, H-100, 300, 50, 'left'),
                dr=(W/2-200, H-50, 400, 40, 'center'), toast=(W/2-300, H*.65, 600, 60, 'center'),
                dist=(W-190, H-190, 180, 30, 'right')).items():
            self.lb[n].pos = (x, y)
            self.lb[n].size = (w, h)
            self.lb[n].text_size = (w, h)
            self.lb[n].halign = al
            self.lb[n].valign = 'middle'
        self.gb.pos = (g, H - 165)

    def hit(self, t):
        for k, (x, y, w, h) in self.btn.items():
            if x <= t.x <= x + w and y <= t.y <= y + h:
                return k

    def on_touch_down(self, t):
        if self.paused:
            return super().on_touch_down(t)
        k = self.hit(t)
        if k is None:
            return super().on_touch_down(t)
        self.tk[t.uid] = k
        self.K[k] = 1
        return True

    def on_touch_move(self, t):
        if t.uid in self.tk:
            k = self.hit(t)
            o = self.tk[t.uid]
            if k != o:
                self.K[o] = 0
                if k:
                    self.K[k] = 1
                    self.tk[t.uid] = k
                else:
                    del self.tk[t.uid]
            return True
        return super().on_touch_move(t)

    def on_touch_up(self, t):
        if t.uid in self.tk:
            self.K[self.tk.pop(t.uid)] = 0
            return True
        return super().on_touch_up(t)

    def step(self, dt):
        S, K = self.S, self.K
        s = K['r'] - K['l']
        vf0 = self.vx * math.sin(self.a) + self.vz * math.cos(self.a)
        top = 44 + S['eng'] * 5
        acc = 22 + S['eng'] * 4
        grip = 7 + S['tire'] * 1.8
        nm = 100 + S['nit'] * 40
        non = K['n'] and K['g'] and self.nit > 2
        self.nit = self.nit - 30 * dt if non else min(nm, self.nit + 9 * dt)
        sg = (vf0 > 0) - (vf0 < 0)
        self.a += s * 2.2 * (1 - min(.5, abs(vf0) / 120)) * min(1, abs(vf0) / 9) * sg * (1.5 if K['h'] else 1) * dt
        sa, ca = math.sin(self.a), math.cos(self.a)
        vf = self.vx * sa + self.vz * ca
        vl = self.vx * ca - self.vz * sa
        tp = top + (18 if non else 0)
        if K['g']:
            vf += (acc + (24 if non else 0)) * max(0, 1 - vf / tp) * dt
        if K['b']:
            vf = vf - 48 * dt if vf > 1 else max(-14, vf - 16 * dt)
        if not K['g'] and not K['b']:
            vf *= 1 - .5 * dt
        vf *= 1 - .06 * dt
        if K['h']:
            vf *= 1 - .55 * dt
        gp = grip * (.12 if K['h'] else (.55 if s and vf > top * .55 else 1))
        vl *= math.exp(-gp * dt)
        self.vx = sa * vf + ca * vl
        self.vz = ca * vf - sa * vl
        nx, nz = self.x + self.vx * dt, self.z + self.vz * dt
        if solid(nx, nz):
            if not solid(nx, self.z):
                nz = self.z; self.vz *= -.3; self.vx *= .85
            elif not solid(self.x, nz):
                nx = self.x; self.vx *= -.3; self.vz *= .85
            else:
                nx, nz = self.x, self.z; self.vx *= -.3; self.vz *= -.3
            if self.dp > 0:
                self.dp = self.dtm = 0
                self.say('Авария!')
        self.x, self.z = nx, nz
        slip = abs(vl)
        self.spd = math.hypot(self.vx, self.vz)
        if slip > 4.5 and abs(vf) > 10:
            self.dp += slip * abs(vf) * dt * .1 * (1 + self.dtm * .15)
            self.dtm += dt
            self.idle = 0
        else:
            self.idle += dt
            if self.idle > .7 and self.dp > 0:
                p = int(self.dp)
                S['cash'] += p
                self.say('Дрифт +$%d' % p)
                self.dp = self.dtm = 0
                self.save()
        if math.hypot(self.x - self.bx, self.z - self.bz) < 12:
            S['cash'] += 520
            self.say('Маяк! +$520')
            self.save()
            self.nb()

    def tick(self, dt):
        dt = min(dt, .05)
        if not self.paused:
            self.step(dt)
        if self.msgt > 0:
            self.msgt -= dt
        self.draw()

    def draw(self):
        W, H = self.size
        if not W:
            return
        S = self.S
        z = max(5.5, 10 - self.spd * .08)
        cx, cz = self.x, self.z
        X = lambda v: (v - cx) * z + W / 2
        Y = lambda v: (v - cz) * z + H / 2
        c = self.canvas.before
        c.clear()
        with c:
            Color(.04, .09, .07); Rectangle(pos=(0, 0), size=(W, H))
            Color(.13, .13, .17); Rectangle(pos=(X(0), Y(0)), size=(SZ * z, SZ * z))
            for i in range(N):
                bx = R + i * P
                if X(bx + B) < 0 or X(bx) > W:
                    continue
                for j in range(N):
                    bz = R + j * P
                    if Y(bz + B) < 0 or Y(bz) > H:
                        continue
                    Color(.22, .22, .28); Rectangle(pos=(X(bx), Y(bz)), size=(B * z, B * z))
                    for q in range(4):
                        Color(*self.cols[i][j][q])
                        Rectangle(pos=(X(bx + B * (.06 + .5 * (q // 2))), Y(bz + B * (.06 + .5 * (q % 2)))), size=(B * .38 * z, B * .38 * z))
            Color(.9, .77, .28)
            for i in range(N + 1):
                ln = i * P + R / 2
                if abs(ln - cx) < W / z / 2 + 2:
                    for t in range(int((cz - H / z / 2) // 14) * 14, int(cz + H / z / 2) + 14, 14):
                        if 0 <= t <= SZ:
                            Rectangle(pos=(X(ln) - 1, Y(t)), size=(2, 7 * z))
                if abs(ln - cz) < H / z / 2 + 2:
                    for t in range(int((cx - W / z / 2) // 14) * 14, int(cx + W / z / 2) + 14, 14):
                        if 0 <= t <= SZ:
                            Rectangle(pos=(X(t), Y(ln) - 1), size=(7 * z, 2))
            Color(1, .82, 0, .85); Ellipse(pos=(X(self.bx) - 6 * z, Y(self.bz) - 6 * z), size=(12 * z, 12 * z))
            PushMatrix()
            Translate(W / 2, H / 2)
            Rotate(angle=-math.degrees(self.a), axis=(0, 0, 1), origin=(0, 0))
            if NEO[S['neon']]:
                Color(*NEO[S['neon']], .4); Rectangle(pos=(-1.7 * z, -3 * z), size=(3.4 * z, 6 * z))
            col = COLS[S['color']]
            Color(*col); Rectangle(pos=(-z, -2.2 * z), size=(2 * z, 4.4 * z))
            Color(.06, .07, .1); Rectangle(pos=(-.8 * z, -.9 * z), size=(1.6 * z, 1.5 * z))
            if S['spoil']:
                Color(*col); Rectangle(pos=(-1.05 * z, -2.5 * z), size=(2.1 * z, .4 * z))
            Color(1, 1, .9); Rectangle(pos=(-.8 * z, 2 * z), size=(.5 * z, .25 * z)); Rectangle(pos=(.3 * z, 2 * z), size=(.5 * z, .25 * z))
            Color(1, .1, .1); Rectangle(pos=(-.8 * z, -2.2 * z), size=(.5 * z, .25 * z)); Rectangle(pos=(.3 * z, -2.2 * z), size=(.5 * z, .25 * z))
            PopMatrix()
            m = 150 / SZ
            mx, my = W - 160, H - 160
            Color(.1, .1, .14, .9); Rectangle(pos=(mx, my), size=(150, 150))
            Color(.3, .3, .38)
            for i in range(N):
                for j in range(N):
                    Rectangle(pos=(mx + (R + i * P) * m, my + (R + j * P) * m), size=(B * m, B * m))
            Color(1, .82, 0); Rectangle(pos=(mx + self.bx * m - 3, my + self.bz * m - 3), size=(6, 6))
            Color(0, .9, 1); Rectangle(pos=(mx + cx * m - 3, my + cz * m - 3), size=(6, 6))
            for k, (x, y, w, h) in self.btn.items():
                Color(1, .24, .5, .75) if self.K[k] else Color(1, 1, 1, .18)
                Rectangle(pos=(x, y), size=(w, h))
        self.lb['cash'].text = '$%d   Нитро %d%%' % (S['cash'], self.nit / (100 + S['nit'] * 40) * 100)
        self.lb['spd'].text = '%d км/ч' % (self.spd * 3.6)
        self.lb['dr'].text = 'Дрифт +%d  x%.1f' % (self.dp, 1 + self.dtm * .15) if self.dp > 0 else ''
        self.lb['toast'].text = self.msg if self.msgt > 0 else ''
        self.lb['dist'].text = '%d м до маяка' % math.hypot(cx - self.bx, cz - self.bz)

    def mk(self, text, cb, on=True):
        return Button(text=text, disabled=not on, on_release=cb, font_size='18sp')

    def garage(self, *a):
        self.paused = True
        self.K = dict.fromkeys(self.K, 0)
        self.tk = {}
        self.box = BoxLayout(orientation='vertical', spacing=8, padding=8)
        self.pop = Popup(title='Гараж', content=self.box, size_hint=(.92, .96), auto_dismiss=False)
        self.fill()
        self.pop.open()

    def fill(self):
        S, b = self.S, self.box
        b.clear_widgets()
        b.add_widget(Label(text='Деньги: $%d' % S['cash'], font_size='22sp'))
        for k, n, c in UPN:
            l = S[k]
            pr = (l + 1) * c
            t = '%s: уровень %d из 5, $%d' % (n, l, pr) if l < 5 else '%s: максимум' % n
            b.add_widget(self.mk(t, lambda *_, k=k, c=c: self.buy(k, c), S['cash'] >= pr and l < 5))
        b.add_widget(self.mk('Цвет кузова: сменить', lambda *_: self.cyc('color', len(COLS))))
        b.add_widget(self.mk('Спойлер: ' + ('есть' if S['spoil'] else 'нет'), lambda *_: self.cyc('spoil', 2)))
        b.add_widget(self.mk('Неон: сменить', lambda *_: self.cyc('neon', len(NEO))))
        b.add_widget(self.mk('Ехать', lambda *_: self.close()))

    def buy(self, k, c):
        pr = (self.S[k] + 1) * c
        if self.S['cash'] >= pr and self.S[k] < 5:
            self.S['cash'] -= pr
            self.S[k] += 1
            self.save()
        self.fill()

    def cyc(self, k, n):
        self.S[k] = (self.S[k] + 1) % n
        self.save()
        self.fill()

    def close(self):
        self.pop.dismiss()
        self.paused = False

class DriftApp(App):
    def build(self):
        return Game(self)

DriftApp().run()
