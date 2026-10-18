# AGP Assessment 1 - MonoGame Catchup

This is a catchup version of the [original Assessment 1 student repository](https://github.com/brockbankl/BFC-Advanced-Games-Programming-Assessment-1). GitHub access problems on college PCs have put some students behind through no fault of their own. This copy gives you the starting project and four classroom examples so you can catch up and start your own modifications.

**Assessment 1 only.** `main` contains the original student MonoGame 3D platformer baseline. Each lesson branch starts from that baseline and contains its own MonoGame code and assets. Make your own **private repository**, then take on the challenge of combining the examples into a working project, like we covered in lesson.

## Start here: copy-and-paste setup

Open **PowerShell** (or a PowerShell terminal in VS Code) and paste the whole block below. You need Git installed and your own GitHub account.

```powershell
$agpScript = Join-Path $env:TEMP ("AGP-Private-Copy-" + [guid]::NewGuid().ToString('N') + ".ps1")
Invoke-WebRequest 'https://raw.githubusercontent.com/brockbankl/BFC-Advanced-Games-Programming-Assessment-1-Catchup/main/New-PrivateAssessment1.ps1' -UseBasicParsing -OutFile $agpScript
if ((Get-FileHash -LiteralPath $agpScript -Algorithm SHA256).Hash -ne '369893373F8FFD40BAFDEE0F03529FEED6E994A758E3D7E8B555DEB6B4AB8F5B') { throw 'The script checksum did not match. Get the current command from the catchup README.' }
powershell -NoProfile -ExecutionPolicy Bypass -File $agpScript
```

Choose **1** for automatic setup. Enter a name for your new repository and your **own GitHub username**, then complete GitHub's browser/device sign-in. GitHub CLI is prepared in your user profile if needed; it does not need an administrator installation. The script checks the signed-in account, creates a **private, independent repository**, pushes `main` and all four lesson branches, and verifies them. It sets your commit identity and GitHub credential helper for this clone only.

GitHub sign-in happens through GitHub's browser prompts; do not type your GitHub password into the script. If the browser does not open automatically, follow the device-login URL and one-time code shown in the terminal. Git's `user.name` and `user.email` identify commit authors; they are separate from signing in.

Your project is saved under your Windows **Documents\projects** folder, using the repository name you chose (`AGP-Assessment-1` by default). The script prints the folder and repository URL, and opens the folder in VS Code when available. It will stop rather than overwrite an existing folder or repository. If it stops, keep the complete message visible for your lecturer.

You can also run the included [`New-PrivateAssessment1.ps1`](New-PrivateAssessment1.ps1) from an existing download. This helper copies the separate branches; combining them remains your challenge.

### Netlab PCs: use VS Code Source Control if sign-in is still broken

If the Netlab PCs have not been fixed yet, choose **2** when the script asks for a sign-in method. This downloads the project and prepares all five local branches, then opens VS Code. It leaves the clone ready to publish through VS Code's own GitHub sign-in, without requiring GitHub CLI authentication.

1. Open **Source Control** (`Ctrl+Shift+G`). Select **Publish to GitHub**, or run that command through `Ctrl+Shift+P`.
2. Sign in to **your GitHub account** when VS Code prompts you. This project is hosted on GitHub.
3. Choose **Publish to GitHub private repository** and an available repository name. VS Code creates your private repository and publishes the current `main` branch.
4. Use the branch name in VS Code's bottom status bar to switch to `particle-effect`, `post-process`, `shader` and `rising-water` in turn. For each, use **Publish Branch** in Source Control. This uploads the four separate branches; it does not merge them.
5. Return to `main`. On GitHub, check that your repository says **Private** and its branch menu contains all five branches.

This fallback uses the VS Code Source Control sign-in route we have been using in the labs. A VS Code sign-in does not necessarily sign GitHub CLI in as well. If terminal sign-in fails during automatic setup, the helper also prepares this VS Code fallback. Refer back to the **GitHub video and cheatsheet on the AGP Teams channel** if you need a refresher.

On shared PCs, sign out of the account you used when you finish, including the browser and VS Code or GitHub CLI as appropriate.

Official guidance: [GitHub CLI browser sign-in](https://cli.github.com/manual/gh_auth_login) and [publishing a private repository from VS Code](https://code.visualstudio.com/docs/sourcecontrol/repos-remotes#_publish-to-github).

## Manual alternative 1: clone the project and keep all four branches

Open PowerShell in `C:\Users\<your-login>\Documents\projects` and run:

```powershell
git clone https://github.com/brockbankl/BFC-Advanced-Games-Programming-Assessment-1-Catchup.git AGP-Assessment-1-Catchup
cd AGP-Assessment-1-Catchup

git branch --track particle-effect origin/particle-effect
git branch --track post-process origin/post-process
git branch --track shader origin/shader
git branch --track rising-water origin/rising-water
git branch
```

The final command should list `main` and the four lesson branches. A normal clone downloads the remote branches but only creates a local `main`; the four `git branch` commands create local copies ready to push to your own repository. Use a normal clone, without `--single-branch`.

## Manual alternative 2: make it your own private repository

1. Sign into your own GitHub account and select **New repository**.
2. Name it something like `AGP-Assessment-1` and choose **Private**.
3. Leave the README, `.gitignore` and licence options empty, then create the repository. It must be empty because these files already exist in your clone.
4. Copy your new repository's HTTPS URL. In the same terminal, run the commands below, replacing `YOUR-USERNAME` and `YOUR-REPO` with your own details:

```powershell
git remote rename origin catchup
git remote add origin https://github.com/YOUR-USERNAME/YOUR-REPO.git
git push --set-upstream origin main particle-effect post-process shader rising-water
git remote -v
```

`origin` should now point to your private repository. `catchup` points to this public teaching copy so you can find it again. Complete the browser sign-in if Git asks you to authenticate.

On your new GitHub repository, check that it says **Private** and that its branch menu contains all five branches. You now own an independent copy with the lesson branches included. Keep your assessment work in that private repository and share access with your lecturer as directed.

## Set up and run the starting project

Open the complete project folder in Visual Studio Code: the folder printed by the helper (`AGP-Assessment-1` by default), or `AGP-Assessment-1-Catchup` if you used the manual clone commands. The root should contain `Platformer3D.slnx`, `Source`, `Content` and `WindowsDX`.

1. Double-click `Setup-Assessment1.cmd` in File Explorer.
2. Wait for `ASSESSMENT 1 SETUP COMPLETE`.
3. Run this in the VS Code integrated terminal:

   ```powershell
   dotnet run --project ./WindowsDX/Platformer3D.csproj
   ```

Check that the baseline game runs before changing it. Close the game before switching branches or pulling changes.

You need Git, Visual Studio Code and the .NET 10 SDK. The setup script checks dependencies and can install a user-level SDK when college policy allows. The recommended VS Code extensions are **C# Dev Kit** and **HLSL Tools**. Setup is safe to run again.

Use **WindowsDX** on college Windows PCs. For macOS/Linux, install the .NET 10 SDK and use `dotnet run --project ./DesktopGL/Platformer3D.csproj`. The other inherited platform targets are optional.

## The four lesson branches

| Branch | Classroom example |
| --- | --- |
| `shader` | Cel shading with lighting bands, specular threshold and rim lighting. **Ctrl+F4** compares it with the original lighting. |
| `particle-effect` | Weather particles, starting with snow, with rain and wind settings ready to modify. |
| `post-process` | Posterisation applied to the finished scene after bloom and vignette. **Ctrl+T** toggles it. |
| `rising-water` | Animated water material and a spiral climbing level, with a short head start before the water rises. Water contact is harmless in this supplied example. |

The keyboard toggles are available in the normal Debug build used by `dotnet run`. Each example works on its own branch; combining them is your task.

## Branches, PRs and the catchup challenge

A **branch** keeps a set of changes separate while you develop and test them. A **pull request (PR)** proposes bringing a branch's changes into another branch and gives you a chance to inspect the diff first, like we covered in lesson.

A **merge conflict** happens when Git cannot automatically decide how overlapping changes should fit together. Some of these examples change the same parts of the game. Your challenge is to use PRs in **your own private repository**, work out how to resolve the conflicts, and combine all four features into a fully working project. Read the code, make your decisions and test the result as you go.

For a refresher, refer back to the **GitHub video and cheatsheet on the AGP Teams channel**.

Once you have combined the examples, use your own branches and PRs for your modifications. The catchup examples are a starting point for learning; follow the assessment brief for your own work and evidence.

## Troubleshooting

- **Setup reports `[FAIL]` or restore fails:** keep the full error visible and show your lecturer the message and PC number. Network or installation restrictions may need college IT support.
- **A lesson branch is missing from your private repository:** check `git branch`. All four branches must exist locally before the push in step 2.
- **Push fails with an authentication error:** sign in as the GitHub account that owns your private repository and check `git remote -v`.
- **Wrong folder:** open the whole repository, rather than only `Source`, `Content` or one C# file.
- **Setup script will not run:** double-click `Setup-Assessment1.cmd`, or run `powershell -NoProfile -ExecutionPolicy Bypass -File .\Setup-Assessment1.ps1`. The override applies to that process only.
- **Git is temporarily unavailable:** **Code > Download ZIP** gives you a snapshot of the selected branch for local practice. A ZIP does not include Git history or the other branches; use the clone route when Git works to complete the private-repository workflow.

## Project layout and credits

- `Source/`: C# gameplay, scenes, rendering and collision.
- `Content/`: source assets and the C# MonoGame Content Builder. It automatically includes effects from `Assets/Effects`; no separate MGCB Editor step is needed for the supplied lesson effects.
- `WindowsDX/`: the normal college target. `DesktopGL/`: macOS/Linux alternative.
- `docs/OFFICIAL_MONOGAME_RESOURCES.md`: official MonoGame references.
- `ORIGIN.md` and `upstream.json`: student baseline and starter-kit provenance.

The project preserves the MonoGame and Kenney licences and asset credits in [`LICENSE.md`](LICENSE.md) and the asset folders. The original starter kit is [MonoGame/Starter-Kit-3D-Platformer](https://github.com/MonoGame/Starter-Kit-3D-Platformer).

For the private-copy workflow, see GitHub's guidance on [duplicating a repository](https://docs.github.com/en/repositories/creating-and-managing-repositories/duplicating-a-repository).
