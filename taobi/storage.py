"""数据持久层 —— 纯 Python，可在任意平台测试。

负责把"治疗准备型逃避"练习的每日记录读写到本地 JSON 文件。
默认存储在 ~/.taobi/data.json，可通过环境变量 TAOBI_DATA_DIR 覆盖（测试用）。
"""

from __future__ import annotations

import datetime as _dt
import json
import os
from typing import Any, Dict, List


DATA_DIRNAME = ".taobi"
DATA_FILENAME = "data.json"


def data_dir() -> str:
    override = os.environ.get("TAOBI_DATA_DIR")
    if override:
        return override
    return os.path.join(os.path.expanduser("~"), DATA_DIRNAME)


def data_path() -> str:
    return os.path.join(data_dir(), DATA_FILENAME)


def today_key(today: _dt.date | None = None) -> str:
    return (today or _dt.date.today()).isoformat()


def _empty_day() -> Dict[str, Any]:
    """一天的空白记录骨架，对应五个固定动作 + 焦虑校准 + 启动延迟。"""
    return {
        # ① 决策秒杀：最多 3 个双向门决策
        "decisions": [],  # [{"text": str, "ts": iso}]
        # ② 五分钟启动
        "five_min_started": False,
        # ③ 每日一发（核心 rep）
        "daily_ship": {"done": False, "what": "", "below_standard": True},
        # ④ 留一个不完美
        "imperfection_left": False,
        # ⑤ 晚间复盘
        "evening_review": {"done": False, "note": ""},
        # 焦虑校准：发之前的预测 vs 发之后的实际（0-10）
        "calibration": {
            "pred_reaction": None,
            "pred_anxiety": None,
            "actual_reaction": None,
            "actual_anxiety": None,
            "anxiety_faded_min": None,
        },
        # 启动延迟（分钟）：从"决定做"到"真正动手"
        "startup_latency_min": None,
        # 启动延迟计时的内部状态（决定时间戳）
        "_decide_ts": None,
    }


