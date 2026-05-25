# Mole 多端通用可视化页面实施计划

## 1. 项目现状与约束（基线）

### 1.1 当前技术结构
- 主程序入口是 Bash 脚本 `mole`，负责命令分发与子命令生命周期管理（`clean / analyze / status / optimize ...`）。
- `analyze` 与 `status` 已由 Go 实现交互式 TUI（终端界面），其余能力主要是 Bash 子脚本。
- 当前展示层与采集/执行逻辑耦合较高：
  - `cmd/status` 中包含指标采集（CPU/内存/网络等）与终端渲染逻辑。
  - `cmd/analyze` 中目录扫描、删除动作、渲染逻辑都在同一应用内。

### 1.2 业务能力资产（可复用）
- 可复用能力面：系统体检、磁盘分析、清理计划、优化任务、卸载检测等。
- 可复用数据面：`status` 快照、`analyze` 扫描结果、`clean/purge` 的候选清单与风险提示。
- 命令资产丰富，可作为“后台执行引擎”，Web/桌面/移动端只需做可视化和交互编排。

### 1.3 多端目标定义
建议把“多端通用”定义为统一的产品能力矩阵（避免首期目标过大）：
- **P0（必须）**：Web（桌面浏览器）+ 桌面壳（Tauri/Electron 二选一）。
- **P1（应当）**：移动端只做“远程查看 + 审批执行”（不做本地深度清理）。
- **P2（可选）**：云同步、跨设备策略模板、团队版策略下发。

---

## 2. 目标架构（推荐）

### 2.1 总体分层
采用 **Core Engine + API Gateway + Multi-Client UI**：

1. **Core Engine（本地执行层）**
   - 保留现有 Bash/Go 能力，新增统一“任务执行 API 适配层”。
   - 以“任务”作为最小执行单位（扫描、预览、执行、回滚信息、日志）。

2. **Gateway（本地服务层）**
   - 新增常驻本地服务（建议 Go）：
     - REST（同步查询）+ WebSocket/SSE（实时进度）。
     - 统一鉴权（本机 token + session）。
     - 统一任务编排、并发控制、日志聚合。

3. **UI（多端展示层）**
   - Web 前端（React + TypeScript + 组件库）。
   - 桌面端（Tauri 首选，体积更小、权限更贴近系统工具）。
   - 移动端（React Native/Flutter）复用同一 OpenAPI + 设计系统。

### 2.2 为什么先做“本地 API 化”
- 当前 CLI 已稳定，直接重写风险大；先 API 化可保留成熟逻辑。
- UI 可快速迭代，而清理/优化逻辑保持原子性与兼容性。
- 后续 TUI 也可以消费同一 API，逐步收敛为统一后端。

### 2.3 核心数据模型（先定协议再做 UI）
- `SystemSnapshot`：CPU/内存/磁盘/网络/温度/健康分。
- `ScanTask`：`queued/running/success/failed/cancelled` + 进度 + 统计。
- `CleanupCandidate`：路径、大小、类别、风险等级、建议动作。
- `ExecutionReport`：释放空间、失败项、需要手动处理项、耗时。
- `PolicyProfile`：白名单、路径规则、调度策略、阈值告警。

---

## 3. 产品范围拆解（按端）

### 3.1 Web/桌面（首发重点）
1. **总览仪表盘**
   - 健康分趋势、容量趋势、最近清理收益、异常告警。
2. **磁盘分析页**
   - 目录树 + Treemap + TopN 大文件 + 时间维度过滤。
3. **清理中心**
   - 扫描结果分组（系统/应用/开发/浏览器）。
   - 勾选执行、风险提示、模拟执行（dry-run）。
4. **优化中心**
   - 任务开关化（可审计），展示副作用说明。
5. **日志与审计**
   - 可追溯任务历史，导出报告。

### 3.2 移动端（第二阶段）
- 只提供：状态查看、告警、远程触发、审批确认。
- 不提供：高风险本地删除、复杂路径选择器、系统权限管理。

---

## 4. 12 周落地路线图（可执行）

## 阶段 A（第 1-2 周）：技术梳理与契约冻结
- 产出：能力清单、接口草案、错误码规范、权限边界文档。
- 任务：
  - 对现有命令做“输入/输出/副作用”盘点。
  - 定义统一任务状态机与日志格式。
  - 冻结 OpenAPI v1（最小字段可扩展）。
