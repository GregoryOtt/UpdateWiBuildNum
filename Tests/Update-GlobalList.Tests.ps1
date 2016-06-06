$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$sut = (Split-Path -Leaf $MyInvocation.MyCommand.Path).Replace(".Tests.", ".")
. "$here\..\$sut" # This file resides in a sub folder Tests.

# Loading configuration file
$configFilePath = Get-ChildItem -Path $here -Filter "*Config.json" | Select-Object -First 1
if($configFilePath -eq $null)
{
    Write-Warning "Unable to load configuration file, file note found. You must have a configuration file named '*Config.json' in the $here directory."
}
else
{
    Write-Output "Loading config file from: $($configFilePath.FullName)"
    $config = Get-Content $($configFilePath.FullName) | ConvertFrom-Json
}

Describe "Global working" {
    Context "when tests configuration file is found" {
        It "environment variables are set" {
            $env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI | Should Be $config.Environment.Server
            $env:SYSTEM_TEAMPROJECT | Should Be $config.Environment.TeamProject
            $env:BUILD_BUILDNUMBER | Should Be $config.Environment.BuildNumber
            $env:AGENT_HOMEDIRECTORY | Should Be $config.Environment.AgentHomeDir
        }
    }
    
    BeforeEach {
        $env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI = $config.Environment.Server
        $env:SYSTEM_TEAMPROJECT = $config.Environment.TeamProject
        $env:BUILD_BUILDNUMBER = $config.Environment.BuildNumber
        $env:AGENT_HOMEDIRECTORY = $config.Environment.AgentHomeDir
    }

    AfterEach {
        $env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI = $null
        $env:SYSTEM_TEAMPROJECT = $null
        $env:BUILD_BUILDNUMBER = $null
        $env:AGENT_HOMEDIRECTORY = $null
    }
}

Describe "Test Update-GlobalListXml" {
    
    Context "when project collection globallist does not exists" {
        It "it is created and the buildNumber is added as listitem" {
            $buildNumber = "20160606.1"
            $glName = "Builds - $($config.Environment.TeamProject)"
            $gls = Update-GlobalListXml -globalListsDoc $null -glName $glName -buildNumber $buildNumber
            $gl = $gls.GLOBALLISTS.GLOBALLIST | Where-Object { $_.name -eq $glName }
            $gl | Should Not BeNullOrEmpty 
            $gl.Length | Should BeNullOrEmpty
            $gl.LISTITEM | Where-Object { $_.value -eq $buildNumber } | Should Not BeNullOrEmpty
        }
    }

    Context "when project collection globallist already exists" {
        It "it adds a LISTITEM with the buildNumber" {
            $buildNumber = "20160606.2"
            $glName = "Builds - $($config.Environment.TeamProject)"
            $xml = [xml]"<gl:GLOBALLISTS xmlns:gl=`"http://schemas.microsoft.com/VisualStudio/2005/workitemtracking/globallists`"><GLOBALLIST name=`"$glName`"><LISTITEM value=`"20160606.1`" /></GLOBALLIST></gl:GLOBALLISTS>"
            $gls = Update-GlobalListXml -globalListsDoc $xml -glName $glName -buildNumber $buildNumber
            $gl = $gls.GLOBALLISTS.GLOBALLIST | Where-Object { $_.name -eq $glName }
            $gl | Should Not BeNullOrEmpty
            $gl.Length | Should BeNullOrEmpty
            $gl.LISTITEM | Where-Object { $_.value -eq $buildNumber } | Should Not BeNullOrEmpty
        }
    }

    Context "when project collection globallist already exists among multiple globallists" {
        It "it adds a LISTITEM with the buildNumber" {
            $buildNumber = "20160606.2"
            $glName = "Builds - $($config.Environment.TeamProject)"
            $xml = [xml]"<gl:GLOBALLISTS xmlns:gl=`"http://schemas.microsoft.com/VisualStudio/2005/workitemtracking/globallists`"><GLOBALLIST name =`"Activity`"><LISTITEM value=`"Coffee`" /><LISTITEM value=`"PingPong`" /><LISTITEM value=`"Giraffe painting`" /></GLOBALLIST><GLOBALLIST name =`"Environment`"><LISTITEM value=`"Pre-Prod`" /><LISTITEM value=`"Pre-PreProd`" /><LISTITEM value=`"Pre-PrePreProd`" /></GLOBALLIST><GLOBALLIST name=`"$glName`"><LISTITEM value=`"20160606.1`" /></GLOBALLIST></gl:GLOBALLISTS>"
            $gls = Update-GlobalListXml -globalListsDoc $xml -glName $glName -buildNumber $buildNumber
            $gl = $gls.GLOBALLISTS.GLOBALLIST | Where-Object { $_.name -eq $glName }
            $gl | Should Not BeNullOrEmpty
            $gl.Length | Should BeNullOrEmpty
            $gl.LISTITEM | Where-Object { $_.value -eq $buildNumber } | Should Not BeNullOrEmpty
        }
    }
}