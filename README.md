<div align="center">

<img src="docs/duofold-banner.png" alt="DuoFold MacBook fold animation" width="100%">

# DuoFold

**让 MacBook 的屏幕，在合盖时像真实的柔性屏一样折叠。**

一个安静、原生、常驻菜单栏的 macOS 小工具。你合上 MacBook，桌面会跟随转轴动作弯折、卷起、收拢；再次打开时，画面自然恢复。

<p>macOS 14+ · 原生体验 · 本地运行 · 无账号</p>

</div>

## 为什么是 DuoFold

合盖通常是一个瞬间。DuoFold 把这个瞬间变成一段有物理感的视觉反馈：桌面像一块屏幕材料一样沿着转轴运动，让离开、暂停、收起和重新开始都更有仪式感。

它适合喜欢桌面美学的人、做产品演示的人，也适合想让 MacBook 多一点个性的人。应用不改变你的工作流，菜单栏里点一下即可暂停或切换效果。

## 六种折叠风格

| 模式 | 看起来像什么 | 适合什么时候用 |
| --- | --- | --- |
| Duo | 经典的透视折叠与柔和渐隐 | 日常使用 |
| Ghost | 桌面留在原处，画面像幽灵一样错位 | 展示空间感 |
| Roll | 屏幕从转轴处卷起 | 录屏和分享 |
| Shutter | 多段面板像百叶窗一样收拢 | 快速、节奏感强 |
| Flex | 连续曲面弯折，带轻微高光 | 更强的物理感 |
| Iris | 从边缘向中心合拢 | 展示模式 |

不方便真的合盖时，可以在设置里点击预览。预览使用生成画面，不会保存真实桌面，适合录制演示。

## 使用方式

1. 启动 DuoFold，点击菜单栏图标。
2. 第一次使用时，在系统设置中允许 DuoFold 访问“屏幕与系统音频录制”。
3. 选择动画风格；需要时调整行为、模糊和透视强度。
4. 合上或打开 MacBook，动画会跟随转轴角度运行。

DuoFold 只支持带有连续合盖角度传感器的 MacBook。没有传感器的设备仍可以使用预览模式查看动画。

## 安装

从源码构建需要 macOS 14+、Xcode 和 Swift 6：

```sh
git clone git@github.com:Ryder-MHumble/DuoFold.git
cd DuoFold
./build.sh
open "build/DuoFold.app"
```

建议把最终应用放到 `/Applications/DuoFold.app`，并始终从同一个位置启动。macOS 会把屏幕录制授权与应用路径、Bundle ID 和签名关联起来；重新构建或更换位置后，系统可能要求再次确认授权。

## 隐私

- 桌面画面只在本机内存中用于生成动画，效果结束后释放。
- 不使用摄像头、麦克风、账号或分析服务。
- 不上传、不保存你的桌面内容。

## 当前状态

DuoFold 目前优先打磨 macOS 原生体验，包括稳定的 Duo 效果、Ghost / Roll / Shutter / Flex / Iris 模式、Replay 预览、中文与英文界面、Reduce Motion 和开机启动。

Windows 版本会在 macOS 体验稳定后进行有限机型验证。由于多数 Windows 笔记本没有可读取的连续转轴角度，首版会提供手动或 Replay 模式，不承诺全品牌自动折叠。

## 许可证

DuoFold 使用 Apache-2.0 发布。许可证和法律要求保留的 NOTICE 位于 [LICENSE](LICENSE) 与 [NOTICE](NOTICE)。第三方来源和修改边界见 [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md)。

由 Ryder 开发。
