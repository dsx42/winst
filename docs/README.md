# 文档索引

winst 的技术文档。想先上手看 [README](../README.md)，需要细节再按下面的表查。

| 文档 | 内容 |
|---|---|
| [architecture.md](architecture.md) | 模块划分、两种模块形态、跨模块状态、代码约定 |
| [cli.md](cli.md) | 命令、选项、退出码、交互菜单 |
| [manifest.md](manifest.md) | 软件源、清单格式、条目字段、六种下载来源 |
| [data-files.md](data-files.md) | `config.json`、`state.json`、缓存索引、清单文件 |
| [install-flows.md](install-flows.md) | 版本检测、安装决策、安装 / 更新 / 卸载 / 修复流程 |
| [development.md](development.md) | 仓库结构、开发调试、打包发布 |
| [troubleshooting.md](troubleshooting.md) | 常见故障与排查 |

## 一句话架构

```
winst.ps1            入口：设偏好 -> 按模块形态加载 -> 初始化状态 -> 调用 Winst.App
Modules\Winst.*\     开发树：每个模块 = psd1(元数据) + psm1(加载器) + Public\ + Private\
Modules\Winst\       release：build.ps1 合并出的单一模块（psd1 + psm1）
```

业务逻辑全部在模块里，`manifest.json` 只放软件定义，用户数据全部落在数据目录与安装根目录。
