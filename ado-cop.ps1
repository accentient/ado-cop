# ado-cop.ps1: runs the rules in rules.json against Azure DevOps projects.
# Run with no arguments (F5) and Main supplies everything, with the PAT read from
# Windows Credential Manager. The pipeline passes every value as a parameter instead.
# Read-only: Invoke-AdoGet is the only network call and it hard-codes GET.
param(
  [string]$AdoOrgUrl,
  [string]$AdoToken,
  [string[]]$Projects,
  [string]$RulesFile,
  [string]$OutputPath,
  [string]$PatEntryName   # Windows Credential Manager entry that holds the PAT; not the PAT itself
)

function Main {
  if (-not $env:TF_BUILD) { try { Clear-Host } catch { } }

  # Local defaults. Anything passed on the command line (the pipeline does this) wins.
  $script:AdoOrgUrl         = Coalesce $AdoOrgUrl      "https://dev.azure.com/<organization>/"
  $script:AdoCredentialName = Coalesce $PatEntryName "ado-cop-PAT"
  $script:RulesFile         = Coalesce $RulesFile      (Join-Path $PSScriptRoot "rules.json")
  $script:ReportPath        = Join-Path $PSScriptRoot "ado-cop.md"   # overwritten each run
  $script:AdoToken          = $AdoToken   # pipeline only; empty means use Credential Manager

  # Test-AdoConnection     # uncomment to confirm the PAT works and list visible projects

  # The projects to inspect. Pass -Projects or put the local default list here.
  # The results stay in $AdoCop after the run.
  $targets = if ($Projects) { @($Projects) } else { @() }
  if ($targets.Count -eq 0) { throw "Pass -Projects <name>[,<name>] or set the default list in the Main function of ado-cop.ps1." }

  $script:AdoCop = Invoke-AdoCop -Projects $targets -OutputPath $OutputPath
}

# API versions. 7.1 is current GA; Analytics is still on a preview tag.
$script:ApiVersion          = "7.1"
$script:AnalyticsApiVersion = "v4.0-preview"

# Status values a rule can report. The report maps them to glyphs.
$script:StatusPass    = "Pass"
$script:StatusWarning = "Warning"
$script:StatusError   = "Error"

# =============================================================================
# Windows Credential Manager (CredRead only). Compiled on first use so the script
# also loads on a Linux build agent, where the PAT arrives as -AdoToken instead.
# =============================================================================

function Initialize-AdoCredMan {
  if ("AdoCredMan" -as [type]) { return }
  $onWindows = ($PSVersionTable.PSVersion.Major -lt 6) -or $IsWindows
  if (-not $onWindows) {
    throw "Windows Credential Manager is only available on Windows. Pass -AdoToken instead."
  }
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;

public static class AdoCredMan
{
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    public struct CREDENTIAL
    {
        public uint Flags;
        public uint Type;
        public string TargetName;
        public string Comment;
        public System.Runtime.InteropServices.ComTypes.FILETIME LastWritten;
        public uint CredentialBlobSize;
        public IntPtr CredentialBlob;
        public uint Persist;
        public uint AttributeCount;
        public IntPtr Attributes;
        public string TargetAlias;
        public string UserName;
    }

    [DllImport("advapi32.dll", EntryPoint = "CredReadW", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern bool CredRead(string target, uint type, uint flags, out IntPtr credential);

    [DllImport("advapi32.dll")]
    private static extern void CredFree(IntPtr credential);

    private const uint CRED_TYPE_GENERIC = 1;
    private const int ERROR_NOT_FOUND = 1168;

    public static string Read(string target)
    {
        IntPtr ptr;
        if (!CredRead(target, CRED_TYPE_GENERIC, 0, out ptr))
        {
            int err = Marshal.GetLastWin32Error();
            if (err == ERROR_NOT_FOUND) return null;
            throw new System.ComponentModel.Win32Exception(err);
        }
        try
        {
            CREDENTIAL cred = (CREDENTIAL)Marshal.PtrToStructure(ptr, typeof(CREDENTIAL));
            if (cred.CredentialBlobSize == 0) return string.Empty;
            return Marshal.PtrToStringUni(cred.CredentialBlob, (int)cred.CredentialBlobSize / 2);
        }
        finally
        {
            CredFree(ptr);
        }
    }
}
"@
}

function Get-AdoOrgName {
  # Parses the organization name out of $script:AdoOrgUrl.
  $url = [string]$script:AdoOrgUrl
  if ([string]::IsNullOrWhiteSpace($url)) {
    throw "Set `$script:AdoOrgUrl in the Main function of ado-cop.ps1 (or pass -AdoOrgUrl) to your organization URL."
  }
  $url = $url.Trim()
  if (-not $url.EndsWith('/')) { $url += '/' }
  if ($url -match '^https://dev\.azure\.com/([^/]+)/$') { return $Matches[1] }
  if ($url -match '^https://([^./]+)\.visualstudio\.com/$') { return $Matches[1] }
  throw "Unrecognized organization URL '$url'. Expected https://dev.azure.com/{org}/ or https://{org}.visualstudio.com/"
}

function Get-AdoCredentialName {
  if ([string]::IsNullOrWhiteSpace($script:AdoCredentialName)) {
    throw "Set `$script:AdoCredentialName in the Main function of ado-cop.ps1 to the Credential Manager entry that holds the PAT."
  }
  return $script:AdoCredentialName
}

function Get-AdoPat {
  # A token passed on the command line (pipeline) wins over Credential Manager.
  if (-not [string]::IsNullOrWhiteSpace($script:AdoToken)) { return $script:AdoToken.Trim() }
  $target = Get-AdoCredentialName
  Initialize-AdoCredMan
  $pat = [AdoCredMan]::Read($target)
  if ([string]::IsNullOrWhiteSpace($pat)) {
    throw "No PAT found. Add a Windows generic credential named '$target' (see README.md) or pass -AdoToken."
  }
  return $pat.Trim()
}

# =============================================================================
# Connection
# =============================================================================

function Connect-Ado {
  # Resolves the organization URLs and builds the auth header. Called automatically.
  $org = Get-AdoOrgName

  $script:Org           = $org
  $script:CoreBase      = "https://dev.azure.com/$org/"
  $script:GraphBase     = "https://vssps.dev.azure.com/$org/"
  $script:AnalyticsBase = "https://analytics.dev.azure.com/$org/"
  $script:ReleaseBase   = "https://vsrm.dev.azure.com/$org/"
  $script:FeedsBase     = "https://feeds.dev.azure.com/$org/"

  $pat = Get-AdoPat
  $bytes = [Text.Encoding]::ASCII.GetBytes(":" + $pat)
  $script:AdoHeaders = @{
    Authorization = "Basic " + [Convert]::ToBase64String($bytes)
    Accept        = "application/json"
  }
  $pat = $null
  $script:Connected = $true
}

function Test-AdoConnection {
  # Confirms the PAT authenticates and shows the identity it resolves to.
  Connect-Ado
  $data = Invoke-AdoGet -Uri ($script:CoreBase + "_apis/connectionData?api-version=$($script:ApiVersion)-preview.1")
  $user = $data.authenticatedUser
  $account = $null
  try { $account = $user.properties.Account.'$value' } catch { }
  if (-not $account) { $account = $user.id }
  Write-Host ("Connected to {0} as {1} ({2})" -f $script:Org, $user.providerDisplayName, $account) -ForegroundColor Green
  $projects = Invoke-AdoGet -Uri ($script:CoreBase + "_apis/projects?api-version=$($script:ApiVersion)") -AllPages
  Write-Host ("{0} project(s) visible: {1}" -f @($projects).Count, (($projects | Sort-Object name | ForEach-Object { $_.name }) -join ", "))
}

# =============================================================================
# HTTP: the ONLY function that talks to Azure DevOps. GET is hard-coded.
# =============================================================================

function Invoke-AdoGet {
  # Issues an HTTP GET and returns the parsed JSON body. -AllPages follows
  # continuation tokens and OData nextLink and returns the concatenated "value"
  # arrays. -Raw returns the body as text.
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)][string]$Uri,
    [switch]$AllPages,
    [switch]$Raw
  )

  if (-not $script:Connected) { Connect-Ado }

  $collected = New-Object System.Collections.Generic.List[object]
  $nextUri = $Uri
  $guard = 0

  while ($nextUri) {
    $guard++
    if ($guard -gt 500) { throw "Paging guard tripped for $Uri" }

    # The verb below is the only verb this script ever uses.
    try {
      $response = Invoke-WebRequest -Uri $nextUri -Headers $script:AdoHeaders -Method Get -UseBasicParsing -ErrorAction Stop
    } catch {
      # Some endpoints still require "-preview" on the api-version. Azure DevOps says
      # so explicitly; when it does, retry once with the preview tag appended.
      $bodyText = Get-AdoErrorBody $_
      if ($bodyText -like '*VssInvalidPreviewVersionException*' -and $nextUri -match 'api-version=([\d.]+)(&|$)') {
        $retryUri = $nextUri -replace 'api-version=([\d.]+)(&|$)', 'api-version=$1-preview$2'
        Write-Verbose "Retrying with preview api-version: $retryUri"
        $response = Invoke-WebRequest -Uri $retryUri -Headers $script:AdoHeaders -Method Get -UseBasicParsing -ErrorAction Stop
      } else {
        # Put the server's own message in the exception so a rule's error result
        # says what went wrong (missing scope, bad query) rather than just "400".
        throw (Get-AdoErrorMessage $_ $bodyText)
      }
    }

    $contentType = ""
    foreach ($k in $response.Headers.Keys) {
      if ($k -ieq 'Content-Type') { $contentType = [string](@($response.Headers[$k])[0]) }
    }
    if ($contentType -like 'text/html*') {
      throw "Azure DevOps returned an HTML sign-in page instead of JSON. The PAT is missing, expired, or lacks access. ($nextUri)"
    }

    if ($Raw) { return $response.Content }

    $body = ConvertFrom-AdoJson $response.Content
    if (-not $AllPages) { return $body }

    if ($null -ne $body.PSObject.Properties['value']) {
      foreach ($item in @($body.value)) { $collected.Add($item) }
    } elseif ($null -ne $body.PSObject.Properties['members']) {
      foreach ($item in @($body.members)) { $collected.Add($item) }
    } else {
      $collected.Add($body)
    }

    $nextUri = $null

    # Continuation token in a response header (Core, Graph, Build, Test Plans)
    $token = $null
    foreach ($k in $response.Headers.Keys) {
      if ($k -ieq 'x-ms-continuationtoken') { $token = [string](@($response.Headers[$k])[0]) }
    }
    # Continuation token in the body (Member Entitlement Management)
    if (-not $token -and $null -ne $body.PSObject.Properties['continuationToken'] -and $body.continuationToken) {
      $token = [string]$body.continuationToken
    }
    if ($token) {
      $sep = '&'
      if ($Uri -notlike '*?*') { $sep = '?' }
      $nextUri = $Uri + $sep + "continuationToken=" + [uri]::EscapeDataString($token)
    }
    # OData nextLink (Analytics)
    if ($null -ne $body.PSObject.Properties['@odata.nextLink'] -and $body.'@odata.nextLink') {
      $nextUri = [string]$body.'@odata.nextLink'
    }
  }

  return ,$collected.ToArray()
}

