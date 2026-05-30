"""用 py2app 把工具打包成原生 .app，可常驻菜单栏（开机自启可加到登录项）。

构建：
    pip install py2app rumps
    python setup.py py2app
产物在 dist/Taobi.app —— 双击即驻留菜单栏。

LSUIElement=True 让它只出现在菜单栏，不出现在 Dock。
"""

from setuptools import setup

APP = ["run_app.py"]
OPTIONS = {
    "argv_emulation": False,
    "plist": {
        "CFBundleName": "Taobi",
        "CFBundleDisplayName": "治疗准备型逃避",
        "CFBundleIdentifier": "com.taobi.menubar",
        "CFBundleVersion": "0.1.0",
        "CFBundleShortVersionString": "0.1.0",
        "LSUIElement": True,  # 只在菜单栏，不在 Dock
        "NSHumanReadableCopyright": "21 天刻意练习",
    },
    "packages": ["rumps", "taobi"],
}

setup(
    app=APP,
    name="Taobi",
    options={"py2app": OPTIONS},
    setup_requires=["py2app"],
)
