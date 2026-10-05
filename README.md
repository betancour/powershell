# PowerShell profile

Personal startup for Windows PowerShell 5.1 and PowerShell 7. A new shell loads `Profile.Core` only. Disk, process, network, and file commands load their own modules the first time you use them.

Repository: <https://github.com/betancour/powershell>

## Requirements

- Windows PowerShell 5.1 or PowerShell 7.
- Optional. [oh-my-posh](https://ohmyposh.dev/) for the prompt, Chocolatey for `choco` completion, and PSReadLine for the history filter.

Execution policy is not changed at startup. Set it once if this machine still blocks local scripts:

```powershell
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
```

## Install

Clone the repository, then dot-source it from the profile PowerShell already runs. Do not copy a single script out of the tree. The entry points find `src` and `config` from their own location.

Windows PowerShell 5.1 reads `Documents\WindowsPowerShell`. PowerShell 7 reads `Documents\PowerShell`. Each edition has its own profile file, and that file is what starts the configuration.

Windows PowerShell 5.1. Put this in `$PROFILE`:

```powershell
. 'C:\path\to\powershell\profiles\WindowsPowerShell\Microsoft.PowerShell_profile.ps1'
```

PowerShell 7. Put this in `$PROFILE`:

```powershell
. 'C:\path\to\powershell\profiles\PowerShell\Microsoft.PowerShell_profile.ps1'
```

The 5.1 file runs only when `$PSVersionTable.PSEdition` is `Desktop`. The 7 file runs only when it is `Core`. Each one then loads the shared console profile, which loads the configuration once per session.

Every host (console, VS Code, ISE). Put this in `$PROFILE.CurrentUserAllHosts` (`profile.ps1`) for the Documents folder of that edition:

```powershell
. 'C:\path\to\powershell\profiles\CurrentUserAllHosts.ps1'
```

You can install the edition profile and the all-hosts profile together. Startup still runs once.

oh-my-posh, the fallback prompt, host colors, and the history filter run only in `ConsoleHost`. Other hosts still get `PATH`, the module path, and the commands.

## Layout

```
profiles/
  WindowsPowerShell/
    Microsoft.PowerShell_profile.ps1   Profile that starts the config for 5.1.
  PowerShell/
    Microsoft.PowerShell_profile.ps1   Profile that starts the config for 7.
  CurrentUserCurrentHost.ps1    Shared console entry.
  CurrentUserAllHosts.ps1       Loads the shared startup once.
src/
  Start-Profile.ps1             Shared startup. Module path, core import, prompt.
  Modules/
    Profile.Core/               Prompt, PATH, history, Chocolatey, oh-my-posh.
    Profile.System/             uptime, df, proc, sysinfo.
    Profile.Network/            netinfo.
    Profile.FileSystem/         touch.
config/
  settings.psd1                 Theme, PATH, Chocolatey, host colors.
```

Each module has the same shape:

- `Profile.*.psd1` and `Profile.*.psm1` keep the module name. PowerShell autoload requires the folder and the root module to match, so those filenames stay fixed.
- `Public/` holds one exported command per file.
- `Private/` holds helpers. The module file lists every file it dot-sources. It does not execute whatever happens to be in the directory.
- `Formats/` holds the default views for the typed objects.
- Classes stay in the `.psm1`. `SystemReport.ToDisplayString()` calls the report formatters in that same file so Windows PowerShell 5.1 can resolve them. Public commands declare `OutputType` with the class name as a string. A type literal such as `[OutputType([DiskVolume])]` cannot see a class defined in the module file.

`Profile.Core` exports `Initialize-ProfileShell` and `Enable-ChocolateyCompletion`. The other commands stay private and are called from the startup script.

## Startup

1. The edition profile checks Desktop or Core, then dot-sources `CurrentUserCurrentHost.ps1`.
2. `CurrentUserCurrentHost.ps1` dot-sources `CurrentUserAllHosts.ps1`, which loads `src/Start-Profile.ps1` once per session.
3. Startup prepends `src/Modules` to the process `PSModulePath` when it is not already there.
4. It imports `Profile.Core`.
5. `Initialize-ProfileShell` reads `config/settings.psd1` with `Import-PowerShellDataFile`.
6. It applies host colors, the history filter, process `PATH` entries, the fallback prompt, and Chocolatey stubs.
7. If oh-my-posh returns a short session launcher, startup runs that launcher in the profile scope so it can replace the prompt.
8. The first use of `uptime`, `df`, `proc`, `sysinfo`, `netinfo`, or `touch` autoloads that command's module.

There is no startup banner and no change to `$ErrorActionPreference`.

The fallback prompt is installed before oh-my-posh runs. If the theme or the executable is rejected, the fallback remains:

```text
[DOMAIN\user] C:\current\path >
```

On a machine without a Windows identity, the name comes from `USERNAME` or `USER`.

## Commands

| Alias | Command | Module | What it returns |
| --- | --- | --- | --- |
| `uptime` | `Get-SystemUptime` | Profile.System | Boot time and elapsed `TimeSpan` |
| `df` | `Get-DiskUsage` | Profile.System | One disk object per volume |
| `proc` | `Get-ProcessDetail` | Profile.System | One process object |
| `sysinfo` | `Get-SystemReport` | Profile.System | One machine snapshot |
| `netinfo` | `Get-NetworkInfo` | Profile.Network | One adapter object |
| `touch` | `Update-FileStamp` | Profile.FileSystem | Nothing, or a `FileInfo` with `-PassThru` |

`uptime` is `Get-SystemUptime`, so it does not hide PowerShell 7's `Get-Uptime`.

### uptime

```powershell
uptime
(Get-SystemUptime).Elapsed.TotalHours
```

The default view prints `Uptime: N Days, N Hours, N Minutes, N Seconds`. `LastBoot` and `Elapsed` stay on the object. The value comes from `Win32_OperatingSystem`.

### df

```powershell
df
Get-DiskUsage -DriveType Local, Removable
```

`-DriveType` accepts `Local`, `Removable`, `Network`, and `Optical`. The default is `Local` (`DriveType=3`). Network mappings are skipped unless you ask for them, because a disconnected mapping can stall the call. Pass at least one type and at most four.

Empty media is skipped. Used space is `Size - Free` in bytes. The object carries bytes, gigabytes, and percentages. The default table shows `Name`, `Volume`, `FS`, `TotalGB`, `UsedGB`, `FreeGB`, and `Used%`.

### proc

```powershell
proc -Top 10
Get-ProcessDetail -Name explorer -IncludeFileInfo
Get-ProcessDetail -Top 5 -OrderBy CpuTime
```

| Parameter | Meaning |
| --- | --- |
| `Name` | One or more process names. Wildcards are allowed. |
| `Top` | Keep this many rows after sorting. `1` through `500`. |
| `OrderBy` | `Memory` (default when `-Top` is set), `CpuTime`, `Name`, or `Id`. |
| `IncludeFileInfo` | Fill `Path` and `Description`. |

Sorting runs only when `-Top` or `-OrderBy` is passed. `CPU(s)` is cumulative processor time in seconds, from `TotalProcessorTime`. `Mem(MB)` is `WorkingSet64`. `Path` and `Description` stay empty unless `-IncludeFileInfo` is set, because reading them touches every image and can be slow or denied. Access denied becomes an empty string.

The default table shows `Id`, `Name`, `CPU(s)`, `Mem(MB)`, and `Threads`.

### sysinfo

```powershell
sysinfo
sysinfo -Top 0
(Get-SystemReport).MemoryUsedGB
```

`-Top` is how many processes to include, ordered by working set. The default is `10`. `0` skips the process list. The maximum is `50`.

The default view is a text box. The object is still there for the pipeline. The box uses these labels:

| Label | Source |
| --- | --- |
| Product, release, build, architecture | `Win32_OperatingSystem`, then `HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion` for `DisplayVersion` and `CurrentBuild.UBR` |
| Host, CPU, logical processors | Computer system and `Win32_Processor` |
| Uptime | Now minus last boot |
| IPv4 | First non-loopback, non-APIPA address on an up adapter. An adapter with a gateway wins. |
| Memory | Visible physical memory, used and total, in GB |
| CPU now | `Win32_PerfFormattedData_PerfOS_Processor` where `Name = '_Total'` |
| System drive | `$env:SystemDrive` when it looks like `C:`, otherwise `C:` |
| Processes | Count of `Get-Process` |
| Sessions | Distinct `SessionId` values of `explorer.exe` |
| Top processes | Working set. `CPU(s)` in that table is cumulative processor time, not the live percentage. |

`CPU now` is the only live percentage. Process CPU is never labeled as a percentage. Queries are local CIM calls. The command does not open a WinRM session.

### netinfo

```powershell
netinfo
Get-NetworkInfo -All | Select-Object Name, IPv4Address, DnsServer
```

Reads `System.Net.NetworkInformation.NetworkInterface`. Loopback adapters are omitted. Adapters that are not `Up` are omitted unless you pass `-All`. DNS values are address strings. Gateway and unicast values are read from their `Address` property when that property is an `IPAddress`.

The default table shows `Name`, `Status`, `IPv4`, `Gateway`, `DNS`, and `DHCP`. `Description`, `MacAddress`, and `IPv6Address` are on the object.

### touch

```powershell
touch .\notes.txt
'a.txt', 'b.txt' | Update-FileStamp -PassThru
touch .\notes.txt -WhatIf
```

| Parameter | Meaning |
| --- | --- |
| `LiteralPath` | File path or paths. `Path` and `FullName` are accepted, including from the pipeline. Wildcards in a name are literal. |
| `PassThru` | Return the `FileInfo` after the update. |
| `WhatIf` / `Confirm` | Supported. The action is `Update file timestamp`. |

An existing file is opened with `OpenOrCreate`, which does not truncate it, and its last-write and last-access times are set to now. A missing file is created empty. A missing parent directory is an error and is not created. A directory path is an error.

## Objects

Default formatting is applied by the module format files. `Select-Object *` still shows every property.

| Type name | Command | Default view |
| --- | --- | --- |
| `Profile.SystemUptime` | `uptime` | Sentence from `ToString()` |
| `Profile.DiskVolume` | `df` | Table of size and percent used |
| `Profile.ProcessDetail` | `proc` | Table without path or description |
| `Profile.ProcessSnapshot` | rows inside `sysinfo` | `Id`, `Name`, `CPU(s)`, `Mem(MB)` |
| `Profile.SystemReport` | `sysinfo` | Text box from `ToDisplayString()` |
| `Profile.NetworkAdapterInfo` | `netinfo` | Adapter table |

## Settings

`config/settings.psd1` is data. `Import-PowerShellDataFile` loads it and rejects script blocks, so an expression in that file cannot run. Unknown keys are ignored. A missing file, or a file that fails to load, falls back to the defaults below. A failed load writes a warning.

```powershell
@{
    ThemeConfig = 'C:\Users\betan\OneDrive\.posh_themes\config.omp.json'
    PathEntries = @()
    EnableChocolateyCompletion = $true
    HostColor = @{
        ErrorForegroundColor   = 'Red'
        WarningForegroundColor = 'Yellow'
        VerboseForegroundColor = 'Green'
        DebugForegroundColor   = 'Magenta'
    }
}
```

| Key | Default | Effect |
| --- | --- | --- |
| `ThemeConfig` | none | oh-my-posh theme. See the checks below. A missing file is verbose, not a warning. |
| `PathEntries` | empty | Absolute directories appended to the **process** `PATH` only. User and machine `PATH` are never written. |
| `EnableChocolateyCompletion` | `$true` | Install `refreshenv` and `Update-SessionEnvironment` stubs, and arm `choco` completion. Chocolatey itself stays unloaded. |
| `HostColor` | the four colors above | ConsoleHost colors. When this key is present it replaces the whole default map. Names that are not `[ConsoleColor]` values are ignored. Properties the host does not have are ignored. |

A `PathEntries` item is skipped when it is relative, a UNC path, missing, a drive root, or world-writable. ACL failure is treated as world-writable. An entry already on `PATH` is left where it is.

## Security

- The profile never calls `Set-ExecutionPolicy`.
- Settings are loaded as data, not invoked.
- The module loader dot-sources an explicit file list. Dropping a script into `Public` or `Private` does not make startup run it.
- Theme files must end in `.omp.json` and must live under `USERPROFILE`, under `HOME` when that path is the user profile or inside it, or under `OneDrive`, `OneDriveConsumer`, or `OneDriveCommercial`. Anything else is ignored.
- oh-my-posh is accepted only from `oh-my-posh.exe` (`CommandType Application`). The process must exit `0`, the text must contain `POSH_SESSION_ID`, and the text must be at most 16,384 characters. Empty output is rejected. That launcher is run from `Start-Profile.ps1`, in the profile scope. It is not cached across sessions, because the session id has to be new.
- Chocolatey is imported only when `helpers\chocolateyProfile.psm1` resolves inside `$env:ChocolateyInstall`. A prefix such as `C:\Users\betan-evil` does not match `C:\Users\betan`.
- The history filter is installed only when PSReadLine is already loaded. The profile does not call `Get-Command PSReadLine`, which would autoload it. The filter drops a line that contains a secret-style switch (`--password`, `--token`, and the same family), an assignment such as `token=`, a `Bearer` token, or a PEM private-key banner. A bare `pwd` or `Get-Location` is kept, because the password pattern requires a switch or `=` / `:`.
- `PATH` changes stay in the process environment.

## Performance

- `Profile.System`, `Profile.Network`, and `Profile.FileSystem` are not imported at startup. PowerShell loads them when their exported command or alias is first used.
- Manifests export named functions and aliases. They do not use wildcards.
- Chocolatey is not imported at startup. The first `refreshenv`, `Update-SessionEnvironment`, or Tab on `choco` loads it. The first Tab returns the built-in command names (`install`, `upgrade`, and the rest). Later Tab presses return immediately so Chocolatey's own completer can answer. A failed load is attempted once per session.
- `df` queries local fixed disks unless `-DriveType` says otherwise.
- `proc` does not read file path or description unless `-IncludeFileInfo` is set.
- `netinfo` and the report's IPv4 use `NetworkInterface` instead of `Get-NetIPConfiguration`.
- `sysinfo` uses one set of local CIM queries and the current-version registry key. It does not map build numbers in code.
- Host colors, the history filter, each `PATH` entry, the fallback prompt, Chocolatey, and oh-my-posh each have their own error path. One failure does not skip the rest.

## After you edit

Open a new session after you change a class in `Profile.System.psm1` or `Profile.Network.psm1`. `Import-Module -Force` does not reload PowerShell classes cleanly.

Command help is on the functions:

```powershell
Get-Help Get-DiskUsage -Full
Get-Help Update-FileStamp -Examples
```
