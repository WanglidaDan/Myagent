# Orion Assistant iOS 数据设计

## 1. 设计目标

- 以 iOS 原生数据层为中心，优先使用 `SwiftData`
- 将系统数据与应用数据分层，避免直接复制系统日历全量内容
- 将 AI 推理输出与可执行动作解耦
- 为后续离线能力、审计和同步预留空间

## 2. 数据架构概览

分为四层：

1. 系统接入层
   - `EventKit`
   - `MapKit`
   - `Vision / VisionKit`
   - `UserNotifications`
2. 领域模型层
   - App 自有实体
   - 外部系统引用实体
3. AI 动作层
   - 意图解析
   - 计划草案
   - 用户确认动作
4. 展示与统计层
   - 今日聚合
   - 行程聚合
   - 费用统计

## 3. 技术选型

- 本地数据库：`SwiftData`
- 临时缓存：内存 + 文件缓存
- 图片文件：`Application Support` 私有目录
- 敏感配置：`Keychain`
- OCR 结果：本地结构化存储
- 云端同步：后续可接 `CloudKit` 或自有后端，MVP 先不强依赖

## 4. 核心实体

### 4.1 UserProfile

用途：保存用户偏好和助理默认行为

字段：

- `id: UUID`
- `displayName: String`
- `homeCity: String?`
- `defaultDepartureLocation: String?`
- `defaultCalendarIdentifier: String?`
- `defaultReminderListIdentifier: String?`
- `workdayStartHour: Int`
- `workdayEndHour: Int`
- `travelPreference: TravelModePreference`
- `expenseCurrency: String`
- `createdAt: Date`
- `updatedAt: Date`

### 4.2 AssistantSession

用途：对话会话容器

字段：

- `id: UUID`
- `title: String`
- `contextType: SessionContextType`
- `createdAt: Date`
- `updatedAt: Date`
- `isPinned: Bool`

### 4.3 AssistantMessage

用途：保存用户消息、模型回复和动作结果

字段：

- `id: UUID`
- `sessionId: UUID`
- `role: MessageRole`
- `content: String`
- `structuredPayloadJSON: String?`
- `createdAt: Date`

### 4.4 ActionDraft

用途：承接 LLM 输出的待确认动作，不直接写系统

字段：

- `id: UUID`
- `sessionId: UUID`
- `actionType: DraftActionType`
- `title: String`
- `summary: String`
- `payloadJSON: String`
- `status: DraftStatus`
- `sourceMessageId: UUID?`
- `createdAt: Date`
- `confirmedAt: Date?`

### 4.5 CalendarEventLink

用途：保存 App 内记录与系统日历事件的映射

字段：

- `id: UUID`
- `externalEventIdentifier: String`
- `calendarIdentifier: String`
- `titleSnapshot: String`
- `startDateSnapshot: Date`
- `endDateSnapshot: Date`
- `tripId: UUID?`
- `source: EventSourceType`
- `lastSyncedAt: Date`

说明：

- 不完整复制系统事件，只保存关联引用和快照
- 若系统事件被删除，可在同步时标记为失效

### 4.6 ReminderLink

用途：保存 App 与系统提醒事项映射

字段：

- `id: UUID`
- `externalReminderIdentifier: String`
- `listIdentifier: String`
- `titleSnapshot: String`
- `dueDateSnapshot: Date?`
- `tripId: UUID?`
- `lastSyncedAt: Date`

### 4.7 TripPlan

用途：出差或复杂行程主容器

字段：

- `id: UUID`
- `title: String`
- `destinationCity: String`
- `startDate: Date`
- `endDate: Date`
- `status: TripStatus`
- `objective: String?`
- `budgetAmount: Decimal?`
- `currency: String`
- `notes: String?`
- `createdAt: Date`
- `updatedAt: Date`

### 4.8 TripSegment

用途：行程子节点，可表示会议、交通、住宿、自由安排

字段：

- `id: UUID`
- `tripId: UUID`
- `segmentType: TripSegmentType`
- `title: String`
- `startDate: Date`
- `endDate: Date`
- `locationName: String?`
- `address: String?`
- `calendarEventLinkId: UUID?`
- `reminderLinkId: UUID?`
- `sortOrder: Int`

### 4.9 ExpenseItem

用途：费用明细

字段：

- `id: UUID`
- `tripId: UUID?`
- `category: ExpenseCategory`
- `merchantName: String?`
- `amount: Decimal`
- `currency: String`
- `expenseDate: Date`
- `city: String?`
- `paymentMethod: PaymentMethod?`
- `reimbursementStatus: ReimbursementStatus`
- `invoiceRecordId: UUID?`
- `notes: String?`
- `createdAt: Date`
- `updatedAt: Date`

