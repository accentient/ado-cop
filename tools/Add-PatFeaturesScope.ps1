# Adds the hidden vso.features scope to one of your existing Azure DevOps PATs so that
# CFG100 can read which services a project has enabled.
#
# The token page never shows this scope, and the Feature Management API answers a bare
# 401 to any PAT without it. The PAT lifecycle API can set it, but that API accepts only
# an Entra ID sign-in, never a PAT, so this script opens your browser to sign you in.
# It uses the MSAL library that ships inside the Microsoft.Graph.Authentication
# PowerShell module (Install-Module Microsoft.Graph.Authentication if it is missing).
#
#   .\tools\Add-PatFeaturesScope.ps1 -Org contoso -Tenant contoso.com -DisplayName ado-cop-PAT
#       Signs in and lists your PATs with their real scope strings. Changes nothing.
#   .\tools\Add-PatFeaturesScope.ps1 -Org contoso -Tenant contoso.com -DisplayName ado-cop-PAT -Apply
#       Also appends " vso.features" to that PAT's scope and, when -CredEntry names the
#       Credential Manager entry holding the token, tests the Feature Management GET with it.
#
# A scope update keeps the token string, so Credential Manager needs no change. Give the
# scope a minute to propagate before the first ado-cop run. This is the only file in the
# repository that issues anything other than GET, and it touches only your own PAT.
param(
  [Parameter(Mandatory = $true)][string]$Org,          # organization name, as in https://dev.azure.com/<Org>/
  [Parameter(Mandatory = $true)][string]$Tenant,       # Entra tenant of the organization, e.g. contoso.com or its GUID
  [Parameter(Mandatory = $true)][string]$DisplayName,  # the PAT's name on the token page
  [string]$CredEntry,                                  # Credential Manager entry holding that PAT, for the test
  [switch]$Apply
)
$ErrorActionPreference = 'Stop'

# ---- MSAL from the Graph PowerShell module
$mod = Get-Module -ListAvailable Microsoft.Graph.Authentication | Sort-Object Version -Descending | Select-Object -First 1
if (-not $mod) { throw "Microsoft.Graph.Authentication is not installed. Run: Install-Module Microsoft.Graph.Authentication -Scope CurrentUser" }
Add-Type -Path (Join-Path $mod.ModuleBase "Dependencies\Microsoft.IdentityModel.Abstractions.dll")
Add-Type -Path (Join-Path $mod.ModuleBase "Dependencies\Core\Microsoft.Identity.Client.dll")

# Azure CLI's public client id, pre-consented for the Azure DevOps resource in every tenant.
$app = [Microsoft.Identity.Client.PublicClientApplicationBuilder]::Create('04b07795-8ddb-461a-bbee-02f9e1bf7b46').
  WithAuthority("https://login.microsoftonline.com/$Tenant").WithRedirectUri('http://localhost').Build()
$scopes = [string[]]@('499b84ac-1321-427f-aa17-267ca6975798/.default')
Write-Host "Signing in to $Tenant in your browser..." -ForegroundColor Cyan
$auth = $app.AcquireTokenInteractive($scopes).ExecuteAsync().GetAwaiter().GetResult()
Write-Host ("Signed in as {0}" -f $auth.Account.Username) -ForegroundColor Green
$bearer = @{ Authorization = "Bearer " + $auth.AccessToken; Accept = "application/json" }

# ---- List PATs
$base = "https://vssps.dev.azure.com/$Org/_apis/tokens/pats"
$list = Invoke-RestMethod -Uri "$base`?api-version=7.1-preview.1" -Headers $bearer -Method Get
Write-Host ""
Write-Host "Your PATs in ${Org}:" -ForegroundColor Cyan
foreach ($p in $list.patTokens) {
  Write-Host ("  {0,-28} valid to {1:yyyy-MM-dd}  scope: {2}" -f $p.displayName, [datetime]$p.validTo, $p.scope)
}

