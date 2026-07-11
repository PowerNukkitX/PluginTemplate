param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[A-Za-z_][A-Za-z0-9_]*(\.[A-Za-z_][A-Za-z0-9_]*)*$')]
    [string]$Package,

    [Parameter(Mandatory = $true)]
    [ValidatePattern('^[A-Za-z_][A-Za-z0-9_]*$')]
    [string]$Name,

    [string[]]$Author = @('YourName'),
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

$packagePath = $Package.Replace('.', [System.IO.Path]::DirectorySeparatorChar)
$javaDirectory = Join-Path $projectRoot "src/main/java/$packagePath"
$javaFile = Join-Path $javaDirectory "$Name.java"
$pomFile = Join-Path $projectRoot 'pom.xml'
$ideaDirectory = Join-Path $projectRoot '.idea'
$ideaWorkspaceFile = Join-Path $ideaDirectory 'workspace.xml'

$plannedFiles = @(
    $pomFile,
    $javaFile
)
$conflictingFiles = @($plannedFiles | Where-Object { Test-Path -LiteralPath $_ })
if ($conflictingFiles.Count -gt 0 -and -not $Force) {
    $fileList = $conflictingFiles -join "`r`n"
    throw "These generated files already exist. Use -Force to overwrite only these files:`r`n$fileList"
}

New-Item -ItemType Directory -Force -Path $javaDirectory | Out-Null
New-Item -ItemType Directory -Force -Path $ideaDirectory | Out-Null

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

Write-Utf8NoBom $pomFile $pom
Write-Utf8NoBom $javaFile $javaSource
if ($Force -or -not (Test-Path -LiteralPath $ideaWorkspaceFile)) {
    Write-Utf8NoBom $ideaWorkspaceFile $ideaWorkspace
}

Write-Host "Created $Name in $projectRoot"

if (-not [string]::IsNullOrWhiteSpace($PSCommandPath) -and (Test-Path -LiteralPath $PSCommandPath)) {
    Remove-Item -LiteralPath $PSCommandPath -Force
}
