# Claudoctor

> Mac 菜单栏应用 — 自动监控并维护 Claude Code 会话健康。
> Keeps your Claude Code sessions healthy, right from the menu bar.

Claude Code 把每个会话存成 `~/.claude/projects/` 下的 `.jsonl` 文件。会话越聊越大，上下文被污染、响应变慢。Claudoctor 在菜单栏盯着这些文件，一眼看清健康度，自动归档臃肿会话，并能一键 **暂存并重启（Park & Restart）**——带着记忆开一个干净的新会话。

---

## 安装

需要 **macOS 13 (Ventura) 及以上**，并装好 Xcode 15+ / Swift 5.9+ 工具链。

```bash
git clone https://github.com/chjam12301-sys/Claude-Health-Tool.git
cd Claude-Health-Tool
./build-app.sh
open Claudoctor.app
```

`build-app.sh` 会用 `swift build -c release` 编译并打包出 `Claudoctor.app`。也可以直接用 Xcode 打开 `Package.swift` 编译。

**首次启动会请求两类权限：**

- **通知** — 归档完成、卫生提醒等。
- **自动化 / 辅助功能** — 暂存并重启时打开新终端运行 `claude`。
  - Terminal / iTerm / Ghostty：只需「自动化（Automation）」。
  - Warp：还需在 **系统设置 → 隐私与安全性 → 辅助功能** 勾选 Claudoctor（Warp 靠键入命令启动）。

图标出现在屏幕顶部菜单栏（不在 Dock），是一个听诊器 🩺。

---

## 它能做什么

### 一眼看清会话健康
菜单栏图标三态：健康 / 警告（≥5MB）/ 臃肿（≥10MB，阈值可调）。点开面板，所有项目的会话按大小排序，当前会话单独高亮，带大小进度条和警戒线。

### 自动归档
超过阈值的臃肿会话会自动搬到 `~/claude-archive/`（带时间戳前缀，**只移动不删除**）。正在写入的活跃会话会被跳过，不会动你手头的对话。触发时机：启动、定时、以及文件变化（FSEvents）。

### 暂存并重启（Park & Restart）
一键完成"无痛接力"：

1. **预检** — 先测一次网络可达性，不通就中止、原会话毫发无损。
2. **生成交接笔记** — 让 Claude 总结本次会话，写入项目的 `.notes/`。
3. **关掉旧会话** — 精确结束该项目目录下的旧 `claude` 进程。
4. **归档** — 把旧会话 `.jsonl` 移进 `~/claude-archive/`。
5. **开新会话** — 在你的首选终端打开新 `claude`，**开场自动读交接笔记接上进度**。

还有 **Auto 授权** 变体：新会话以 `claude --dangerously-skip-permissions` 启动，跳过所有权限确认（请谨慎）。

### 代理 / 连接（大陆友好）
GUI 应用读不到 `.zshrc` 的代理变量，Claudoctor 自己管：

- **自动检测** — 读取系统代理 + 探测常见本地端口（7890 / 7897 / 7993 / 1087 / 6152 …），用 `curl` 实测哪个能连通 `api.anthropic.com`。
- **手动配置** — 直接填 `http://host:port` 或 `socks5://host:port`。
- **禁用** — 直连。
- 给 `claude` 子进程注入代理环境变量，并可选在新终端命令前加 `export …`。
- 独立的「代理状态」Tab：连接状态、延迟、错误类型、一键重测。

### 还有
- **卫生提醒** — 长会话（60+ 轮）、闲置会话（7 天 / >3MB）的温和通知，24 小时去重。
- **多语言** — 跟随系统 / English / 中文，设置里即时切换。
- **开机自启** — 可选。
- **隐私优先** — 无遥测；除可选的代理可达性探测外，不发起任何网络请求；只读 `~/.claude/projects/` 和你指定的归档目录。

---

## 面板一览

| Tab | 内容 |
|---|---|
| **会话健康** | 状态总览 + 三张统计卡（项目数 / 最大会话 / 代理延迟）+ 当前会话卡片（进度条 + Park / Auto / 在访达显示）+ 其他会话列表 |
| **代理状态** | 连接状态 Hero + 详情（模式 / URL / 最后测试 / 错误类型）+ 立即重测 |

底栏：设置 · 打开 Claude Code · 更多（功能介绍 / 关于 / 退出）。

---

## 设置

左侧分类导航：阈值 · 自动归档 · 代理 · 终端 · 启动 · 语言 · 高级。改动即时生效，自动持久化。

- **阈值** — 警告 1–20 MB，臃肿 5–50 MB（臃肿必须 ≥ 警告 + 1）。
- **自动归档** — 开关、扫描周期（1–30 分钟）、归档目录。
- **终端** — 自动检测（Ghostty > Warp > iTerm > Terminal）或手动指定。
- **高级** — 暂存时跳过预检（不推荐）。

---

## 恢复已归档的会话

归档只是移动文件。想续接某个旧会话：把 `~/claude-archive/<时间戳>-<uuid>.jsonl` 改回 `<uuid>.jsonl` 移回对应的 `~/.claude/projects/<编码目录>/`，然后 `claude --resume <uuid>`。交接摘要在项目的 `.notes/` 里。

---

## 技术栈

Swift 5.9 · SwiftUI（MenuBarExtra）· FSEvents · UserNotifications · SMAppService。零第三方依赖，全部用系统框架。源码结构见 `Sources/Claudoctor/`（App / Models / Services / ViewModels / Views / Utilities）。

---

## License

MIT — 见 [LICENSE](LICENSE)。
