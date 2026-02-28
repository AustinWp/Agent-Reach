#!/usr/bin/env bash
# ============================================================
# Agent Reach — 一键迁移 (代码 + Skills)
# 日期: 2026-02-28
# 用途: 在新设备/云主机上运行，同步最新代码并覆盖安装 skill
# 使用: bash migrate-skills.sh
# ============================================================
set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }

# pip 兼容：优先用项目 venv，其次 python3 -m pip
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
if [ -f "$PROJECT_DIR/.venv/bin/pip" ]; then
  PIP="$PROJECT_DIR/.venv/bin/pip"
elif command -v pip3 &>/dev/null; then
  PIP="pip3"
else
  PIP="python3 -m pip"
fi

# --------------------------------------------------
# 0. 更新 agent-reach 代码仓库 + 重装 Python 包
# --------------------------------------------------
REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"

if [ -d "$REPO_DIR/.git" ]; then
  echo ""
  echo ">>> 更新代码仓库: $REPO_DIR"
  git -C "$REPO_DIR" fetch --all 2>/dev/null

  CURRENT=$(git -C "$REPO_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null)
  if [ "$CURRENT" = "refactor-v1.1" ]; then
    git -C "$REPO_DIR" pull --rebase 2>/dev/null && log "代码已更新 (refactor-v1.1)"
  else
    warn "当前分支: $CURRENT — 切换到 refactor-v1.1"
    git -C "$REPO_DIR" checkout refactor-v1.1 2>/dev/null
    git -C "$REPO_DIR" pull --rebase 2>/dev/null && log "已切换并更新到 refactor-v1.1"
  fi

  echo ""
  echo ">>> 重新安装 Python 包 (editable mode)"
  if $PIP install -e "$REPO_DIR" 2>&1 | tail -5; then
    log "agent-reach Python 包已更新 ($(agent-reach version 2>/dev/null || echo 'unknown'))"
  else
    warn "pip install 失败，请手动执行: $PIP install -e $REPO_DIR"
  fi
else
  warn "未找到 git 仓库: $REPO_DIR — 跳过代码更新"
  warn "请先 git clone 仓库，或手动安装: pip install -e /path/to/reach-agent"
fi

echo ""

# --------------------------------------------------
# 1. 安装 agent-reach skill（Claude Code + OpenClaw）
# --------------------------------------------------
for SKILL_DIR in \
  "$HOME/.claude/skills/agent-reach" \
  "$HOME/.openclaw/skills/agent-reach"; do

  mkdir -p "$SKILL_DIR"
  cat > "$SKILL_DIR/SKILL.md" << 'AGENT_REACH_EOF'
---
name: agent-reach
description: >
  Give your AI agent eyes to see the entire internet. Read and search across
  Twitter/X, Reddit, YouTube, GitHub, Bilibili, XiaoHongShu, RSS, and any web page
  — all from a single CLI. Use when: (1) reading content from URLs (tweets, Reddit posts,
  articles, videos), (2) searching across platforms (web, Twitter, Reddit, GitHub, YouTube,
  Bilibili, XiaoHongShu), (3) analyzing user feedback or sentiment from any platform,
  (4) checking channel health or updating Agent Reach.
  Triggers: "search Twitter/Reddit/YouTube", "read this URL", "find posts about",
  "搜索", "读取", "查一下", "看看这个链接", "分析", "调研", "舆情",
  "通过小红书分析", "通过XX平台分析".
---

# Agent Reach

Read and search the internet across 9+ platforms via unified CLI.

## IMPORTANT: Platform Research Workflow

When the user asks to **analyze/research/调研** user feedback via any platform, follow this mandatory workflow:

1. **Invoke this skill (`agent-reach`) FIRST** — get the correct platform usage guide before any search/read. NEVER run CLI commands blindly.
2. **Collect data** — follow the platform-specific instructions below (search → read details).
3. **Download images locally** — during data collection, extract all image URLs from posts and download to `images/` folder. See "Image Download" section below.
4. **Invoke `user-research-report` skill BEFORE writing the report** — load the output template. NEVER output a free-form analysis.
5. **Write and save the report** — strictly follow the `user-research-report` template format (folder-based with local images).

## Setup

First check if agent-reach is installed:
```bash
agent-reach doctor
```

If command not found, install it:
```bash
pip install https://github.com/AustinWp/Agent-Reach/archive/main.zip
agent-reach install --env=auto
```

`install` auto-detects your environment and installs all dependencies (Node.js, mcporter, bird CLI, gh CLI). Read the output and run `agent-reach doctor` to see what's active.

For channels that need user input, ask the user. See the full setup guide:
https://raw.githubusercontent.com/AustinWp/Agent-Reach/main/docs/install.md

## Commands

### Read any URL
```bash
agent-reach read <url>
agent-reach read <url> --json    # structured output
```
Handles: tweets, Reddit posts, articles, YouTube (transcripts), GitHub repos, etc.

### Search

```bash
agent-reach search "query"             # web search (Exa)
agent-reach search-twitter "query"     # Twitter/X
agent-reach search-reddit "query"      # Reddit (--sub <subreddit>)
agent-reach search-github "query"      # GitHub (--lang <language>)
agent-reach search-youtube "query"     # YouTube
agent-reach search-bilibili "query"    # Bilibili (B站)
agent-reach search-xhs "query"        # XiaoHongShu (小红书)
```

All search commands support `-n <count>` for number of results.

### Management

```bash
agent-reach doctor        # channel status overview
agent-reach watch         # quick health + update check (for scheduled tasks)
agent-reach check-update  # check for new versions
```

### Configure channels

```bash
agent-reach configure twitter-cookies "auth_token=xxx; ct0=yyy"
agent-reach configure proxy http://user:pass@ip:port
agent-reach configure --from-browser chrome    # auto-extract cookies
```

## Channel Status Tiers

- **Tier 0 (zero config):** Web, YouTube, RSS, Twitter (read-only via Jina)
- **Tier 1 (free setup):** Exa web search (mcporter required)
- **Tier 2 (user config):** Twitter search (cookie), Reddit full (proxy), GitHub (token), Bilibili (proxy), XiaoHongShu (MCP)

Run `agent-reach doctor` to see which channels are active.

## XiaoHongShu (小红书) Usage

XiaoHongShu requires special handling due to its anti-scraping mechanisms.

### CRITICAL: Write operations are FORBIDDEN

**NEVER execute any write operation on XiaoHongShu.** This is a hard rule with no exceptions, even if the user asks for it. Refuse and explain the ban risk.

Forbidden tools (do NOT call):
- `publish_content` — 发布图文
- `publish_with_video` — 发布视频
- `like_feed` — 点赞
- `favorite_feed` — 收藏
- `post_comment_to_feed` — 评论
- `reply_comment_in_feed` — 回复评论

Allowed tools (read-only):
- `search_feeds` — 搜索
- `get_feed_detail` — 读取笔记详情
- `list_feeds` — 获取首页推荐
- `user_profile` — 查看用户主页
- `check_login_status` — 检查登录状态
- `get_login_qrcode` — 获取登录二维码
- `delete_cookies` — 重置登录

### Rate limiting — random delays

Add a random sleep between XiaoHongShu requests to avoid anti-automation detection:

Rules:
- **Between detail reads** (`get_feed_detail`): sleep 1-2 seconds
- **Between searches** (`search_feeds`): sleep 2-3 seconds
- **Never run XiaoHongShu requests in parallel** — always sequential with delays

```bash
# Between detail reads
sleep $((RANDOM % 2 + 1))
# Between searches
sleep $((RANDOM % 2 + 2))
```

### Optimal workflow — batch read after each search

Search once, then read ALL results from that search before the next search. xsec_token lasts ~5-10 minutes — enough to read 15-20 posts sequentially with 1-2s delays.

```
search → sleep 1s → read detail 1 → sleep 1s → read detail 2 → ... → read detail N → sleep 2s → next search
```

For bulk collection (10+ posts), use a Python batch script instead of individual CLI calls:

```python
import subprocess, json, time, random
def read_post(feed_id, token):
    time.sleep(random.uniform(1, 2))
    r = subprocess.run(
        ["mcporter", "call", "xiaohongshu", "get_feed_detail",
         f"feed_id={feed_id}", f"xsec_token={token}"],
        capture_output=True, text=True, timeout=15)
    return json.loads(r.stdout) if r.stdout.strip() else None
```

### xsec_token handling

- Tokens expire in ~5-10 minutes. Read all results from a search before doing the next search.
- If `get_feed_detail` returns empty/error, the token expired. Re-search to get a fresh token.
- Do NOT collect tokens from multiple searches before reading — tokens from the first search may expire while you search again.

### Reading post details requires search first

`agent-reach read <xhs-url>` cannot resolve xsec_token on its own. Use `mcporter call xiaohongshu search_feeds` to get tokens, then `mcporter call xiaohongshu get_feed_detail` with the token.

### mcporter call examples (read-only operations only)

```bash
# Search (returns feed_id + xsec_token for each result)
mcporter call xiaohongshu search_feeds keyword="关键词"

# Read detail (1-2s delay after previous request)
sleep $((RANDOM % 2 + 1))
mcporter call xiaohongshu get_feed_detail feed_id="ID" xsec_token="TOKEN"

# Load all comments
sleep $((RANDOM % 2 + 1))
mcporter call xiaohongshu get_feed_detail feed_id="ID" xsec_token="TOKEN" load_all_comments=true limit=30

# Browse
sleep $((RANDOM % 2 + 2))
mcporter call xiaohongshu list_feeds

# Check status (no delay needed)
mcporter call xiaohongshu check_login_status
```

### CRITICAL: XiaoHongShu API response field names

The two main APIs return **completely different JSON structures**. Using wrong field names silently returns empty results — the most common XHS debugging pitfall.

**`search_feeds` response** — top-level key is `feeds` (NOT `data.items`), fields are **camelCase**:
```json
{
  "feeds": [
    {
      "id": "68d8d944000000000e0201cc",
      "xsecToken": "ABcDe...",
      "noteCard": {
        "displayTitle": "标题",
        "user": {"nickname": "用户名", "userId": "..."},
        "interactInfo": {
          "likedCount": "128",
          "commentCount": "32"
        },
        "time": 1727510400000
      }
    }
  ]
}
```

**`get_feed_detail` response** — nested under `data.note`, field names differ:
```json
{
  "data": {
    "note": {
      "title": "标题",
      "desc": "正文内容",
      "time": 1727510400000,
      "user": {"nickname": "用户名"},
      "interactInfo": {
        "likedCount": "128",
        "commentCount": "32",
        "collectedCount": "45",
        "shareCount": "12"
      },
      "imageList": [{"urlDefault": "https://..."}]
    },
    "comments": {
      "list": [{"content": "评论内容", "likeCount": "5"}]
    }
  }
}
```

**Common mistakes to avoid:**
| Wrong (will silently fail) | Correct |
|---|---|
| `d["data"]["items"]` | `d["feeds"]` |
| `item["xsec_token"]` | `item["xsecToken"]` |
| `item["note_card"]` | `item["noteCard"]` |
| `nc["display_title"]` | `nc["displayTitle"]` |
| `nc["interact_info"]` | `nc["interactInfo"]` |
| `info["liked_count"]` | `info["likedCount"]` |
| `info["comment_count"]` | `info["commentCount"]` |

**Note:** `check_login_status` returns **plain text** (not JSON). Do not pipe through `json.loads()`.

### Login expiration

If `check_login_status` shows not logged in, re-authenticate:
```bash
mcporter call xiaohongshu get_login_qrcode
# Save the base64 image, open it, ask user to scan with XHS app
```

### Login fallback — manual cookie injection

If QR code login fails repeatedly ("fail to login"), the user can provide `web_session` from their browser (via Cookie-Editor extension on xiaohongshu.com). Inject it directly into the Docker container:

```bash
docker exec xiaohongshu-mcp sh -c 'cat > /app/cookies.json << EOF
[
  {
    "name": "web_session",
    "value": "USER_WEB_SESSION_VALUE",
    "domain": ".xiaohongshu.com",
    "path": "/",
    "httpOnly": true,
    "secure": true
  }
]
EOF'
```

Then verify with `mcporter call xiaohongshu check_login_status`.

## Image Download

When collecting data for research reports, **always download images locally** to prevent CDN link expiration.

### Workflow

1. Create the report folder and `images/` subfolder first:
   ```bash
   REPORT_DIR="$HOME/Desktop/我的知识库/用户调研/{报告文件夹名}"
   mkdir -p "$REPORT_DIR/images"
   ```

2. After reading each post detail (`get_feed_detail`), extract image URLs from `data.note.imageList[].urlDefault` and download:
   ```bash
   curl -sL -o "$REPORT_DIR/images/img-001.jpg" \
     -H "Referer: https://www.xiaohongshu.com/" \
     "https://sns-webpic-qc.xhscdn.com/..."
   ```

3. For batch downloading, use inline Python:
   ```python
   import subprocess, json, os, time, random, urllib.request

   report_dir = os.path.expanduser("~/Desktop/我的知识库/用户调研/{报告文件夹名}")
   img_dir = os.path.join(report_dir, "images")
   os.makedirs(img_dir, exist_ok=True)

   img_counter = 1

   def download_images(image_list):
       global img_counter
       for img in image_list:
           url = img.get("urlDefault", "")
           if not url:
               continue
           ext = "jpg"
           out_path = os.path.join(img_dir, f"img-{img_counter:03d}.{ext}")
           req = urllib.request.Request(url, headers={"Referer": "https://www.xiaohongshu.com/"})
           try:
               with urllib.request.urlopen(req, timeout=10) as resp:
                   with open(out_path, "wb") as f:
                       f.write(resp.read())
               img_counter += 1
           except Exception as e:
               print(f"Failed to download {url}: {e}")
   ```

4. In the report markdown, reference images with relative paths:
   ```markdown
   <img src="./images/img-001.jpg" width="150" />
   ```

### Important notes

- Download images **during data collection**, not after — CDN URLs expire in hours
- Use `Referer: https://www.xiaohongshu.com/` header to avoid 403 errors
- Keep sequential numbering (`img-001`, `img-002`, ...) across all posts in the report
- Each post's images should be noted with their `img-XXX` numbers for mapping to the report

## Tips

- Always try `agent-reach read <url>` first for any URL — it auto-detects the platform
- For Twitter cookies, recommend the user install [Cookie-Editor](https://chromewebstore.google.com/detail/cookie-editor/hlkenndednhfkekhgcdicdfddnkalmdm) Chrome extension
- Reddit and Bilibili block server IPs — suggest a residential proxy (~$1/month) if on a server
- If a channel breaks, run `agent-reach doctor` to diagnose
AGENT_REACH_EOF

  log "agent-reach skill → $SKILL_DIR/SKILL.md"
done

# --------------------------------------------------
# 2. 安装 user-research-report skill
# --------------------------------------------------
for SKILL_DIR in \
  "$HOME/.claude/skills/user-research-report" \
  "$HOME/.openclaw/skills/user-research-report"; do

  mkdir -p "$SKILL_DIR"
  cat > "$SKILL_DIR/SKILL.md" << 'REPORT_SKILL_EOF'
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
- **加粗标题** — 赞数 / 评论数 / 转发数 / 收藏数
- > 作者 · IP属地
- > 引用原文关键内容
- 图片用 `<img src="./images/img-001.jpg" width="150" />` 引用本地图片，多图空格分隔

---

## 四、负向舆情

同上格式，额外标注核心槽点

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
REPORT_SKILL_EOF

  log "user-research-report skill → $SKILL_DIR/SKILL.md"
done

# --------------------------------------------------
# 3. 创建用户调研报告目录
# --------------------------------------------------
mkdir -p "$HOME/Desktop/我的知识库/用户调研"
log "报告目录 → ~/Desktop/我的知识库/用户调研/"

# --------------------------------------------------
# 4. 完成
# --------------------------------------------------
echo ""
echo "========================================="
echo "  迁移完成！已覆盖安装:"
echo "  [0] agent-reach 代码 + Python 包"
echo "  [1] agent-reach skill (含 XHS/图片下载)"
echo "  [2] user-research-report skill (文件夹格式)"
echo "  [3] 用户调研报告目录"
echo "========================================="
echo ""
echo "验证:"
echo "  agent-reach doctor"
echo "  agent-reach version"