- 验收：
  - API 合同评审通过。
  - 能用 mock 数据驱动前端原型。

## 阶段 B（第 3-5 周）：Gateway MVP
- 产出：本地服务进程（Go）+ 任务调度 + SSE/WebSocket。
- 任务：
  - 实现 `/health` `/status/snapshot` `/tasks` `/tasks/{id}`。
  - 封装 CLI 调用器（stdout/stderr 结构化解析）。
  - 增加并发限制（如同类任务互斥）。
- 验收：
  - 能稳定跑通 status 拉流与 analyze 扫描进度。
  - 异常中断可恢复，日志可追踪。

## 阶段 C（第 6-8 周）：Web 前端 Beta
- 产出：可用 Web 控制台。
- 任务：
  - 完成仪表盘、扫描页、清理执行页。
  - 加入统一 Design Token（色彩、间距、图表规范）。
  - 引入状态管理（TanStack Query + Zustand/Redux）。
- 验收：
  - 关键链路：扫描 -> 预览 -> 执行 -> 报告 全通。
  - 首屏 < 2s（本地）、实时数据刷新 < 1s 延迟。

## 阶段 D（第 9-10 周）：桌面封装与权限治理
- 产出：Tauri 桌面版。
- 任务：
  - 进程托管（拉起本地 Gateway、守护重启）。
  - 系统权限向导（Full Disk Access、sudo 场景提示）。
  - 打包签名与自动更新策略。
- 验收：
  - 安装后 3 分钟内可完成首次扫描与清理预览。

## 阶段 E（第 11-12 周）：稳定性与发布
- 产出：Release Candidate + 灰度发布计划。
- 任务：
  - 回归测试、性能压测、失败注入（权限拒绝/磁盘繁忙）。
  - 关键指标看板（崩溃率、任务成功率、平均耗时）。
  - 文档与迁移指南（CLI 用户升级路径）。
- 验收：
  - 任务成功率 > 98%，严重故障可回滚。

---

## 5. 研发实施细化（工程视角）

### 5.1 代码组织建议
- `cmd/gateway/`：本地 API 服务入口。
- `internal/orchestrator/`：任务编排与状态机。
- `internal/adapters/cli/`：对 Bash/Go 子命令适配。
- `web/`：前端项目。
- `desktop/`：Tauri 壳层。

### 5.2 与现有模块的衔接策略
- `mo status`：优先抽取指标采集层，渲染层保留。
- `mo analyze`：先包装成任务型接口，后续再考虑深度重构。
- `mo clean/optimize/purge`：先保证 dry-run 与 execute 双接口一致。

### 5.3 API 设计样例（建议）
- `GET /api/v1/status/snapshot`
- `POST /api/v1/tasks/analyze`
- `POST /api/v1/tasks/clean:dry-run`
- `POST /api/v1/tasks/clean:execute`
- `GET /api/v1/tasks/{taskId}/events`
- `GET /api/v1/reports/{reportId}`

---

## 6. 非功能与质量门禁

### 6.1 安全
- 所有删除动作默认二次确认（可配置跳过但需显式开关）。
- 高风险路径（系统关键目录）强制保护。
- 前端不直接持有 sudo，统一由本地服务受控提权。

### 6.2 性能
- 扫描分页 + 增量流式返回，避免一次性大 JSON。
- 大目录采用优先级队列（先返回 TopN 热点节点）。
- 任务日志按级别采样，避免 UI 渲染阻塞。

### 6.3 可观测性
- 统一 TraceID：一次任务全链路可跟踪。
- 指标：任务耗时 P50/P95、失败类型分布、磁盘 I/O 峰值。
- 崩溃与 panic 自动上报（可本地匿名开关）。

---

## 7. 风险清单与预案

1. **权限模型复杂（macOS 限制）**
   - 预案：权限探测前置，给出逐步引导与降级能力。
2. **CLI 输出不稳定导致解析脆弱**
   - 预案：逐步引入结构化输出（JSON 模式）替代文本解析。
3. **多端需求膨胀**
   - 预案：冻结 P0 功能集，移动端严格只读 + 远程触发。