$target = @($list.patTokens | Where-Object { $_.displayName -eq $DisplayName })
if ($target.Count -ne 1) { throw "Expected exactly one PAT named '$DisplayName', found $($target.Count)." }
$target = $target[0]
if ($target.scope -match '\bvso\.features\b') {
  Write-Host ""; Write-Host "'$DisplayName' already has vso.features." -ForegroundColor Yellow
} elseif (-not $Apply) {
  Write-Host ""; Write-Host "Run again with -Apply to add vso.features to '$DisplayName'." -ForegroundColor Yellow
  return
} else {
  # ---- Update the PAT's scope. Name, expiry and the token itself are kept.
  $body = @{
    authorizationId = $target.authorizationId
    displayName     = $target.displayName
    scope           = ($target.scope.Trim() + " vso.features")
    validTo         = $target.validTo
    allOrgs         = $false
  } | ConvertTo-Json
  $res = Invoke-RestMethod -Uri "$base`?api-version=7.1-preview.1" -Headers $bearer -Method Put -Body $body -ContentType "application/json"
  if ($res.patTokenError -and $res.patTokenError -ne 'none') { throw "PAT update refused: $($res.patTokenError)" }
  Write-Host ""; Write-Host ("Updated. New scope: {0}" -f $res.patToken.scope) -ForegroundColor Green
  Write-Host "Allow a minute for the scope to propagate." -ForegroundColor Yellow
}

# ---- Optional test with the PAT from Credential Manager
if (-not $CredEntry) { return }
Add-Type -TypeDefinition @"
using System; using System.Runtime.InteropServices;
public static class PatCred {
  [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
  public struct CREDENTIAL { public uint Flags; public uint Type; public string TargetName; public string Comment; public System.Runtime.InteropServices.ComTypes.FILETIME LastWritten; public uint CredentialBlobSize; public IntPtr CredentialBlob; public uint Persist; public uint AttributeCount; public IntPtr Attributes; public string TargetAlias; public string UserName; }
  [DllImport("advapi32.dll", EntryPoint = "CredReadW", CharSet = CharSet.Unicode, SetLastError = true)] static extern bool CredRead(string target, uint type, uint flags, out IntPtr credential);
  [DllImport("advapi32.dll")] static extern void CredFree(IntPtr credential);
  public static string Read(string target) { IntPtr ptr; if (!CredRead(target, 1, 0, out ptr)) return null; try { CREDENTIAL c = (CREDENTIAL)Marshal.PtrToStructure(ptr, typeof(CREDENTIAL)); return c.CredentialBlobSize == 0 ? "" : Marshal.PtrToStringUni(c.CredentialBlob, (int)c.CredentialBlobSize / 2); } finally { CredFree(ptr); } }
}
"@
$pat = [PatCred]::Read($CredEntry)
if (-not $pat) { Write-Host "No Credential Manager entry '$CredEntry'; skipping the test." -ForegroundColor Yellow; return }
$basic = @{ Authorization = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(":" + $pat)); Accept = "application/json" }
$pat = $null
$project = (Invoke-RestMethod -Uri "https://dev.azure.com/$Org/_apis/projects?`$top=1&api-version=7.1" -Headers $basic).value | Select-Object -First 1
Write-Host ""; Write-Host "Feature Management GET for project '$($project.name)' with the '$CredEntry' PAT (retrying for up to two minutes):" -ForegroundColor Cyan
$deadline = (Get-Date).AddMinutes(2)
do {
  try {
    $r = Invoke-RestMethod -Uri "https://dev.azure.com/$Org/_apis/FeatureManagement/FeatureStates/host/project/$($project.id)/ms.vss-work.agile?api-version=7.1-preview.1" -Headers $basic -Method Get
    Write-Host ("  Boards state = {0}. The scope works." -f $r.state) -ForegroundColor Green
    return
  } catch {
    Write-Host "  401, waiting 15 seconds for the scope to propagate..." -ForegroundColor DarkYellow
    Start-Sleep -Seconds 15
  }
} while ((Get-Date) -lt $deadline)
Write-Host "  Still 401 after two minutes. Check the scope string above and try again in a few minutes." -ForegroundColor Red
