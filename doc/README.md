# QuinHub 文档中心

所有文档的唯一索引。修改代码前先读对应文档；修改了文档所描述的行为，必须回写对应文档。

## AGENTS 文档

AI 代理首次接触仓库：`plan.md` → `decisions.md` → `engineering.md`，其余按需查阅。

| 文档 | 内容 | 什么时候读 |
|---|---|---|
| [plan.md](agents/plan.md) | 第一期方案：架构、目录结构、数据模型概览、功能范围、里程碑、验收标准 | 动任何代码前 |
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
