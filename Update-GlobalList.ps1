[CmdletBinding(SupportsShouldProcess=$false)]
param()


function Update-GlobalListXml
{
    [CmdletBinding(SupportsShouldProcess=$false)]
    param(
        [xml]$globalListsDoc,
        [parameter(Mandatory=$true)][string][ValidateNotNullOrEmpty()]$glName,
        [parameter(Mandatory=$true)][string][ValidateNotNullOrEmpty()]$buildNumber
    )
    
    Write-Verbose "Checking whether '$glName' exists"
    $buildList = $globalListsDoc.GLOBALLISTS.GLOBALLIST | Where-Object { $_.name -eq $glName }
    if ($buildList -eq $null)
    {
        Write-Host "GlobalList '$glName' does not exist and will be created"
        $globalLists = $globalListsDoc.GLOBALLISTS
        if($globalLists -eq $null)
        {
            $doc = [xml]"<gl:GLOBALLISTS xmlns:gl=`"http://schemas.microsoft.com/VisualStudio/2005/workitemtracking/globallists`"></gl:GLOBALLISTS>"
            $globalLists = $doc.GLOBALLISTS
        }
        $globalList = $globalLists.OwnerDocument.CreateElement("GLOBALLIST")
        $globalList.SetAttribute("name",$glName)
        $buildList  = $globalLists.AppendChild($globalList)
    }
    Write-Host "Adding '$buildNumber' as a new LISTITEM in '$glName'"
    $build = $buildList.OwnerDocument.CreateElement("LISTITEM")
    $build.SetAttribute("value", $buildNumber)
    $buildList.AppendChild($build)
    
    return $buildList.OwnerDocument
}


function Update-GlobalList
{
    [CmdletBinding(SupportsShouldProcess=$false)]
    param()

    # Get environment variables
    $tpcUri = $env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI
    Write-Verbose "Team Project Collection Url: $tpcUri"
    $teamProjectName = $env:SYSTEM_TEAMPROJECT
    Write-Verbose "Team Project: $teamProjectName"
    $buildNumber = $env:BUILD_BUILDNUMBER
    Write-Verbose "Build Number: $buildNumber"
    $agentHome = $env:AGENT_HOMEDIRECTORY
    Write-Verbose "Agent home direrctory: $agentHome"

    # Loads client API binaries from agent folder
    $agentWorker = Join-Path $agentHome "AgentBin\agent\Worker"

    $clientDll = Join-Path $agentWorker "Microsoft.TeamFoundation.Client.dll"
    $wiTDll = Join-Path $agentWorker "Microsoft.TeamFoundation.WorkItemTracking.Client.dll"
    [System.Reflection.Assembly]::LoadFrom($clientDll) | Write-Verbose
    [System.Reflection.Assembly]::LoadFrom($wiTDll) | Write-Verbose

    # Connect to TFS TPC
    $tfsTpc = [Microsoft.TeamFoundation.Client.TfsTeamProjectCollectionFactory]::GetTeamProjectCollection($tpcUri)
    $wiStore = $tfsTpc.GetService([Microsoft.TeamFoundation.WorkItemTracking.Client.WorkItemStore])

    # Retrive GLOBALLISTS
    $xmlDoc = $wiStore.ExportGlobalLists()
    $gls = Update-GlobalListXml -globalListsDoc $xmlDoc -glName $globalListName -buildNumber $buildNumber
    
    #$wiStore.ImportGlobalLists($gls)
}