# Orion Assistant iOS 原型说明

## 1. 原型目标

本轮原型用于确认以下事项：

- 导航结构是否成立
- 助理是否作为核心入口
- 出差与费用是否应独立成一级导航
- 信息密度是否符合商务型工具定位

## 2. 视觉方向

- 风格关键词：冷静、可信、专业、偏系统原生
- 主色：深蓝 `#1D3D73`
- 强调色：青绿 `#2AA198`
- 背景：暖灰白 `#F5F3EE`
- 卡片：高对比浅底卡片，强调信息层级

## 3. 页面清单

- `home-dashboard.svg`
  - 今日总览
  - 待确认 AI 建议
  - 今日事件
  - 即将出发
- `assistant-chat.svg`
  - 对话区
  - 动作确认卡片
  - 快速输入建议
- `trip-planner.svg`
  - 单次出差详情
  - 时间轴
  - 预算与路线摘要
- `expense-center.svg`
  - 费用统计
  - 发票列表
  - 报销状态
- `travel-routing.svg`
  - 路线建议
  - 通勤时间比较
  - 出发提醒

## 4. 交互原则

- 所有 AI 动作都必须显式确认
- 所有系统写入前展示摘要差异
- 复杂信息采用卡片和时间线，不堆纯文本
- 重要动作固定在底部安全区域

## 5. 图标方向

- 采用罗盘星标 + 日历切角的组合
- 含义：方向感、规划、时间组织、私人助理
- 视觉要求：在小尺寸下仍保留识别度

## 6. 代码阶段建议

进入开发时，先从以下静态页面开始：

1. `TodayDashboardView`
2. `AssistantChatView`
3. `TripPlannerView`
4. `ExpenseCenterView`
5. `PermissionsOnboardingView`