function Get-AdoErrorBody($ErrorRecord) {
  # Returns the response body text from a failed Invoke-WebRequest, on both
  # PowerShell 7 (ErrorDetails) and Windows PowerShell 5.1 (response stream).
  try {
    if ($ErrorRecord.ErrorDetails -and $ErrorRecord.ErrorDetails.Message) { return [string]$ErrorRecord.ErrorDetails.Message }
    $resp = $ErrorRecord.Exception.Response
    if ($resp -and ($resp -is [System.Net.HttpWebResponse])) {
      $stream = $resp.GetResponseStream()
      if ($stream) {
        $reader = New-Object System.IO.StreamReader($stream)
        $text = $reader.ReadToEnd()
        $reader.Dispose()
        return $text
      }
    }
  } catch { }
  return [string]$ErrorRecord.Exception.Message
}

function Get-AdoErrorMessage($ErrorRecord, [string]$BodyText) {
  # "HTTP 400: VS403522: The property 'AreaPath' is not available..." when the body
  # is the usual Azure DevOps JSON error; otherwise the raw exception message.
  $status = $null
  try { $status = [int]$ErrorRecord.Exception.Response.StatusCode } catch { }
  $message = $null
  try {
    $parsed = $BodyText | ConvertFrom-Json
    if ($parsed.error -and $parsed.error.message) { $message = [string]$parsed.error.message }
    elseif ($parsed.message) { $message = [string]$parsed.message }
  } catch { }
  if (-not $message) { $message = [string]$ErrorRecord.Exception.Message }
  if ($status) { return "HTTP ${status}: $message" }
  return $message
}

function ConvertFrom-AdoJson([string]$Content) {
  # Some payloads (work item types) carry a property whose name is an empty
  # string, which PowerShell 7's parser refuses. Rename it and retry.
  try {
    return ($Content | ConvertFrom-Json)
  } catch {
    $patched = $Content -replace '"\s*"\s*:', '"_empty_":'
    return ($patched | ConvertFrom-Json)
  }
}

function Get-AdoAllProjects {
  if ($null -eq $script:ProjectCache) {
    # No @() here: -AllPages already returns an array, and @() would nest it.
    $script:ProjectCache = Invoke-AdoGet -Uri ($script:CoreBase + "_apis/projects?`$top=1000&api-version=$($script:ApiVersion)") -AllPages
  }
  return $script:ProjectCache
}

# =============================================================================
# Rules engine
# =============================================================================

function Read-RuleFile([string]$Path) {
  # Keys shaped XXX###_Name set to true are rules to run; Test_Rule names a single
  # rule to run instead; everything else is a setting rules read with Get-Setting.
  if (-not (Test-Path $Path)) { throw "Rules file not found: $Path" }
  $json = Get-Content $Path -Raw | ConvertFrom-Json

  $settings = [ordered]@{}
  $active   = New-Object System.Collections.Generic.List[string]
  $testRule = ""

  foreach ($prop in $json.PSObject.Properties) {
    $name  = ([string]$prop.Name).Trim()
    $value = $prop.Value
    if ($name -eq 'Test_Rule') {
      if ($value -is [string]) { $testRule = $value.Trim() }
    } elseif ($name -match '^[A-Z]{3}\d{3}_') {
      if ($value) { $active.Add($name) }
    } else {
      if ($value -is [string]) { $value = $value.Trim() }
      $settings[$name] = $value
    }
  }

  return [pscustomobject]@{
    Path     = $Path
    Settings = $settings
    Active   = $active.ToArray()
    TestRule = $testRule
  }
}

function Get-Setting([string]$Name, $Default = $null) {
  # Reads a non-rule key from the rules JSON, with a default when it is absent or blank.
  $settings = $script:Rules.Settings
  if ($settings.Contains($Name)) {
    $value = $settings[$Name]
    if ($null -ne $value -and -not ($value -is [string] -and [string]::IsNullOrWhiteSpace($value))) { return $value }
  }
  return $Default
}

