# 问题复现与修复方案

## 问题描述

当用户通过 GitHub Action 使用 ansible-lint 并传入 `requirements_file` 参数安装集合依赖时，pre-commit 钩子中的 ansible-lint 执行会因为环境变量未正确传递而无法找到已安装的依赖。

## 错误复现步骤

### 1. GitHub Action 配置

假设有一个 GitHub Action 工作流如下：

```yaml
name: Lint
on: [push, pull_request]

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Run ansible-lint
        uses: ansible/ansible-lint-action@main
        with:
          requirements_file: requirements.yml
```

### 2. requirements.yml 文件

```yaml
---
collections:
  - name: community.general
    version: 10.5.0
```

### 3. .pre-commit-config.yaml

```yaml
---
repos:
  - repo: https://github.com/ansible/ansible-lint
    rev: v24.7.0
    hooks:
      - id: ansible-lint
```

### 4. 包含依赖集合的 Playbook

```yaml
---
- name: Test playbook
  hosts: localhost
  tasks:
    - name: Use community.general module
      community.general.systemd:
        name: docker
        state: started
```

### 问题现象

当 GitHub Action 运行时：
1. 首先通过 `ansible-galaxy install -r requirements.yml` 安装集合依赖
2. 然后运行 pre-commit 钩子时，ansible-lint 无法找到 `community.general` 集合
3. 报错信息通常包含：`ERROR! couldn't resolve module/action 'community.general.systemd'` 或类似错误

## 问题根本原因

1. **GitHub Action 中环境变量未正确传递给 pre-commit**
   - GitHub Action 设置了 `ANSIBLE_COLLECTIONS_PATH` 和 `PYTHONPATH` 以包含安装位置
   - 但当调用 pre-commit 时，这些环境变量可能未正确传递给子进程
2. **pre-commit 钩子的执行环境是隔离的**
   - pre-commit 在自己的隔离环境中运行
   - 它不会继承父进程的所有环境变量，特别是与模块查找相关的
3. **ansible-lint 在 GitHub Action 和 pre-commit 中的执行上下文不一致**

## 修复方案

### 修复方案一：修改 action.yml

**重点**：确保在安装集合后设置必要的环境变量，并且这些变量能够传递给后续步骤，包括 pre-commit。

### 修复方案二：修改 .pre-commit-hooks.yaml

**重点**：pre-commit 钩子需要能够继承和保留 Ansible 集合查找路径

让我实现这两个修复方案。
