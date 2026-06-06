#!/usr/bin/env python3
"""Wrapper script for ansible-lint pre-commit hook that ensures proper environment variable inheritance."""

import os
import sys
from pathlib import Path


def main():
    """Main function to wrap ansible-lint execution."""
    # 确保当前目录在搜索路径中，以便找到本地集合和角色
    cwd = Path.cwd()
    
    # 构建集合和角色的默认搜索路径
    collections_paths = []
    roles_paths = []
    
    # 检查常见的集合和角色位置
    possible_locations = [
        cwd / "collections",
        cwd / "roles",
    ]
    
    for loc in possible_locations:
        if loc.exists() and loc.is_dir():
            if "collection" in loc.name:
                collections_paths.append(str(loc))
            elif "role" in loc.name:
                roles_paths.append(str(loc))
    
    # 合并并设置环境变量
    if collections_paths:
        current = os.environ.get("ANSIBLE_COLLECTIONS_PATH", "")
        if current:
            os.environ["ANSIBLE_COLLECTIONS_PATH"] = ":".join(collections_paths + [current])
        else:
            os.environ["ANSIBLE_COLLECTIONS_PATH"] = ":".join(collections_paths)
    
    if roles_paths:
        current = os.environ.get("ANSIBLE_ROLES_PATH", "")
        if current:
            os.environ["ANSIBLE_ROLES_PATH"] = ":".join(roles_paths + [current])
        else:
            os.environ["ANSIBLE_ROLES_PATH"] = ":".join(roles_paths)
    
    # 同样处理 PYTHONPATH
    python_paths = []
    for collections_path in collections_paths:
        if collections_path not in sys.path:
            python_paths.append(collections_path)
    
    if python_paths:
        # 确保 PYTHONPATH 包含我们的集合路径
        current_pythonpath = os.environ.get("PYTHONPATH", "")
        if current_pythonpath:
            os.environ["PYTHONPATH"] = ":".join(python_paths + [current_pythonpath])
        else:
            os.environ["PYTHONPATH"] = ":".join(python_paths)
    
    # 现在执行 ansible-lint
    from ansiblelint.__main__ import _run_cli_entrypoint
    return _run_cli_entrypoint()


if __name__ == "__main__":
    sys.exit(main())
