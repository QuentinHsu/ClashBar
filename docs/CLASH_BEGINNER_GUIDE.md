# CatBar 的 Clash / mihomo 新手指南

这是一份面向 **Clash / mihomo 新手** 的入门说明，帮助你在 `CatBar` 中完成最基本的可用配置。

本文基于 [`docs/mihomo-template.yml`](./mihomo-template.yml) 的结构整理而来，帮你以最小的步骤把 CatBar 跑通。

如果你以前从来没碰过 Clash，也不用慌。你现在看到的不是火箭发射面板，只是一份比较长的 YAML 而已 🙂

## 先理解 CatBar 需要什么

`CatBar` 当前发布的是 **no-core** 版本，也就是：

- 应用本体只负责菜单栏面板和配置管理；
- **不会内置 mihomo 核心**；
- 你需要自己准备 `mihomo` 可执行文件。

`CatBar` 的工作目录如下：

- 根目录：`~/Library/Application Support/catbar/`
- 核心目录：`~/Library/Application Support/catbar/core/`
- 配置目录：`~/Library/Application Support/catbar/config/`
- 日志目录：`~/Library/Application Support/catbar/logs/`

其中最重要的两个目录是：

1. 把 `mihomo` 放到 `~/Library/Application Support/catbar/core/`
2. 把你的 `.yaml` / `.yml` 配置放到 `~/Library/Application Support/catbar/config/`

## 你需要准备的东西

开始前，请确认你有下面这些材料：

- 已安装 `CatBar`
- 一个可运行的 `mihomo` 二进制文件
- 一条 **Clash / mihomo 兼容订阅链接**，或者你自己维护的节点配置

如果你只有“机场订阅链接”，通常也足够了；后面的示例配置会教你怎么把订阅挂进模板里。

## 最短路径：让 CatBar 先跑起来

### 1. 放入 mihomo 核心

将 `mihomo` 文件放到：

`~/Library/Application Support/catbar/core/mihomo`

如果是手动下载的二进制，记得确认它具有执行权限。

### 2. 准备配置文件

你可以任选一种方式：

- **方式 A：导入本地配置文件**
  - 把 `.yaml` / `.yml` 文件放进 `~/Library/Application Support/catbar/config/`
  - 或者在 `CatBar` 的 `Proxy` 页使用 **Import Local Config** 导入
- **方式 B：导入远程订阅链接**
  - 在 `CatBar` 的 `Proxy` 页使用 **Import Subscription Link**
  - 应用会把远程配置下载到本地配置目录里

### 3. 在 CatBar 中切换配置

在 `Proxy` 页的快速操作里，你会看到这些入口（不同语言环境下名称可能略有差异）：

- `Switch Config`：切换当前配置
- `Import Local Config`：导入本地配置
- `Import Subscription Link`：导入远程订阅
- `Update Subscription Links`：更新远程订阅
- `Reload Config List`：刷新配置列表
- `Show in Finder`：在 Finder 打开当前配置目录

### 4. 打开系统代理

当配置已经加载、核心正常启动后，再打开系统代理。这样浏览器和大多数应用才会真正走 `mihomo`。

如果开关打不开，优先检查：

- `mihomo` 是否存在于 `core/` 目录
- 配置文件是否是合法 YAML
- 订阅链接是否可访问

## 新手先认识这几个配置块

你不需要一次看懂全部字段，只先记住下面几个模块：

### 顶部基础项

这部分决定监听端口、模式、日志级别等：

- `mixed-port`：HTTP / SOCKS 混合端口
- `allow-lan`：是否允许局域网访问
- `mode: rule`：按规则分流
- `external-controller`：供面板或外部工具连接的控制地址

### `proxy-providers`

这是“**订阅来源**”。

如果你使用机场订阅，通常会把订阅地址放在这里，由 `mihomo` 定时拉取并生成节点列表。

### `proxy-groups`

这是“**怎么选节点**”。

例如：

- `Sub`：展示订阅里的所有节点
- `Auto Sub`：自动测速选择延迟较低的节点
- `Global Proxy`：手动决定用 `Sub` 还是 `Auto Sub`
- `Final`：最终兜底策略

