param(
    [string]$Package,

    [string]$Name,

    [string[]]$Author,
    [string]$Version = '1.0.0',
    [string[]]$Api = @('3.0.0'),
    [string]$Description,
    [string]$Website,
    [string]$Prefix,
    [string[]]$Depend,
    [string[]]$SoftDepend,
    [string[]]$LoadBefore,
    [ValidateSet('STARTUP', 'POSTWORLD')]
    [string]$Order,
    [string[]]$Features,
    [string]$OutputDirectory = '.',
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Escape-JavaString {
    param([string]$Value)

    return $Value.Replace('\', '\\').Replace('"', '\"')
}

function Format-JavaStringArray {
    param(
        [string]$PropertyName,
        [string[]]$Values
    )

    if ($null -eq $Values -or $Values.Count -eq 0) {
        return $null
    }

    $escapedValues = @($Values | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object {
        '                "' + (Escape-JavaString $_) + '"'
    })

    if ($escapedValues.Count -eq 0) {
        return $null
    }

    return @(
        "        $PropertyName = {"
        ($escapedValues -join ",`r`n")
        '        }'
    ) -join "`r`n"
}

function Add-AnnotationEntry {
    param(
        [System.Collections.Generic.List[string]]$Entries,
        [string]$Entry
    )

    if (-not [string]::IsNullOrWhiteSpace($Entry)) {
        $Entries.Add($Entry)
    }
}

function ConvertTo-JavaIdentifier {
    param(
        [string]$Value,
        [switch]$LowerCase
    )

    if ([string]::IsNullOrWhiteSpace($Value)) {
        return $null
    }

    $parts = @($Value -split '[^A-Za-z0-9_]+' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($parts.Count -eq 0) {
        return $null
    }

    $identifier = $parts -join ''
    if ($LowerCase) {
        $identifier = $identifier.ToLowerInvariant()
    }

    if ($identifier -notmatch '^[A-Za-z_]') {
        $identifier = "_$identifier"
    }

    return $identifier
}

function Get-GitHubRepositoryInfo {
    param([string]$RepositoryPath)

    try {
        $remoteUrl = git -C $RepositoryPath config --get remote.origin.url 2>$null
    }
    catch {
        return $null
    }

    if ([string]::IsNullOrWhiteSpace($remoteUrl)) {
        return $null
    }

    $remoteUrl = $remoteUrl.Trim()
    if ($remoteUrl -match '^https://github\.com/([^/]+)/([^/]+?)(?:\.git)?/?$' -or
        $remoteUrl -match '^git@github\.com:([^/]+)/([^/]+?)(?:\.git)?$') {
        return [PSCustomObject]@{
            Owner = $Matches[1]
            Name = $Matches[2]
            Url = "https://github.com/$($Matches[1])/$($Matches[2])"
        }
    }

    return $null
}

function Write-Utf8NoBom {
    param(
        [string]$Path,
        [string]$Value
    )

    $encoding = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($Path, $Value, $encoding)
}

if ([System.IO.Path]::IsPathRooted($OutputDirectory)) {
    $projectRoot = [System.IO.Path]::GetFullPath($OutputDirectory)
}
else {
    $projectRoot = [System.IO.Path]::GetFullPath((Join-Path (Get-Location) $OutputDirectory))
}

if (-not (Test-Path -LiteralPath $projectRoot)) {
    New-Item -ItemType Directory -Force -Path $projectRoot | Out-Null
}

$repositoryInfo = Get-GitHubRepositoryInfo $projectRoot
if ($null -eq $repositoryInfo) {
    $repositoryInfo = Get-GitHubRepositoryInfo (Get-Location)
}

$repositoryName = Split-Path -Leaf $projectRoot
$repositoryOwner = 'YourName'
$repositoryUrl = $null
if ($null -ne $repositoryInfo) {
    $repositoryName = $repositoryInfo.Name
    $repositoryOwner = $repositoryInfo.Owner
    $repositoryUrl = $repositoryInfo.Url
}

if ([string]::IsNullOrWhiteSpace($Name)) {
    $Name = ConvertTo-JavaIdentifier $repositoryName
}
if ([string]::IsNullOrWhiteSpace($Package)) {
    $packageOwner = ConvertTo-JavaIdentifier $repositoryOwner -LowerCase
    $packageName = ConvertTo-JavaIdentifier $repositoryName -LowerCase
    $Package = "io.github.$packageOwner.$packageName"
}
if ($null -eq $Author -or @($Author | Where-Object { -not [string]::IsNullOrWhiteSpace($_) }).Count -eq 0) {
    $Author = @($repositoryOwner)
}
if ([string]::IsNullOrWhiteSpace($Website) -and -not [string]::IsNullOrWhiteSpace($repositoryUrl)) {
    $Website = $repositoryUrl
}

if ($Name -notmatch '^[A-Za-z_][A-Za-z0-9_]*$') {
    throw "Name must be a valid Java class name, but was '$Name'."
}
if ($Package -notmatch '^[A-Za-z_][A-Za-z0-9_]*(\.[A-Za-z_][A-Za-z0-9_]*)*$') {
    throw "Package must be a valid Java package name, but was '$Package'."
}

$packagePath = $Package.Replace('.', [System.IO.Path]::DirectorySeparatorChar)
$javaDirectory = Join-Path $projectRoot "src/main/java/$packagePath"
$javaFile = Join-Path $javaDirectory "$Name.java"
$pomFile = Join-Path $projectRoot 'pom.xml'
$readmeFile = Join-Path $projectRoot 'README.md'
$ideaDirectory = Join-Path $projectRoot '.idea'
$ideaWorkspaceFile = Join-Path $ideaDirectory 'workspace.xml'
$githubWorkflowDirectory = Join-Path $projectRoot '.github/workflows'
$githubWorkflowFile = Join-Path $githubWorkflowDirectory 'build.yml'

$plannedFiles = @(
    $pomFile,
    $javaFile,
    $githubWorkflowFile
)
$conflictingFiles = @($plannedFiles | Where-Object { Test-Path -LiteralPath $_ })
if ($conflictingFiles.Count -gt 0 -and -not $Force) {
    $fileList = $conflictingFiles -join "`r`n"
    throw "These generated files already exist. Use -Force to overwrite only these files:`r`n$fileList"
}

New-Item -ItemType Directory -Force -Path $javaDirectory | Out-Null
New-Item -ItemType Directory -Force -Path $ideaDirectory | Out-Null
New-Item -ItemType Directory -Force -Path $githubWorkflowDirectory | Out-Null

$annotationEntries = [System.Collections.Generic.List[string]]::new()
Add-AnnotationEntry $annotationEntries ('        name = "' + (Escape-JavaString $Name) + '"')
Add-AnnotationEntry $annotationEntries ('        version = "' + (Escape-JavaString $Version) + '"')
Add-AnnotationEntry $annotationEntries (Format-JavaStringArray 'authors' $Author)
Add-AnnotationEntry $annotationEntries (Format-JavaStringArray 'api' $Api)

if (-not [string]::IsNullOrWhiteSpace($Description)) {
    Add-AnnotationEntry $annotationEntries ('        description = "' + (Escape-JavaString $Description) + '"')
}
if (-not [string]::IsNullOrWhiteSpace($Website)) {
    Add-AnnotationEntry $annotationEntries ('        website = "' + (Escape-JavaString $Website) + '"')
}
if (-not [string]::IsNullOrWhiteSpace($Prefix)) {
    Add-AnnotationEntry $annotationEntries ('        prefix = "' + (Escape-JavaString $Prefix) + '"')
}

Add-AnnotationEntry $annotationEntries (Format-JavaStringArray 'depend' $Depend)
Add-AnnotationEntry $annotationEntries (Format-JavaStringArray 'softDepend' $SoftDepend)
Add-AnnotationEntry $annotationEntries (Format-JavaStringArray 'loadBefore' $LoadBefore)

if (-not [string]::IsNullOrWhiteSpace($Order)) {
    Add-AnnotationEntry $annotationEntries "        order = PluginLoadOrder.$Order"
}

Add-AnnotationEntry $annotationEntries (Format-JavaStringArray 'features' $Features)

$annotationBody = $annotationEntries -join ",`r`n"
$loadOrderImport = ''
if (-not [string]::IsNullOrWhiteSpace($Order)) {
    $loadOrderImport = "import org.powernukkitx.plugin.PluginLoadOrder;`r`n"
}

$javaSource = @"
package $Package;

import org.powernukkitx.plugin.PluginBase;
${loadOrderImport}import org.powernukkitx.plugin.annotation.PluginMeta;

@PluginMeta(
$annotationBody
)
public class $Name extends PluginBase {

    private static $Name INSTANCE;

    @Override
    public void onEnable() {
        INSTANCE = this;
    }

    public static $Name get() {
        return INSTANCE;
    }
}
"@

$pom = @"
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <groupId>$Package</groupId>
    <artifactId>$Name</artifactId>
    <version>$Version</version>

    <properties>
        <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
        <project.reporting.outputEncoding>UTF-8</project.reporting.outputEncoding>
        <maven.compiler.encoding>UTF-8</maven.compiler.encoding>
        <maven.compiler.source>21</maven.compiler.source>
        <maven.compiler.target>21</maven.compiler.target>
    </properties>

    <repositories>
        <repository>
            <id>PowerNukkitX-releases</id>
            <name>PowerNukkitX Repository</name>
            <url>https://repo.powernukkitx.org/releases</url>
        </repository>
        <repository>
            <id>opencollab-repository-maven-releases</id>
            <name>Opencollab Repository releases</name>
            <url>https://repo.opencollab.dev/maven-releases</url>
        </repository>
        <repository>
            <id>opencollab-repository-maven-snapshots</id>
            <name>Opencollab Repository snapshots</name>
            <url>https://repo.opencollab.dev/maven-snapshots</url>
        </repository>
    </repositories>

    <build>
        <finalName>`${project.artifactId}</finalName>
        <sourceDirectory>`${basedir}/src/main/java</sourceDirectory>
        <plugins>
            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-compiler-plugin</artifactId>
                <version>3.10.0</version>
                <configuration>
                    <source>`${maven.compiler.source}</source>
                    <target>`${maven.compiler.target}</target>
                    <encoding>`${maven.compiler.encoding}</encoding>
                    <proc>full</proc>
                    <annotationProcessors>
                        <annotationProcessor>org.powernukkitx.plugin.annotation.PluginAnnotationProcessor</annotationProcessor>
                    </annotationProcessors>
                    <annotationProcessorPaths>
                        <path>
                            <groupId>org.powernukkitx</groupId>
                            <artifactId>server</artifactId>
                            <version>nightly-SNAPSHOT</version>
                        </path>
                    </annotationProcessorPaths>
                </configuration>
            </plugin>
            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-shade-plugin</artifactId>
                <version>3.5.1</version>
                <executions>
                    <execution>
                        <phase>package</phase>
                        <goals>
                            <goal>shade</goal>
                        </goals>
                    </execution>
                </executions>
            </plugin>
        </plugins>
    </build>

    <dependencies>
        <dependency>
            <groupId>org.powernukkitx</groupId>
            <artifactId>server</artifactId>
            <version>nightly-SNAPSHOT</version>
            <scope>provided</scope>
        </dependency>
    </dependencies>
</project>
"@

$ideaWorkspace = @'
<?xml version="1.0" encoding="UTF-8"?>
<project version="4">
  <component name="PropertiesComponent">{}</component>
</project>
'@

$readme = @"
# $Name

A plugin for [PowerNukkitX](github.com/PowerNukkitX/PowerNukkitX)
"@

$githubWorkflow = @'
name: Build and Release

on:
  workflow_dispatch:
  push:
    tags:
      - 'v*'
    branches:
      - '**'
  pull_request:

permissions:
  contents: write

jobs:
  build-maven:
    runs-on: ubuntu-latest
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4
        with:
          fetch-depth: 0

      - name: Setup Java
        uses: actions/setup-java@v4
        with:
          distribution: 'temurin'
          java-version: '21'

      - name: Build with Maven
        run: mvn -B package -DskipTests=false -Darguments="-Dmaven.javadoc.skip=true"

      - name: Read project metadata
        id: project
        shell: bash
        run: |
          ARTIFACT_ID=$(mvn help:evaluate -Dexpression=project.artifactId -q -DforceStdout)
          VERSION=$(mvn help:evaluate -Dexpression=project.version -q -DforceStdout)
          FINAL_NAME=$(mvn help:evaluate -Dexpression=project.build.finalName -q -DforceStdout)

          echo "artifact_id=$ARTIFACT_ID" >> "$GITHUB_OUTPUT"
          echo "version=$VERSION" >> "$GITHUB_OUTPUT"
          echo "final_name=$FINAL_NAME" >> "$GITHUB_OUTPUT"
          echo "tag=v$VERSION" >> "$GITHUB_OUTPUT"
          echo "jar_path=target/$FINAL_NAME.jar" >> "$GITHUB_OUTPUT"

      - name: Verify artifact
        shell: bash
        run: |
          if [ ! -f "${{ steps.project.outputs.jar_path }}" ]; then
            echo "${{ steps.project.outputs.jar_path }} was not created"
            exit 1
          fi

      - name: Upload artifacts
        uses: actions/upload-artifact@v4
        if: success()
        with:
          name: ${{ steps.project.outputs.artifact_id }}
          path: ${{ steps.project.outputs.jar_path }}

      - name: Create GitHub release
        if: github.event_name == 'push' && (github.ref_type == 'tag' || github.ref_name == github.event.repository.default_branch)
        env:
          GH_TOKEN: ${{ github.token }}
        run: |
          if [ "${{ github.ref_type }}" = "tag" ]; then
            RELEASE_TAG="${{ github.ref_name }}"
          else
            RELEASE_TAG="${{ steps.project.outputs.tag }}"
          fi

          if gh release view "$RELEASE_TAG" >/dev/null 2>&1; then
            gh release upload "$RELEASE_TAG" "${{ steps.project.outputs.jar_path }}" --clobber
          else
            gh release create "$RELEASE_TAG" "${{ steps.project.outputs.jar_path }}" --target "${{ github.sha }}" --title "$RELEASE_TAG" --notes "Automated release for $RELEASE_TAG"
          fi
'@

Write-Utf8NoBom $pomFile $pom
Write-Utf8NoBom $javaFile $javaSource
Write-Utf8NoBom $readmeFile $readme
Write-Utf8NoBom $githubWorkflowFile $githubWorkflow
if ($Force -or -not (Test-Path -LiteralPath $ideaWorkspaceFile)) {
    Write-Utf8NoBom $ideaWorkspaceFile $ideaWorkspace
}

$runConfigurationDirectory = Join-Path $projectRoot '.run'
if (Test-Path -LiteralPath $runConfigurationDirectory) {
    Remove-Item -LiteralPath $runConfigurationDirectory -Recurse -Force
}

if (-not [string]::IsNullOrWhiteSpace($PSCommandPath) -and (Test-Path -LiteralPath $PSCommandPath)) {
    Remove-Item -LiteralPath $PSCommandPath -Force
}

$gitRoot = git -C $projectRoot rev-parse --show-toplevel 2>$null
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($gitRoot)) {
    throw "Generated project, but could not stage changes because '$projectRoot' is not inside a Git repository."
}

git -C $gitRoot.Trim() add -A
if ($LASTEXITCODE -ne 0) {
    throw "Generated project, but failed to stage changes."
}

git -C $gitRoot.Trim() diff --cached --quiet
if ($LASTEXITCODE -eq 0) {
    Write-Host "No staged changes to commit."
}
elseif ($LASTEXITCODE -eq 1) {
    git -C $gitRoot.Trim() commit --quiet -m "Generate plugin project"
    if ($LASTEXITCODE -ne 0) {
        throw "Generated project and staged changes, but failed to commit."
    }
}
else {
    throw "Generated project and staged changes, but failed to check staged changes."
}

Write-Host "Created $Name in $projectRoot"

exit 0
