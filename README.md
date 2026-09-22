# ado-cop

  Opinionated, rules-based analyzer for Azure DevOps organizations. Every rule has an ID, an
  explanation and an off switch.

  **ado-cop** runs a set of rules against an Azure DevOps Services organization and reports what
  looks off: features with no parent epic, open items under closed parents, sprints without
  dates, a hub project that still holds repos, items closed in a batch on the last day of
  the Sprint. It reads what the organization holds today, projects and processes, work items
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

  contoso, 2026-09-16 17:32. 31 rules, 1 project.

  | Rule   | Description                                   | Status | Notes                                        |
  |:-------|:----------------------------------------------|:------:|:---------------------------------------------|
  | **CFG (Configuration)** |                              |        |                                              |
  | CFG000 | Hub project uses hub process                  | 🟡     | On Agile, not Contoso Scrum                  |
  | CFG110 | Hub project contains no repos                 | 🟡     | 2 repositories in the hub                    |
  | CFG160 | Iterations have dates                         | 🟢     | Every sprint has dates (7 checked)           |
  | **WRK (Work Items)** |                                 |        |                                              |
  | WRK110 | Features have parent Epic                     | 🟡     | 175 open Features lack a parent Epic         |
  | WRK300 | Closed Epics have no open children            | 🟡     | 8 open Features sit under closed Epics       |
  | WRK700 | Items are not closed in batches               | 🟢     | No batch closing in the last 90 days         |
  | WRK900 | No stale open items                           | 🟡     | 50 open items untouched for over 90 days     |
  ```

  Next to the report, `ado-cop.log` lists every offending item by ID, type, title, state and
  area, grouped by rule in the same order, and `ado-cop.json` holds the same data for
  anything downstream (Power BI, a dashboard widget, a wiki page).

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

  The report lands next to the script as `ado-cop.md`, with `ado-cop.log` and
  `ado-cop.json` beside it. Pass `-OutputPath` to put them somewhere else.

  On Windows you can keep the token out of your shell history by storing it in Credential
  Manager as a generic credential (user name `pat`, the token as the password) and passing
  the entry's name instead:

  ```powershell
  .\ado-cop.ps1 -AdoOrgUrl https://dev.azure.com/<organization>/ -PatEntryName <entry-name> -Projects <project>
  ```

  The script only reads the entry; it never writes one.

  ### Parameters

  | Parameter | Meaning |
  |:--|:--|
  | `-AdoOrgUrl` | Organization URL, `https://dev.azure.com/<organization>/` |
  | `-AdoToken` | The PAT. Use this in pipelines, from a secret variable |
  | `-PatEntryName` | Windows Credential Manager entry holding the PAT. Use this locally instead of `-AdoToken` |
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

  | Scope (Read) | Used for |
  |:--|:--|
  | Project and Team | Project list, process name, area and iteration trees, team settings |
  | Analytics | Work item queries for every WRK rule |
  | Work Items | Parent lookups across projects |
  | Code | Git repositories and TFVC |
  | Build | Build pipelines |
  | Release | Classic release pipelines |
  | Packaging | Artifact feeds |
  | Graph | Teams and permissions rules, when you enable them |

  Two limits worth knowing. Analytics refuses Stakeholder accounts, so the PAT owner needs
  Basic or higher plus the "View analytics" project permission that Readers and
  Contributors have by default; Analytics can also lag live data by a few minutes. And the
  Feature Management API that says which services a project has enabled refuses every
  custom-scoped PAT and answers only to a full-access token, so the rule that reads it is
  off by default and reports the limitation if you switch it on.

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
  | `HubProject`, `HubProcess` | none | CFG rules | The project that holds all work items in a hub and spoke layout, and the process it should be on. Leave empty if you do not run a hub |
  | `IgnoreStateCategories` | `Completed,Removed` | every WRK rule | State categories that do not count as open |
  | `SprintMaxDays` | `21` | iteration rules | An iteration spanning this many days or fewer is a sprint; longer ones are PIs or releases |
  | `ResolvedMaxDays` | `30` | WRK720 | Days an item may sit in the Resolved category before it counts as parked |
  | `StaleDays` | `90` | WRK900 | Days without a change before an open item counts as stale |
  | `BatchWindowDays`, `BatchSize` | `90`, `5` | WRK700 | Look back this many days; this many items closed in one minute is a batch |
  | `EstimateField` | `StoryPoints` | WRK800 | The Analytics estimate column: `StoryPoints` on Agile, `Effort` on Scrum |

  Every active rule runs once per project, in the order the keys appear. `rules.md` is the
  human-readable catalogue: every rule number, what it checks, why it matters, and which
  metric goes wrong when it fails.

  ## Rule families

  Rule IDs are three letters and three digits. The letters are the family; the digits leave
  room, a new hundred when the idea changes and the next ten within an idea.

  | Family | Covers | Examples |
  |:--|:--|:--|
  | CFG | Project and process configuration: process, services, areas, iterations, teams, hub and spoke shape | CFG000 hub project uses the hub process; CFG160 iterations have dates; CFG180 consistent iteration lengths |
  | WRK | Work item hygiene: parent chain, rollup, placement, closing discipline, ownership, estimates, staleness | WRK110 features have a parent epic; WRK300 closed epics have no open children; WRK700 items are not closed in batches |
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
  4. Add the key to `rules.json` and a row to `rules.md`, marked 🧪 until it has been
     reviewed against real data.

  Write the rule as an opinion you can defend in one sentence. If you cannot say which
  metric or which team habit it protects, it is a preference, not a rule.

  ## Notes and limits

  - The parent rules read the parent ID from Analytics and resolve the parent's type
    through the work items API, so a parent in another project still counts. The rollup
    rules only see parents in the same project, which is the right answer for a hub.
  - "Open" means every state category except Completed and Removed, so Resolved counts as
    open. Adjust `IgnoreStateCategories` if your process disagrees.
  - The report, log and JSON name work items by ID and title. They are client data. Do not
    commit them, and scrub anything you use as a sample. `.gitignore` excludes the default
    output names.
  - The rules assume Azure DevOps Services. Azure DevOps Server will mostly work for the
    REST rules and mostly not for the Analytics ones.

  ## License

  MIT. See `LICENSE`.

  Two notes on the draft. The "Rule families" table names families that do not exist yet as "planned"; drop those rows if you would rather the README only describe what ships. And the sample report is a scrubbed version of a real run, with the organization and process renamed;
  the numbers are real, so change them if you do not want a client's counts in a public repo even anonymized.