### `rule-providers` 与 `rules`

这是“**流量怎么分流**”。

常见思路是：

- 国内 / 局域网直连
- GitHub、Google、OpenAI、Telegram 等走代理
- 最后没命中的流量走 `Final`

## 使用提供的模板起步

我们为你内置了一份功能完备的基础模板：[`docs/mihomo-template.yml`](./mihomo-template.yml)。

> 使用前请至少替换里面的占位符：
>
> - `https://www.mihomo.me/api/v1/proxies?secret=xxx`：将其替换为你真实的 Clash / mihomo 订阅链接（注意模板中有 `sub` 和 `sub2` 两个订阅提供器，请按需修改或删除）。
> - 如有需要，可把顶部的 `allow-lan: true` 改成 `false` 以提升本地安全性。

### 这份模板怎么用？

你有两种常见用法：

**玩法 1：保存为本地配置再导入**

1. 将 `docs/mihomo-template.yml` 复制到其他地方
2. 使用文本编辑器打开，将里面的订阅链接替换为你自己的
3. 把它放到 `CatBar` 的配置目录 `~/Library/Application Support/catbar/config/`，可以改个符合你心意的名字，比如 `my-config.yaml`
4. 打开 `CatBar` → `Proxy` → `Switch Config`，选择这份配置即可加载运行

**玩法 2：先放本地，后续仍用远程订阅更新**

如果你希望长期维护同一个模板，但节点由机场或服务商提供的订阅自动更新，那么就：

- 保留这份 YAML 作为你的主配置
- 把订阅链接填在 `proxy-providers.sub.url` 中
- 后续主要更新订阅链接里的节点列表本身，而不必频繁修改你的主配置结构

这也是很多人最终会采用的方式：**主配置负责分流策略，订阅负责更新节点内容**。

## 新手最容易踩的坑

### 1. 只导入了 CatBar，但没有 mihomo 核心

症状：界面能打开，但代理功能不起作用。

排查：检查 `~/Library/Application Support/catbar/core/mihomo` 是否存在。

### 2. 订阅链接不是 Clash / mihomo 兼容格式

症状：配置导入失败，或者导入成功但没有节点。

排查：确认订阅链接输出的是 **Clash YAML**，而不是其他客户端专用格式。

### 3. YAML 缩进错了

症状：核心启动失败、配置无法选择、规则不生效。

排查：YAML 对缩进非常敏感，建议使用支持 YAML 高亮的编辑器修改。

### 4. `proxy-providers` 下载成功，但规则没走代理

症状：节点列表有了，但 GitHub / OpenAI 等仍直连。

排查：重点检查：

- `proxy-groups` 里是否存在对应策略组
- `rules` 是否把目标流量分到正确策略组
- 最后的 `MATCH` 是否指向了 `Final`

### 5. `allow-lan: true` 带来额外暴露面

如果你只是自己在 Mac 上用，建议先设为 `false`。这样更安全，也更符合“先跑起来再逐步开放”的思路。

## 推荐的新手成长路径

如果你刚接触 Clash / mihomo，建议按这个顺序来：

1. **先跑通模板配置**：确认 `CatBar + mihomo + 填好订阅的模板` 能正常工作
2. **再理解代理组**：学会 `select`、`url-test`、`DIRECT`、`REJECT` 等选项以及如何给节点分类
3. **再理解规则**：知道哪些站点应该直连，哪些应该代理
4. **最后再折腾高级项**：如 `sniffer`（域名嗅探）、更细致的各种 DNS 策略、多配置源组装、更多规则集

一句话概括就是：**先把路打通，再追求优雅。**

## 一句话总结

对于 `CatBar` 新手来说，最关键的不是一上来就写出最复杂的配置，而是先完成这三个动作：

- 放好 `mihomo` 核心
- 准备一份能被 `CatBar` 读取的 YAML 配置
- 在 `Proxy` 页里切换配置并开启系统代理/Tun 模式

当这三步跑通后，你就已经跨过了最难的第一道门槛。后面再慢慢给规则和策略组“加戏”，就从容多了。