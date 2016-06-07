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
        if($globalLists.OuterXml -eq $null)
        {
            $newDoc = [xml]"<gl:GLOBALLISTS xmlns:gl=`"http://schemas.microsoft.com/VisualStudio/2005/workitemtracking/globallists`"></gl:GLOBALLISTS>"
            $globalLists = $newDoc.GLOBALLISTS
        }
        $globalList = $globalLists.OwnerDocument.CreateElement("GLOBALLIST")
        $globalList.SetAttribute("name", $glName)
        $buildList = $globalLists.AppendChild($globalList)
    }
    if(($buildList.LISTITEM | where-object { $_.value -eq $buildNumber }) -ne $null)
    {
        throw "The LISTITEM value: '$buildNumber' already exists in the GLOBALLIST: '$glName'"
    }

    Write-Host "Adding '$buildNumber' as a new LISTITEM in '$glName'"
    $build = $buildList.OwnerDocument.CreateElement("LISTITEM")
    $build.SetAttribute("value", $buildNumber)
    $buildList.AppendChild($build) | out-null
    
    return $buildList.OwnerDocument
}

function Invoke-GlobalListAPI()
{
    [CmdletBinding(SupportsShouldProcess=$false)]
    param(
        [parameter(Mandatory=$true)][Microsoft.TeamFoundation.WorkItemTracking.Client.WorkItemStore]$wiStore,
        [parameter(Mandatory=$true,ParameterSetName="Import")][switch]$import,
        [parameter(Mandatory=$true,ParameterSetName="Import")][xml]$globalLists,
        [parameter(ParameterSetName="Export")][switch]$export
    )

    try {
        if($import)
        {
            $wiStore.ImportGlobalLists($globalLists.OuterXml) # Account must be explicitly in the Project Administrator Group
        }
        if($export)
        {
            return [xml]$wiStore.ExportGlobalLists()
        }
    }
    catch [Microsoft.TeamFoundation.TeamFoundationServerException] {
        Write-Error "An error has occured while exporting or importing GlobalList"
        throw $_
    }
}

function Get-WorkItemStore()
{
    [CmdletBinding(SupportsShouldProcess=$false)]
    param(
        [parameter(Mandatory=$true)][string][ValidateNotNullOrEmpty()]$tpcUri,
        [parameter(Mandatory=$true)][string][ValidateNotNullOrEmpty()]$agentWorker
    )

    # Loads client API binaries from agent folder
    $clientDll = Join-Path $agentWorker "Microsoft.TeamFoundation.Client.dll"
    $wiTDll = Join-Path $agentWorker "Microsoft.TeamFoundation.WorkItemTracking.Client.dll"
    [System.Reflection.Assembly]::LoadFrom($clientDll) | Write-Verbose
    [System.Reflection.Assembly]::LoadFrom($wiTDll) | Write-Verbose

    try {
        Write-Host "Connecting to $tpcUri"
        $tfsTpc = [Microsoft.TeamFoundation.Client.TfsTeamProjectCollectionFactory]::GetTeamProjectCollection($tpcUri)
        return $tfsTpc.GetService([Microsoft.TeamFoundation.WorkItemTracking.Client.WorkItemStore])
    }
    catch [Microsoft.TeamFoundation.TeamFoundationServerException] {
        Write-Error "An error has occured while retrieving WorkItemStore"
        throw $_
    }
    
}

function Get-WITDataStore64
{
	[CmdletBinding(SupportsShouldProcess=$false)]
    param()

	if($env:VS140COMNTOOLS -eq $null)
	{
		throw New-Object System.InvalidOperationException "Visual Studio 2015 must be installed on the build agent" # TODO: Change it by checking agent capabilities
	}

	$idePath = Join-Path (Split-Path -Parent $env:VS140COMNTOOLS) "IDE"
	return Get-ChildItem -Recurse -Path $idePath -Filter "Microsoft.WITDataStore64.dll" | Select-Object -First 1 -ExpandProperty FullName
}

function Update-GlobalList
{
    [CmdletBinding(SupportsShouldProcess=$false)]
    param()

    # Get environment variables
    $tpcUri = $env:SYSTEM_TEAMFOUNDATIONCOLLECTIONURI
    Write-Verbose "Team Project Collection Url: '$tpcUri'"
    $teamProjectName = $env:SYSTEM_TEAMPROJECT
    Write-Verbose "Team Project: '$teamProjectName'"
    $buildNumber = $env:BUILD_BUILDNUMBER
    Write-Verbose "Build Number: '$buildNumber'"
    $agentHome = $env:AGENT_HOMEDIRECTORY
    Write-Verbose "Agent home direrctory: '$agentHome'"
    $globalListName = "Builds - $teamProjectName"
    Write-Verbose "GlobalList name: '$teamProjectName'"

	# Copy 'Microsoft.WITDataStore64.dll' from Visual Studio directory to AgentBin directory if it does not exist
	$agentWorker = Join-Path $agentHome "agent\Worker"
	$targetPath = Join-Path $agentWorker "Microsoft.WITDataStore64.dll" # Only compatible with x64 process #TODO use constant instead
	if(-not (Test-Path $targetPath))
	{
		$wITDataStore64FilePath = Get-WITDataStore64
		Write-Host "Copying $wITDataStore64FilePath to $targetPath"
		Copy-Item $wITDataStore64FilePath $targetPath | Write-Verbose
	}
	
    # Connect to TFS TPC
    $wiStore = Get-WorkItemStore -tpcUri $tpcUri -agentWorker $agentWorker

    # Retrive GLOBALLISTS
    $xmlDoc = Invoke-GlobalListAPI -export -wiStore $wiStore
    $gls2 = Update-GlobalListXml -globalListsDoc $xmlDoc -glName $globalListName -buildNumber $buildNumber

    Invoke-GlobalListAPI -import -globalLists $gls2 -wiStore $wiStore

	Write-Verbose $gls2.OuterXml
}

Update-GlobalList