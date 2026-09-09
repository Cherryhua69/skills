---
name: remote-device-coding
description: Use when modifying code on LAN servers, embedded Linux devices, SSH-only build machines, or remote project directories while explicitly avoiding edits to the local workspace.
---

# Remote Device Coding

## Overview

在局域网服务器或嵌入式设备上改代码时，把目标设备当成唯一工作区：本地只用于发起连接、记录命令输出和临时草稿，不修改本地项目代码。

核心原则：先连通和定位，再理解远端代码，再最小改动，最后在远端验证。

## Workflow

1. 明确目标：确认 `host`、`user`、认证方式、远端项目路径、具体子目录、要改的需求和“不要改本地项目”的边界。
2. 连通性检查：优先用 `ping` / `Test-NetConnection` / `ssh -o BatchMode=yes` 判断网络和 SSH 端口；不要把密码写入技能、仓库、脚本或日志文件。
3. 进入远端项目：通过 SSH 执行 `pwd`、`ls`、`git status --short`、`git branch --show-current`，确认路径和工作区状态。
4. 理解代码：在远端使用 `rg`、`find`、`grep`、构建脚本和测试配置定位调用链；不要在本地项目目录复制或改写同名文件。
5. 修改代码：优先在远端生成补丁并用 `git apply --check && git apply` 应用；小改动也要先备份上下文或查看 diff。
6. 验证结果：在远端运行最小可行验证，例如单测、编译、lint、目标模块构建或命令行自检。
7. 汇报交付：说明远端路径、改了什么、执行了哪些验证、是否有未提交改动，以及无法验证的原因。

## Ready Gate

目标服务器网络可达只代表第一步成功。调用本技能后，只有同时满足下面条件，才可以继续代码修改或回复“连接成功”：

- SSH 登录成功，并确认 `hostname`、`whoami`、`pwd` 与用户给定目标一致。
- 目标项目路径存在，目标子目录存在，能执行 `ls` / `find` / `rg` 等只读代码检索。
- 已检查项目工作区状态，例如 `git status --short`；如果不是 Git 项目，要说明用什么方式追踪改动。
- 已确认目标项目具有必要读写权限：能读取关键源码，能在项目目录或允许的临时目录创建和删除探测文件。
- 已确认补丁写入路径可用：能写入远端 `/tmp` 或项目允许的临时补丁文件，并能执行 `git apply --check` 或等价检查。
- 已理解目标代码结构：至少确认入口文件、相关模块、调用链、构建/运行脚本、验证方式，以及本次需求可能影响的文件范围。
- 如果权限不足、路径不一致、代码理解不完整或只能 HTTP 访问，只能回复具体阻塞原因，不能说“目标项目连接成功且代码理解完成”。

权限探测要使用无害文件名，并立即清理：

```bash
cd /path/to/project
touch .codex_write_probe && rm -f .codex_write_probe
tmp_patch="/tmp/codex_patch_probe_$$.patch"
printf '' > "$tmp_patch" && rm -f "$tmp_patch"
```

完成 Ready Gate 后，回复必须包含这句话：

```text
目标项目连接成功且代码理解完成。
```

## Command Pattern

PowerShell 本地发起远端只读检查：

```powershell
$HostName = "192.168.1.132"
$UserName = "ztl"
$Project = "/home/ztl/ks_face_recognition"
Test-Connection -ComputerName $HostName -Count 2 -Quiet
ssh "$UserName@$HostName" "cd '$Project' && pwd && git status --short"
```

如果环境没有可非交互输入密码的 SSH 工具，说明限制并请用户在交互终端完成登录、配置 SSH key，或提供可用的安全连接方式。不要假装已经登录成功。

## Connection Methods

根据历史任务，按下面顺序选择连接方式。每一种方式都只用于本次任务，不把密码写入仓库、技能或长期脚本。

| 方式 | 适用场景 | 做法 |
| --- | --- | --- |
| OpenSSH 免密 | 用户已配置 SSH key，或已在服务器授权公钥 | `ssh -o BatchMode=yes user@host "hostname && pwd"`，成功后继续远端操作 |
| OpenSSH 交互登录 | 用户愿意在终端手动输入密码 | 让用户执行 `ssh user@host` 完成首次登录或授权公钥；Codex 不能接管另一个已登录的 cmd 会话 |
| Paramiko 密码登录 | 本机没有 `sshpass/plink`，但 Python 有 `paramiko` | 用临时 Python 脚本建立 SSH/SFTP，只在内存变量里使用用户当次提供的密码；脚本放系统临时目录，用完删除 |
| `SSH_ASKPASS` 临时授权 | Windows OpenSSH 可用，需自动执行一次密码认证或写入公钥 | 创建临时 askpass 脚本，通过环境变量喂本次密码，执行完立即删除；不要把脚本放项目目录 |
| `sshpass` / `plink` | 机器已安装这些工具，用户允许本次自动密码登录 | 仅在临时命令或临时脚本中使用，避免进入长期文件；优先禁用公钥误试：`PreferredAuthentications=password` |
| 跳板机 / 构建机 | 目标设备只能从另一台服务器访问，或本机直连看到的文件系统不对 | 先登录跳板机，再从跳板机 SSH 到目标机；必要时用 `ProxyCommand` / `nc`，并明确区分“代码机”“运行机”“日志机” |
| HTTP 只读检查 | SSH 凭据不对，但服务端口可访问 | 只做健康接口、日志接口或页面状态检查；不能据此宣称已检查远端代码 |
| 公网服务器握手失败 | 22 端口可连但 `kex_exchange_identification` 或 `ssh-keyscan` 失败 | 先让用户通过云控制台检查安全组、防火墙、Fail2Ban、`sshd` 状态，再授权公钥 |

