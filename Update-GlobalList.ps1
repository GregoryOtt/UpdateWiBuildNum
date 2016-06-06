function Update-GlobalList()
{
    [CmdletBinding(SupportsShouldProcess=$false)]
    param()

    # Get environment variables
    $tpcUri = $env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI
    Write-Output "Team Project Collection Url: $tpcUri"
    $teamProjectName = $env:SYSTEM_TEAMPROJECT
    Write-Output "Team Project: $teamProjectName"
    $buildNumber = $env:BUILD_BUILDNUMBER
    Write-Output "Build Number: $buildNumber"
    $agentHome = $env:AGENT_HOMEDIRECTORY
    Write-Output "Agent home direrctory: $agentHome"

    # Loads client API binaries from agent folder
    $agentWorker = Join-Path $agentHome "AgentBin\agent\Worker"

    $clientDll = Join-Path $agentWorker "Microsoft.TeamFoundation.Client.dll"
    $wiTDll = Join-Path $agentWorker "Microsoft.TeamFoundation.WorkItemTracking.Client.dll"
    [System.Reflection.Assembly]::LoadFrom($clientDll)
    [System.Reflection.Assembly]::LoadFrom($wiTDll)

    # Update GL
    $tfsTpc = [Microsoft.TeamFoundation.Client.TfsTeamProjectCollectionFactory]::GetTeamProjectCollection($tpcUri)
    $wiStore = $tfsTpc.GetService([Microsoft.TeamFoundation.WorkItemTracking.Client.WorkItemStore])

    $gls = [xml]$wiStore.ExportGlobalLists()
}