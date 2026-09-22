<div align="center">

<video src="demo.mp4" controls muted loop playsinline width="100%" aria-label="DuoFold 产品演示视频"></video>

<p><a href="demo.mp4">播放或下载演示视频</a></p>

# DuoFold

**合上 MacBook，也给桌面一个漂亮的收场。**

DuoFold 是一款常驻菜单栏的 macOS 动效工具，把合盖这一刻变成一段有物理感的屏幕动画：桌面沿着转轴弯折、卷起、收拢，重新打开时再自然展开。

它不改变你的工作方式，只为每天都会发生的动作增加一点秩序、反馈和仪式感。适合注重桌面体验的 Mac 用户，也适合产品演示、录屏和社交分享。

<p>macOS 14+ · 原生体验 · 本地运行 · 无账号</p>

[![下载 DuoFold](https://img.shields.io/badge/下载-DuoFold%200.1.0-ff8a3d?style=for-the-badge&logo=apple&logoColor=white)](https://github.com/Ryder-MHumble/DuoFold/releases/download/v0.1.0/DuoFold-0.1.0.dmg)

</div>

## 让每一次合盖，都值得被看见

合盖通常只是一瞬间，DuoFold 让这一瞬间有了清晰、自然、可感知的反馈。无论是暂时离开、结束一天的工作，还是录一段产品演示，画面都会跟随转轴动作完成收拢。

菜单栏即可控制，随时暂停或切换风格。它安静地工作在后台，把注意力留给你，把质感留给桌面。

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

### 一键安装

点击上方 **下载 DuoFold** 按钮，或直接下载 [DuoFold-0.1.0.dmg](https://github.com/Ryder-MHumble/DuoFold/releases/download/v0.1.0/DuoFold-0.1.0.dmg)。打开 DMG 后，把 DuoFold 拖到 `Applications` 文件夹，再从“应用程序”启动。

### 首次打开遇到“无法验证开发者”

当前安装包使用 ad-hoc 签名，macOS 第一次启动时可能会拦截应用。这不是应用损坏，请按下面步骤操作：

1. 先把 DuoFold 拖入 `Applications`，然后尝试打开一次。
2. 弹窗出现后点击“完成”，不要把应用移到废纸篓。
3. 打开 **系统设置 → 隐私与安全性**，向下滚动到“安全性”。
4. 找到“DuoFold 已被阻止使用”，点击旁边的 **仍要打开（Open Anyway）**。
5. 使用系统密码或 Touch ID 确认，在新的确认弹窗中点击“打开”。

如果看不到“仍要打开”，先关闭系统设置，重新双击 `/Applications/DuoFold.app` 一次，再回到“隐私与安全性”查看。完成一次确认后，之后从应用程序或菜单栏启动即可。

首次运行还需要在 **系统设置 → 隐私与安全性 → 屏幕与系统音频录制** 中允许 DuoFold，然后重新打开应用。

从源码构建需要 macOS 14+、Xcode 和 Swift 6：

```sh
git clone git@github.com:Ryder-MHumble/DuoFold.git
cd DuoFold
./build.sh
open "build/DuoFold.app"
```

本地生成带有 DuoFold 安装背景和拖拽布局的 DMG：

```sh
./package-dmg.sh
open build/release/DuoFold-0.1.0-local.dmg
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