### 4.10 InvoiceRecord

用途：发票/票据原始记录

字段：

- `id: UUID`
- `documentType: InvoiceDocumentType`
- `imageLocalPath: String`
- `thumbnailLocalPath: String?`
- `ocrRawText: String`
- `merchantName: String?`
- `invoiceDate: Date?`
- `totalAmount: Decimal?`
- `taxAmount: Decimal?`
- `invoiceCode: String?`
- `city: String?`
- `confidenceScore: Double`
- `reviewStatus: ReviewStatus`
- `createdAt: Date`
- `updatedAt: Date`

### 4.11 RoutePlan

用途：保存一次路线建议与估算结果

字段：

- `id: UUID`
- `relatedTripSegmentId: UUID?`
- `originName: String`
- `destinationName: String`
- `departureDate: Date`
- `recommendedLeaveAt: Date?`
- `transportMode: TransportMode`
- `estimatedDurationMinutes: Int`
- `distanceMeters: Double?`
- `routeSummary: String?`
- `createdAt: Date`

## 5. 关键枚举

- `SessionContextType`
  - `general`
  - `tripPlanning`
  - `expenseManagement`
- `DraftActionType`
  - `createCalendarEvent`
  - `createReminder`
  - `createTrip`
  - `createExpense`
  - `generateRoute`
- `DraftStatus`
  - `pending`
  - `confirmed`
  - `cancelled`
  - `failed`
- `TripStatus`
  - `draft`
  - `active`
  - `completed`
  - `archived`
- `ExpenseCategory`
  - `transport`
  - `hotel`
  - `meal`
  - `entertainment`
  - `office`
  - `other`
- `ReimbursementStatus`
  - `unfiled`
  - `submitted`
  - `processing`
  - `reimbursed`
  - `rejected`
- `TransportMode`
  - `walking`
  - `driving`
  - `transit`
  - `taxi`

## 6. 关系设计

- `UserProfile` 1:many `AssistantSession`
- `AssistantSession` 1:many `AssistantMessage`
- `AssistantSession` 1:many `ActionDraft`
- `TripPlan` 1:many `TripSegment`
- `TripPlan` 1:many `ExpenseItem`
- `InvoiceRecord` 1:1 or 1:many `ExpenseItem`
- `TripSegment` 0..1:1 `CalendarEventLink`
- `TripSegment` 0..1:1 `ReminderLink`
- `TripSegment` 0..many `RoutePlan`

## 7. 同步策略

### 7.1 日历同步

- 首次授权后读取用户选择的日历列表
- App 只主动维护自己创建或映射过的事件
- 通过 `externalEventIdentifier` 做增量校验
- 冲突处理优先提示用户，而不是静默覆盖

### 7.2 提醒事项同步

- 读取目标提醒清单
- 对已映射提醒做变更检测
- 若系统项被删除，App 端标记失联并展示修复入口

### 7.3 发票文件管理

- 原图与缩略图单独存储
- 数据库存路径引用，不存二进制大对象
- 删除费用时不自动删原图，避免误删审计材料

## 8. AI 动作协议

LLM 不直接输出业务文本，而是输出结构化动作草案：

```json
{
  "intent": "create_trip",
  "confidence": 0.94,
  "requires_confirmation": true,
  "drafts": [
    {
      "type": "create_calendar_event",
      "title": "客户拜访",
      "startDate": "2026-03-31T10:00:00+08:00",
      "endDate": "2026-03-31T11:30:00+08:00",
      "location": "杭州滨江区"
    }
  ]
}
```

动作层职责：

- 校验时间和地点合法性
- 绑定默认日历和提醒清单
- 执行前生成确认卡片
- 执行后落日志并刷新映射关系

## 9. 查询视图

建议为 UI 层准备聚合查询对象：

- `TodayDashboardViewModel`
  - 今日事件
  - 即将到期提醒
  - 待确认 AI 动作
  - 最近费用
- `TripDetailViewModel`
  - 行程段
  - 关联费用
  - 预算使用率
  - 路线建议
- `ExpenseCenterViewModel`
  - 月度汇总
  - 待提交费用
  - 待人工复核票据

## 10. 隐私与安全

- 发票图像使用文件级保护
- 用户偏好与模型密钥分离存储
- 日历/提醒仅读取必要字段
- AI 上下文发送前做字段裁剪，默认不上传完整历史
- 每次执行系统写入动作保留本地审计日志

## 11. 代码阶段建议模块划分

- `App`
- `Core`
- `Data`
- `Integrations`
- `Features/Today`
- `Features/Assistant`
- `Features/Trips`
- `Features/Expenses`
- `Features/Settings`

