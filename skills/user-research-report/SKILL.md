---
name: user-research-report
description: >
  用户调研/舆情分析报告的标准输出模板。当进行任何平台的用户调研、舆情分析、用户反馈分析时，
  必须在生成报告前调用此 skill 获取模板格式。
  触发词：分析用户反馈、舆情分析、用户调研、小红书分析、平台调研、保存调研报告、写入调研目录。
  IMPORTANT: 此 skill 应在数据收集完成后、生成报告前调用，而非仅在"保存"时才调用。
---

# 用户调研报告

## 使用时机

**MUST** 在以下场景中调用此 skill：
1. 用户要求"分析"/"调研"/"舆情分析"某平台的用户反馈 → 数据收集完毕后、写报告前调用
2. 用户要求"保存调研报告" → 直接调用

**禁止** 在未加载此模板的情况下，以自由格式输出调研/舆情分析报告。

## 保存路径

```
~/Desktop/我的知识库/用户调研/{报告文件夹名}/
```

每份报告是一个**文件夹**，包含：
```
{报告文件夹名}/
├── README.md          ← 报告正文（GitLab 自动渲染）
└── images/
    ├── img-001.jpg
    ├── img-002.jpg
    └── ...
```

## 文件夹命名

```
{产品名}-{功能/主题}-{平台}-{报告类型}
```

示例：`网易云音乐盲盒一期-喵喵家族-小红书舆情分析/`

## Markdown 格式模板

```markdown
# {产品名}「{功能/主题}」{平台}{报告类型}

> 分析时间：{YYYY-MM-DD}
> 数据来源：{平台名称}
> 搜索关键词：{关键词1}、{关键词2}、...

---

## 一、数据概览

| 指标 | 数据 |
|------|------|
| 搜索关键词组 | X组 |
| 有效笔记数 | XX 条 |
| 最高互动帖 | XX赞 / XX评论 |
| 内容时间跨度 | YYYY年X月至今 |

---

## 二、内容类型分布

表格列：类型 | 占比 | 说明

---

## 三、正向舆情

每条帖子格式：
- **[加粗标题](原贴链接)** — 赞数 / 评论数 / 转发数 / 收藏数 · YYYY-MM-DD
- > 作者 · IP属地
- > 引用原文关键内容
- 图片用 `<img src="./images/img-001.jpg" width="150" />` 引用本地图片，多图空格分隔

链接格式按平台：
- 小红书：`https://www.xiaohongshu.com/explore/{note_id}`
- 微博：`https://weibo.com/{uid}/{mid}`
- Twitter：`https://x.com/{username}/status/{tweet_id}`
- 其他平台：使用原始 URL

日期格式：从帖子的 `time` 字段（毫秒时间戳）转换为 `YYYY-MM-DD`

---

## 四、负向舆情

同上格式（含原贴链接和日期），额外标注核心槽点

---

## 五、互换/交易生态（如适用）

---

## 六、总结与建议

包含：
- 整体舆情倾向（正面/负面比例）
- 负面核心风险点表格（风险点 | 严重程度 | 建议）
- 与其他期/版本的对比表（如适用）
```

## 图片规则

- **必须下载图片到本地** `images/` 子目录，不依赖外部 CDN 链接（CDN 链接会过期）
- 报告中使用**相对路径**引用：`<img src="./images/img-001.jpg" width="150" />`
- 图片命名：`img-001.jpg`、`img-002.jpg`，按出现顺序递增
- 多图同行用空格分隔
- 下载图片时使用 curl，添加 Referer 头避免防盗链：
  ```bash
  curl -sL -o "./images/img-001.jpg" -H "Referer: https://www.xiaohongshu.com/" "CDN_URL"
  ```

## 上传到 Git 仓库

报告保存到本地后，**必须** 同步上传到 GitLab 仓库。

### 仓库信息

```
https://g.hz.netease.com/hzwupeng1/product_user_research.git
```

### 上传流程

```bash
# 1. 定义仓库本地路径
REPO_DIR="$HOME/.cache/product_user_research"

# 2. 首次克隆或后续拉取最新
if [ ! -d "$REPO_DIR/.git" ]; then
  git clone https://g.hz.netease.com/hzwupeng1/product_user_research.git "$REPO_DIR"
else
  git -C "$REPO_DIR" pull --rebase
fi

# 3. 复制报告文件夹到仓库（整个文件夹，包含 images/）
cp -r "报告文件夹本地路径" "$REPO_DIR/"

# 4. 提交并推送
git -C "$REPO_DIR" add .
git -C "$REPO_DIR" commit -m "docs: 新增 {报告文件夹名}"
git -C "$REPO_DIR" push
```

### 注意事项

- 报告文件夹直接放在仓库根目录，文件夹名与本地一致
- commit message 格式：`docs: 新增 {文件夹名}`（新增）或 `docs: 更新 {文件夹名}`（覆盖更新）
- 上传完成后告知用户 GitLab 仓库链接

