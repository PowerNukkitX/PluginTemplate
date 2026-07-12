# PowerNukkitX Plugin Generator

PowerShell script for generating a minimal PowerNukkitX plugin project.

## Quick Start

Create a new repository from this GitHub template, clone your new repository, open it in IntelliJ, then run the `Generate Plugin` run configuration.
<br>
<br>
<br>
<br>
<br>
<br>

## Optional Metadata
You can also run the generator from PowerShell in the repository root:

```powershell
.\generate.ps1
```
The script creates a Maven plugin project using defaults from the GitHub `origin` remote.

After generation, import the Maven project when prompted. The generator script deletes itself after a successful run.

`Author` is optional and defaults to the GitHub repository owner when available:

```powershell
.\generate.ps1 `
  -Package org.powernukkitx.example `
  -Name ExamplePlugin `
  -Author YourName
```

All supported `PluginMeta` values can be supplied:

```powershell
.\generate.ps1 `
  -Package org.powernukkitx.example `
  -Name ExamplePlugin `
  -Author YourName `
  -Version 1.0.0 `
  -Api 3.0.0 `
  -Description "Example plugin" `
  -Website "https://example.com" `
  -Prefix Example `
  -Depend EconomyAPI `
  -SoftDepend PlaceholderAPI `
  -LoadBefore OtherPlugin `
  -Order POSTWORLD `
  -Features "feature-a","feature-b"
```

Supported optional parameters:

```text
Package
Name
Author
Version
Api
Description
Website
Prefix
Depend
SoftDepend
LoadBefore
Order
Features
Force
```

`Order` accepts `STARTUP` or `POSTWORLD`.
<br>
<br>
<br>
## Build The Plugin

Open the directory in IntelliJ or run Maven there:

```powershell
mvn package
```

The jar is written to:

```text
target/ExamplePlugin.jar
```
