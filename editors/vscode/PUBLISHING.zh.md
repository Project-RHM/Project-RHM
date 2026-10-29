# 发布 VS Code 扩展

本扩展以 publisher（发布者）及命名空间 `rhema` 的名义发布到两个扩展商店：
VS Code 使用的 **Visual Studio Marketplace**，以及 Cursor、VSCodium 等基于
VS Code 的编辑器使用的 **Open VSX**。扩展有自己独立的版本号（`package.json`
中的 `version`），与 `rhema` 软件包的版本无关。扩展的名称（`name`）是
`rhema-language`，因此其标识为 `rhema.rhema-language`；显示名称（`displayName`）是
`Rhema Language`。Marketplace 要求这两者都在整个商店内唯一，而不仅是在同一
publisher 之下唯一，而 `rhema` 和 `Rhema` 都已被占用。

目前本扩展只发布在 Marketplace 上。Open VSX 是可选的；下文保留了它的步骤，供
Cursor 或 VSCodium 的用户需要时使用。

[English](PUBLISHING.md)

## 首次发布前（只需做一次）

### Visual Studio Marketplace

用将来拥有本扩展的微软账号登录 <https://marketplace.visualstudio.com/manage>，
创建一个 publisher：ID 为 `rhema`（必须与 `package.json` 中的 `publisher`
相同），名称为 `Rhema`。手动发布只需要这一步：安装包就在该页面上传（见下文
第 5 步）。

从命令行发布还需要凭据。`vsce` 一直使用的 Azure DevOps 全局个人访问令牌（PAT）
将于 2026-12-01 停止使用；替代方式是 Microsoft Entra ID（`vsce publish
--azure-credential`），它适用于工作或学校账号，但官方文档没有说明个人微软账号能否
使用。依赖它之前，请先验证：

```bash
az login --allow-no-subscriptions
```

```bash
npx --yes @vscode/vsce@3.9.1 verify-pat --azure-credential rhema
```

### Open VSX

1. 在 <https://accounts.eclipse.org> 注册账号，并在“GitHub username”一栏填写
   下一步要用的 GitHub 账号。
2. 用该 GitHub 账号登录 <https://open-vsx.org>，在个人资料页关联 Eclipse 账号，
   并在同一页面签署 Publisher Agreement（发布者协议）。
3. 在 Access Tokens 页面生成一个令牌。令牌只显示一次，请保存在密码管理器中。
4. 创建命名空间：

   ```bash
   npx --yes ovsx@1.2.0 create-namespace rhema -p <令牌>
   ```

5. 按照 Open VSX wiki（<https://github.com/eclipse/openvsx/wiki>）中
   Namespace Access 页面的说明，申请命名空间的所有权，使只有其成员才能向其中
   发布。

## 每次发布

以下命令都在 `editors/vscode/` 目录中运行。

1. 修改 `package.json` 中的 `version`，运行 `npm install`（它会把版本号写入
   `package-lock.json`），并把 `CHANGELOG.md` 中“unreleased”一节改为该版本号
   和日期。扩展到 1.0 时，从 `package.json` 中删去 `"preview": true`。通过
   pull request 合并进 `main`，等待 CI 通过。
2. 用最新的 `rhema` 开发构建（在 `generator/` 中运行 `dune build @install`）
   做检查：

   ```bash
   npm ci && npm run check && npm test && npm run test:integration
   ```

3. 打包，并在 VS Code 中试用打出的包：

   ```bash
   npm run package
   ```

   ```bash
   code --install-extension rhema-language-X.Y.Z.vsix
   ```

   `npm run package` 会把 README 中的相对链接改写为指向 GitHub 上 `main`
   分支的地址，这样 Marketplace 页面上的链接才能打开。请发布这个命令打出的
   包，不要用其他方式打包。
4. 给提交打标签并推送：

   ```bash
   git tag vscode-vX.Y.Z && git push origin vscode-vX.Y.Z
   ```

5. 发布到 Marketplace：在
   <https://marketplace.visualstudio.com/manage/publishers/rhema> 页面，
   首次发布选择 **New extension > Visual Studio Code**，以后在扩展的菜单中选择
   **Update**，然后上传 `rhema-language-X.Y.Z.vsix`。如果上面的验证已经通过，也可以改用
   命令行：

   ```bash
   npm run publish:marketplace -- --azure-credential
   ```

6. 发布到 Open VSX：

   ```bash
   OVSX_PAT=<令牌> npm run publish:openvsx
   ```

7. 几分钟后检查两个页面：
   <https://marketplace.visualstudio.com/items?itemName=rhema.rhema-language>
   和 <https://open-vsx.org/extension/rhema/rhema-language>。

已发布的版本不能替换；发布有误时，请发布下一个补丁版本来修正。
