# 调研依据

仅在需要解释命名规则、处理 Codex 项目与代码项目边界，或更新本技能时阅读。

## 官方资料

- [OpenAI：Projects and chats](https://learn.chatgpt.com/codex/projects)
  - 建议为每个明确结果建立独立会话，使消息与产出保持聚焦。
  - 建议用简短标题描述会话结果，例如 “Q3 launch brief” 或 “Checkout accessibility review”。
  - 本地项目可以挂载一个或多个文件夹；主文件夹只是新会话、Git 操作以及 `AGENTS.md`、skills、`config.toml` 自动发现的默认入口。因此 Codex 项目与具体代码项目不是同一概念。
- [OpenAI：Codex App Server](https://developers.openai.com/codex/app-server)
  - App Server 暴露会话读取、列出和重命名语义；用户可见标题保存在会话名称中。技能应使用产品提供的会话管理能力，而不是直接修改内部存储文件。
- [Git：git-remote](https://git-scm.com/docs/git-remote)
  - Git 远端记录仓库 URL，可作为跨工作路径、worktree 和主机识别仓库正式身份的重要证据。

## 规则推导

1. “内容”采用明确结果而非泛化动作，来自 OpenAI 对短标题和单一结果会话的建议。
2. “项目”必须从仓库与项目元数据判断，因为 Codex 项目可包含多个文件夹，也可能跨不同局域网服务器承载多个代码项目。
3. 远端仓库名通常比本地目录名稳定，但仍需与清单文件、README 和会话实际内容交叉验证，避免 fork、镜像、单仓多应用或同名仓库误判。
