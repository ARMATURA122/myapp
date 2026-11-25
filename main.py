import random
from kivy.app import App
from kivy.uix.widget import Widget
from kivy.uix.label import Label
from kivy.graphics import Color, Ellipse, Rectangle
from kivy.clock import Clock


class Game(Widget):
    def __init__(self, **kw):
        super().__init__(**kw)
        self.label = Label(font_size="26sp", halign="center")
        self.add_widget(self.label)
        self.bind(size=self.draw, pos=self.draw)
        Clock.schedule_interval(self.tick, 1)
        self.reset()

    def reset(self):
        self.score = 0
        self.left = 30
        self.move()

    def move(self):
        self.r = 50
        self.cx = random.randint(self.r, max(self.r, int(self.width) - self.r))
        self.cy = random.randint(self.r, max(self.r, int(self.height) - 150))
        self.draw()

    def tick(self, dt):
        if self.left > 0:
            self.left -= 1
            self.draw()

    def draw(self, *a):
        self.canvas.before.clear()
        with self.canvas.before:
            Color(0, 0, 0, 1)
            Rectangle(pos=self.pos, size=self.size)
            if self.left > 0:
                Color(0.9, 0.1, 0.1, 1)
                Ellipse(pos=(self.cx - self.r, self.cy - self.r),
                        size=(self.r * 2, self.r * 2))
        self.label.size = (self.width, 100)
        self.label.pos = (0, self.height - 120)
        if self.left > 0:
            self.label.text = "Очки: %d   Время: %d" % (self.score, self.left)
        else:
            self.label.text = "Конец! Очки: %d\nТапни, чтобы заново" % self.score

    def on_touch_down(self, t):
        if self.left <= 0:
            self.reset()
            return True
        if (t.x - self.cx) ** 2 + (t.y - self.cy) ** 2 <= self.r ** 2:
            self.score += 1
            self.move()
        return True


class TapApp(App):
    def build(self):
        return Game()


TapApp().run()