4. **实时数据导致前端性能问题**
   - 预案：统一节流（250ms/500ms）与虚拟列表。

---

## 8. 团队分工建议（最小 6 人）
- 后端/系统（2）：Gateway、任务编排、权限与执行适配。
- 前端（2）：Web 控制台、图表与状态管理。
- 客户端（1）：Tauri 打包、升级、系统桥接。
- QA/测试（1）：自动化回归、兼容性与风险场景。

若资源更少（3-4 人），建议只做：Gateway MVP + Web 单端。

---

## 9. 里程碑交付物清单
- 架构设计文档（ADR）
- OpenAPI v1 + 事件协议
- Web Beta 可运行包
- 桌面 RC 安装包
- 回归报告与发布手册

---

## 10. 你可以马上开始的“第一周执行清单”
1. 盘点现有命令输入/输出（status/analyze/clean/optimize/purge）。
2. 先写 OpenAPI 草案与任务状态机图。
3. 用 mock server 跑出 Web 原型（仪表盘 + 扫描列表）。
4. 实现 Gateway 的 `/health` 与 `/status/snapshot`。
5. 建立日志规范和错误码基线（后续全模块统一）。

> 建议策略：**先 API 契约，后 UI 细节；先稳定任务链路，后做视觉增强。**

---

## 11. 开工前必须补齐的交付物（Definition of Ready）

在进入编码前，建议把以下 8 项作为“开工门槛”，避免范围漂移与返工：

1. **MVP PRD（2-3 页）**
   - 目标用户、核心场景、非目标、成功指标。
2. **能力边界清单（Must/Should/Could）**
   - 逐页逐功能列清楚，避免“默认都要做”。
3. **OpenAPI v1（字段级）**
   - 请求/响应 schema、错误码、幂等语义、分页规则。
4. **事件流协议 v1（SSE/WebSocket）**
   - 事件类型、序列号、重连、去重与回放窗口。
5. **权限矩阵与提权策略**
   - 功能到权限映射、拒绝授权降级路径。
6. **设计系统 v1**
   - Design Token、组件清单、状态规范（loading/error/empty）。
7. **测试策略 v1**
   - 单元/契约/E2E 比例、数据集、CI 门禁。
8. **发布治理机制**
   - RACI、迭代节奏、风险升级路径。

---

## 12. MVP 范围补齐（建议可直接评审）

### 12.1 P0 功能清单（首发）

**Must（必须）**
- 仪表盘：健康分、CPU/内存/磁盘/网络实时状态。
- 扫描中心：发起扫描、查看进度、查看 TopN 占用。
- 清理中心：dry-run 预览、勾选执行、执行报告。
- 任务中心：任务状态、日志、失败原因、重试。
- 安全保护：高风险路径保护 + 二次确认。

**Should（应该）**
- 历史趋势图（7d/30d）。
- 任务筛选（类型/状态/时间）。
- 报告导出（JSON/文本）。

**Could（可选）**
- 自定义规则模板。
- 移动端远程只读看板。

### 12.2 P0 非目标（明确不做）
- 首发不做云同步与多设备账号体系。
- 首发不做移动端本地深度清理。
- 首发不做跨平台（Windows/Linux）系统级执行能力。

### 12.3 页面级验收标准（DoD）
- **仪表盘**：首屏渲染 < 2s（本地），实时刷新延迟 < 1s。
- **扫描页**：可见任务进度、预计剩余、可取消。
- **清理页**：执行前可预览候选项与风险等级，执行后生成报告。
- **任务页**：失败任务可定位到错误码与原始日志片段。

---

## 13. API 与事件协议补齐（字段级草案）

### 13.1 错误码与响应约定

统一错误响应：

```json
{
  "error": {
    "code": "PERMISSION_DENIED",
    "message": "Full Disk Access is required",
    "traceId": "trc_01J...",
    "retryable": false
  }
}
```

建议错误码最小集合：
- `INVALID_ARGUMENT`
- `UNAUTHORIZED`
- `PERMISSION_DENIED`
- `RESOURCE_NOT_FOUND`
- `CONFLICT`
- `RATE_LIMITED`
- `INTERNAL_ERROR`
- `DEPENDENCY_FAILED`

### 13.2 关键接口 schema（最小字段）

