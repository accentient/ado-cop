# Contoso (example client folder)

A scrubbed copy of what a client folder under `clients/` looks like. Every other folder
here is ignored by git because it names a real organization, its work items and its
people; this one is committed as the template. Copy it to `clients/<name>/`, then edit.

| File | What it is |
|:--|:--|
| `rules.json` | The client rules file. `PatEntryName` names the Windows Credential Manager entry that holds the PAT (the name only, never the token). `ProjectModel` is HubSpoke, so CFG002, CFG004 and CFG120 to CFG132 are on and the single-project rules CFG000, CFG100 and CFG110 are off: `HubProject` Hub on the Contoso Scrum process with only Boards, `SpokeProjects` Payments and Lending on Agile with Repos, Pipelines and Artifacts. `ExpectedTeams` lists the four teams so CFG305 and CFG307 flag any that vanish or appear. `SprintNamePattern` is the SAFe shape (26.1.2), `SprintLengthDays` 14. Every rule is on and the item log is written |
| `pipeline.yml` | A scheduled pipeline for the Contoso organization that runs the root script with this rules file. Add a secret variable `adoToken` in the pipeline |
| `example-report.md`, `example-report.log` | What a run produces: the report table and the item log behind its warnings. Real runs are named `report <date>.md` and ignored by git |
| `rules.md` (optional) | Some engagements keep an annotated copy of the root catalogue here, with decision references and a per-rule review status |

Organization facts worth recording in a real folder: the organization URL, which project
is the system of record and which are sandboxes, the process and its customizations, the
sprint length and cadence, the team and area layout, and anything the PAT can or cannot
reach. The dated facts are what make a later report readable.

To run locally from the repo root:

```powershell
.\ado-cop.ps1 -AdoOrgUrl https://dev.azure.com/contoso/ `
  -Projects Hub -RulesFile .\clients\example\rules.json `
  -OutputPath ".\clients\example\report $(Get-Date -Format yyyy-MM-dd).md"
```