function Get-SettingList([string]$Name, [string[]]$Default = @()) {
  # As Get-Setting, but splits a comma-separated string into trimmed, non-empty parts.
  $value = Get-Setting $Name
  if ($null -eq $value) { return $Default }
  if ($value -is [string]) {
    return @($value -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
  }
  return @($value)
}

function Get-RuleCode([string]$FunctionName) {
  # Rule_WRK110_FeaturesHaveParentEpic -> WRK110
  return ($FunctionName -replace '^Rule_([A-Z]{3}\d{3})_.*$', '$1')
}

function Get-RuleTitle([string]$RuleName) {
  # WRK110_FeaturesHaveParentEpic -> "WRK110: Features have parent epic"
  $trimmed = $RuleName -replace '^Rule_', ''
  $code, $namePart = $trimmed -split '_', 2
  if (-not $namePart) { return $trimmed }
  $words = [regex]::Replace($namePart, '(?<=[a-z0-9])(?=[A-Z])|(?<=[A-Z])(?=[A-Z][a-z])', ' ')
  $sentence = $words.ToLower()
  $sentence = $sentence.Substring(0, 1).ToUpper() + $sentence.Substring(1)
  # Work item type names keep their capitals; states stay lower case.
  $sentence = $sentence -replace '\bepic', 'Epic' -replace '\bfeature', 'Feature' -replace '\bstor(y|ies)\b', 'Stor$1' `
    -replace '\bbug', 'Bug' -replace '\btask', 'Task' -replace '\binitiative', 'Initiative' `
    -replace '\buser (Stor)', 'User $1' -replace '\bproduct backlog item', 'Product Backlog Item'
  return "${code}: $sentence"
}

function Add-Result {
  # Records what a rule found for one project. Description is the full finding for the
  # console; Note is the short version for the report table (defaults to Description).
  # Items is an optional list of objects the JSON keeps in full.
  param(
    [Parameter(Mandatory = $true)]$Project,
    [Parameter(Mandatory = $true)][string]$Rule,
    [Parameter(Mandatory = $true)][string]$Status,
    [Parameter(Mandatory = $true)][string]$Description,
    [string]$Note,
    [object[]]$Items = @()
  )
  if ([string]::IsNullOrWhiteSpace($Note)) { $Note = $Description }
  $script:Results.Add([pscustomobject]@{
    Project     = [string]$Project.name
    Rule        = $Rule
    Title       = $script:RuleTitles[$Rule]
    Status      = $Status
    Description = $Description
    Note        = $Note
    Count       = @($Items).Count
    Items       = @($Items)
  })
  # One line per result on the console, under the "Rule:" heading Invoke-AdoCop prints.
  $color = switch ($Status) { 'Pass' { 'Green' } 'Warning' { 'Yellow' } default { 'Red' } }
  $prefix = if ($script:TargetCount -gt 1) { "$($Project.name): " } else { "" }
  Write-Host ("{0,-7} {1}{2}" -f $Status, $prefix, $Description) -ForegroundColor $color
  if ($env:TF_BUILD -and $Status -ne $script:StatusPass) {
    $type = if ($Status -eq $script:StatusError) { 'error' } else { 'warning' }
    Write-Host "##vso[task.logissue type=$type]$($Project.name) $Rule $Description"
  }
}

function Invoke-Rule($RuleName, $Project) {
  $functionName = "Rule_" + $RuleName
  $code = Get-RuleCode $functionName
  $script:RuleTitles[$code] = Get-RuleTitle $RuleName
  if (-not (Get-Command $functionName -ErrorAction SilentlyContinue)) {
    Add-Result -Project $Project -Rule $code -Status $script:StatusError -Description "Function $functionName not found in ado-cop.ps1."
    return
  }
  try {
    & $functionName -Project $Project
  } catch {
    Add-Result -Project $Project -Rule $code -Status $script:StatusError -Description "$code failed: $($_.Exception.Message)"
  }
}

function Invoke-AdoCop {
  # Runs the active rules against the given projects, writes the Markdown report
  # (default ado-cop.md next to the script) plus a JSON dump next to it, and
  # returns the result objects, one per project per rule.
  [CmdletBinding()]
  param(
    [Parameter(Mandatory = $true)][string[]]$Projects,
    [string]$OutputPath
  )

  Connect-Ado
  $script:ProjectCache = $null
  $script:PairsCache   = @{}
  $script:ProcessMap   = $null
  $script:Results      = New-Object System.Collections.Generic.List[object]
  $script:RuleTitles   = @{}
  $script:Rules        = Read-RuleFile $script:RulesFile

  $ruleNames = @($script:Rules.Active)
  if ($script:Rules.TestRule) {
    $ruleNames = @($script:Rules.TestRule)
    Write-Host ("Test_Rule is set: running only {0}" -f $script:Rules.TestRule) -ForegroundColor Yellow
  }
  if ($ruleNames.Count -eq 0) { throw "No active rules in $($script:RulesFile)." }

  # Resolve requested names against the organization
  $available = @(Get-AdoAllProjects)
  # Accept 'A','B' (PowerShell), "A,B" (pwsh -File or cmd), and stray quotes from either.
  $requested = @($Projects | ForEach-Object { $_ -split ',' } |
    ForEach-Object { $_.Trim().Trim("'", '"').Trim() } | Where-Object { $_ } | Select-Object -Unique)
  $targets = New-Object System.Collections.Generic.List[object]
  $missing = New-Object System.Collections.Generic.List[string]
  foreach ($name in $requested) {
    $match = $available | Where-Object { $_.name -ieq $name } | Select-Object -First 1
    if ($match) { $targets.Add($match) } else { $missing.Add($name) }
  }
  if ($missing.Count -gt 0) {
    Write-Host ("Not found in {0} (check spelling or PAT project access): {1}" -f $script:Org, ($missing -join ', ')) -ForegroundColor Yellow
  }
  if ($targets.Count -eq 0) { throw "No matching projects to inspect." }

  $started = Get-Date
  $script:TargetCount = $targets.Count
  Write-Host ("Started {0}" -f $started.ToString('HH:mm:ss')) -ForegroundColor Cyan
  Write-Host ""
  Write-Host ("Running rules from {0}" -f (Split-Path -Leaf $script:RulesFile))
  foreach ($ruleName in $ruleNames) {
    Write-Host ""
    Write-Host ("Rule: {0}" -f (Get-RuleTitle $ruleName)) -ForegroundColor Cyan
    foreach ($project in $targets) {
      Invoke-Rule -RuleName $ruleName -Project $project
    }
  }
  Write-Host ""

  # Write outputs
  if (-not $OutputPath) {
    $OutputPath = $script:ReportPath
    if ([string]::IsNullOrWhiteSpace($OutputPath)) { $OutputPath = Join-Path $PSScriptRoot "ado-cop.md" }
  }
  $outFolder = Split-Path -Parent $OutputPath
  if ($outFolder -and -not (Test-Path $outFolder)) { New-Item -ItemType Directory -Path $outFolder | Out-Null }
  $jsonPath = [IO.Path]::ChangeExtension($OutputPath, '.json')
  $markdown = New-AdoCopReport -Results $script:Results -Missing $missing -Started $started
  [IO.File]::WriteAllText($OutputPath, $markdown, [Text.UTF8Encoding]::new($false))
  $logPath = [IO.Path]::ChangeExtension($OutputPath, '.log')
  [IO.File]::WriteAllText($logPath, (New-AdoCopLog -Results $script:Results -Started $started), [Text.UTF8Encoding]::new($false))
  $script:Results | ConvertTo-Json -Depth 8 | Set-Content -Path $jsonPath -Encoding UTF8

  $warnings = @($script:Results | Where-Object { $_.Status -eq $script:StatusWarning }).Count
  $errors   = @($script:Results | Where-Object { $_.Status -eq $script:StatusError }).Count
  $finished = Get-Date
  Write-Host ("Report: {0}  ({1} pass, {2} warning, {3} error)" -f $OutputPath, ($script:Results.Count - $warnings - $errors), $warnings, $errors)
  Write-Host ("Log:    {0}" -f $logPath)
  Write-Host ""
  Write-Host ("Ending {0}" -f $finished.ToString('HH:mm:ss')) -ForegroundColor Cyan
  if ($env:TF_BUILD -and ($warnings + $errors) -gt 0) {
    Write-Host "##vso[task.complete result=SucceededWithIssues;]$warnings warning(s), $errors error(s)"
  }
  return $script:Results.ToArray()
}

# =============================================================================
# Shared helpers for rules
# =============================================================================

function ConvertTo-ODataString([string]$Value) {
  # Escapes a value for use inside single quotes in an OData filter.
  return $Value -replace "'", "''"
}

function Get-AnalyticsWorkItems {
  # Reads work items for one project from the Analytics OData service (GET).
  # Filter is appended to the project filter, e.g. "WorkItemType eq 'Feature'".
  # Area and iteration paths are not columns; get them through Expand, e.g.
  # "Area(`$select=AreaPath)", and read $item.Area.AreaPath. Do not expand Parent
  # on the org-level endpoint: it 403s unless the PAT can see every project.
  param(
    [Parameter(Mandatory = $true)]$Project,
    [Parameter(Mandatory = $true)][string]$Filter,
    [string]$Select = "WorkItemId,Title,WorkItemType,State",
    [string]$Expand
  )
  $projectFilter = "Project/ProjectName eq '$(ConvertTo-ODataString $Project.name)'"
  $uri = $script:AnalyticsBase + "_odata/$($script:AnalyticsApiVersion)/WorkItems?" +
         "`$filter=$projectFilter and ($Filter)&`$select=$Select"
  if ($Expand) { $uri += "&`$expand=$Expand" }
  $rows = Invoke-AdoGet -Uri $uri -AllPages
  return ,@($rows)
}

function Get-WorkItemFields {
  # Reads a few fields for a set of work item IDs through the work items REST API
  # (GET, 200 IDs per call). Works across projects. Returns a hashtable keyed by
  # ID; IDs the PAT cannot read are simply absent.
  param(
    [Parameter(Mandatory = $true)][int[]]$Ids,
    [string[]]$Fields = @('System.WorkItemType', 'System.TeamProject')
  )
  $map = @{}
  $unique = @($Ids | Where-Object { $_ } | Select-Object -Unique)
  for ($i = 0; $i -lt $unique.Count; $i += 200) {
    $batch = $unique[$i..([Math]::Min($i + 199, $unique.Count - 1))]
    $uri = $script:CoreBase + "_apis/wit/workitems?ids=" + ($batch -join ',') +
           "&fields=" + ($Fields -join ',') + "&errorPolicy=omit&api-version=$($script:ApiVersion)"
    $page = Invoke-AdoGet -Uri $uri
    foreach ($wi in @($page.value)) { $map[[int]$wi.id] = $wi.fields }
  }
  return $map
}

function Get-WorkItemUrl($Project, $Id) {
  return $script:CoreBase + [uri]::EscapeDataString($Project.name) + "/_workitems/edit/$Id"
}

function Get-Plural([string]$Type) {
  switch ($Type) { 'User Story' { 'User Stories' } 'Product Backlog Item' { 'Product Backlog Items' } default { $Type + 's' } }
}

function Format-Count([int]$Count, [string]$Singular, [string]$Plural = "") {
  if (-not $Plural) { $Plural = $Singular + "s" }
  if ($Count -eq 1) { return "1 $Singular" }
  return "$Count $Plural"
}

#######################################################################################################################################################################
#                                                                    RULES: CFG (project configuration)                                                              #
#######################################################################################################################################################################

function Get-AdoProcessMap {
  # Process typeId -> process object, with ParentName added for inherited processes.
  if (-not $script:ProcessMap) {
    $map = @{}
    $procs = Invoke-AdoGet -Uri ($script:CoreBase + "_apis/work/processes?api-version=$($script:ApiVersion)") -AllPages
    foreach ($p in $procs) { $map[[string]$p.typeId] = $p }
    foreach ($p in $procs) {
      $parentName = $null
      if ($p.parentProcessTypeId -and $map.ContainsKey([string]$p.parentProcessTypeId)) { $parentName = $map[[string]$p.parentProcessTypeId].name }
      $p | Add-Member -NotePropertyName ParentName -NotePropertyValue $parentName -Force
    }
    $script:ProcessMap = $map
  }
  return $script:ProcessMap
}

function Get-ProjectProcessName($Project) {
  # The (inherited) process the project is on, e.g. "Core Agile".
  $detail = Invoke-AdoGet -Uri ($script:CoreBase + "_apis/projects/$($Project.id)?includeCapabilities=true&api-version=$($script:ApiVersion)")
  $name = $null; $typeId = $null
  if ($detail.capabilities -and $detail.capabilities.processTemplate) {
    $name = [string]$detail.capabilities.processTemplate.templateName
    $typeId = [string]$detail.capabilities.processTemplate.templateTypeId
  }
  $map = Get-AdoProcessMap
  if ($typeId -and $map.ContainsKey($typeId)) { $name = [string]$map[$typeId].name }
  return $name
}

# Project services, by the feature id the Feature Management API uses.
$script:ProjectServices = [ordered]@{
  'Boards'     = 'ms.vss-work.agile'
  'Repos'      = 'ms.vss-code.version-control'
  'Pipelines'  = 'ms.vss-build.pipelines'
  'Test Plans' = 'ms.vss-test-web.test'
  'Artifacts'  = 'ms.feed.feed'
}

function Get-ProjectServiceStates($Project) {
  # Service name -> $true when enabled. "undefined" means the default, which is on.
  $states = [ordered]@{}
  foreach ($svc in $script:ProjectServices.Keys) {
    $fid = $script:ProjectServices[$svc]
    $r = Invoke-AdoGet -Uri ($script:CoreBase + "_apis/FeatureManagement/FeatureStates/host/project/$($Project.id)/$fid" + "?api-version=$($script:ApiVersion)-preview.1")
    $states[$svc] = ([string]$r.state -ne 'disabled')
  }
  return $states
}

function Get-ClassificationTree($Project, [string]$StructureType) {
  # The area or iteration tree, root node included, depth 50.
  $nodes = Invoke-AdoGet -Uri ($script:CoreBase + "$($Project.id)/_apis/wit/classificationnodes?`$depth=50&api-version=$($script:ApiVersion)")
  return @($nodes.value | Where-Object { $_.structureType -eq $StructureType })[0]
}

function Get-TreeNodes($Node, [string]$Path = "") {
  # Flattens a classification tree into (Path, Node, Depth, IsLeaf) rows, root excluded.
  $out = New-Object System.Collections.Generic.List[object]
  $walk = $null
  $walk = {
    param($n, $p, $d)
    if (-not $n.children) { return }   # @($null) would loop forever
    foreach ($c in @($n.children)) {
      $cp = if ($p) { "$p\$($c.name)" } else { [string]$c.name }
      $isLeaf = -not ($c.children -and @($c.children).Count -gt 0)
      $out.Add([pscustomobject]@{ Path = $cp; Node = $c; Depth = $d; IsLeaf = $isLeaf })
      & $walk $c $cp ($d + 1)
    }
  }
  & $walk $Node $Path 1
  return $out.ToArray()
}

function New-NodeItem($Project, $Row, [string]$Type, [string]$Problem) {
  [pscustomobject]@{
    Id = [int]$Row.Node.id; Type = $Type; Title = $Row.Path; State = ""; AreaPath = ""
    Problem = $Problem; ParentId = $null; ParentType = $null; Url = $null
  }
}

function New-NamedItem([string]$Type, [string]$Title, [string]$Problem, [string]$Url = $null, $Id = 0) {
  [pscustomobject]@{ Id = $Id; Type = $Type; Title = $Title; State = ""; AreaPath = ""; Problem = $Problem; ParentId = $null; ParentType = $null; Url = $Url }
}

function Test-IsHub($Project) {
  $hub = [string](Get-Setting 'HubProject' '')
  return (-not [string]::IsNullOrWhiteSpace($hub) -and [string]$Project.name -ieq $hub)
}

# ---- Organization
function Rule_CFG000_HubProjectUsesHubProcess {
  # The hub project (HubProject setting) is on the hub process (HubProcess setting).
  param($Project)
  $code = Get-RuleCode $MyInvocation.MyCommand.Name
  $hub = [string](Get-Setting 'HubProject' '')
  $want = [string](Get-Setting 'HubProcess' '')
  $have = Get-ProjectProcessName $Project
  if ([string]::IsNullOrWhiteSpace($hub) -or [string]::IsNullOrWhiteSpace($want)) {
    Add-Result -Project $Project -Rule $code -Status $script:StatusPass -Description "No HubProject or HubProcess setting in the rules file; nothing to check." -Note "No hub settings"
    return
  }
  if (-not (Test-IsHub $Project)) {
    Add-Result -Project $Project -Rule $code -Status $script:StatusPass -Description "Not the hub project ($hub); on the $have process." -Note "Not the hub; on $have"
    return
  }
  if ($have -ieq $want) {
    Add-Result -Project $Project -Rule $code -Status $script:StatusPass -Description "$hub is on the $want process." -Note "On the $want process"
  } else {
    Add-Result -Project $Project -Rule $code -Status $script:StatusWarning -Description "$hub is on the $have process, not $want." -Note "On $have, not $want" `
      -Items @(New-NamedItem 'Project' $hub "Process is $have, expected $want")
  }
}

# ---- Hub project
function Rule_CFG100_HubProjectOnlyHasBoardsEnabled {
  # Boards on; Repos, Pipelines, Test Plans and Artifacts off in the hub.
  param($Project)
  $code = Get-RuleCode $MyInvocation.MyCommand.Name
  try {
    $states = Get-ProjectServiceStates $Project
  } catch {
    # The Feature Management API is not listed under any custom PAT scope. Extensions
    # (Read) is the closest candidate; if that still fails, switch this rule off and
    # check Project settings, Overview, in the browser.
    Add-Result -Project $Project -Rule $code -Status $script:StatusError `
      -Description "Cannot read the project's service states with this PAT ($($_.Exception.Message)). Try adding the Extensions (Read) scope; if it still fails, switch CFG100 off and check Project settings, Overview, in the browser." `
      -Note "PAT cannot read service states; try the Extensions (Read) scope"
    return
  }
  $on = @($states.Keys | Where-Object { $states[$_] })
  if (-not (Test-IsHub $Project)) {
    Add-Result -Project $Project -Rule $code -Status $script:StatusPass -Description "Not the hub project; services on: $($on -join ', ')." -Note "Not the hub; on: $($on -join ', ')"
    return
  }
  $extra = @($on | Where-Object { $_ -ne 'Boards' })
  if ($states['Boards'] -and $extra.Count -eq 0) {
    Add-Result -Project $Project -Rule $code -Status $script:StatusPass -Description "Only Boards is enabled." -Note "Only Boards is enabled"
    return
  }
  $items = @($extra | ForEach-Object { New-NamedItem 'Service' $_ 'Enabled in the hub' })
  if (-not $states['Boards']) { $items += New-NamedItem 'Service' 'Boards' 'Disabled in the hub' }
  $note = if ($extra.Count -gt 0) { "$(Format-Count $extra.Count 'extra service' 'extra services') enabled: $($extra -join ', ')" } else { "Boards is disabled" }
  Add-Result -Project $Project -Rule $code -Status $script:StatusWarning -Description "$note." -Note $note -Items $items
}

function Rule_CFG110_HubProjectContainsNoRepos {
  # No Git repositories and no TFVC in the hub.
  param($Project)
  $code = Get-RuleCode $MyInvocation.MyCommand.Name
  $items = New-Object System.Collections.Generic.List[object]
  $repos = Invoke-AdoGet -Uri ($script:CoreBase + "$($Project.id)/_apis/git/repositories?api-version=$($script:ApiVersion)")
  foreach ($r in @($repos.value)) { $items.Add((New-NamedItem 'Git repository' ([string]$r.name) 'Repository in the hub' ([string]$r.webUrl))) }
  try {
    $tfvc = Invoke-AdoGet -Uri ($script:CoreBase + "$($Project.id)/_apis/tfvc/items?scopePath=" + [uri]::EscapeDataString('$/' + $Project.name) + "&recursionLevel=None&api-version=$($script:ApiVersion)")
    if ($tfvc.value -and @($tfvc.value).Count -gt 0) { $items.Add((New-NamedItem 'TFVC' ('$/' + $Project.name) 'TFVC root in the hub')) }
  } catch { }   # 404 means no TFVC
  if (-not (Test-IsHub $Project)) {
    $n = $items.Count
    Add-Result -Project $Project -Rule $code -Status $script:StatusPass -Description "Not the hub project; $(Format-Count $n 'repository' 'repositories')." -Note "Not the hub; $(Format-Count $n 'repository' 'repositories')"
    return
  }
  Add-CountResult -Project $Project -RuleCode $code -Items $items.ToArray() -PassNote "No repositories" -Singular "repository in the hub" -Plural "repositories in the hub"
}

function Rule_CFG120_HubProjectContainsNoPipelines {
  # No build definitions and no classic release definitions in the hub.
  param($Project)
  $code = Get-RuleCode $MyInvocation.MyCommand.Name
  $items = New-Object System.Collections.Generic.List[object]
  $builds = Invoke-AdoGet -Uri ($script:CoreBase + "$($Project.id)/_apis/build/definitions?api-version=$($script:ApiVersion)") -AllPages
  foreach ($d in @($builds)) { $items.Add((New-NamedItem 'Build pipeline' ([string]$d.name) 'Pipeline in the hub' $null ([int]$d.id))) }
  try {
    $releases = Invoke-AdoGet -Uri ($script:ReleaseBase + "$($Project.id)/_apis/release/definitions?api-version=$($script:ApiVersion)") -AllPages
    foreach ($d in @($releases)) { $items.Add((New-NamedItem 'Release pipeline' ([string]$d.name) 'Release pipeline in the hub' $null ([int]$d.id))) }
  } catch { }   # Release scope missing: builds still counted
  if (-not (Test-IsHub $Project)) {
    $n = $items.Count
    Add-Result -Project $Project -Rule $code -Status $script:StatusPass -Description "Not the hub project; $(Format-Count $n 'pipeline')." -Note "Not the hub; $(Format-Count $n 'pipeline')"
    return
  }
  Add-CountResult -Project $Project -RuleCode $code -Items $items.ToArray() -PassNote "No pipelines" -Singular "pipeline in the hub" -Plural "pipelines in the hub"
}

function Rule_CFG130_HubProjectContainsNoArtifactFeeds {
  # No project-scoped artifact feeds in the hub.
  param($Project)
  $code = Get-RuleCode $MyInvocation.MyCommand.Name
  $feeds = Invoke-AdoGet -Uri ($script:FeedsBase + "$($Project.id)/_apis/packaging/feeds?api-version=$($script:ApiVersion)-preview.1")
  $items = @(@($feeds.value) | ForEach-Object { New-NamedItem 'Feed' ([string]$_.name) 'Feed in the hub' })
  if (-not (Test-IsHub $Project)) {
    $n = $items.Count
    Add-Result -Project $Project -Rule $code -Status $script:StatusPass -Description "Not the hub project; $(Format-Count $n 'artifact feed')." -Note "Not the hub; $(Format-Count $n 'artifact feed')"
    return
  }
  Add-CountResult -Project $Project -RuleCode $code -Items $items -PassNote "No artifact feeds" -Singular "artifact feed in the hub" -Plural "artifact feeds in the hub"
}

function Rule_CFG140_AreasDefined {
  # The area tree has nodes under the root.
  param($Project)
  $code = Get-RuleCode $MyInvocation.MyCommand.Name
  $rows = Get-TreeNodes (Get-ClassificationTree $Project 'area')
  if ($rows.Count -eq 0) {
    Add-Result -Project $Project -Rule $code -Status $script:StatusWarning -Description "No areas under the root; every item lands in the project root." -Note "No areas defined" `
      -Items @(New-NamedItem 'Area' ([string]$Project.name) 'Only the root area exists')
    return
  }
  $top = @($rows | Where-Object { $_.Depth -eq 1 })
  Add-Result -Project $Project -Rule $code -Status $script:StatusPass `
    -Description ("{0} defined, {1} directly under the root: {2}." -f (Format-Count $rows.Count 'area'), $top.Count, (($top | ForEach-Object { $_.Node.name }) -join ', ')) `
    -Note (Format-Count $rows.Count 'area defined' 'areas defined')
}

function Rule_CFG150_IterationsDefined {
  # The iteration tree has nodes under the root.
  param($Project)
  $code = Get-RuleCode $MyInvocation.MyCommand.Name
  $rows = Get-TreeNodes (Get-ClassificationTree $Project 'iteration')
  if ($rows.Count -eq 0) {
    Add-Result -Project $Project -Rule $code -Status $script:StatusWarning -Description "No iterations under the root." -Note "No iterations defined" `
      -Items @(New-NamedItem 'Iteration' ([string]$Project.name) 'Only the root iteration exists')
    return
  }
  $leaves = @($rows | Where-Object { $_.IsLeaf })
  Add-Result -Project $Project -Rule $code -Status $script:StatusPass `
    -Description ("{0} defined, {1} of them leaf nodes." -f (Format-Count $rows.Count 'iteration'), $leaves.Count) `
    -Note (Format-Count $rows.Count 'iteration defined' 'iterations defined')
}

function Rule_CFG160_IterationsHaveDates {
  # Every sprint (leaf iteration) has a start and a finish date.
  param($Project)
  $code = Get-RuleCode $MyInvocation.MyCommand.Name
  $leaves = @((Get-TreeNodes (Get-ClassificationTree $Project 'iteration')) | Where-Object { $_.IsLeaf })
  $items = @($leaves | Where-Object { -not ($_.Node.attributes -and $_.Node.attributes.startDate -and $_.Node.attributes.finishDate) } |
    ForEach-Object { New-NodeItem $Project $_ 'Iteration' 'No start or finish date' })
  Add-CountResult -Project $Project -RuleCode $code -Items $items -PassNote "Every sprint has dates ($($leaves.Count) checked)" `
    -Singular "sprint has no dates" -Plural "sprints have no dates"
}

function Rule_CFG180_ConsistentIterationLengths {
  # Every sprint (a dated leaf iteration of SprintMaxDays or fewer) is the same number of
  # days. The most common length is the norm; sprints of any other length are flagged. PI
  # nodes are longer than SprintMaxDays and so are left out.
  param($Project)
  $code = Get-RuleCode $MyInvocation.MyCommand.Name
  $leaves = @((Get-TreeNodes (Get-ClassificationTree $Project 'iteration')) | Where-Object { $_.IsLeaf -and $_.Node.attributes -and $_.Node.attributes.startDate -and $_.Node.attributes.finishDate })
  if ($leaves.Count -eq 0) {
    Add-Result -Project $Project -Rule $code -Status $script:StatusPass -Description "No dated sprints to compare." -Note "No dated sprints to compare"
    return
  }
  $max = [int](Get-Setting 'SprintMaxDays' 21)
  $dated = @($leaves | ForEach-Object {
    $days = [int](([datetime]$_.Node.attributes.finishDate).Date - ([datetime]$_.Node.attributes.startDate).Date).TotalDays + 1
    [pscustomobject]@{ Row = $_; Days = $days }
  } | Where-Object { $_.Days -le $max })
  $norm = ($dated | Group-Object Days | Sort-Object Count, Name -Descending | Select-Object -First 1).Name
  $odd = @($dated | Where-Object { [string]$_.Days -ne [string]$norm })
  if ($odd.Count -eq 0) {
    Add-Result -Project $Project -Rule $code -Status $script:StatusPass -Description "All $($dated.Count) dated sprints are $norm days long." -Note "All sprints are $norm days"
    return
  }
  $items = @($odd | ForEach-Object { New-NodeItem $Project $_.Row 'Iteration' "$($_.Days) days, not $norm" })
  $lengths = (($odd | ForEach-Object { $_.Days } | Sort-Object -Unique) -join ', ')
  Add-Result -Project $Project -Rule $code -Status $script:StatusWarning `
    -Description ("{0} of {1} dated sprints are not {2} days long ({3} days)." -f $odd.Count, $dated.Count, $norm, $lengths) `
    -Note ("{0} not {1} days ({2})" -f (Format-Count $odd.Count 'sprint is' 'sprints are'), $norm, $lengths) -Items $items
}


#######################################################################################################################################################################
#                                                                          RULES: WRK (work items)                                                                    #
#######################################################################################################################################################################

function New-TypeFilter([string[]]$Types) {
  # OData filter matching any of the given work item types.
  return "(" + (($Types | ForEach-Object { "WorkItemType eq '$(ConvertTo-ODataString $_)'" }) -join ' or ') + ")"
}

function Get-OpenFilter {
  # OData filter fragment excluding the IgnoreStateCategories setting (default Completed, Removed).
  $f = ""
  foreach ($category in (Get-SettingList 'IgnoreStateCategories' @('Completed', 'Removed'))) {
    $f += " and StateCategory ne '$(ConvertTo-ODataString $category)'"
  }
  return $f
}

# The work item types the hierarchy rules look at, top to bottom.
$script:HierarchyTypes = @('Epic', 'Feature', 'User Story', 'Product Backlog Item', 'Bug', 'Task')

function Test-ParentRule {
  # Shared check behind the hierarchy rules: every open item of the child type(s) has a
  # parent, and that parent is one of the allowed type(s). Reads the children from
  # Analytics with the plain ParentWorkItemId column, then resolves parent types through
  # the work items REST API so parents in other projects count. Items in the
  # IgnoreStateCategories setting (default Completed, Removed) are skipped.
  param(
    [Parameter(Mandatory = $true)]$Project,
    [Parameter(Mandatory = $true)][string]$RuleCode,
    [Parameter(Mandatory = $true)][string[]]$ChildTypes,
    [Parameter(Mandatory = $true)][string]$Singular,
    [Parameter(Mandatory = $true)][string]$Plural,
    [Parameter(Mandatory = $true)][string[]]$ParentTypes,
    [Parameter(Mandatory = $true)][string]$ParentLabel,
    [switch]$AllowNoParent   # no parent is fine; only a parent of the wrong type is flagged
  )

  $filter = (New-TypeFilter $ChildTypes) + (Get-OpenFilter)
  $article = if ($ParentLabel -match '^[AEIOaeio]') { 'an' } else { 'a' }   # "an Epic", "a User Story"

  $children = Get-AnalyticsWorkItems -Project $Project -Filter $filter `
    -Select "WorkItemId,Title,WorkItemType,State,ParentWorkItemId" `
    -Expand "Area(`$select=AreaPath)"

  if ($children.Count -eq 0) {
    if ($AllowNoParent) {
      Add-Result -Project $Project -Rule $RuleCode -Status $script:StatusPass `
        -Description "No $Plural with a wrong parent; there are no open $Plural in this project." -Note "No open $Plural"
    } else {
      Add-Result -Project $Project -Rule $RuleCode -Status $script:StatusPass `
        -Description "No orphaned $Plural; there are no open $Plural in this project." -Note "No open, orphaned $Plural"
    }
    return
  }

  $parentIds = @($children | ForEach-Object { $_.ParentWorkItemId } | Where-Object { $_ } | ForEach-Object { [int]$_ })
  $parents = @{}
  if ($parentIds.Count -gt 0) { $parents = Get-WorkItemFields -Ids $parentIds }

  $items = New-Object System.Collections.Generic.List[object]
  foreach ($c in $children) {
    $problem = $null
    $parentId = $null
    $parentType = $null
    if ($c.ParentWorkItemId) {
      $parentId = [int]$c.ParentWorkItemId
      if ($parents.ContainsKey($parentId)) {
        $parentType = [string]$parents[$parentId].'System.WorkItemType'
        if ($ParentTypes -notcontains $parentType) { $problem = "Parent is a $parentType" }
      } else {
        $parentType = "unreadable"
        $problem = "Parent not readable by this PAT"
      }
    } elseif (-not $AllowNoParent) {
      $problem = "No parent"
    }
    if ($problem) {
      $items.Add([pscustomobject]@{
        Id         = [int]$c.WorkItemId
        Type       = [string]$c.WorkItemType
        Title      = [string]$c.Title
        State      = [string]$c.State
        AreaPath   = if ($c.Area) { [string]$c.Area.AreaPath } else { "" }
        Problem    = $problem
        ParentId   = $parentId
        ParentType = $parentType
        Url        = Get-WorkItemUrl $Project $c.WorkItemId
      })
    }
  }

  $total = Format-Count $children.Count "open $Singular" "open $Plural"
  if ($items.Count -eq 0) {
    if ($AllowNoParent) {
      Add-Result -Project $Project -Rule $RuleCode -Status $script:StatusPass `
        -Description "All $total have no parent or a parent $ParentLabel." -Note "No $Plural with a wrong parent"
    } else {
      Add-Result -Project $Project -Rule $RuleCode -Status $script:StatusPass `
        -Description "No orphaned $Plural; all $total have a parent $ParentLabel." -Note "No orphaned $Plural"
    }
    return
  }

  $noParent    = @($items | Where-Object { $_.Problem -eq 'No parent' }).Count
  $unreadable  = @($items | Where-Object { $_.ParentType -eq 'unreadable' }).Count
  $wrongParent = @($items | Where-Object { $_.Problem -like 'Parent is a *' })
  $parts = @()
  if ($noParent -gt 0) { $parts += "$noParent with no parent" }
  if ($wrongParent.Count -gt 0) {
    $byType = $wrongParent | Group-Object ParentType | Sort-Object Name | ForEach-Object { "$($_.Name): $($_.Count)" }
    $parts += "$($wrongParent.Count) with a parent that is not $article $ParentLabel ($($byType -join ', '))"
  }
  if ($unreadable -gt 0) { $parts += "$unreadable with a parent this PAT cannot read" }

  $found = if ($items.Count -eq 1) { "$Singular found" } else { "$Plural found" }
  if ($AllowNoParent) {
    $description = "{0} with a parent that is not {1} {2}: {3} of {4} ({5})." -f $found, $article, $ParentLabel, $items.Count, $total, ($parts -join '; ')
    $has = if ($items.Count -eq 1) { "has" } else { "have" }
    $note = "{0} {1} a parent that is not {2} {3}" -f (Format-Count $items.Count "open $Singular" "open $Plural"), $has, $article, $ParentLabel
  } else {
    $description = "{0} without parent {1}: {2} of {3} ({4})." -f $found, $ParentLabel, $items.Count, $total, ($parts -join '; ')
    $lack = if ($items.Count -eq 1) { "lacks" } else { "lack" }
    $note = "{0} {1} a parent {2}" -f (Format-Count $items.Count "open $Singular" "open $Plural"), $lack, $ParentLabel
  }
  Add-Result -Project $Project -Rule $RuleCode -Status $script:StatusWarning -Description $description -Note $note -Items ($items | Sort-Object Problem, Id)
}

function Rule_WRK100_NoSameTypeParentLinks {
  # No parent-child link between two items of the same type: no Feature under a
  # Feature, no Epic under an Epic, no Task under a Task.
  param($Project)
  $code = Get-RuleCode $MyInvocation.MyCommand.Name
  $filter = (New-TypeFilter $script:HierarchyTypes) + (Get-OpenFilter) + " and ParentWorkItemId ne null"
  $children = Get-AnalyticsWorkItems -Project $Project -Filter $filter `
    -Select "WorkItemId,Title,WorkItemType,State,ParentWorkItemId" -Expand "Area(`$select=AreaPath)"
  if ($children.Count -eq 0) {
    Add-Result -Project $Project -Rule $code -Status $script:StatusPass `
      -Description "No same-type links; no open items have a parent in this project." -Note "No same-type links (no parent links open)"
    return
  }
  $parents = Get-WorkItemFields -Ids @($children | ForEach-Object { [int]$_.ParentWorkItemId })
  $items = New-Object System.Collections.Generic.List[object]
  foreach ($c in $children) {
    $parentKey = [int]$c.ParentWorkItemId
    if (-not $parents.ContainsKey($parentKey)) { continue }
    $ptype = [string]$parents[$parentKey].'System.WorkItemType'
    if ($ptype -eq [string]$c.WorkItemType) {
      $items.Add([pscustomobject]@{
        Id = [int]$c.WorkItemId; Type = [string]$c.WorkItemType; Title = [string]$c.Title; State = [string]$c.State
        AreaPath = if ($c.Area) { [string]$c.Area.AreaPath } else { "" }
        Problem = "$ptype under $ptype"; ParentId = $parentKey; ParentType = $ptype; Url = Get-WorkItemUrl $Project $c.WorkItemId
      })
    }
  }
  $links = Format-Count $children.Count "parent link"
  if ($items.Count -eq 0) {
    Add-Result -Project $Project -Rule $code -Status $script:StatusPass `
      -Description "No same-type links; $links checked." -Note "No same-type links ($links checked)"
    return
  }
  $byType = $items | Group-Object Type | Sort-Object Name | ForEach-Object { "$($_.Name) under $($_.Name): $($_.Count)" }
  $found = if ($items.Count -eq 1) { "Same-type link found" } else { "Same-type links found" }
  Add-Result -Project $Project -Rule $code -Status $script:StatusWarning `
    -Description ("{0}: {1} of {2} ({3})." -f $found, $items.Count, $links, ($byType -join ', ')) `
    -Note ((Format-Count $items.Count "parent link joins" "parent links join") + " two items of the same type") -Items ($items | Sort-Object Type, Id)
}

function Rule_WRK110_FeaturesHaveParentEpic {
  # Every open Feature has a parent, and that parent is an Epic (D4).
  param($Project)
  Test-ParentRule -Project $Project -RuleCode (Get-RuleCode $MyInvocation.MyCommand.Name) `
    -ChildTypes 'Feature' -Singular 'Feature' -Plural 'Features' `
    -ParentTypes 'Epic' -ParentLabel 'Epic'
}

function Rule_WRK200_StoriesHaveParentFeature {
  # Every open User Story (or Product Backlog Item, once the hub is on Scrum) has a
  # parent, and that parent is a Feature (D4).
  param($Project)
  Test-ParentRule -Project $Project -RuleCode (Get-RuleCode $MyInvocation.MyCommand.Name) `
    -ChildTypes 'User Story', 'Product Backlog Item' -Singular 'User Story' -Plural 'User Stories' `
    -ParentTypes 'Feature' -ParentLabel 'Feature'
}

function Rule_WRK210_BugsHaveParent {
  # Every open Bug has a parent, and that parent is a Feature or a User Story (D16).
  param($Project)
  Test-ParentRule -Project $Project -RuleCode (Get-RuleCode $MyInvocation.MyCommand.Name) `
    -ChildTypes 'Bug' -Singular 'Bug' -Plural 'Bugs' `
    -ParentTypes 'Feature', 'User Story', 'Product Backlog Item' -ParentLabel 'Feature or User Story'
}

function Rule_WRK220_TasksHaveParentStoryOrBug {
  # Every open Task has a parent, and that parent is a User Story, Product Backlog Item
  # or Bug. Tasks are optional, but never orphans (D23).
  param($Project)
  Test-ParentRule -Project $Project -RuleCode (Get-RuleCode $MyInvocation.MyCommand.Name) `
    -ChildTypes 'Task' -Singular 'Task' -Plural 'Tasks' `
    -ParentTypes 'User Story', 'Product Backlog Item', 'Bug' -ParentLabel 'User Story or Bug'
}

function Rule_WRK120_EpicsHaveNoParentOrInitiative {
  # Nothing sits above Epic (D3). An Epic may have no parent, or an Initiative while that
  # type still exists; any other parent is flagged.
  param($Project)
  Test-ParentRule -Project $Project -RuleCode (Get-RuleCode $MyInvocation.MyCommand.Name) `
    -ChildTypes 'Epic' -Singular 'Epic' -Plural 'Epics' `
    -ParentTypes 'Initiative' -ParentLabel 'Initiative' -AllowNoParent
}

$script:StoryTypes = @('User Story', 'Product Backlog Item')

function Get-ParentChildPairs {
  # Every item in the hierarchy that has a parent (any state but Removed), plus a
  # hashtable of the possible parents in the same project with their state category.
  # Fetched once per project and cached, since several rules read the same two queries.
  # Parents in other projects are not resolved, which is right for the hub.
  param($Project)
  if (-not $script:PairsCache) { $script:PairsCache = @{} }
  $key = [string]$Project.id
  if ($script:PairsCache.ContainsKey($key)) { return $script:PairsCache[$key] }
  $parentTypes = @('Epic', 'Feature') + $script:StoryTypes + @('Bug')
  $parents = @{}
  $rows = Get-AnalyticsWorkItems -Project $Project -Filter ((New-TypeFilter $parentTypes) + " and StateCategory ne 'Removed'") `
    -Select "WorkItemId,Title,WorkItemType,State,StateCategory"
  foreach ($r in $rows) { $parents[[int]$r.WorkItemId] = $r }
  $children = Get-AnalyticsWorkItems -Project $Project -Filter ((New-TypeFilter $script:HierarchyTypes) + " and StateCategory ne 'Removed' and ParentWorkItemId ne null") `
    -Select "WorkItemId,Title,WorkItemType,State,StateCategory,ParentWorkItemId" -Expand "Area(`$select=AreaPath)"
  $result = [pscustomobject]@{ Children = @($children); Parents = $parents }
  $script:PairsCache[$key] = $result
  return $result
}

function New-ChildItem($Project, $Child, $Parent, [string]$Problem) {
  [pscustomobject]@{
    Id = [int]$Child.WorkItemId; Type = [string]$Child.WorkItemType; Title = [string]$Child.Title; State = [string]$Child.State
    AreaPath = if ($Child.Area) { [string]$Child.Area.AreaPath } else { "" }
    Problem = $Problem; ParentId = [int]$Parent.WorkItemId; ParentType = [string]$Parent.WorkItemType
    Url = Get-WorkItemUrl $Project $Child.WorkItemId
  }
}

function New-ParentItem($Project, $Parent, [string]$Problem) {
  [pscustomobject]@{
    Id = [int]$Parent.WorkItemId; Type = [string]$Parent.WorkItemType; Title = [string]$Parent.Title
    State = [string]$Parent.State; AreaPath = ""; Problem = $Problem; ParentId = $null; ParentType = $null
    Url = Get-WorkItemUrl $Project $Parent.WorkItemId
  }
}

function Test-ClosedParentRule {
  # No open child under a Closed parent of the given type(s) (D2, D21).
  param($Project, [string]$RuleCode, [string[]]$ParentTypes, [string]$ParentPlural, [string]$ChildPlural)
  $pairs = Get-ParentChildPairs -Project $Project
  $items = New-Object System.Collections.Generic.List[object]
  foreach ($c in $pairs.Children) {
    if ($c.StateCategory -eq 'Completed') { continue }
    $p = $pairs.Parents[[int]$c.ParentWorkItemId]
    if ($null -eq $p -or $ParentTypes -notcontains [string]$p.WorkItemType -or $p.StateCategory -ne 'Completed') { continue }
    $items.Add((New-ChildItem $Project $c $p "Parent $($p.WorkItemType) $($p.WorkItemId) is $($p.State)"))
  }
  if ($items.Count -eq 0) {
    Add-Result -Project $Project -Rule $RuleCode -Status $script:StatusPass `
      -Description "No open $ChildPlural under closed $ParentPlural." -Note "No open $ChildPlural under closed $ParentPlural"
    return
  }
  $byType = $items | Group-Object Type | Sort-Object Name | ForEach-Object { "$($_.Name): $($_.Count)" }
  # Name the children by type when they are all one type (the normal case), else "items".
  $types = @($items | ForEach-Object { $_.Type } | Select-Object -Unique)
  $what = if ($types.Count -eq 1) { Format-Count $items.Count "open $($types[0])" "open $(Get-Plural $types[0])" } else { Format-Count $items.Count "open item" "open items" }
  $sit = if ($items.Count -eq 1) { "sits" } else { "sit" }
  Add-Result -Project $Project -Rule $RuleCode -Status $script:StatusWarning `
    -Description ("{0} {1} under closed {2} ({3})." -f $what, $sit, $ParentPlural, ($byType -join ', ')) `
    -Note ("{0} {1} under closed {2}" -f $what, $sit, $ParentPlural) -Items ($items | Sort-Object ParentId, Id)
}

function Test-AllChildrenClosedRule {
  # An open parent of the given type(s) whose every child is Closed should be Closed:
  # last child Closed sets the parent Closed (D2).
  param($Project, [string]$RuleCode, [string[]]$ParentTypes, [string]$ParentSingular, [string]$ParentPlural)
  $pairs = Get-ParentChildPairs -Project $Project
  $byParent = @{}
  foreach ($c in $pairs.Children) {
    $parentKey = [int]$c.ParentWorkItemId
    if (-not $byParent.ContainsKey($parentKey)) { $byParent[$parentKey] = New-Object System.Collections.Generic.List[object] }
    $byParent[$parentKey].Add($c)
  }
  $items = New-Object System.Collections.Generic.List[object]
  foreach ($parentKey in $byParent.Keys) {
    $p = $pairs.Parents[$parentKey]
    if ($null -eq $p -or $ParentTypes -notcontains [string]$p.WorkItemType -or $p.StateCategory -eq 'Completed') { continue }
    $kids = $byParent[$parentKey]
    if (@($kids | Where-Object { $_.StateCategory -ne 'Completed' }).Count -eq 0) {
      $items.Add((New-ParentItem $Project $p "$($p.State) with all $($kids.Count) children closed"))
    }
  }
  if ($items.Count -eq 0) {
    Add-Result -Project $Project -Rule $RuleCode -Status $script:StatusPass `
      -Description "No open $ParentPlural with closed children." -Note "No open $ParentPlural with closed children"
    return
  }
  $label = if ($items.Count -eq 1) { "open $ParentSingular has" } else { "open $ParentPlural have" }
  Add-Result -Project $Project -Rule $RuleCode -Status $script:StatusWarning `
    -Description ("Open {0} found with every child closed: {1}." -f $ParentPlural, $items.Count) `
    -Note ("{0} {1} only closed children" -f $items.Count, $label) -Items ($items | Sort-Object Id)
}

function Test-ActiveChildRule {
  # A parent of the given type(s) still in the Proposed category (New) while a child is
  # in progress: first child Active sets the parent Active (D2).
  param($Project, [string]$RuleCode, [string[]]$ParentTypes, [string]$ParentSingular, [string]$ParentPlural)
  $pairs = Get-ParentChildPairs -Project $Project
  $seen = @{}
  $items = New-Object System.Collections.Generic.List[object]
  foreach ($c in @($pairs.Children | Where-Object { $_.StateCategory -eq 'InProgress' -or $_.StateCategory -eq 'Resolved' })) {
    $parentKey = [int]$c.ParentWorkItemId
    if ($seen.ContainsKey($parentKey)) { continue }
    $p = $pairs.Parents[$parentKey]
    if ($null -eq $p -or $ParentTypes -notcontains [string]$p.WorkItemType -or $p.StateCategory -ne 'Proposed') { continue }
    $seen[$parentKey] = $true
    $items.Add((New-ParentItem $Project $p "$($p.State) while child $($c.WorkItemType) $($c.WorkItemId) is $($c.State)"))
  }
  if ($items.Count -eq 0) {
    Add-Result -Project $Project -Rule $RuleCode -Status $script:StatusPass `
      -Description "No new $ParentPlural have active children." -Note "No new $ParentPlural have active children"
    return
  }
  $label = if ($items.Count -eq 1) { "new $ParentSingular has" } else { "new $ParentPlural have" }
  Add-Result -Project $Project -Rule $RuleCode -Status $script:StatusWarning `
    -Description ("New {0} found with active children: {1}." -f $ParentPlural, $items.Count) `
    -Note ("{0} {1} active children" -f $items.Count, $label) -Items ($items | Sort-Object Id)
}

# ---- Closed parents with open children
function Rule_WRK300_ClosedEpicsHaveNoOpenChildren    { param($Project); Test-ClosedParentRule -Project $Project -RuleCode (Get-RuleCode $MyInvocation.MyCommand.Name) -ParentTypes 'Epic' -ParentPlural 'Epics' -ChildPlural 'Features' }
function Rule_WRK310_ClosedFeaturesHaveNoOpenChildren { param($Project); Test-ClosedParentRule -Project $Project -RuleCode (Get-RuleCode $MyInvocation.MyCommand.Name) -ParentTypes 'Feature' -ParentPlural 'Features' -ChildPlural 'User Stories' }
function Rule_WRK320_ClosedStoriesHaveNoOpenChildren  { param($Project); Test-ClosedParentRule -Project $Project -RuleCode (Get-RuleCode $MyInvocation.MyCommand.Name) -ParentTypes $script:StoryTypes -ParentPlural 'User Stories' -ChildPlural 'Tasks' }

# ---- Parents with every child Closed should be Closed
function Rule_WRK400_EpicsWithAllChildrenClosedAreClosed    { param($Project); Test-AllChildrenClosedRule -Project $Project -RuleCode (Get-RuleCode $MyInvocation.MyCommand.Name) -ParentTypes 'Epic' -ParentSingular 'Epic' -ParentPlural 'Epics' }
function Rule_WRK410_FeaturesWithAllChildrenClosedAreClosed { param($Project); Test-AllChildrenClosedRule -Project $Project -RuleCode (Get-RuleCode $MyInvocation.MyCommand.Name) -ParentTypes 'Feature' -ParentSingular 'Feature' -ParentPlural 'Features' }
function Rule_WRK420_StoriesWithAllChildrenClosedAreClosed  { param($Project); Test-AllChildrenClosedRule -Project $Project -RuleCode (Get-RuleCode $MyInvocation.MyCommand.Name) -ParentTypes $script:StoryTypes -ParentSingular 'User Story' -ParentPlural 'User Stories' }

# ---- Parents with an active child should be active
function Rule_WRK500_EpicsWithActiveChildAreActive    { param($Project); Test-ActiveChildRule -Project $Project -RuleCode (Get-RuleCode $MyInvocation.MyCommand.Name) -ParentTypes 'Epic' -ParentSingular 'Epic' -ParentPlural 'Epics' }
function Rule_WRK510_FeaturesWithActiveChildAreActive { param($Project); Test-ActiveChildRule -Project $Project -RuleCode (Get-RuleCode $MyInvocation.MyCommand.Name) -ParentTypes 'Feature' -ParentSingular 'Feature' -ParentPlural 'Features' }
function Rule_WRK520_StoriesWithActiveChildAreActive  { param($Project); Test-ActiveChildRule -Project $Project -RuleCode (Get-RuleCode $MyInvocation.MyCommand.Name) -ParentTypes $script:StoryTypes -ParentSingular 'User Story' -ParentPlural 'User Stories' }


#######################################################################################################################################################################
#                                                              RULES: WRK 600 to 900 (placement, state, fields, staleness)                                          #
#######################################################################################################################################################################

function New-WorkItemRow($Project, $W, [string]$Problem) {
  [pscustomobject]@{
    Id = [int]$W.WorkItemId; Type = [string]$W.WorkItemType; Title = [string]$W.Title; State = [string]$W.State
    AreaPath = if ($W.Area) { [string]$W.Area.AreaPath } else { "" }
    Problem = $Problem; ParentId = $null; ParentType = $null; Url = Get-WorkItemUrl $Project $W.WorkItemId
  }
}

function Test-IsSprint($Iteration) {
  # A sprint is an iteration with dates spanning no more than SprintMaxDays. Depth cannot
  # tell: some organizations keep 90-day PI nodes and 14-day sprints side by side under the root.
  if (-not $Iteration -or -not $Iteration.StartDate -or -not $Iteration.EndDate) { return $false }
  $days = ([datetime]$Iteration.EndDate).Date.Subtract(([datetime]$Iteration.StartDate).Date).TotalDays + 1
  return ($days -le [int](Get-Setting 'SprintMaxDays' 21))
}

function Get-UtcCutoff([int]$DaysAgo) {
  return (Get-Date).ToUniversalTime().AddDays(-$DaysAgo).ToString("yyyy-MM-ddTHH:mm:ssZ")
}

function Add-CountResult {
  # Pass when there are no items; otherwise a warning whose note is "<count> <what>".
  param($Project, [string]$RuleCode, $Items, [string]$PassNote, [string]$Singular, [string]$Plural, [string]$Detail = "")
  $Items = @($Items | ForEach-Object { $_ })   # a List[object] trips @().Count here; flatten to a plain array
  if ($Items.Count -eq 0) {
    Add-Result -Project $Project -Rule $RuleCode -Status $script:StatusPass -Description "$PassNote." -Note $PassNote
    return
  }
  $what = Format-Count $Items.Count $Singular $Plural
  $description = if ($Detail) { "$what ($Detail)." } else { "$what." }
  Add-Result -Project $Project -Rule $RuleCode -Status $script:StatusWarning -Description $description -Note $what -Items @($Items | Sort-Object Type, Id)
}

function Get-TypeCounts($Items) {
  return (@($Items) | Group-Object Type | Sort-Object Name | ForEach-Object { "$($_.Name): $($_.Count)" }) -join ', '
}

# ---- Placement
function Rule_WRK600_EpicsAndFeaturesAreNotInASprint {
  # Epics and Features live at the root or PI level of the iteration tree, never in a
  # sprint (an iteration of SprintMaxDays or fewer).
  param($Project)
  $code = Get-RuleCode $MyInvocation.MyCommand.Name
  $rows = Get-AnalyticsWorkItems -Project $Project -Filter ((New-TypeFilter @('Epic', 'Feature')) + (Get-OpenFilter)) `
    -Select "WorkItemId,Title,WorkItemType,State" -Expand "Area(`$select=AreaPath),Iteration(`$select=IterationPath,StartDate,EndDate)"
  $items = @($rows | Where-Object { Test-IsSprint $_.Iteration } |
    ForEach-Object { New-WorkItemRow $Project $_ "In sprint $($_.Iteration.IterationPath)" })
  Add-CountResult -Project $Project -RuleCode $code -Items $items -PassNote "No Epics or Features in a sprint" `
    -Singular "Epic or Feature sits in a sprint" -Plural "Epics and Features sit in a sprint" -Detail (Get-TypeCounts $items)
}

function Rule_WRK610_OpenItemsAreNotInAPastIteration {
  # Nothing open is left in an iteration that has already ended.
  param($Project)
  $code = Get-RuleCode $MyInvocation.MyCommand.Name
  $rows = Get-AnalyticsWorkItems -Project $Project -Filter ((New-TypeFilter $script:HierarchyTypes) + (Get-OpenFilter)) `
    -Select "WorkItemId,Title,WorkItemType,State" -Expand "Area(`$select=AreaPath),Iteration(`$select=IterationPath,EndDate,IsEnded)"
  $items = @($rows | Where-Object { $_.Iteration -and $_.Iteration.IsEnded -eq $true } |
    ForEach-Object { New-WorkItemRow $Project $_ "In ended iteration $($_.Iteration.IterationPath)" })
  Add-CountResult -Project $Project -RuleCode $code -Items $items -PassNote "No open items in a past iteration" `
    -Singular "open item sits in a past iteration" -Plural "open items sit in a past iteration" -Detail (Get-TypeCounts $items)
}

function Rule_WRK620_ExecutionItemsAreNotInTheRootArea {
  # Stories, Bugs and Tasks belong to a team area, never the project root.
  param($Project)
  $code = Get-RuleCode $MyInvocation.MyCommand.Name
  $types = $script:StoryTypes + @('Bug', 'Task')
  $rows = Get-AnalyticsWorkItems -Project $Project -Filter ((New-TypeFilter $types) + (Get-OpenFilter)) `
    -Select "WorkItemId,Title,WorkItemType,State" -Expand "Area(`$select=AreaPath)"
  $items = @($rows | Where-Object { $_.Area -and [string]$_.Area.AreaPath -eq [string]$Project.name } |
    ForEach-Object { New-WorkItemRow $Project $_ "In the root area" })
  Add-CountResult -Project $Project -RuleCode $code -Items $items -PassNote "No Stories, Bugs or Tasks in the root area" `
    -Singular "open item sits in the root area" -Plural "open items sit in the root area" -Detail (Get-TypeCounts $items)
}

# ---- State hygiene
function Rule_WRK700_ItemsAreNotClosedInBatches {
  # Closed means the DoD was met that day, not a batch at Sprint end (D21). Flags groups of
  # BatchSize or more items closed within the same minute over the last BatchWindowDays.
  param($Project)
  $code = Get-RuleCode $MyInvocation.MyCommand.Name
  $size = [int](Get-Setting 'BatchSize' 5)
  $days = [int](Get-Setting 'BatchWindowDays' 90)
  $rows = Get-AnalyticsWorkItems -Project $Project `
    -Filter ((New-TypeFilter $script:HierarchyTypes) + " and StateCategory eq 'Completed' and CompletedDate ge $(Get-UtcCutoff $days)") `
    -Select "WorkItemId,Title,WorkItemType,State,CompletedDate" -Expand "Area(`$select=AreaPath)"
  $groups = @($rows | Group-Object { ([datetime]$_.CompletedDate).ToString('yyyy-MM-dd HH:mm') } | Where-Object { $_.Count -ge $size })
  $items = New-Object System.Collections.Generic.List[object]
  foreach ($g in ($groups | Sort-Object Name)) {
    foreach ($w in $g.Group) { $items.Add((New-WorkItemRow $Project $w "Closed at $($g.Name) with $($g.Count - 1) others")) }
  }
  if ($groups.Count -eq 0) {
    Add-Result -Project $Project -Rule $code -Status $script:StatusPass `
      -Description "No batch closing in the last $days days." -Note "No batch closing in the last $days days"
    return
  }
  $batches = Format-Count $groups.Count "batch" "batches"
  Add-Result -Project $Project -Rule $code -Status $script:StatusWarning `
    -Description ("{0} of {1} or more items closed in the same minute, {2} items in all, in the last {3} days." -f $batches, $size, $items.Count, $days) `
    -Note ("{0} of {1}+ items closed in the same minute" -f $batches, $size) -Items $items
}

function Rule_WRK710_ActiveItemsHaveAnOwner {
  # Anything in progress is assigned to someone.
  param($Project)
  $code = Get-RuleCode $MyInvocation.MyCommand.Name
  $rows = Get-AnalyticsWorkItems -Project $Project `
    -Filter ((New-TypeFilter $script:HierarchyTypes) + " and StateCategory eq 'InProgress' and AssignedToUserSK eq null") `
    -Select "WorkItemId,Title,WorkItemType,State" -Expand "Area(`$select=AreaPath)"
  $items = @($rows | ForEach-Object { New-WorkItemRow $Project $_ "$($_.State) with nobody assigned" })
  Add-CountResult -Project $Project -RuleCode $code -Items $items -PassNote "Every active item has an owner" `
    -Singular "active item has no owner" -Plural "active items have no owner" -Detail (Get-TypeCounts $items)
}

function Rule_WRK720_NoItemsParkedInResolved {
  # Resolved is inside the Cycle Time span, not a place to park work (D11, D21). Flags
  # items that have sat in the Resolved category longer than ResolvedMaxDays.
  param($Project)
  $code = Get-RuleCode $MyInvocation.MyCommand.Name
  $days = [int](Get-Setting 'ResolvedMaxDays' 30)
  $rows = Get-AnalyticsWorkItems -Project $Project `
    -Filter ((New-TypeFilter $script:HierarchyTypes) + " and StateCategory eq 'Resolved' and StateChangeDate lt $(Get-UtcCutoff $days)") `
    -Select "WorkItemId,Title,WorkItemType,State,StateChangeDate" -Expand "Area(`$select=AreaPath)"
  $items = @($rows | ForEach-Object { New-WorkItemRow $Project $_ "$($_.State) since $(([datetime]$_.StateChangeDate).ToString('yyyy-MM-dd'))" })
  Add-CountResult -Project $Project -RuleCode $code -Items $items -PassNote "No items parked in Resolved beyond $days days" `
    -Singular "item has sat in Resolved for over $days days" -Plural "items have sat in Resolved for over $days days" -Detail (Get-TypeCounts $items)
}

# ---- Fields
function Rule_WRK800_SprintItemsHaveAnEstimate {
  # Every Story or Bug in a sprint carries an estimate (D8, D13). The field name comes
  # from the EstimateField setting (StoryPoints on Agile, Effort on Scrum).
  param($Project)
  $code = Get-RuleCode $MyInvocation.MyCommand.Name
  $field = [string](Get-Setting 'EstimateField' 'StoryPoints')
  $rows = Get-AnalyticsWorkItems -Project $Project `
    -Filter ((New-TypeFilter ($script:StoryTypes + @('Bug'))) + (Get-OpenFilter) + " and $field eq null") `
    -Select "WorkItemId,Title,WorkItemType,State" -Expand "Area(`$select=AreaPath),Iteration(`$select=IterationPath,StartDate,EndDate)"
  $items = @($rows | Where-Object { Test-IsSprint $_.Iteration } |
    ForEach-Object { New-WorkItemRow $Project $_ "No $field in $($_.Iteration.IterationPath)" })
  Add-CountResult -Project $Project -RuleCode $code -Items $items -PassNote "Every Story and Bug in a sprint has an estimate" `
    -Singular "sprint item has no estimate" -Plural "sprint items have no estimate" -Detail (Get-TypeCounts $items)
}

