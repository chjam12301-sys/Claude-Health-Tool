#!/usr/bin/env bash
# 一键运行（开发模式）：建虚拟环境、装依赖、启动菜单栏 App。
set -euo pipefail
cd "$(dirname "$0")"

if [ ! -d ".venv" ]; then
  python3 -m venv .venv
fi
# shellcheck disable=SC1091
source .venv/bin/activate
pip install --quiet --upgrade pip
pip install --quiet -r requirements.txt

echo "启动中… 看屏幕右上角菜单栏的 🔥"
python run_app.py