`GET /api/v1/status/snapshot`

```json
{
  "timestamp": "2026-01-01T10:00:00Z",
  "healthScore": 92,
  "cpu": { "usage": 45.2, "tempC": 58.1 },
  "memory": { "usedPercent": 58.4, "usedGB": 14.2, "totalGB": 24.0 },
  "disk": { "usedPercent": 67.2, "freeGB": 156.3 },
  "network": { "downMBps": 0.54, "upMBps": 0.02 }
}
```

`POST /api/v1/tasks/clean:dry-run`

```json
{
  "scope": ["system", "apps", "dev", "browser"],
  "excludeRules": ["~/Library/Caches/JetBrains"],
  "riskThreshold": "medium"
}
```

返回：

```json
{
  "taskId": "tsk_01J...",
  "status": "queued"
}
```

### 13.3 事件流协议（SSE 示例）

事件头：
- `event`: `task.progress | task.log | task.completed | task.failed`
- `id`: 全局递增序列号（用于断线续传）

事件体示例：

```json
{
  "taskId": "tsk_01J...",
  "status": "running",
  "progress": 63,
  "step": "scan.browser.cache",
  "traceId": "trc_01J...",
  "at": "2026-01-01T10:00:12Z"
}
```

重连策略：
- 客户端带 `Last-Event-ID` 重连。
- 服务端保留最近 10 分钟事件缓冲（可配置）。

### 13.4 任务状态机（统一）

`queued -> running -> success`

`queued -> running -> failed`

`queued -> running -> cancelled`

约束：
- 仅 `queued/running` 允许取消。
- 同一资源域（例如 clean execute）默认互斥。

---

## 14. 权限矩阵与安全补齐

| 功能 | 所需权限 | 未授权行为 | UI 提示 |
| --- | --- | --- | --- |
| 系统缓存扫描 | Full Disk Access | 仅扫描用户可访问目录 | 引导授权并说明影响 |
| 高风险清理执行 | sudo | 降级为 dry-run | 显示“需管理员授权” |
| 网络/硬件指标 | 系统命令访问 | 显示部分指标缺失 | 标记数据不完整 |

高风险动作安全阈值：
- 默认二次确认。
- 关键目录硬保护（不可删除）。
- 批量删除上限阈值（例如单次 > 20GB 再确认）。

审计字段最小集：
- `who`（本机用户）
- `when`（时间戳）
- `what`（动作 + 目标）
- `result`（成功/失败 + 错误码）
- `traceId`

---

## 15. 测试与发布治理补齐

### 15.1 测试分层
- **单元测试**：状态机、解析器、规则过滤。
- **契约测试**：OpenAPI schema 与 mock 对齐。
- **E2E 测试**：扫描 -> 预览 -> 执行 -> 报告。

### 15.2 测试数据集
- 大目录（> 500k 文件）样本。
- 权限拒绝样本。
- 高风险路径样本（应被拒绝）。
- 磁盘空间紧张样本。

### 15.3 CI 门禁（建议）
- API schema lint 必过。
- 关键 E2E 冒烟必过。
- 变更影响说明（risk note）必填。

### 15.4 发布治理（RACI）
- **A（Approve）**：Tech Lead / Product Owner
- **R（Responsible）**：Gateway Owner / Frontend Owner
- **C（Consulted）**：Security / QA
- **I（Informed）**：文档与社区维护者

---

## 16. 首周可执行 Backlog（按天）

### Day 1
- 输出 MVP PRD v1（含非目标、成功指标）。
- 输出 P0 页面清单与流程图。

### Day 2
- 输出 OpenAPI v1 草案。
- 输出错误码字典与示例响应。

### Day 3
- 输出事件协议 v1（SSE/WebSocket）。
- 完成任务状态机评审。

### Day 4
- 输出权限矩阵与提权交互草图。
- 确认高风险路径硬保护策略。

### Day 5
- 搭建 Gateway skeleton（`/health`、`/status/snapshot`、`/tasks`）。
- 前端接入 mock + 真接口双模式。

### 周五验收清单
- [ ] 文档齐全并通过跨角色评审（产品/后端/前端/QA）
- [ ] 有可运行 demo（至少展示状态快照 + 任务列表）
- [ ] 风险与阻塞项形成 issue 清单并排期