# ---- Staleness
function Rule_WRK900_NoStaleOpenItems {
  # Nothing open has gone untouched for more than StaleDays.
  param($Project)
  $code = Get-RuleCode $MyInvocation.MyCommand.Name
  $days = [int](Get-Setting 'StaleDays' 90)
  $rows = Get-AnalyticsWorkItems -Project $Project `
    -Filter ((New-TypeFilter $script:HierarchyTypes) + (Get-OpenFilter) + " and ChangedDate lt $(Get-UtcCutoff $days)") `
    -Select "WorkItemId,Title,WorkItemType,State,ChangedDate" -Expand "Area(`$select=AreaPath)"
  $items = @($rows | ForEach-Object { New-WorkItemRow $Project $_ "Untouched since $(([datetime]$_.ChangedDate).ToString('yyyy-MM-dd'))" })
  Add-CountResult -Project $Project -RuleCode $code -Items $items -PassNote "No open items untouched for over $days days" `
    -Singular "open item untouched for over $days days" -Plural "open items untouched for over $days days" -Detail (Get-TypeCounts $items)
}


# =============================================================================
# Report rendering
# =============================================================================

function Coalesce {
  # First argument that is not null, an empty string, or an empty array.
  foreach ($a in $args) {
    if ($null -eq $a) { continue }
    if ($a -is [string] -and $a -eq '') { continue }
    if ($a -is [array] -and $a.Count -eq 0) { continue }
    return $a
  }
  return $null
}

function MdCell([object]$Value) {
  if ($null -eq $Value) { return "" }
  return ([string]$Value -replace '\|', '\|' -replace '[\r\n]+', ' ').Trim()
}

function Get-StatusGlyph([string]$Status) {
  # Green, yellow and red circles, built from code points so this file stays plain ASCII.
  switch ($Status) {
    'Pass'    { return [char]::ConvertFromUtf32(0x1F7E2) }
    'Warning' { return [char]::ConvertFromUtf32(0x1F7E1) }
    default   { return [char]::ConvertFromUtf32(0x1F534) }
  }
}

function New-AdoCopLog {
  # Companion to the report: every warning and error with the actual items behind it,
  # grouped by rule in the same order as the report table.
  param($Results, [datetime]$Started)
  $sb = New-Object System.Text.StringBuilder
  $add = { param($line) [void]$sb.AppendLine($line) }
  $projects = @($Results | ForEach-Object { $_.Project } | Select-Object -Unique)
  $flagged = @($Results | Where-Object { $_.Status -ne $script:StatusPass } | Sort-Object Rule, Project)

  & $add "ado-cop log, $($script:Org), $($Started.ToString('yyyy-MM-dd HH:mm')). Warnings and errors only; the summary is ado-cop.md."
  if ($flagged.Count -eq 0) {
    & $add ""
    & $add "Nothing to report: every rule passed."
    return $sb.ToString()
  }
  foreach ($r in $flagged) {
    & $add ""
    $where = if ($projects.Count -gt 1) { " ($($r.Project))" } else { "" }
    & $add "Rule: $($r.Title)$where  [$($r.Status)]  $($r.Description)"
    if (@($r.Items).Count -eq 0) { continue }
    foreach ($i in $r.Items) {
      $problem = [string]$i.Problem
      if ($i.ParentId -and $problem -notmatch "\b$($i.ParentId)\b") { $problem += " (parent $($i.ParentId))" }
      $area = if ($i.AreaPath) { "  $($i.AreaPath)" } else { "" }
      & $add ("  {0,-20} {1,7}  {2,-10}  {3}  |  {4}{5}" -f $i.Type, $i.Id, $i.State, $problem, $i.Title, $area)
    }
  }
  return $sb.ToString()
}

function New-AdoCopReport {
  param($Results, $Missing, [datetime]$Started)
  $sb = New-Object System.Text.StringBuilder
  $add = { param($line) [void]$sb.AppendLine($line) }

  $projects = @($Results | ForEach-Object { $_.Project } | Select-Object -Unique)
  $rules    = @($Results | ForEach-Object { $_.Rule } | Select-Object -Unique | Sort-Object)

  & $add "# ado-cop report"
  & $add ""
  & $add "$($script:Org), $($Started.ToString('yyyy-MM-dd HH:mm')). $(Format-Count $rules.Count 'rule'), $(Format-Count $projects.Count 'project')."
  & $add ""
  if ($Missing -and @($Missing).Count -gt 0) {
    $names = (@($Missing) | ForEach-Object { '`' + $_ + '`' }) -join ', '
    & $add "Not found or not visible to the PAT: $names."
    & $add ""
  }

  # One table, one row per rule (per project when more than one is inspected): rule
  # number, rule name, status light, short note. Each rule family (CFG, WRK, ...) opens
  # with a bold label row, since Markdown cannot draw a line inside a table. The items
  # are in the log and the JSON.
  $labels = @{ CFG = 'Configuration'; WRK = 'Work Items'; REP = 'Repos' }
  & $add "| Rule | Description | Status | Notes |"
  & $add "|:--|:--|:--:|:--|"
  $family = $null
  foreach ($r in @($Results | Sort-Object Rule, Project)) {
    $f = $r.Rule.Substring(0, 3)
    if ($f -ne $family) {
      $family = $f
      $label = if ($labels.ContainsKey($f)) { "$f ($($labels[$f]))" } else { $f }
      & $add "| **$label** |  |  |  |"
    }
    $name = MdCell ($r.Title -replace '^[A-Z]{3}\d{3}:\s*', '')
    if ($projects.Count -gt 1) { $name += " ($(MdCell $r.Project))" }
    & $add "| $(MdCell $r.Rule) | $name | $(Get-StatusGlyph $r.Status) | $(MdCell $r.Note) |"
  }
  & $add ""

  $elapsed = (Get-Date) - $Started
  & $add "_$([int]$elapsed.TotalSeconds) seconds, read-only REST calls, ado-cop.ps1._"
  return $sb.ToString()
}

Main
