"""菜单栏 App —— 基于 rumps 的 macOS status bar 工具。

运行：python -m taobi.app   （需 macOS + `pip install rumps`）

设计原则与练习本身一致：能跑就发，别为了"再准备一下"而过度打磨。
"""

from __future__ import annotations

import datetime as _dt
import re
from typing import Optional

import rumps

from .storage import Store
from . import stats


# ---- 4 周进阶难度提示（渐进暴露）----
WEEK_LABEL = {
    1: "周1 · 零风险、私密、可逆",
    2: "周2 · 有少量真实受众",
    3: "周3 · 有真实利害、会被评判",
    4: "周4 · 对外承诺死线",
}

ABOUT_TEXT = (
    "治疗准备型逃避 · 21 天刻意练习\n\n"
    "你练的是一块很具体的肌肉：在没准备好的状态下行动、"
    "并把不完美的东西交出去。\n\n"
    "判断标准只有一条：如果某个练习没让你感到不适，它就不算数。\n\n"
    "三条铁律：\n"
    "1. 练习期禁止开新方向（新点子丢 Parking List）。\n"
    "2. \"再准备一下\"是禁用词——一旦冒出来，就当成\"该发了\"的信号。\n"
    "3. 漏一天不补、不自责，第二天继续。"
)


def _parse_numbers(text: str, count: int):
    """从用户输入里提取 count 个数字，提取不到的位置为 None。"""
    nums = re.findall(r"-?\d+(?:\.\d+)?", text or "")
    vals = [float(x) for x in nums][:count]
    vals += [None] * (count - len(vals))
    return vals


def _clamp(v: Optional[float], lo=0.0, hi=10.0) -> Optional[float]:
    if v is None:
        return None
    return max(lo, min(hi, v))


