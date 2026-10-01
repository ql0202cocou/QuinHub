# QuinHub 文档中心

所有文档的唯一索引。修改代码前先读对应文档；修改了文档所描述的行为，必须回写对应文档。

> **项目当前状态**：第一期（对话核心）已完成，2026-10-01 完成 LobeUI 风格 UI 翻新；第二期方案为草案未立项（见 plan-v2.md）。
>
> 交接文档按时间倒序阅读：
> - [agents/2026-10-01-lobeui-refresh-notes.md](agents/2026-10-01-lobeui-refresh-notes.md)：**最新**，LobeUI token 体系 + `app/lib/ui/` 组件库 + 全页面换皮
> - [agents/2026-09-27-macos-setup-notes.md](agents/2026-09-27-macos-setup-notes.md)：macOS 开发环境与 iOS 构建链路
> - [agents/2026-09-23-v1-status-and-backlog.md](agents/2026-09-23-v1-status-and-backlog.md)：第一期盘点与 backlog

## AGENTS 文档

AI 代理首次接触仓库：`plan.md` → `decisions.md` → `engineering.md`，其余按需查阅。

| 文档 | 内容 | 什么时候读 |
|---|---|---|
| [plan.md](agents/plan.md) | 第一期方案：架构、目录结构、数据模型概览、功能范围、里程碑、验收标准 | 动任何代码前 |
| [plan-v2.md](agents/plan-v2.md) | 第二期方案（**草案，未立项**）：云同步服务端 + 助手体系的方向与取舍 | 评审第二期时 |
| [decisions.md](agents/decisions.md) | 技术决策记录（ADR）：选型结论与利弊（决策一~四） | 做选型 / 改架构前 |
| [protocol-mapping.md](agents/protocol-mapping.md) | OpenAI / Anthropic SSE 协议映射、错误码归一化、超时重试 | 碰网络 / 协议 / SSE |
| [engineering.md](agents/engineering.md) | 工程与协作约定：版本锁定、生成物策略、CI、日志红线、同步方向 | 碰 git / CI / 依赖 / 日志 |
| [data-model.md](agents/data-model.md) | SQLite DDL、索引、JSON schema、查询与迁移约定 | 碰数据库 |
| [pages-and-routing.md](agents/pages-and-routing.md) | 页面清单、路由表、交互细节（LobeHub 风格） | 碰 UI / 导航 |
| [release-checklist.md](agents/release-checklist.md) | 发布与合规 checklist | M5 / 发布前 |

## QuinHub 文档

项目完成后，所有 **QuinHub** 应用的文档均归档至本目录（`doc/`），供后续维护与查阅。

## 存放约定

- **AGENTS 文档**（方案、ADR、协议、工程约定等）放 `agents/`，新增文档先加入上方清单。
- **AGENTS 交接文档**（工作日志、进度交接、会话总结、issues、todo-list 等）也放 `agents/`，命名建议 `YYYY-MM-DD-<主题>.md`。
- **QuinHub 应用文档**（项目完成后的产品文档）放本目录（`doc/`）。

## 维护约定

1. 行为变更必须回写对应文档。
2. `decisions.md` 的历史结论不改；决策变更新增条目并标注替代关系。