### Paramiko 临时脚本模式

当用户明确提供账号密码、且本机没有 `sshpass/plink` 时，可以用 Paramiko 做只读检查或 SFTP 补丁写入。脚本必须放在系统临时目录，执行后删除。

```python
import paramiko

host = "192.168.x.x"
user = "user"
password = "use-runtime-secret-only"
project = "/path/to/project"

client = paramiko.SSHClient()
client.set_missing_host_key_policy(paramiko.AutoAddPolicy())
client.connect(host, username=user, password=password, timeout=10)
stdin, stdout, stderr = client.exec_command(f"cd {project!r} && pwd && git status --short")
print(stdout.read().decode("utf-8", "replace"))
print(stderr.read().decode("utf-8", "replace"))
client.close()
```

实际执行时不要把真实密码写入技能或项目文件；如果需要临时脚本，脚本结束后清理。

### Jump Host Pattern

历史任务里常见这种拓扑：

```text
本机 -> 1.155 测试/代理机 -> 2.133 构建机 -> 目标运行目录
```

处理这类任务时先画清楚角色：

- 代码机：真正修改和编译代码的位置。
- 运行机：服务实际运行、日志和数据库所在位置。
- 跳板机：只负责连通，不默认等于代码机。
- 本地目录：只用于查看上下文，除非用户明确要求，否则不修改。

如果本机直连某个 IP 看到的目录和历史记录不一致，不要继续部署；改从已知跳板机视角重新确认 `hostname`、`ip addr`、`pwd`、目标目录和进程。

## Remote Edit Pattern

在远端应用补丁时使用可回滚路径：

```bash
cd /home/ztl/ks_face_recognition
git status --short
cat >/tmp/change.patch <<'PATCH'
diff --git a/path/file.c b/path/file.c
--- a/path/file.c
+++ b/path/file.c
@@
 old line
+new line
PATCH
git apply --check /tmp/change.patch && git apply /tmp/change.patch
git diff -- path/file.c
```

复杂改动可以先把补丁写到远端 `/tmp`，检查通过后再应用。避免用本地 `apply_patch` 修改工作区文件，因为那会改到本机，不是目标服务器。

## Safety Rules

- 不把密码、私钥、token 写入技能、仓库、提交说明、补丁或长期文件。
- 不在本地项目目录创建镜像副本后修改；如需临时下载只读文件，放到系统临时目录并标明仅供分析。
- 远端已有未提交改动时先汇报；只改任务相关文件，不覆盖他人改动。
- 修改前后都看 `git diff`；涉及生成物、SDK、交叉编译产物时先确认项目约定。
- Bug 修复先定位根因；新功能先做最小可运行实现。
- 远端新增或改动的方法、函数、类、复杂逻辑块要写中文注释；简单 getter、常量或一眼可懂的一行逻辑不强行注释。
- 如果刻意采用最小实现且有已知上限，在代码注释里用 `ponytail:` 标明原因、限制和未来升级路径。

## Quick Reference

| 场景 | 做法 |
| --- | --- |
| 只确认设备在线 | `ping` / `Test-Connection`，再测 22 端口 |
| 确认远端项目 | `ssh user@host "cd /path && pwd && ls"` |
| 确认读写权限 | `touch .codex_write_probe && rm -f .codex_write_probe` |
| 确认代码理解 | 找到入口、模块、调用链、构建脚本和验证方式 |
| 查代码 | `ssh user@host "cd /path && rg 'keyword' subdir"` |
| 看远端改动 | `ssh user@host "cd /path && git diff --stat && git diff"` |
| 应用改动 | 远端 `/tmp/*.patch` + `git apply --check` |
| 验证 | 在远端运行项目已有测试、构建或最小复现命令 |
| 密码自动登录 | 优先 Paramiko / 临时 `SSH_ASKPASS`，用完删除临时脚本 |
| 经跳板机访问 | 先确认跳板机和目标机角色，再用 `ProxyCommand` 或跳板机侧临时脚本 |

## Current Request Shape

当用户给出类似信息时触发本技能：

```text
服务器：192.168.1.132
用户名：ztl
远端项目：/home/ztl/ks_face_recognition
目标子目录：Hisi3516DV500_COMC.870.990.V2.0.3.sdk200.DevKit_glibc_shandong
要求：不要修改本地项目代码
```

把这些值视为本次任务参数，不要固化到技能之外；尤其不要保存密码。

## Common Mistakes

- 在本地仓库搜索到同名目录后直接改本地文件：应改远端项目。
- 只 ping 通就说“已连接”：必须区分网络在线、SSH 端口可达、登录成功、项目路径存在。
- 只确认服务器可达就开始改：必须先确认目标项目读写权限、文件操作权限和代码理解完成。
- 只看了目录树就说理解代码：至少要确认入口、调用链、构建/运行脚本和可验证方式。
- 为了方便把密码写进脚本：改用交互登录、SSH key、会话缓存或用户确认的安全工具。
- 未查看远端 `git status` 就应用补丁：可能覆盖别人的未提交改动。
- 验证只跑本地命令：远端 SDK、交叉编译链和系统库才是目标环境。
