"""storage / stats 的单元测试（纯逻辑，无需 macOS / rumps）。"""

import datetime as dt
import os
import sys
import tempfile

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

from taobi.storage import Store  # noqa: E402
from taobi import stats  # noqa: E402


def fresh_store():
    tmp = tempfile.mkdtemp()
    return Store(path=os.path.join(tmp, "data.json"))


def test_empty_completion():
    s = fresh_store()
    assert s.completion() == (0, 5)


def test_decisions_complete_at_three():
    s = fresh_store()
    s.add_decision("a")
    s.add_decision("b")
    assert s.completion()[0] == 0  # 决策项要到 3 个才算完成
    s.add_decision("c")
    assert s.completion()[0] == 1


def test_full_day_completion():
    s = fresh_store()
    for x in "abc":
        s.add_decision(x)
    s.set_five_min(True)
    s.set_ship(True, "a commit")
    s.toggle_imperfection()
    s.set_review("done")
    assert s.completion() == (5, 5)


def test_ship_persisted_and_reloaded():
    s = fresh_store()
    s.set_ship(True, "小红书一条")
    s2 = Store(path=s.path)
    assert s2.day()["daily_ship"]["done"] is True
    assert s2.day()["daily_ship"]["what"] == "小红书一条"


def test_startup_latency_flow():
    s = fresh_store()
    assert s.mark_started() is None  # 没先决定
    s.mark_decided()
    assert s.has_pending_decide() is True
    # 手动把决定时间往前挪 5 分钟，模拟延迟
    key = list(s.data["days"].keys())[0]
    past = dt.datetime.now() - dt.timedelta(minutes=5)
    s.data["days"][key]["_decide_ts"] = past.isoformat(timespec="seconds")
    latency = s.mark_started()
    assert 4.5 <= latency <= 5.5
    assert s.has_pending_decide() is False


def test_day_and_week_number():
    s = fresh_store()
    start = dt.date(2026, 5, 1)
    s.set_start_date(start.isoformat())
    assert s.day_number(dt.date(2026, 5, 1)) == 1
    assert s.day_number(dt.date(2026, 5, 8)) == 8
    assert s.week_number(dt.date(2026, 5, 1)) == 1
    assert s.week_number(dt.date(2026, 5, 8)) == 2
    assert s.week_number(dt.date(2026, 5, 22)) == 4


def test_calibration_summary_overestimate():
    s = fresh_store()
    today = dt.date(2026, 5, 30)
    k = today.isoformat()
    s.set_prediction(8, 9, key=k)
    s.set_actual(2, 3, faded_min=10, key=k)
    summary = stats.calibration_summary(s.data["days"], today=today)
    assert summary["reaction_overestimate"] == 6.0
    assert summary["anxiety_overestimate"] == 6.0
    assert summary["samples"] == 1


def test_latency_summary_trend():
    s = fresh_store()
    today = dt.date(2026, 5, 30)
    # 前一周高、本周低 → 在好转
    for i in range(7, 14):
        k = (today - dt.timedelta(days=i)).isoformat()
        s.day(k)["startup_latency_min"] = 30
    for i in range(0, 7):
        k = (today - dt.timedelta(days=i)).isoformat()
        s.day(k)["startup_latency_min"] = 10
    s.save()
    summ = stats.latency_summary(s.data["days"], today=today)
    assert summ["recent_avg"] == 10
    assert summ["prev_avg"] == 30


def test_ship_streak_counts_today_optional():
    s = fresh_store()
    today = dt.date(2026, 5, 30)
    # 昨天和前天发了，今天还没发 —— streak 不应被打断
    for i in (1, 2):
        k = (today - dt.timedelta(days=i)).isoformat()
        s.set_ship(True, "x", key=k)
    assert stats.ship_streak(s.data["days"], today=today) == 2


def test_parking_list():
    s = fresh_store()
    s.add_parking("一个超棒但要换赛道的点子")
    assert len(s.parking()) == 1


def test_sparkline_handles_gaps():
    line = stats.sparkline([None, 1, 5, 10, None])
    assert len(line) == 5
    assert "·" in line


if __name__ == "__main__":
    import traceback

    fns = [v for k, v in sorted(globals().items()) if k.startswith("test_") and callable(v)]
    failed = 0
    for fn in fns:
        try:
            fn()
            print(f"PASS {fn.__name__}")
        except Exception:
            failed += 1
            print(f"FAIL {fn.__name__}")
            traceback.print_exc()
    print(f"\n{len(fns) - failed}/{len(fns)} passed")
    sys.exit(1 if failed else 0)
