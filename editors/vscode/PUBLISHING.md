# Publishing the VS Code extension

The extension is published under the publisher and namespace `project-rhm`
to two registries: the **Visual Studio Marketplace**, which VS Code uses,
and **Open VSX**, which Cursor, VSCodium and other editors built on VS Code
use. Its version is its own (`version` in `package.json`), independent of
the `rhema` package.

[中文](PUBLISHING.zh.md)

## Once, before the first release

### Visual Studio Marketplace

Sign in at <https://marketplace.visualstudio.com/manage> with the Microsoft
account that will own the extension, and create a publisher with the ID
`project-rhm` (it must equal `publisher` in `package.json`) and the name
`Project RHM`. That is all a release by hand needs: the package is uploaded
on that page (step 5 below).

Publishing from the command line needs a credential as well. Azure DevOps
personal access tokens of the global kind, which `vsce` has used, stop
working on 2026-12-01; their replacement is Microsoft Entra ID
(`vsce publish --azure-credential`), which works for work and school
accounts but is not documented for personal Microsoft accounts. Check
before relying on it:

```bash
az login --allow-no-subscriptions
```

```bash
npx --yes @vscode/vsce@3.9.1 verify-pat --azure-credential project-rhm
```

### Open VSX

1. Create an account at <https://accounts.eclipse.org>, and fill in the
   GitHub username field with the GitHub account you will use below.
2. Sign in at <https://open-vsx.org> with that GitHub account, link the
   Eclipse account on your profile page, and sign the Publisher Agreement
   there.
3. On the Access Tokens page, generate a token. Keep it in a password
   manager; it is shown once.
4. Create the namespace:

   ```bash
   npx --yes ovsx@1.2.0 create-namespace project-rhm -p <token>
   ```

5. Ask for ownership of the namespace, so that only its members can
   publish into it, as the Namespace Access page of the Open VSX wiki
   (<https://github.com/eclipse/openvsx/wiki>) describes.

## Each release

All commands run in `editors/vscode/`.

1. Set `version` in `package.json`, run `npm install` (it records the
   version in `package-lock.json`), and move the `CHANGELOG.md` entry from
   "unreleased" to the version and date. Remove `"preview": true` from
   `package.json` when the extension reaches 1.0. Merge to `main` through a
   pull request and wait for CI.
2. Check, with a current development build of `rhema`
   (`dune build @install` in `generator/`):

   ```bash
   npm ci && npm run check && npm test && npm run test:integration
   ```

3. Package, and try the result in VS Code:

   ```bash
   npm run package
   ```

   ```bash
   code --install-extension rhema-X.Y.Z.vsix
   ```

   `npm run package` rewrites the README's relative links to point at
   `main` on GitHub, so the Marketplace page links work; publish this file,
   not a package made another way.
4. Tag the commit and push the tag:

   ```bash
   git tag vscode-vX.Y.Z && git push origin vscode-vX.Y.Z
   ```

5. Publish to the Marketplace: on
   <https://marketplace.visualstudio.com/manage/publishers/project-rhm>,
   choose **New extension > Visual Studio Code** for the first release, or
   **Update** in the extension's menu afterwards, and upload
   `rhema-X.Y.Z.vsix`. From the command line instead, once the check above
   succeeds:

   ```bash
   npm run publish:marketplace -- --azure-credential
   ```

6. Publish to Open VSX:

   ```bash
   OVSX_PAT=<token> npm run publish:openvsx
   ```

7. Check both pages a few minutes later:
   <https://marketplace.visualstudio.com/items?itemName=project-rhm.rhema>
   and <https://open-vsx.org/extension/project-rhm/rhema>.

A published version cannot be replaced; a mistake is fixed by publishing
the next patch version.
