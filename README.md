# PowerNukkitX Plugin Generator

PowerShell script for generating a minimal PowerNukkitX plugin project.

## Usage

Generate a plugin in the current directory:

```powershell
.\generate.ps1 `
  -Package org.powernukkitx.example `
  -Name ExamplePlugin
```

`Package` is used as the Java package and Maven `groupId`.
`Name` is used as the plugin name, Maven `artifactId`, jar name, and main class.

## Optional Metadata

`Author` is optional and defaults to `YourName`:

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

## Build The Plugin

Open the directory in IntelliJ or run Maven there:

```powershell
mvn package
```

The jar is written to:

```text
target/ExamplePlugin.jar
```