class TaobiApp(rumps.App):
    def __init__(self):
        super().__init__("Taobi", title="🔥 …", quit_button=None)
        self.store = Store()
        self.store.ensure_started()
        self._day_key = self.store_today_key()
        self._timers = []  # 保留一次性计时器引用，防止被 GC
        self._build_menu()
        self.refresh()
        # 周期刷新：处理跨天 + 标签更新
        self._ticker = rumps.Timer(self._tick, 30)
        self._ticker.start()
        # 每日提醒
        self._reminded_morning = None
        self._reminded_evening = None
        self._reminder = rumps.Timer(self._reminder_tick, 60)
        self._reminder.start()

    # ------------------------------------------------------------------ #
    # 辅助
    # ------------------------------------------------------------------ #
    @staticmethod
    def store_today_key() -> str:
        return _dt.date.today().isoformat()

    def day(self):
        return self.store.day(self._day_key)

    # ------------------------------------------------------------------ #
    # 菜单构建
    # ------------------------------------------------------------------ #
    def _build_menu(self):
        self.mi_header = rumps.MenuItem("")  # 周难度提示（不可点）
        self.mi_dec = rumps.MenuItem("① 决策秒杀", callback=None)
        self.mi_dec_add = rumps.MenuItem("＋ 添加一个决策（60 秒拍板）", callback=self.add_decision)
        self.mi_dec.add(self.mi_dec_add)
        self.mi_dec.add(rumps.separator)
        # 决策列表占位（refresh 时重建）
        self._dec_list_anchor = self.mi_dec

        self.mi_five = rumps.MenuItem("② 五分钟启动", callback=self.start_five_min)
        self.mi_ship = rumps.MenuItem("③ 每日一发 ★核心", callback=self.do_ship)
        self.mi_imp = rumps.MenuItem("④ 留一个不完美", callback=self.toggle_imperfection)
        self.mi_review = rumps.MenuItem("⑤ 晚间复盘", callback=self.do_review)

        # 焦虑校准
        self.mi_calib = rumps.MenuItem("🎯 焦虑校准")
        self.mi_calib.add(rumps.MenuItem("发之前 · 记录预测", callback=self.record_prediction))
        self.mi_calib.add(rumps.MenuItem("发之后 · 记录实际", callback=self.record_actual))

        # 启动延迟（thermometer）
        self.mi_lat = rumps.MenuItem("⏱ 启动延迟")
        self.mi_lat_decide = rumps.MenuItem("我决定要做某事（开始计时）", callback=self.latency_decide)
        self.mi_lat_start = rumps.MenuItem("我真正动手了（停止计时）", callback=self.latency_start)
        self.mi_lat.add(self.mi_lat_decide)
        self.mi_lat.add(self.mi_lat_start)

        # 数据与趋势
        self.mi_data = rumps.MenuItem("📊 数据与趋势", callback=self.show_data)

        # Parking list
        self.mi_park = rumps.MenuItem("🅿️ Parking List（新点子丢这里）", callback=self.add_parking)

        # 设置
        self.mi_settings = rumps.MenuItem("⚙️ 设置")
        self.mi_settings.add(rumps.MenuItem("设置开始日期…", callback=self.set_start_date))
        self.mi_settings.add(rumps.MenuItem("查看数据文件位置", callback=self.show_data_path))

        self.menu = [
            self.mi_header,
            rumps.separator,
            self.mi_dec,
            self.mi_five,
            self.mi_ship,
            self.mi_imp,
            self.mi_review,
            rumps.separator,
            self.mi_calib,
            self.mi_lat,
            self.mi_data,
            self.mi_park,
            rumps.separator,
            self.mi_settings,
            rumps.MenuItem("关于这套练习", callback=self.show_about),
            rumps.MenuItem("退出", callback=rumps.quit_application),
        ]

    # ------------------------------------------------------------------ #
    # 刷新显示
    # ------------------------------------------------------------------ #
    def refresh(self):
        store = self.store
        d = self.day()
        done, total = store.completion(self._day_key)
        day_n = store.day_number()
        self.title = f"🔥 第{day_n}天 · {done}/{total}"

        week = min(store.week_number(), 4)
        self.mi_header.title = f"今日 · {WEEK_LABEL.get(week, WEEK_LABEL[4])}"

        # ① 决策
        n_dec = len(d["decisions"])
        self.mi_dec.title = f"{'✓' if n_dec >= 3 else '○'} ① 决策秒杀（{n_dec}/3）"
        self._rebuild_decisions(d)

        # ②③④⑤
        self.mi_five.title = f"{'✓' if d['five_min_started'] else '○'} ② 五分钟启动"
        ship_done = d["daily_ship"]["done"]
        self.mi_ship.title = f"{'✓' if ship_done else '○'} ③ 每日一发 ★核心"
        self.mi_imp.title = f"{'✓' if d['imperfection_left'] else '○'} ④ 留一个不完美"
        self.mi_review.title = f"{'✓' if d['evening_review']['done'] else '○'} ⑤ 晚间复盘"

        # 启动延迟状态
        if store.has_pending_decide(self._day_key):
            self.mi_lat.title = "⏱ 启动延迟 · 计时中…"
        elif d.get("startup_latency_min") is not None:
            self.mi_lat.title = f"⏱ 启动延迟 · 今日 {d['startup_latency_min']} 分钟"
        else:
            self.mi_lat.title = "⏱ 启动延迟"

    def _rebuild_decisions(self, d):
        # 只删我们加过的决策项（dec:: 前缀），保留"添加"按钮与分隔符
        for key in list(self.mi_dec.keys()):
            if str(key).startswith("dec::"):
                del self.mi_dec[key]
        for i, dec in enumerate(d["decisions"]):
            mi = rumps.MenuItem(f"  {i+1}. {dec['text']}", callback=None)
            self.mi_dec[f"dec::{i}"] = mi

    # ------------------------------------------------------------------ #
    # 跨天 / 提醒
    # ------------------------------------------------------------------ #
    def _tick(self, _timer):
        cur = self.store_today_key()
        if cur != self._day_key:
            self._day_key = cur  # 跨天，切换到新的一天
        self.refresh()

    def _reminder_tick(self, _timer):
        now = _dt.datetime.now()
        today = now.date().isoformat()
        d = self.day()
        # 早 9 点：还没记决策就提醒
        if now.hour == 9 and self._reminded_morning != today and len(d["decisions"]) < 3:
            self._reminded_morning = today
            self._notify("决策秒杀 · 早上 5 分钟", "列 3 个双向门小决策，每个 60 秒拍板。")
        # 晚 9 点：还没发 / 还没复盘就提醒
        if now.hour == 21 and self._reminded_evening != today:
            self._reminded_evening = today
            if not d["daily_ship"]["done"]:
                self._notify("每日一发 ★核心", "今天还没发——把一件低于满意标准的东西交出去。")
            elif not d["evening_review"]["done"]:
                self._notify("晚间复盘 · 5 分钟", "记一下今天的焦虑校准，看预测 vs 实际。")

    def _notify(self, title, message, subtitle=""):
        try:
            rumps.notification(title, subtitle, message)
        except Exception:
            pass  # 未打包成 .app 时通知可能不可用，忽略

    # ------------------------------------------------------------------ #
    # ① 决策秒杀
    # ------------------------------------------------------------------ #
    def add_decision(self, _sender):
        d = self.day()
        if len(d["decisions"]) >= 3:
            rumps.alert("今日决策已满", "已经记满 3 个了。不准回头改——这正是练习。")
            return
        resp = rumps.Window(
            message="一个今天要做的小决策（双向门：错了能改）。\n点 OK 后给自己 60 秒拍板，不回头。",
            title="① 决策秒杀",
            default_text="",
            ok="拍板",
            cancel="取消",
            dimensions=(320, 80),
        ).run()
        if resp.clicked and resp.text.strip():
            n = self.store.add_decision(resp.text, self._day_key)
            self._notify("60 秒倒计时开始", f"第 {n}/3 个决策。到点必须定，不准回头改。")
            t = rumps.Timer(self._decision_timeout, 60)
            self._timers.append(t)
            t.start()
            self.refresh()

    def _decision_timeout(self, timer):
        timer.stop()
        if timer in self._timers:
            self._timers.remove(timer)
        self._notify("⏰ 时间到", "拍板！信息不全也要定。")

    # ------------------------------------------------------------------ #
    # ② 五分钟启动
    # ------------------------------------------------------------------ #
    def start_five_min(self, _sender):
        d = self.day()
        if d["five_min_started"]:
            rumps.alert("今天已经启动过", "这一步练的是\"启动\"，不是\"完成\"。今天的 rep 已完成 ✓")
            return
        self.store.set_five_min(True, self._day_key)
        self._notify("五分钟启动", "挑最想拖的那件事，只做 5 分钟，到点即止。计时开始。")
        t = rumps.Timer(self._five_done, 300)
        self._timers.append(t)
        t.start()
        self.refresh()

    def _five_done(self, timer):
        timer.stop()
        if timer in self._timers:
            self._timers.remove(timer)
        self._notify("⏰ 五分钟到", "到点即止。你已经完成今天的\"启动\" rep。")

    # ------------------------------------------------------------------ #
    # ③ 每日一发
    # ------------------------------------------------------------------ #
    def do_ship(self, _sender):
        d = self.day()
        if d["daily_ship"]["done"]:
            rumps.alert("今日已发 ✓", f"内容：{d['daily_ship']['what'] or '（未记录）'}")
            return
        resp = rumps.Window(
            message="把今天这件【低于你满意标准】的东西交出去后，写下它是什么：\n"
            "（commit / 朋友圈 / 邮件 / demo / 草稿…）",
            title="③ 每日一发 ★核心",
            default_text="",
            ok="已发出 ✓",
            cancel="还没",
            dimensions=(320, 80),
        ).run()
        if resp.clicked:
            self.store.set_ship(True, resp.text, self._day_key)
            self._notify("发出了 🎉", "这就是核心 rep。别修了——\"再准备一下\"是禁用词。")
            # 顺手提示记录焦虑校准
            if d["calibration"]["actual_reaction"] is None:
                rumps.alert("顺手做个焦虑校准", "去 🎯 焦虑校准 → 记录实际，对比你发之前的预测。")
            self.refresh()

    # ------------------------------------------------------------------ #
    # ④ 留一个不完美
    # ------------------------------------------------------------------ #
    def toggle_imperfection(self, _sender):
        now = self.store.toggle_imperfection(self._day_key)
        if now:
            self._notify("留一个不完美", "故意留下一个无关紧要的瑕疵别碰。然后观察：天塌了吗？")
        self.refresh()

    # ------------------------------------------------------------------ #
    # ⑤ 晚间复盘
    # ------------------------------------------------------------------ #
    def do_review(self, _sender):
        d = self.day()
        resp = rumps.Window(
            message="晚间复盘 5 分钟：今天哪一发最不适？预测 vs 实际差多少？明天推哪一个？",
            title="⑤ 晚间复盘",
            default_text=d["evening_review"].get("note", ""),
            ok="保存",
            cancel="取消",
            dimensions=(360, 120),
        ).run()
        if resp.clicked:
            self.store.set_review(resp.text, self._day_key)
            self.refresh()

    # ------------------------------------------------------------------ #
    # 焦虑校准
    # ------------------------------------------------------------------ #
    def record_prediction(self, _sender):
        resp = rumps.Window(
            message="发之前 · 预测（0-10，用空格分隔两个数）：\n"
            "① 这事会引发多糟的反应  ② 我会焦虑到几分",
            title="🎯 焦虑校准 · 预测",
            default_text="7 7",
            ok="记下预测",
            cancel="取消",
            dimensions=(320, 80),
        ).run()
        if resp.clicked:
            r, a = _parse_numbers(resp.text, 2)
            self.store.set_prediction(_clamp(r), _clamp(a), self._day_key)
            self._notify("预测已记", "现在去发。发完回来记实际。")
            self.refresh()

    def record_actual(self, _sender):
        resp = rumps.Window(
            message="发之后 · 实际（用空格分隔三个数）：\n"
            "① 实际反应有多糟(0-10)  ② 实际焦虑峰值(0-10)  ③ 焦虑几分钟消退",
            title="🎯 焦虑校准 · 实际",
            default_text="2 3 15",
            ok="记下实际",
            cancel="取消",
            dimensions=(320, 80),
        ).run()
        if resp.clicked:
            r, a, faded = _parse_numbers(resp.text, 3)
            self.store.set_actual(_clamp(r), _clamp(a), faded, self._day_key)
            c = self.day()["calibration"]
            msg = "证据 +1。"
            if c["pred_reaction"] is not None and r is not None:
                gap = round(c["pred_reaction"] - _clamp(r), 1)
                msg = f"你高估了反应严重程度 {gap} 分。预测远高于实际——这就是证据。"
            self._notify("实际已记", msg)
            self.refresh()

    # ------------------------------------------------------------------ #
    # 启动延迟
    # ------------------------------------------------------------------ #
    def latency_decide(self, _sender):
        self.store.mark_decided(self._day_key)
        self._notify("⏱ 计时开始", "从现在到你真正动手的分钟数，就是\"启动延迟\"。越短越好。")
        self.refresh()

    def latency_start(self, _sender):
        latency = self.store.mark_started(self._day_key)
        if latency is None:
            rumps.alert("还没开始计时", "先点\"我决定要做某事\"，再点这个。")
            return
        self._notify("⏱ 启动延迟", f"{latency} 分钟。这是这个病最干净的体温计——盯着它往下走。")
        self.refresh()

    # ------------------------------------------------------------------ #
    # 数据与趋势
    # ------------------------------------------------------------------ #
    def show_data(self, _sender):
        days = self.store.data["days"]
        lat = stats.latency_summary(days)
        series = [v for _, v in stats.latency_series(days, 14)]
        spark = stats.sparkline(series)
        calib = stats.calibration_summary(days)
        streak = stats.ship_streak(days)
        total = stats.ship_total(days)

        def fmt(x, unit=""):
            return "—" if x is None else f"{x}{unit}"

        trend = ""
        if lat["recent_avg"] is not None and lat["prev_avg"] is not None:
            delta = round(lat["recent_avg"] - lat["prev_avg"], 1)
            arrow = "↓ 在好转" if delta < 0 else ("↑ 注意" if delta > 0 else "→ 持平")
            trend = f"（较上周 {arrow} {abs(delta)} 分钟）"

        lines = [
            f"🔥 每日一发：连续 {streak} 天 · 累计 {total} 次",
            "",
            "⏱ 启动延迟（体温计，越低越好）",
            f"   近 14 天：{spark}",
            f"   本周均值 {fmt(lat['recent_avg'], ' min')} {trend}",
            f"   总体均值 {fmt(lat['all_avg'], ' min')}",
            "",
            "🎯 焦虑校准（你系统性高估行动后果的证据）",
            f"   反应：预测 {fmt(calib['avg_pred_reaction'])} vs 实际 {fmt(calib['avg_actual_reaction'])}"
            f" → 高估 {fmt(calib['reaction_overestimate'])}",
            f"   焦虑：预测 {fmt(calib['avg_pred_anxiety'])} vs 实际 {fmt(calib['avg_actual_anxiety'])}"
            f" → 高估 {fmt(calib['anxiety_overestimate'])}",
            f"   样本：{calib['samples']} 天",
        ]
        rumps.alert("📊 数据与趋势", "\n".join(lines))

    def add_parking(self, _sender):
        resp = rumps.Window(
            message="冒出来的新方向 / 新点子丢这里——练习期只把一个东西推到底。",
            title="🅿️ Parking List",
            default_text="",
            ok="存入",
            cancel="取消",
            dimensions=(320, 80),
        ).run()
        if resp.clicked and resp.text.strip():
            n = self.store.add_parking(resp.text)
            self._notify("已存入 Parking List", f"共 {n} 条。换赛道是最熟练的逃避——先不碰。")

    # ------------------------------------------------------------------ #
    # 设置 / 关于
    # ------------------------------------------------------------------ #
    def set_start_date(self, _sender):
        resp = rumps.Window(
            message="练习开始日期（YYYY-MM-DD）：",
            title="设置开始日期",
            default_text=self.store.data.get("start_date") or self.store_today_key(),
            ok="保存",
            cancel="取消",
            dimensions=(200, 24),
        ).run()
        if resp.clicked:
            try:
                _dt.date.fromisoformat(resp.text.strip())
                self.store.set_start_date(resp.text.strip())
                self.refresh()
            except ValueError:
                rumps.alert("格式错误", "请用 YYYY-MM-DD，例如 2026-05-30")

    def show_data_path(self, _sender):
        rumps.alert("数据文件", self.store.path)

    def show_about(self, _sender):
        rumps.alert("关于", ABOUT_TEXT)


def main():
    TaobiApp().run()


if __name__ == "__main__":
    main()
