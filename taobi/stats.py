"""趋势与统计 —— 纯 Python，把每日记录汇总成"证据"。

两个核心指标：
  1. 启动延迟（thermometer）：往下走 = 在好转。
  2. 焦虑校准差距：预测 - 实际，systematically 高估行动后果的证据。
"""

from __future__ import annotations

import datetime as _dt
from typing import Any, Dict, List, Optional, Tuple


def _last_n_keys(n: int, today: _dt.date | None = None) -> List[str]:
    today = today or _dt.date.today()
    return [(today - _dt.timedelta(days=i)).isoformat() for i in range(n - 1, -1, -1)]


def latency_series(days: Dict[str, Any], n: int = 14, today: _dt.date | None = None) -> List[Tuple[str, Optional[float]]]:
    """近 n 天的启动延迟序列，缺失为 None。"""
    out = []
    for k in _last_n_keys(n, today):
        rec = days.get(k) or {}
        out.append((k, rec.get("startup_latency_min")))
    return out


def _avg(values: List[float]) -> Optional[float]:
    vals = [v for v in values if v is not None]
    if not vals:
        return None
    return round(sum(vals) / len(vals), 1)


def latency_summary(days: Dict[str, Any], today: _dt.date | None = None) -> Dict[str, Optional[float]]:
    """对比最近一周 vs 前一周的平均启动延迟。"""
    series = latency_series(days, n=14, today=today)
    first_week = [v for _, v in series[:7]]
    second_week = [v for _, v in series[7:]]
    return {
        "recent_avg": _avg(second_week),
        "prev_avg": _avg(first_week),
        "all_avg": _avg([v for _, v in series]),
    }


def calibration_summary(days: Dict[str, Any], today: _dt.date | None = None, n: int = 14) -> Dict[str, Optional[float]]:
    """汇总焦虑校准：平均预测 vs 平均实际，以及高估差距。"""
    pred_r, actual_r, pred_a, actual_a = [], [], [], []
    for k in _last_n_keys(n, today):
        c = (days.get(k) or {}).get("calibration") or {}
        if c.get("pred_reaction") is not None:
            pred_r.append(c["pred_reaction"])
        if c.get("actual_reaction") is not None:
            actual_r.append(c["actual_reaction"])
        if c.get("pred_anxiety") is not None:
            pred_a.append(c["pred_anxiety"])
        if c.get("actual_anxiety") is not None:
            actual_a.append(c["actual_anxiety"])

    avg_pred_r, avg_actual_r = _avg(pred_r), _avg(actual_r)
    avg_pred_a, avg_actual_a = _avg(pred_a), _avg(actual_a)

    def gap(p, a):
        if p is None or a is None:
            return None
        return round(p - a, 1)

    return {
        "avg_pred_reaction": avg_pred_r,
        "avg_actual_reaction": avg_actual_r,
        "reaction_overestimate": gap(avg_pred_r, avg_actual_r),
        "avg_pred_anxiety": avg_pred_a,
        "avg_actual_anxiety": avg_actual_a,
        "anxiety_overestimate": gap(avg_pred_a, avg_actual_a),
        "samples": max(len(pred_r), len(pred_a)),
    }


def ship_streak(days: Dict[str, Any], today: _dt.date | None = None) -> int:
    """"每日一发"的当前连续天数（从今天或昨天往回数）。"""
    today = today or _dt.date.today()
    streak = 0
    # 允许今天还没发：从今天起，遇到第一个未完成且非今天则停。
    for i in range(0, 365):
        k = (today - _dt.timedelta(days=i)).isoformat()
        rec = days.get(k) or {}
        done = (rec.get("daily_ship") or {}).get("done")
        if done:
            streak += 1
        elif i == 0:
            # 今天还没发，不打断已有的连续记录
            continue
        else:
            break
    return streak


def ship_total(days: Dict[str, Any]) -> int:
    return sum(1 for rec in days.values() if (rec.get("daily_ship") or {}).get("done"))


def sparkline(values: List[Optional[float]]) -> str:
    """把一串数字渲染成迷你火花线（用于菜单文本）。"""
    blocks = "▁▂▃▄▅▆▇█"
    present = [v for v in values if v is not None]
    if not present:
        return "（暂无数据）"
    lo, hi = min(present), max(present)
    span = (hi - lo) or 1.0
    out = []
    for v in values:
        if v is None:
            out.append("·")
        else:
            idx = int((v - lo) / span * (len(blocks) - 1))
            out.append(blocks[idx])
    return "".join(out)
