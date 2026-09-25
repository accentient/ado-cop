# ado-cop

  Opinionated, rules-based analyzer for Azure DevOps organizations. Every rule has an ID, an
  explanation and an off switch.

  **ado-cop** runs a set of rules against an Azure DevOps Services organization and reports what
  looks off: features with no parent epic, open items under closed parents, sprints without
  dates, a hub project with Repos still switched on, items closed in a batch on the last day
  of the Sprint. It reads what the organization holds today, projects and processes, work items
  and boards, iterations and areas, repos, pipelines, feeds, and grows toward extensions,
  teams and permissions. The output is a Markdown report with a green, yellow or red light
  per rule, a log of the exact items behind every warning, and a JSON file for tooling.

  The rules are opinionated by design. They encode one way of running Azure DevOps that
  keeps work visible and flow metrics honest. They are not a standard anyone is obliged to
  meet, so read the report as a conversation starter with your teams, not a compliance
  score. When a rule does not fit how a team works, turn it off.

  ado-cop is not affiliated with Microsoft. Azure DevOps is a trademark of Microsoft.

  ## What a run looks like

  ```
  # ado-cop report

  contoso, 2026-09-01 09:05. 31 rules, 1 project.

  | Rule   | Description                                   | Status | Notes                                        |
  |:-------|:----------------------------------------------|:------:|:---------------------------------------------|
  | **CFG (Configuration)** |                              |        |                                              |
  | CFG000 | Project uses expected process                 | 🟡     | Hub uses Agile, expected Contoso Scrum       |
  | CFG100 | Project has expected services enabled         | 🟢     | Boards                                       |
  | CFG110 | Project does not have unexpected services enabled | 🟡 | Unexpected: Repos, Pipelines                 |
  | CFG160 | Iterations have dates                         | 🟢     | Every sprint has dates (12 checked)          |
  | CFG190 | Iterations follow the same cadence            | 🟢     | All sprints run Wednesday to Tuesday         |
  | **WRK (Work Items)** |                                 |        |                                              |
  | WRK110 | Closed Epics have no open children            | 🟡     | 3 open Features sit under closed Epics       |
  | WRK200 | Features have parent Epic                     | 🟡     | 40 open Features lack a parent Epic          |
  | WRK800 | Items are not closed in batches               | 🟢     | No batch closing in the last 90 days         |
  | WRK900 | No stale open items                           | 🟡     | 12 open items untouched for over 90 days     |
  ```

  Two optional companions, both off unless the rules file switches them on: `ado-cop.log`
  (`WriteLog`) lists the offending items by ID, type, title, state and area, grouped by rule
  in the same order (the first `MaxLogItems` per rule, 50 by default), and `ado-cop.json`
  (`WriteJson`) holds every result and every item for anything downstream (Power BI, a
  dashboard widget, a wiki page).

  ## Read-only, by construction

  Every request the script makes goes through one function that hard-codes the HTTP `GET`
  verb. Work item queries use the Analytics OData service, which is a `GET`, rather than
  WIQL, which is a `POST`. A personal access token with only Read scopes is enough, and
  nothing in the organization can change as a result of a run. If you add a rule, keep
  that guarantee: do not add a second call to `Invoke-RestMethod` or `Invoke-WebRequest`.

  ## Quick start

  Requirements: Windows PowerShell 5.1 or PowerShell 7 on any platform, and a PAT with the
  Read scopes listed below.

  ```powershell
  git clone https://github.com/<you>/ado-cop.git
  cd ado-cop
  .\ado-cop.ps1 -AdoOrgUrl https://dev.azure.com/<organization>/ -AdoToken <pat> -Projects <project>
  ```

  The report lands next to the script as `ado-cop.md`. Pass `-OutputPath` to put it
  somewhere else. Switch on `WriteLog` or `WriteJson` in the rules file to get the item
  log and the JSON beside it.

  On Windows you can keep the token out of your shell history by storing it in Credential
  Manager as a generic credential (user name `pat`, the token as the password) and naming
  the entry in the rules file (`PatEntryName`) or on the command line:

  ```powershell
  .\ado-cop.ps1 -AdoOrgUrl https://dev.azure.com/<organization>/ -PatEntryName <entry-name> -Projects <project>
  ```

  The script only reads the entry; it never writes one. The rules file holds the entry's
  name, never the token.

  ### Parameters

  | Parameter | Meaning |
  |:--|:--|
  | `-AdoOrgUrl` | Organization URL, `https://dev.azure.com/<organization>/` |
  | `-AdoToken` | The PAT. Use this in pipelines, from a secret variable |
  | `-PatEntryName` | Windows Credential Manager entry holding the PAT. Use this locally instead of `-AdoToken`. Overrides the `PatEntryName` setting in the rules file |
  | `-Projects` | One or more project names to inspect. Every active rule runs once per project |
  | `-RulesFile` | Path to the rules file. Defaults to `rules.json` next to the script |
  | `-OutputPath` | Where to write the report. The `.log` and `.json` go next to it |

  Run `Test-AdoConnection` (uncomment the call at the top of the script) to confirm the
  token works and see which projects it can reach before running the rules.

  ## Running as a pipeline

  `pipeline.yml` runs the same script on a Linux agent on a weekday schedule and publishes
  the report as a pipeline artifact. Every warning or error is also logged as a pipeline
  issue, and the job finishes as "succeeded with issues" when any rule did not pass, so the
  run summary shows the state at a glance.

  Setup:

  1. Create a pipeline from `pipeline.yml`.
  2. Add a secret variable named `adoToken` holding a PAT with the Read scopes below. The
     pipeline's own `$(System.AccessToken)` also works if the build identity has been given
     access to every project you inspect.
  3. Edit the `-Projects` list in the YAML.

  ## PAT scopes

  Create the PAT as a custom-defined token and tick **Read** only. No Write, Manage or Full
  access scope is ever needed.

  The scopes below are in the order the token page lists them.

  | Scope (Read) | Used for |
  |:--|:--|
  | Analytics | Work item queries for every WRK rule |
  | Build | Build pipelines |
  | Code | Git repositories and TFVC |
  | Graph | Teams and permissions rules, when you enable them |
  | Packaging | Artifact feeds |
  | Project and Team | Project list, process name, area and iteration trees, teams and their members |
  | Release | Classic release pipelines |
  | Work Items | Parent lookups across projects, text fields, links, work item type fields |

  Two limits worth knowing. Analytics refuses Stakeholder accounts, so the PAT owner needs
  Basic or higher plus the "View analytics" project permission that Readers and
  Contributors have by default; Analytics can also lag live data by a few minutes. And
  CFG100, CFG110 and their hub and spoke twins CFG120 to CFG132, the rules that read which services a project has switched on, need a
  PAT scope the token page does not offer. The next section explains.

  ### CFG100, CFG110 and the hidden scope

  CFG100 and CFG110 read the switches under Project settings, Overview, "Azure DevOps
  services" through the Feature Management API:

  ```
  GET https://dev.azure.com/{org}/_apis/FeatureManagement/FeatureStates/host/project/{projectId}/{featureId}?api-version=7.1-preview.1
  ```

  with feature ids `ms.vss-work.agile` (Boards), `ms.vss-code.version-control` (Repos),
  `ms.vss-build.pipelines` (Pipelines), `ms.vss-test-web.test` (Test Plans) and
  `ms.azure-artifacts.feature` (Artifacts). A state of `undefined` means the default, which
  is on. Two gotchas cost a day, so they are written down here.

  **Artifacts has two ids.** `ms.feed.feed` also exists and always reads `undefined`, so a
  script that queries it reports Artifacts as on in projects where it is off. The toggle
  is `ms.azure-artifacts.feature`.

  **No checkbox on the token page unlocks the API.** With a custom-defined PAT it answers a
  bare 401, empty body, no `WWW-Authenticate` header, whatever is ticked. Tried and failed
  on 24 September 2026: every Read scope at once; Extensions (Read); Project and Team
  (Read, write, & manage); the POST `FeatureStatesQuery` endpoint the Terraform provider
  uses; the Settings Entries API; the organization-level and user-level paths; the plain
  feature list. A full-access PAT works, which is where most write-ups stop.

  The actual gate is a scope called `vso.features` (and `vso.features_write` for
  changes). The Azure DevOps service team confirmed it to the Terraform provider
  maintainers; it is simply not on the token page. It can only be set through the PAT
  lifecycle API, `PUT https://vssps.dev.azure.com/{org}/_apis/tokens/pats`, which refuses
  PATs and wants an Entra ID sign-in. The scope takes about a minute to propagate, so the
  first call after adding it may still return 401.

  `tools\Add-PatFeaturesScope.ps1` does all of this. It signs you in through the browser
  using the MSAL library that ships inside the `Microsoft.Graph.Authentication` PowerShell
  module, so nothing needs installing, lists your PATs with their real scope strings (the
  listing alone is worth seeing: those strings are what the token page's checkboxes map
  to), and with `-Apply` appends `vso.features` to the PAT you name. The token string does
  not change, so Credential Manager needs no update.

  ```powershell
  .\tools\Add-PatFeaturesScope.ps1 -Org <organization> -Tenant <tenant.com> -DisplayName <pat-name>
  .\tools\Add-PatFeaturesScope.ps1 -Org <organization> -Tenant <tenant.com> -DisplayName <pat-name> -Apply
  ```

  The tenant is the Entra tenant the organization is connected to, and you sign in with an
  account that is a member of the organization. The tool is the one file in this
  repository that issues anything other than GET, and it touches only your own token.
  `ado-cop.ps1` itself stays GET-only whatever the PAT can do. If you would rather not add
  the scope, switch CFG100 and CFG110 off and read the Overview page in the browser.

  ## The rules file

  `rules.json` is a flat object with three kinds of key:

  - **Rules.** A key shaped `XXX###_RuleName` whose value is `true` runs the function
    `Rule_XXX###_RuleName` in the script; `false` skips it. A key with no matching function
    is reported as an error rather than ignored, so a typo shows up in the report.
  - **`Test_Rule`.** Set it to one rule name to run only that rule, whatever the flags say.
    Handy while writing a rule. Leave it empty otherwise.
  - **Settings.** Anything else. Rules read them with `Get-Setting 'Name' default` or
    `Get-SettingList 'Name' @(defaults)` for comma-separated lists.

  | Setting | Default | Used by | Meaning |
  |:--|:--|:--|:--|
  | `PatEntryName` | `ado-cop-PAT` | credential lookup | The Windows Credential Manager entry that holds the PAT when `-AdoToken` and `-PatEntryName` are not passed. The name only; the token stays in Credential Manager |
  | `MaxLogItems` | `50` | the log | Most items a rule lists in `ado-cop.log`; the rest are counted on a closing line. `0` lists everything. The JSON always holds every item |
  | `ProjectModel` | `Standard` | process and services rules | `Standard`: one project holds work and code, checked by CFG000, CFG100 and CFG110 through `Project`, `ExpectedProcess` and `ExpectedServices`. `HubSpoke`: a hub holds the work items and spokes hold the code, checked by CFG002, CFG004 and CFG120 to CFG132 through the `Hub*` and `Spoke*` settings. Switch on the family that matches; a rule from the other family reports red |
  | `Project`, `ExpectedProcess`, `ExpectedServices` | none | CFG000, CFG100, CFG110 | Standard model: the project to hold to the process and to the comma-separated services (any of `Boards`, `Repos`, `Pipelines`, `Test Plans`, `Artifacts`). An empty `Project` applies them to every inspected project; an empty process or service list skips that check. CFG100 flags listed services that are off; CFG110 flags services that are on but not listed |
  | `HubProject`, `ExpectedHubProcess`, `ExpectedHubServices` | none | CFG002, CFG120, CFG122 | HubSpoke model: the hub project, its process, and its services (a hub lists `Boards`). These rules read the named project directly, so they run once whatever `-Projects` says |
  | `SpokeProjects`, `ExpectedSpokeProcess`, `ExpectedSpokeServices` | none | CFG004, CFG130, CFG132 | HubSpoke model: the comma-separated spoke projects, their process, and their services (spokes usually list `Repos, Pipelines, Artifacts`). An empty process or service list just reports what each spoke uses |
  | `WriteLog` | `false` | output | Also write `ado-cop.log`, the per-item listing behind every warning |
  | `WriteJson` | `false` | output | Also write `ado-cop.json`, every result and every item, for tooling |
  | `IgnoreStateCategories` | `Completed,Removed` | every WRK rule | State categories that do not count as open |
  | `SprintMaxDays` | `21` | iteration rules | An iteration spanning this many days or fewer is a sprint; longer ones are PIs or releases. CFG180 and CFG190 compare only sprints |
  | `ResolvedMaxDays` | `30` | WRK820 | Days an item may sit in the Resolved category before it counts as parked |
  | `StaleDays` | `90` | WRK900 | Days without a change before an open item counts as stale |
  | `BatchWindowDays`, `BatchSize` | `90`, `5` | WRK800 | Look back this many days; this many items closed in one minute is a batch |
  | `EstimateField` | `StoryPoints` | WRK850, WRK370 | The Analytics estimate column: `StoryPoints` on Agile, `Effort` on Scrum |
  | `BugsAreRequirements` | `true` | WRK360, WRK370, WRK600, WRK850, WRK980 | `true` when the teams manage Bugs on the backlog alongside Stories, so the sprint-item rules include Bugs; `false` when Bugs are managed as Tasks |
  | `SprintMaxEstimate` | `8` | WRK370 | Largest estimate a Story or Bug may carry inside a sprint |
  | `PlanAheadSprints` | `1` | WRK785 | How many sprints past the current one may hold open items |
  | `ProductOwners` | none | WRK815 | Comma-separated display names or emails; when set, every open Epic and Feature must be assigned to one of them. Empty means any owner will do |
  | `CycleWindowDays` | `90` | WRK980 | Look back this many days at completed Stories and Bugs when comparing Cycle Time to sprint length |
  | `SprintNamePattern` | none | CFG157 | Regular expression every sprint name must match, `^Sprint (\d{3})$` say; a captured number must run without gaps. Empty skips the check |
  | `SprintLengthDays` | none | CFG180 | The agreed sprint length; when set, every sprint must be exactly this long, otherwise the most common length is the norm. Keep it at or below `SprintMaxDays` |
  | `ExpectedTeams` | none | CFG305, CFG307 | Comma-separated team names the project should have. CFG305 flags listed teams that are missing; CFG307 flags teams that exist but are not listed. Empty just lists the teams |
  | `TeamMaxMembers` | `10` | CFG315 | Most members a team may have |

  Every active rule runs once per project, in the order the keys appear. `rules.md` is the
  human-readable catalogue: every rule number, what it checks, why it matters, and which
  metric goes wrong when it fails.

  ## Rule families

  Rule IDs are three letters and three digits. The letters are the family; the digits leave
  room, a new hundred when the idea changes and the next ten within an idea. In the WRK
  family the hundreds are work item types: WRK1xx Epics, WRK2xx Features, WRK3xx Stories,
  WRK4xx Bugs, WRK5xx Tasks, WRK6xx testing, and WRK7xx to WRK9xx for rules that
  span types or sit beside the work items (hierarchy and placement, state and fields, flow
  and staleness).

  | Family | Covers | Examples |
  |:--|:--|:--|
  | CFG | Project and process configuration: process, services, areas, iterations, teams, hub and spoke shape | CFG000 project uses the expected process; CFG160 iterations have dates; CFG190 iterations follow the same cadence |
  | WRK | Work item hygiene: parent chain, rollup, placement, closing discipline, ownership, estimates, staleness | WRK200 features have a parent epic; WRK110 closed epics have no open children; WRK800 items are not closed in batches |
  | REP | Repositories and branch policy | planned |
  | PIP | Pipelines and their settings | planned |
  | FED | Artifact feeds | planned |
  | EXT | Installed extensions | planned |
  | PRM | Teams, groups and permissions | planned |

  A rule reports one of three states. Green: the rule holds. Yellow: the rule is broken and
  the items are in the log. Red: the rule could not run (the API refused, the setting is
  missing, the function threw), and the note says why.

  ## Adding a rule

  1. Pick a number in the right family (`rules.md` shows the bands in use). Write
     `function Rule_XXX###_Name { param($Project) ... }`. The function gets the project
     object from the projects API; `$Project.name` and `$Project.id` are what you usually
     need. The title in the report comes from the function name, so name it as a sentence.
  2. Read what you need through `Invoke-AdoGet` or `Get-AnalyticsWorkItems`, and nothing
     else. Most rules fit one of the helpers: `Test-ParentRule` for "every X has a parent
     of type Y", `Add-CountResult` for "here is a list of offenders", and
     `Get-ParentChildPairs` for anything that compares a parent's state with its
     children's.
  3. Finish with `Add-Result -Project $Project -Rule $ruleCode -Status ... -Description ...
     -Note ...`, adding `-Items` when there is a list worth showing. `Description` is the
     full finding for the console, `Note` the few words for the report table. Items with
     `Id`, `Type`, `Title`, `State`, `AreaPath`, `Problem` and `Url` properties are written
     to the log and the JSON. Throwing is fine; the engine catches it and records a red
     result.
  4. Add the key to `rules.json` and a row to `rules.md`, marked ✅ now that it is
     implemented.

  Write the rule as an opinion you can defend in one sentence. If you cannot say which
  metric or which team habit it protects, it is a preference, not a rule.

  ## Notes and limits

  - The parent rules read the parent ID from Analytics and resolve the parent's type
    through the work items API, so a parent in another project still counts. The rollup
    rules only see parents in the same project, which is the right answer for a hub.
  - "Open" means every state category except Completed and Removed, so Resolved counts as
    open. Adjust `IgnoreStateCategories` if your process disagrees.
  - Analytics reports items in a Removed state with an empty `StateCategory`, and its `ne`
    filter follows SQL rules and drops nulls, so `StateCategory ne 'Removed'` still excludes
    them. A rule that wants the Removed items must ask for `StateCategory eq 'Removed' or
    StateCategory eq null` (`Get-RemovedFilter`); `eq 'Removed'` alone finds nothing.
  - The report, log and JSON name work items by ID and title. They are client data. Do not
    commit them, and scrub anything you use as a sample. `.gitignore` excludes the default
    output names.
  - The rules assume Azure DevOps Services. Azure DevOps Server will mostly work for the
    REST rules and mostly not for the Analytics ones.

  ## License

  MIT. See `LICENSE`.