class Store:
    """简单的 JSON 存储。所有写操作立即落盘。"""

    def __init__(self, path: str | None = None):
        self.path = path or data_path()
        self.data: Dict[str, Any] = self._load()

    # ---- 底层读写 ----
    def _load(self) -> Dict[str, Any]:
        if os.path.exists(self.path):
            try:
                with open(self.path, "r", encoding="utf-8") as f:
                    data = json.load(f)
            except (json.JSONDecodeError, OSError):
                data = {}
        else:
            data = {}
        data.setdefault("start_date", None)
        data.setdefault("parking_list", [])
        data.setdefault("days", {})
        return data

    def save(self) -> None:
        os.makedirs(os.path.dirname(self.path) or ".", exist_ok=True)
        tmp = self.path + ".tmp"
        with open(tmp, "w", encoding="utf-8") as f:
            json.dump(self.data, f, ensure_ascii=False, indent=2)
        os.replace(tmp, self.path)

    # ---- 开始日期 / 进度 ----
    def ensure_started(self, today: _dt.date | None = None) -> str:
        """首次运行时记录开始日期；返回 ISO 字符串。"""
        if not self.data.get("start_date"):
            self.data["start_date"] = today_key(today)
            self.save()
        return self.data["start_date"]

    def set_start_date(self, iso: str) -> None:
        self.data["start_date"] = iso
        self.save()

    def day_number(self, today: _dt.date | None = None) -> int:
        """从开始日期算起的第几天（第 1 天 = 开始当天）。"""
        start = self.data.get("start_date")
        if not start:
            return 1
        start_d = _dt.date.fromisoformat(start)
        cur = today or _dt.date.today()
        return (cur - start_d).days + 1

    def week_number(self, today: _dt.date | None = None) -> int:
        """第几周（1-4+），用于渐进暴露难度提示。"""
        n = self.day_number(today)
        return max(1, (n - 1) // 7 + 1)

    # ---- 单日记录 ----
    def day(self, key: str | None = None) -> Dict[str, Any]:
        key = key or today_key()
        days = self.data["days"]
        if key not in days:
            days[key] = _empty_day()
        else:
            # 向后兼容：补齐缺失字段
            base = _empty_day()
            for k, v in base.items():
                days[key].setdefault(k, v)
        return days[key]

    # ---- ① 决策秒杀 ----
    def add_decision(self, text: str, key: str | None = None) -> int:
        d = self.day(key)
        d["decisions"].append({"text": text.strip(), "ts": _dt.datetime.now().isoformat(timespec="seconds")})
        self.save()
        return len(d["decisions"])

    # ---- ② 五分钟启动 ----
    def set_five_min(self, value: bool, key: str | None = None) -> None:
        self.day(key)["five_min_started"] = bool(value)
        self.save()

    # ---- ③ 每日一发 ----
    def set_ship(self, done: bool, what: str = "", key: str | None = None) -> None:
        ship = self.day(key)["daily_ship"]
        ship["done"] = bool(done)
        if what:
            ship["what"] = what.strip()
        self.save()

    # ---- ④ 留一个不完美 ----
    def toggle_imperfection(self, key: str | None = None) -> bool:
        d = self.day(key)
        d["imperfection_left"] = not d["imperfection_left"]
        self.save()
        return d["imperfection_left"]

    # ---- ⑤ 晚间复盘 ----
    def set_review(self, note: str, key: str | None = None) -> None:
        r = self.day(key)["evening_review"]
        r["done"] = True
        r["note"] = note.strip()
        self.save()

    # ---- 焦虑校准 ----
    def set_prediction(self, reaction: float, anxiety: float, key: str | None = None) -> None:
        c = self.day(key)["calibration"]
        c["pred_reaction"] = reaction
        c["pred_anxiety"] = anxiety
        self.save()

    def set_actual(self, reaction: float, anxiety: float, faded_min: float | None = None, key: str | None = None) -> None:
        c = self.day(key)["calibration"]
        c["actual_reaction"] = reaction
        c["actual_anxiety"] = anxiety
        if faded_min is not None:
            c["anxiety_faded_min"] = faded_min
        self.save()

    # ---- 启动延迟（thermometer）----
    def mark_decided(self, key: str | None = None) -> None:
        self.day(key)["_decide_ts"] = _dt.datetime.now().isoformat(timespec="seconds")
        self.save()

    def mark_started(self, key: str | None = None) -> float | None:
        """记录"动手"时间，返回启动延迟（分钟）。若没先标记"决定"则返回 None。"""
        d = self.day(key)
        ts = d.get("_decide_ts")
        if not ts:
            return None
        decided = _dt.datetime.fromisoformat(ts)
        latency = (_dt.datetime.now() - decided).total_seconds() / 60.0
        latency = round(max(latency, 0.0), 1)
        d["startup_latency_min"] = latency
        d["_decide_ts"] = None
        self.save()
        return latency

    def has_pending_decide(self, key: str | None = None) -> bool:
        return bool(self.day(key).get("_decide_ts"))

    # ---- Parking List（防逃避：新点子丢这里）----
    def add_parking(self, text: str) -> int:
        self.data["parking_list"].append(
            {"text": text.strip(), "ts": _dt.datetime.now().isoformat(timespec="seconds")}
        )
        self.save()
        return len(self.data["parking_list"])

    def parking(self) -> List[Dict[str, Any]]:
        return self.data.get("parking_list", [])

    # ---- 进度统计 ----
    def completion(self, key: str | None = None) -> tuple[int, int]:
        """返回今日完成的固定动作数 / 总数（5）。"""
        d = self.day(key)
        items = [
            len(d["decisions"]) >= 3,
            d["five_min_started"],
            d["daily_ship"]["done"],
            d["imperfection_left"],
            d["evening_review"]["done"],
        ]
        return sum(1 for x in items if x), len(items)
