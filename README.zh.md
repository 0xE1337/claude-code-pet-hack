# Claude Code 宠物修改器

逆向分析并自定义你的 Claude Code 终端宠物（Buddy）。

> Claude Code 内置了一个隐藏宠物系统 — 每个账号基于 account ID 确定性生成一只伴侣。本项目记录了完整的生成算法，并提供一键修改脚本。

## 免责声明

本项目仅用于**学习和娱乐目的**，与 Anthropic 无任何关联。

- 本工具修改的是你本机安装的文件。**使用风险自负。**
- Claude Code 更新（`npm update -g @anthropic-ai/claude-code`）会**覆盖修改** — 每次更新后需要重新运行脚本。
- 宠物系统纯装饰，不影响 Claude Code 的任何实际功能。
- 虽然封号风险极低（所有修改都在本地，不会向服务器发送数据），但**不做任何保证**。
- 混淆后的函数/变量名会随版本变化，脚本使用特征匹配定位，但未来版本可能需要更新脚本。

**使用本工具即表示你接受所有后果。**

## 什么是 Claude Code Buddy？

在 Claude Code 中输入 `/buddy` 即可查看你的宠物。每只宠物有：

- **物种** — 18 种（龙、猫、鸭子、六角恐龙、蘑菇等）
- **稀有度** — Common (60%) → Uncommon (25%) → Rare (10%) → Epic (4%) → Legendary (1%)
- **闪光** — 1% 概率获得彩虹闪光特效
- **属性** — DEBUGGING, PATIENCE, CHAOS, WISDOM, SNARK（0-100）
- **帽子** — 皇冠、礼帽、巫师帽、光环、螺旋桨帽、毛线帽、小鸭子
- **眼睛** — `·` `✦` `×` `◉` `@` `°`

最稀有的组合是 **Shiny Legendary** — 万分之一的概率。

## 快速开始

```bash
# 一键修改：闪光传说龙 + 满属性
./patch.sh

# 自定义修改
./patch.sh --species dragon --rarity legendary --shiny --hat crown --eye "✦" --stats max

# 只改属性（保留原物种和稀有度）
./patch.sh --stats-only

# 恢复原始
./patch.sh --restore
```

## 生成原理

### 生成链路

```
Account UUID + "friend-2026-401"
    → FNV-1a 哈希
    → Mulberry32 伪随机种子
    → 确定性生成：物种、稀有度、眼睛、帽子、闪光、属性
```

同一账号永远生成同一只宠物。唯一的修改方式是 patch `cli.js` 中的生成函数。

### 稀有度表

| 等级 | 概率 | 基础属性 | 颜色 | 星级 |
|------|------|----------|------|------|
| Common | 60% | 5 | 灰色 | ★ |
| Uncommon | 25% | 15 | 绿色 | ★★ |
| Rare | 10% | 25 | 蓝色 | ★★★ |
| Epic | 4% | 35 | 紫色 | ★★★★ |
| Legendary | 1% | 50 | 金色 | ★★★★★ |

### 属性生成

每只宠物随机选一项为"强项"，一项为"弱项"：

- 强项：`基础 + 50 + random(0-30)`，上限 100
- 弱项：`基础 - 10 + random(0-15)`，下限 1
- 普通：`基础 + random(0-40)`

### 全部物种（18 种）

duck, goose, blob, cat, dragon, octopus, owl, penguin, turtle, snail, ghost, axolotl, capybara, cactus, robot, rabbit, mushroom, chonk

## 手动修改指南

详见 [README.md](./README.md#manual-patch-guide) 英文版的 Manual Patch Guide 部分。

## 已知限制

| 问题 | 影响 | 解决方式 |
|------|------|----------|
| Claude Code 更新覆盖 patch | 更新后修改丢失 | 更新后重新运行 `./patch.sh` |
| 混淆函数名随版本变化 | 脚本可能无法定位目标函数 | 脚本使用结构匹配；如失败需更新脚本 |
| 无服务端持久化 | 宠物数据仅在客户端生成 | 这反而是优点 — 没有服务端校验意味着没有封号风险 |

## 常见问题

**会封号吗？**

概率极低。宠物系统纯装饰，完全在客户端运行，不会向 Anthropic 服务器发送宠物数据进行校验。但不做保证 — 风险自负。

**更新后还在吗？**

不在。`npm update -g @anthropic-ai/claude-code` 或自动更新会覆盖 patch。更新后重新运行 `./patch.sh` 即可。

**更新后函数名变了怎么办？**

混淆后的函数名（如 `Zk_`、`Dk_`、`IG8`）每个版本都不同。脚本使用结构特征匹配（匹配函数体形状而非名字）来定位目标。如果大重构改变了函数结构，需要更新脚本。

**合法吗？**

本工具修改的是你自己机器上安装的本地文件，供个人使用，不分发修改后的 Anthropic 代码。但请自行查阅相关服务条款。

## License

MIT — 见 [LICENSE](./LICENSE)
