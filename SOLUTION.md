# ansible-lint GitHub Action 与 pre-commit 钩子集成问题解决方案

## 问题概述

当用户通过 GitHub Action 使用 ansible-lint 并传入 `requirements_file` 参数安装集合依赖时，pre-commit 钩子执行会因环境变量未正确继承而无法找到已安装的依赖。

## 错误复现与现象

### 复现步骤

1. 在项目中创建 `.github/workflows/lint.yml`，使用 ansible-lint action 并指定 `requirements_file`
2. 创建 `requirements.yml`，包含集合依赖
3. 设置 `.pre-commit-config.yaml` 使用 ansible-lint 钩子
4. 创建一个使用第三方集合模块的 playbook
5. 触发 GitHub Action 工作流

### 错误现象与日志

典型错误日志片段：
```
ERROR! couldn't resolve module/action 'community.general.systemd'. This often indicates a misspelling, missing collection, or incorrect module path.

The error appears to be in '/home/runner/work/repo/repo/playbook.yml': line 5, column 7, but may be elsewhere in the file depending on the exact syntax problem.
```

## 修复方案详解

### 方案一：修改 `action.yml` - GitHub Action 端

#### 修改内容

```yaml
- name: Install role and collection dependencies from requirements file
  if: inputs.requirements_file != ''
  shell: bash
  working-directory: ${{ steps.inputs.outputs.working_directory }}
  run: |
    # 创建本地集合和角色目录
    mkdir -p ./collections ./roles
    
    # 安装依赖，并确保它们安装在可访问的位置
    ansible-galaxy install -r ${{ inputs.requirements_file }} --collections-path ./collections --roles-path ./roles
    
    # 设置环境变量，确保 ansible-lint 能够找到它们
    echo "ANSIBLE_COLLECTIONS_PATH=./collections:${ANSIBLE_COLLECTIONS_PATH:-}" >> $GITHUB_ENV
    echo "ANSIBLE_ROLES_PATH=./roles:${ANSIBLE_ROLES_PATH:-}" >> $GITHUB_ENV
    
    # 同时设置 PYTHONPATH 以确保任何相关的 Python 模块也能被找到
    if [ -d "./collections" ]; then
      echo "PYTHONPATH=./collections:${PYTHONPATH:-}" >> $GITHUB_ENV
    fi
    
    # 验证安装
    echo "Collections installed in:"
    ls -la ./collections/ 2>/dev/null || echo "No collections installed"
    echo "Roles installed in:"
    ls -la ./roles/ 2>/dev/null || echo "No roles installed"
```

#### 修改要点

1. **显式指定安装路径**：使用 `--collections-path` 和 `--roles-path` 参数确保依赖安装在项目目录内的固定位置
2. **设置持久化环境变量**：通过 `$GITHUB_ENV` 机制设置环境变量，使其可用于后续所有步骤
3. **本地目录优先**：确保安装路径在当前工作目录，便于后续查找

### 方案二：修改 `.pre-commit-hooks.yaml` - pre-commit 钩子端

#### 修改内容

```yaml
- id: ansible-lint
  name: ansible-lint
  description: This hook runs ansible-lint with proper environment variable inheritance for collections and roles.
  entry: python3 -m ansiblelint.precommit_hook_wrapper -v --force-color
  language: python
  language_version: python3.14
  pass_filenames: false
  always_run: true
  # 关键：确保关键环境变量传递给钩子
  pass_env:
    - ANSIBLE_COLLECTIONS_PATH
    - ANSIBLE_ROLES_PATH
    - PYTHONPATH
    - HOME
    - PATH
  additional_dependencies:
    - ansible-core>=2.19.0
```

#### 修改要点

1. **添加 `pass_env` 配置**：明确指定哪些环境变量应该传递给 pre-commit 子进程
2. **使用包装脚本**：创建 `precommit_hook_wrapper.py` 来进一步确保环境变量正确设置

### 方案三：创建 `precommit_hook_wrapper.py` 包装脚本

#### 功能

- 自动检测项目目录内的集合和角色位置
- 动态设置和补充环境变量
- 确保 ansible-lint 在正确的上下文中运行

## 为什么 GitHub Action 环境变量无法透传到 pre-commit 子进程？

### 核心原因分析

#### 1. pre-commit 的隔离执行机制

pre-commit 钩子在**隔离环境**中运行，默认情况下：
- 不会继承父进程的所有环境变量，只继承 `PATH` 和 `HOME`
- 每个钩子有自己的执行沙箱
- 环境变量必须显式通过 `pass_env` 配置白名单

#### 2. GitHub Action 环境变量传递机制

GitHub Action 中的环境变量设置方式：
- `$GITHUB_ENV` 机制是为后续步骤设计的
- 当调用外部工具（如 pre-commit）时，环境变量传递会进一步受限
- pre-commit 作为独立进程，不会自动继承所有变量

#### 3. 多层进程树问题

进程树结构：
```
GitHub Runner 
  → Action Step (设置环境变量)
    → pre-commit (进程隔离)
      → ansible-lint (钩子进程)
```

每层都可能过滤或重置环境变量。

## 完整解决方案总结

我们采用了三层防护策略：

1. **GitHub Action 端**：确保依赖安装在固定位置并设置环境变量
2. **pre-commit 配置端**：通过 `pass_env` 明确允许关键变量传递
3. **包装脚本层**：增加额外保险，自动检测和设置查找路径

## 用户使用建议

对于最终用户，在自己的项目中：

1. **确保使用最新版本的 ansible-lint**
2. **在 .pre-commit-config.yaml 中可以补充 pass_env**（如果使用旧版本）

```yaml
repos:
  - repo: https://github.com/ansible/ansible-lint
    rev: v24.7.0
    hooks:
      - id: ansible-lint
        pass_env:
          - ANSIBLE_COLLECTIONS_PATH
          - ANSIBLE_ROLES_PATH
          - PYTHONPATH
```

3. **在 GitHub Action 中，确保 requirements_file 安装到本地目录**
