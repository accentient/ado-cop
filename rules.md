# ado-cop rules

The master list of rules `ado-cop.ps1` can check against Azure DevOps, one row per rule. ✅ is implemented; ⭕ is not yet implemented, a candidate drawn from assessments and engagements. Which rules run on a given engagement is decided in that engagement's rules file, not here. "Open" means every state except Closed and Removed. Numbers step by hundreds when the idea changes and by tens within an idea. WRK rules are banded by work item type: WRK1xx Epics, WRK2xx Features, WRK3xx Stories (User Story or Product Backlog Item), WRK4xx Bugs, WRK5xx Tasks, WRK6xx testing (Test Plans, Test Suites, Test Cases), and WRK7xx to WRK9xx for rules that span several types or sit beside the work items: hierarchy and placement (7xx), state and fields (8xx), flow and staleness (9xx).

| Section | Status | Number | Rule | Description |
|:--|:--:|:--|:--|:--|
| Organization | ✅ | CFG000 | Project uses the expected process | Standard model. The project named in Project (or every inspected project when Project is empty) is on the ExpectedProcess process. Off when ProjectModel is HubSpoke. |
|  | ✅ | CFG002 | Hub project uses the expected process | HubSpoke model. The HubProject is on the ExpectedHubProcess process. Reads the named project, so it runs once whatever -Projects says. Off when ProjectModel is Standard. |
|  | ✅ | CFG004 | Spoke projects use the expected process | HubSpoke model. Every project in SpokeProjects is on the ExpectedSpokeProcess process; with no expected process the note just says what each spoke uses. Runs once. |
|  | ⭕ | CFG010 | Project Collection Administrators matches the agreed list | The organization-level admin group holds exactly the accounts in the setting; anyone else who appears there did so overnight. |
|  | ⭕ | CFG020 | All users have a corporate email | Every user identity is on the corporate domain, apart from listed partner accounts. |
|  | ⭕ | CFG025 | Team members hold a Basic license | Everyone on a delivery team has at least a Basic license; a Stakeholder cannot drag on the board or edit fields, so the team works around them. |
|  | ⭕ | CFG027 | Basic + Test Plans access is limited to the listed authors | Only accounts in the setting hold the Basic + Test Plans entitlement; the rest are Basic or Stakeholder, so a lapsed trial is not still being billed. |
|  | ⭕ | CFG028 | Accounts on the no-access list are not users | No identity on the NoAccessAccounts list (setting; executives who get Planner exports instead) holds an entitlement in the organization. |
|  | ⭕ | CFG030 | No duplicate users with different emails | The same person does not appear twice under different identities. |
|  | ⭕ | CFG035 | Users are added by group rule, not directly | Access is managed through Entra group rules rather than manual user additions. |
|  | ⭕ | CFG040 | Spoke projects do not have Boards enabled | Spokes hold repos, pipelines, and artifacts; all work items live in the hub. |
|  | ⭕ | CFG045 | Spoke projects keep their non-Boards services | Repos, Pipelines, Artifacts, and Test Plans stay on where a spoke uses them. |
|  | ⭕ | CFG050 | No unexpected projects | Every project in the organization is the hub or a listed spoke (setting); anything else is flagged. |
|  | ⭕ | CFG055 | Retired projects stay quiet | No work item in a project listed as retired (setting; a migration or rehearsal copy) was created or changed after the cutover date, so there is no dual running. |
|  | ⭕ | CFG060 | Installed extensions match the agreed list | The organization's installed extensions are exactly the ones in the setting (Child Tasks Template, Multivalue control, Split!, Tags Manager); an extension that was dropped, such as Sprint Goal, is flagged until it is uninstalled. |
|  | ⭕ | CFG065 | Notification subscriptions stay at the defaults | No custom team or project notification subscriptions exist apart from those on the allowed list (setting, a Teams notification channel, say); defaults only. |
| Project | ✅ | CFG100 | Project has expected services enabled | Standard model. Every service in ExpectedServices (comma-separated from Boards, Repos, Pipelines, Test Plans, Artifacts) is switched on in Project settings, Overview. Reads the Feature Management API, which needs the hidden `vso.features` PAT scope; README.md explains how to add it. |
|  | ✅ | CFG110 | Project does not have unexpected services enabled | Standard model. No service outside ExpectedServices is switched on; the other half of CFG100, same setting, same API and scope. |
|  | ✅ | CFG120 | Hub project has expected services enabled | HubSpoke model. Every service in ExpectedHubServices is on in the HubProject (a hub lists Boards). Same API and scope as CFG100. Runs once. |
|  | ✅ | CFG122 | Hub project does not have unexpected services enabled | HubSpoke model. Nothing outside ExpectedHubServices is on in the HubProject; the other half of CFG120. |
|  | ✅ | CFG130 | Spoke projects have expected services enabled | HubSpoke model. Every service in ExpectedSpokeServices (spokes usually list Repos, Pipelines, Artifacts) is on in every SpokeProjects project. Runs once. |
|  | ✅ | CFG132 | Spoke projects do not have unexpected services enabled | HubSpoke model. Nothing outside ExpectedSpokeServices is on in any SpokeProjects project; the other half of CFG130. |
|  | ✅ | CFG140 | Areas defined | The area tree has nodes under the root; the note counts them and the log lists the top level. |
|  | ⭕ | CFG145 | Area tree matches the expected list | The area tree is exactly the areas in the setting: the root, one area per team, and the agreed sub-areas; strays and leftovers from a migration are flagged. |
|  | ✅ | CFG150 | Iterations defined | The iteration tree has nodes under the root; the note counts them and how many are sprints. |
|  | ✅ | CFG155 | Iterations follow SAFe PI naming | PIs sit directly under the root and are named YY.N (26.1); sprints sit under their PI and are named YY.N.M (26.1.2) with the PI name as the prefix; nothing goes deeper. A PI with no sprints yet is fine. |
|  | ✅ | CFG157 | Sprint names follow the agreed pattern | Every sprint name matches the SprintNamePattern setting, a regular expression such as ^Sprint (\d{3})$ (Sprint 001, 26.1.2, PI1 Sprint 3), so the picker sorts and the team says the same name; the flat-list alternative to CFG155. When the pattern captures a number, the numbers must run without gaps. No setting, nothing checked. |
|  | ✅ | CFG160 | Iterations have dates | Every sprint (leaf iteration) has a start and a finish date. |
|  | ✅ | CFG180 | Consistent iteration lengths | Every sprint (a dated leaf iteration of SprintMaxDays or fewer) is the same number of days: SprintLengthDays (setting) when given, otherwise the most common length; the rest are flagged. PI nodes are left out. |
|  | ⭕ | CFG185 | No gaps or overlaps between iterations | Sprints are contiguous. |
|  | ✅ | CFG190 | Iterations follow the same cadence | Every sprint starts on the same weekday and finishes on the same weekday (Wednesday to Tuesday, say); the most common start and finish weekdays are the norm and sprints off either are flagged. With CFG180 this says every sprint is the same shape. |
|  | ⭕ | CFG195 | Iterations exist for the current and next PI | The calendar is always one PI ahead; CFG197 is the same idea counted in sprints. |
|  | ⭕ | CFG197 | Sprints are defined N sprints ahead | Dated sprints exist at least SprintsAhead (setting) beyond the current one, so planning never waits on an administrator; the non-PI form of CFG195. |
|  | ⭕ | CFG200 | Backlog levels match the hierarchy | Epic, Feature, and Story are the only portfolio and requirement backlogs enabled. |
|  | ⭕ | CFG205 | Epic backlog level is enabled only on the portfolio team | Only the team named in the setting shows the Epic backlog; delivery teams see Features and Stories, so Epics are managed in one place. |
|  | ⭕ | CFG207 | Team backlog levels match the setting per team | Each team shows exactly the backlog levels named for it (setting): the root team Epics, Features and Backlog items; a parent team such as Operations Features only; sub-teams Features and Backlog items. Generalizes CFG205. |
|  | ⭕ | CFG210 | Bugs managed with requirements | Every team shows Bugs on the backlog alongside Stories. |
|  | ⭕ | CFG220 | Only agreed work item types are in use | Every work item type in use is on the agreed list (setting); types being retired are declared, not left lying around. |
|  | ⭕ | CFG225 | Work item types have the agreed states | Each type has exactly the states in the setting (Story: New, Ready, In Progress, Done, Removed) and no leftovers such as Approved or Committed after a rename. |
|  | ⭕ | CFG230 | Retired work item types have no open items | Nothing open remains on a type that is disabled or being retired. |
|  | ⭕ | CFG240 | Rollup fields exist identically in every process | Business Value and the other value fields are the same field on Epic and Feature everywhere. |
|  | ⭕ | CFG245 | Expected custom fields exist on the agreed types | Every field in the setting exists on the types it is meant for (Category on Epic and Feature, Constraints and Impacts on Story, Blocked on Story and Task). |
|  | ⭕ | CFG246 | No unexpected fields on the agreed types | The fields on each type are the inherited set plus the agreed custom fields; anything else is flagged (Original Estimate or Completed Work added to Task, a Blocked field nobody agreed). The other half of CFG245. |
|  | ⭕ | CFG247 | Picklist fields do not allow custom values | Every picklist field in the setting has "allow users to set their own values" off, so Category stays a category and not a free-text tag. |
|  | ⭕ | CFG248 | Retired fields are read-only | Fields listed as retired (setting; migration leftovers such as Agility ID, Fiscal Year, Mandate) have a read-only rule for everyone but administrators. |
|  | ⭕ | CFG249 | Unused fields are off the form | Fields listed as unused per type (setting; Business Value on PBI and Bug, Effort, Business Value, Time Criticality and Value Area on Epic and Feature) are hidden on the layout, so nobody fills them in. Reads the process layout API. |
|  | ⭕ | CFG250 | Tags promoted to fields are no longer used as tags | Once a tag becomes a field, no open item still carries the tag. |
| Teams | ⭕ | CFG300 | All teams have the expected members | Team rosters match the org chart (setting), including accounts that belong on every team such as the Product Owner. |
|  | ✅ | CFG305 | Expected teams are present | Every team in the ExpectedTeams setting exists in the project. With no setting the note just lists the teams. |
|  | ✅ | CFG307 | No unexpected teams present | No team exists outside the ExpectedTeams setting; sub-groups that only need a filter are area paths, not teams. The other half of CFG305. |
|  | ⭕ | CFG310 | All teams have descriptions | Every team has a description. |
|  | ✅ | CFG315 | Teams are not oversized | No team has more than TeamMaxMembers (setting, 10); a team of 15 is two teams. |
|  | ⭕ | CFG320 | All teams have an area | Every team owns exactly one area. |
|  | ⭕ | CFG325 | No person is on more than one delivery team | Team rosters do not overlap, apart from accounts on the exceptions list (Scrum Master, Product Owner, RTE). |
|  | ⭕ | CFG327 | External tester accounts are not on delivery teams | No member of the testers group (setting) is a member of any team; business testers run tests, they do not sit on the board. |
|  | ⭕ | CFG330 | Team areas include sub-areas | Sub-areas are included so nothing falls off the board. |
|  | ✅ | CFG335 | Every area is covered by a team | Every area, the root included, is selected by at least one team, directly or through a parent area with sub-areas included; otherwise work there is on no backlog or board. Reads each team's area settings. |
|  | ⭕ | CFG340 | All teams have iterations selected | Current and next PI sprints are selected for every team. |
|  | ⭕ | CFG345 | Teams have no far-future sprints selected | Each team has only the current and next SprintsSelected (setting) sprints selected; future sprints exist in the tree but are not on the team until planning gets there. |
|  | ⭕ | CFG347 | Kanban teams do not use sprints | Teams listed as Kanban (setting) have no sprints selected and no open item in their area sits in a sprint; their board and WIP limits carry the flow. |
|  | ⭕ | CFG350 | Default iteration set to root | Default iteration is the root so new items land on the backlog. |
|  | ⭕ | CFG360 | Backlog iteration set to root | Backlog iteration is the root so every sprint is visible. |
|  | ⭕ | CFG370 | Teams have only their Team Admins group as administrators | No individual team administrators. |
|  | ⭕ | CFG380 | RTE is team administrator for all teams | The RTE accounts (setting) are admins on every team. |
|  | ⭕ | CFG385 | Every team has a dashboard | Each team has at least one dashboard, plus a project dashboard, and each carries the agreed widgets (setting: burndown, cumulative flow, cycle time). |
|  | ⭕ | CFG387 | Teams have the agreed work item templates | Repeatable work has a template: every template named in the setting exists for the team that owns it, so standard Tasks arrive the same way each time. |
|  | ⭕ | CFG390 | Every team board has a Blocked style rule | Blocked work is highlighted on every board. |
|  | ⭕ | CFG391 | Team boards carry the agreed card style rules | Every team board has the style rules in the setting (a red card for the urgent-issue marker, whatever marker is chosen); the general form of CFG390. |
|  | ⭕ | CFG392 | Board automation rules are on at every level | Every team has the activate-parent and resolve or complete-parent work item automation rules switched on for Epic, Feature, and Story backlogs. |
|  | ⭕ | CFG395 | In-progress board columns carry WIP limits | Every doing column has a limit, since WIP is a per-team board indicator. |
|  | ⭕ | CFG396 | Board columns have a description | Every column between the first and the last on every team board carries a description: the column's definition of done, visible as the bubble on the board. |
|  | ⭕ | CFG397 | Board columns named after a state map to that state | A column called Ready maps to the Ready state, not to New; otherwise dragging to Ready changes nothing the queries can see. |
|  | ⭕ | CFG398 | Board columns are the standard set | No non-standard Epic, Feature, or Story board columns. |
|  | ⭕ | CFG399 | Team boards have the agreed swimlanes | Boards named in the setting have their agreed swimlanes (an Operational or Expedite lane beside Sprint work), and no others. |
| Permissions | ⭕ | CFG400 | No team is a member of Project Administrators | Team groups never carry admin rights. |
|  | ⭕ | CFG410 | No team is a member of Contributors | Access comes through team permission groups, not the team itself. |
|  | ⭕ | CFG420 | No team is a member of Readers | As above for Readers. |
|  | ⭕ | CFG430 | Contributors only contains team admin and contributor groups | No individuals or other groups in Contributors. |
|  | ⭕ | CFG440 | Build Administrators has no members | Empty in the hub; reviewed in spokes. |
|  | ⭕ | CFG450 | Endpoint Administrators only contains Project Administrators | Service connections are managed by project admins only. |
|  | ⭕ | CFG460 | Project Administrators is small | No more than N members (setting). |
|  | ⭕ | CFG465 | Project Administrators matches the agreed list | Project Administrators holds exactly the accounts in the setting, not merely fewer than N; the rule that catches who snuck in last night. |
|  | ⭕ | CFG470 | Readers only contains team reader groups | No individuals in Readers. |
|  | ⭕ | CFG480 | Release Administrators has no members | Empty in the hub; reviewed in spokes. |
|  | ⭕ | CFG490 | No individual users in project groups | Only team permission groups are members of project-level groups. |
|  | ⭕ | CFG500 | Each team has exactly three permission groups | Team Admins, Team Contributors, Team Readers exist for every team. |
|  | ⭕ | CFG510 | No user is in more than one of a team's permission groups | A person is an admin, a contributor, or a reader of a team, never two of them. |
|  | ⭕ | CFG520 | Tester accounts cannot edit work items | The testers group (setting) carries Deny on editing work items at the root area, and no work item in the last N days was created or changed by one of its members. |
| Epics | ✅ | WRK100 | No Epics with a parent | Nothing sits above Epic: an open Epic has no parent of any type. |
|  | ✅ | WRK110 | Closed Epics have no open children | No open item sits under a Closed Epic. |
|  | ✅ | WRK120 | Epics with all children Closed are Closed | An open Epic whose every child is Closed should be Closed: last child Closed sets the parent Closed. |
|  | ✅ | WRK130 | Epics with an active child are active | An Epic still in New while a child is in progress: first child Active sets the parent Active. |
|  | ✅ | WRK140 | Epics live in the root area | Every open Epic sits in the project's root area, or in one of the EpicAreas (setting) when the portfolio has its own area; never in a team area. |
|  | ⭕ | WRK150 | Active Epics have at least one child Feature | An Epic in progress with no child Feature is a folder or a large Story, not an Epic that has been broken down. |
|  | ✅ | WRK160 | Epics have a description | Every open Epic carries a value statement in its description: the business outcome it delivers. Reads the text field through the work items REST API. |
|  | ✅ | WRK165 | Epics have acceptance criteria | Every open Epic has acceptance criteria that say how the Epic is known to be done; required only where the type has the field. Reads the text field through the work items REST API. |
|  | ⭕ | WRK170 | No open Epics from a past fiscal year | No open Epic whose title matches a past-period pattern (setting, FY24); they are Done or Removed, not New forever. |
|  | ✅ | WRK180 | Epics have no Effort | Effort is empty on every open Epic, where the client has decided Epics are not sized. |
|  | ✅ | WRK185 | Epics have no Business Value | Business Value is empty on every open Epic, where the client has decided Epics carry no value score. |
|  | ✅ | WRK190 | Epics are assigned to the Product Owner | Every open Epic is assigned to one of the ProductOwners (setting); with no setting, to anyone. The Epic half of WRK815; turn on one form or the other. |
| Features | ✅ | WRK200 | Features have parent Epic | Every open Feature has a parent and that parent is an Epic. |
|  | ✅ | WRK210 | Closed Features have no open children | No open item sits under a Closed Feature. |
|  | ✅ | WRK220 | Features with all children Closed are Closed | Same for Features. |
|  | ✅ | WRK230 | Features with an active child are active | Same for Features. |
|  | ⭕ | WRK240 | Features have children once started | A Feature that is In Progress, or sits in a started PI, with no child Story was never broken down; it is a large Story wearing a Feature's clothes. |
|  | ⭕ | WRK250 | Features that span team areas sit in the root area | A Feature whose children sit in more than one team area is itself in the root area, not in one team's; a Feature with a single team's children may sit in that team's area. |
|  | ⭕ | WRK260 | Intake items get a Disposition | A Feature older than N days with no Disposition is a Business Response Time clock still running. |
|  | ✅ | WRK270 | Features have a description | Every open Feature has a non-empty description; a Feature is how the business reads what IT is doing. |
|  | ✅ | WRK280 | Features have no Effort | Effort is empty on every open Feature, where the client has decided Features are not sized. |
|  | ✅ | WRK285 | Features have no Business Value | Business Value is empty on every open Feature, where the client has decided Features carry no value score. |
|  | ✅ | WRK290 | Features are assigned to the Product Owner | Every open Feature is assigned to one of the ProductOwners (setting); with no setting, to anyone. The Feature half of WRK815; turn on one form or the other. |
|  | ⭕ | WRK296 | Every team area has a holding Feature | Each team area has one open Feature matching the HoldingFeaturePattern (setting, Unparented * work) so a PBI with no natural parent still has one. |
|  | ⭕ | WRK297 | Holding Features stay small | A holding Feature has no more than HoldingMaxItems (setting) open children, and none has sat under it longer than HoldingMaxDays; otherwise WRK300 is satisfied by a drawer, not a plan. |
| Stories | ✅ | WRK300 | Stories have parent Feature | Every open User Story (or Product Backlog Item) has a parent and that parent is a Feature. |
|  | ✅ | WRK305 | Stories are not direct children of an Epic | No open Story sits directly under an Epic; a Feature always sits between them. WRK300 counts these among its wrong parents; this rule names them alone. |
|  | ✅ | WRK310 | Closed Stories have no open children | No open item sits under a Closed User Story. |
|  | ✅ | WRK320 | Stories with all children Closed are Closed | Same for User Stories. |
|  | ✅ | WRK330 | Stories with an active child are active | Same for User Stories. |
|  | ⭕ | WRK340 | Ready Stories have a value clause | A Story in the Ready state whose description has "As a" and "I want" but no "so that" was never refined for value. Text fields through the REST API. |
|  | ⭕ | WRK345 | Open Stories are filled in within N days | Any open Story older than ShellMaxDays (setting) has a description and acceptance criteria whether or not it is in a sprint; the backlog form of WRK360, since steps 1 to 4 are done before refinement. |
|  | ⭕ | WRK347 | Acceptance criteria are not buried in the Description | No open item has an Acceptance Criteria heading in its Description while the Acceptance Criteria field is empty; a migration habit that hides the criteria from WRK160 and WRK360. |
|  | ⭕ | WRK350 | Stories in a future sprint are Ready | Anything planned into a sprint that has not started is in the Ready state (setting); the current sprint is exempt so urgent work is not blocked by the Definition of Ready. |
|  | ⭕ | WRK352 | Ready Stories meet the Definition of Ready | A Story in the Ready state has a description, acceptance criteria and a parent Feature; with WRK355 and WRK357 this is the whole Definition of Ready, checked at Ready rather than only once in a sprint. |
|  | ⭕ | WRK353 | The top of each backlog is Ready | The first ReadyDepth (setting, 10) Stories in each team backlog order are Ready, so Sprint Planning has something to pull; the keep-your-top-ten check. |
|  | ⭕ | WRK355 | Ready Stories have an estimate | Every Story in the Ready state carries an estimate, since sizing is part of refinement and not of Sprint Planning; tightens WRK850. |
|  | ⭕ | WRK357 | Ready Stories are fully tasked | A Story in the Ready state, or in the next sprint, has at least one child Task, and every child Task has Remaining Work; with PreAssignTasks (setting) each also has an Assigned To. For teams that task out in refinement; the Ready form of WRK365. |
|  | ✅ | WRK360 | Sprint Stories have a description and acceptance criteria | Every Story or Bug in a sprint that has not ended has a non-empty description and non-empty Acceptance Criteria; a shell story is a reminder, not a commitment, and the criteria are the Definition of Ready and the source of the test cases. Text fields through the REST API. |
|  | ⭕ | WRK365 | Sprint Stories have child Tasks | A Story in the current sprint has at least one child Task once the sprint has started; for teams that task out their work (setting). |
|  | ✅ | WRK370 | Sprint Stories are not oversized | No Story or Bug in a sprint carries an estimate (EstimateField) above SprintMaxEstimate (setting, 8); a 13 is a Feature. |
|  | ✅ | WRK372 | Stories at the top of the scale are listed for challenge | Every open Story or Bug, sprint or backlog, whose estimate equals ChallengeEstimate (setting, 5) is listed, so the Product Owner can challenge it to be split or hear the team's case; WRK370 catches anything larger. |
|  | ⭕ | WRK375 | No umbrella Stories | A Story with more than StoryMaxTasks (setting) child Tasks, Task hours above StoryMaxHours, or Tasks assigned to members of more than one team is a Feature being worked as a Story. |
|  | ⭕ | WRK377 | Size is not derived from Task hours | Flags Stories whose estimate equals the sum of their Task hours, or that sum divided by a day; size tracks velocity and hours track capacity, and the two are never correlated. |
|  | ⭕ | WRK380 | Acceptance criteria are not widened after work starts | Flags Stories whose Acceptance Criteria changed after they went In Progress; new scope is a new Story. Needs WorkItemRevisions. |
|  | ⭕ | WRK385 | Stories needing business testing record the commitment before Ready | A Story with a Requester that needs business testing names the tester and date in the agreed field (setting, Constraints, say) before it is Ready; no commitment, no pull. |
|  | ✅ | WRK390 | Stories have no Business Value | Business Value is empty on every open Story, where the client has decided backlog order is the only measure of value. |
|  | ✅ | WRK395 | Stories are assigned to the Product Owner | Every open Story is assigned to one of the ProductOwners (setting); the Product Owner owns the backlog item, the doers own its Tasks. |
| Bugs | ✅ | WRK400 | Bugs have a parent | Every open Bug has a parent and that parent is a Feature, User Story or Product Backlog Item. |
|  | ⭕ | WRK410 | Bugs carry the Escaped flag | Escaped is set on every Bug once the field exists. |
|  | ⭕ | WRK420 | No Bugs created after the type is retired | No Bug was created after BugRetiredDate (setting); work that looks like a bug is a PBI with the agreed marker. Pairs with CFG230, which catches the open ones. |
| Tasks | ✅ | WRK500 | Tasks have parent Story or Bug | Every open Task has a parent and that parent is a User Story, Product Backlog Item or Bug; Tasks are optional but never orphans. |
|  | ✅ | WRK510 | Tasks share the area path of their parent | Every open Task has the same Area Path as its parent; otherwise it drops off the taskboard and the burndown. |
|  | ✅ | WRK520 | Tasks are not created ahead of the sprint | No open Task sits under a Story or Bug that is in the backlog or in a sprint that has not started; tasking happens in Sprint Planning, not weeks before. |
|  | ⭕ | WRK525 | Tasks are created in refinement, not at Sprint Planning | For teams that task out in refinement (setting), no Task under a sprint Story was created on the planning day or after the sprint started; the inverse of WRK520, so turn on one or the other. |
|  | ✅ | WRK530 | Sprint Tasks have Remaining Work | Every current-sprint Task still to do or in progress (the Proposed and In Progress state categories: To Do and In Progress on Scrum) has Remaining Work set, or the burndown is flat by construction. |
|  | ⭕ | WRK535 | Done Tasks carry no Remaining Work | A Task in the Done state has Remaining Work of zero or empty; the Scrum process does not clear it, and the burndown never reaches zero otherwise. |
|  | ⭕ | WRK540 | To Do Tasks are not pre-assigned | Tasks still in To Do carry no Assigned To; people pull tasks when they start them. |
|  | ⭕ | WRK545 | Remaining Work moves on in-progress Tasks | An In Progress Task whose Remaining Work has not changed for more than a working day is flagged; tasks are updated at least by the end of each day. Differs from WRK550, which measures time in state. Needs WorkItemRevisions. |
|  | ⭕ | WRK550 | Tasks do not stay In Progress for more than a day | A Task in progress for more than TaskMaxDays (setting, 1 working day) is blocked or was never a task; it belongs in the Daily Scrum. |
|  | ⭕ | WRK555 | People move their own Tasks | The share of Task state changes in the current sprint made by someone other than the assignee, per team; anyone may move a Task, but a high share means one person keeps the board for everyone. Needs WorkItemRevisions. |
|  | ✅ | WRK560 | Tasks are sized at a day or less | Remaining Work on an open Task is at most TaskMaxHours (setting, 8); size the task so that a day is a meaningful threshold. |
|  | ⭕ | WRK565 | No one has more than N Tasks in progress | No person has more than PersonMaxWip (setting, 2) Tasks In Progress at once; a Task goes In Progress only when its owner starts it. The per-person form of WRK970. |
| Testing | ✅ | WRK600 | Sprint Stories have a linked Test Case | Every Story or Bug in the current sprint has at least one Tested By link, one test per acceptance criterion. Links through the REST API. |
|  | ⭕ | WRK605 | Sprint Stories have a test per acceptance criterion | The number of Tested By links on a sprint Story is at least the number of bullets in its Acceptance Criteria; tightens WRK600, scoped the same way (setting, items with a Requester). |
|  | ⭕ | WRK610 | Closed Stories have test cases with a passing outcome | No Story reaches Done while a linked test case has never been run or last failed; the report that says what was not tested. |
|  | ⭕ | WRK615 | Passed results come from running the steps | No Passed result in the last N days was recorded without step results; the quick Pass button bypasses the test. |
|  | ⭕ | WRK620 | Test Cases on active Stories have steps | A test case may start as a title, but by the time its Story is in progress it carries steps, and at least one step has an expected result. |
|  | ⭕ | WRK630 | Test Cases are authored by the agreed accounts | While test authoring is being rolled out, test cases are created by the accounts in the setting (the Product Owners) and nobody else. |
|  | ⭕ | WRK640 | Test Cases are linked to a Story or Bug | Every Test Case has a Tests link to a requirement; per-tester suites do not create the link on their own, so traceability from requirement to result has to be checked. |
|  | ⭕ | WRK650 | Test points are assigned to a named tester | In every active plan no test point is unassigned, and the assignee is one person with Basic access or higher, not a Stakeholder who cannot see the Test Plans hub. |
|  | ⭕ | WRK655 | Each tester suite has one tester | Every static suite in an active plan has all its test points assigned to one person; one named tester per request. |
|  | ⭕ | WRK660 | Assigned tests are run within N days | Test points still not run more than TestRunDays (setting) after assignment are flagged; the dated record that a requester was asked and did not test. |
|  | ⭕ | WRK670 | Failed test results have a linked work item | Every failed result in the last N days has an associated Bug or Story; testers leave comments, someone else triages, and an untriaged failure is a dropped ball. |
|  | ⭕ | WRK672 | Failed results carry a comment or attachment | Every Failed result in the last N days has a comment or screenshot on the result or the failed step, so the person triaging can reproduce it. |
|  | ⭕ | WRK680 | Test plans and suites follow the naming pattern | Plan and suite names match the TestPlanNamePattern and TestSuiteNamePattern settings once the naming is agreed. |
| Hierarchy and placement | ✅ | WRK700 | No parent-child links between the same type | No Feature under a Feature, no Epic under an Epic, no Task under a Task. |
|  | ⭕ | WRK710 | No item has more than one parent | Analytics sees one parent; the links API shows the rest. |
|  | ✅ | WRK715 | Removed parents have no open children | No open item sits under a Removed Epic, Feature or Story; Removed does not cascade, so archiving a parent strands its children. |
|  | ✅ | WRK720 | Epics and Features are not in a sprint | Epics and Features live at the root or PI level of the iteration tree, never in a sprint, an iteration of SprintMaxDays or fewer. |
|  | ✅ | WRK730 | Open items are not in a past iteration | Nothing open is left in an iteration that has ended. |
|  | ✅ | WRK740 | Stories, Bugs and Tasks are not in the root area | Execution items belong to a team area, never the project root. |
|  | ⭕ | WRK745 | Stories sit in a leaf area | Where a team area has sub-areas, open Stories are in one of them rather than at the team level, so sub-group filters and boards see everything. |
|  | ⭕ | WRK747 | Open items are not in an archive area | Nothing open sits in an area listed as an archive (setting); legacy areas collapsed after a migration hold history only. |
|  | ⭕ | WRK750 | No work items in areas without a team | Every area with work items has a team looking after it. |
|  | ⭕ | WRK760 | Backlog levels enabled match the area hierarchy | Portfolio areas show Epics and Features; team areas show Stories. |
|  | ⭕ | WRK770 | Items have both an area and an iteration | No item with an Iteration Path but a root Area Path, or the reverse. |
|  | ⭕ | WRK780 | Parents with every child Removed are not left open | An open Epic, Feature or Story whose children are all Removed. |
|  | ✅ | WRK785 | Items are not planned too far ahead | No open Story, Bug or Task sits in a sprint that starts more than PlanAheadSprints (setting, 1) sprints from today, measured in the tree's usual sprint length; pre-bucketing is a plan nobody made. |
|  | ⭕ | WRK787 | Items join a sprint only at Sprint Planning | No item was moved into a sprint earlier than PlanningLeadDays (setting, 1) before it starts; the revision-based form of WRK785. Needs WorkItemRevisions. |
|  | ⭕ | WRK790 | Active items rank above New items | Within a team backlog no In Progress item ranks below a New item; working on position 11 while 1 to 6 are untouched means the order is not the plan. |
|  | ⭕ | WRK795 | Backlog order follows the sprint | In each team backlog, current-sprint items rank above next-sprint items, which rank above unscheduled items; within each group In Progress ranks above Ready, which ranks above New. Tightens WRK790. |
|  | ⭕ | WRK797 | Story order follows Feature order | No Story in the top StoryOrderDepth (setting) of a team backlog has a parent Feature below FeatureOrderDepth in the Feature backlog; Features are ordered first and drive the order of the PBIs. |
| State and fields | ✅ | WRK800 | Items are not closed in batches | BatchSize or more items closed within the same minute in the last BatchWindowDays suggests batch closing at Sprint end. |
|  | ✅ | WRK810 | Active items have an owner | Anything in progress is assigned to someone. |
|  | ⭕ | WRK811 | Assigned To is a person, not a group | No open item or test point is assigned to a group or shared identity; a group owns nothing. |
|  | ⭕ | WRK812 | Assigned To is a current member of the organization | No open item is assigned to an identity without an entitlement in the organization; former staff are named in a text field, not kept as owners. |
|  | ⭕ | WRK813 | Identity fields name current members | Requester, Functional Expert and the other identity fields in the setting hold identities with an entitlement in the organization; the WRK812 check for fields other than Assigned To. |
|  | ✅ | WRK815 | Epics and Features have an owner | Every open Epic and Feature is assigned, whatever its state, and when the setting names the Product Owner accounts it is assigned to one of them; the PO owns the what, the team owns the flow. WRK190 and WRK290 split it by type. |
|  | ⭕ | WRK817 | Epics and Features are created by Product Owner accounts | Created By on Epics and Features is a Product Owner account (setting); they come from the business through the PO, not from the team. |
|  | ✅ | WRK820 | No items parked in Resolved | Nothing sits in the Resolved category longer than ResolvedMaxDays; Resolved is inside the Cycle Time span, not a parking place. |
|  | ⭕ | WRK830 | No reopened items | Closed then Active again clears CompletedDate and stretches Cycle Time. Needs WorkItemRevisions. |
|  | ⭕ | WRK840 | No items closed straight from New | Work that went New to Closed with no Active in between bypassed the board. Needs WorkItemRevisions. |
|  | ✅ | WRK850 | Sprint items have an estimate | Every open Story in a sprint, and every open Bug when BugsAreRequirements is on (the default), carries an estimate (EstimateField setting: StoryPoints on Agile, Effort on Scrum). |
|  | ⭕ | WRK855 | Closed sprint Stories keep their estimate | Every Story closed in a sprint in the last CycleWindowDays has an estimate; velocity is counted from closed items, so a blank undercounts it. The closed-item half of WRK850. |
|  | ⭕ | WRK857 | Estimates do not change after the sprint starts | Flags Stories whose estimate changed after they entered a started sprint, as a share per sprint; re-sizing at Sprint Planning is allowed but not the norm. Needs WorkItemRevisions. |
|  | ✅ | WRK860 | Estimates are on the agreed scale | Every open Story, and every Bug when BugsAreRequirements is on, carries no estimate or one of the EstimateScale values (setting, 1,2,3,5); an empty estimate is WRK850's business. No setting, nothing checked. |
|  | ⭕ | WRK870 | Epics and Features have Business Value | The value fields are populated at the levels agreed. |
|  | ⭕ | WRK880 | Type of Work is set | Type of Work is set on every open Epic, Feature and Story. |
|  | ⭕ | WRK882 | Required fields are set by state | Fields in the setting are set on the types and from the state named (Requester and Functional Expert on Epic, Feature and PBI once In Progress; Category on Epic and Feature); the general form of WRK880. |
|  | ⭕ | WRK885 | Picklist fields hold only the agreed values | Custom picklist fields (setting) on open items hold one of the agreed values; migrated leftovers are mapped or blanked. |
|  | ⭕ | WRK887 | Retired fields are empty on new items | Items created after a cutover date (setting) have nothing in the retired fields; the data that came over stays, new data goes in the new fields. |
|  | ⭕ | WRK888 | Unused fields stay at their defaults | Fields listed as unused (setting; Priority, Original Estimate, Completed Work, Business Value) hold their default or nothing on items created after the cutover; backlog order is the priority. |
|  | ⭕ | WRK890 | Tags in use are on the approved list | Only tags on the approved list (setting) are in use. |
|  | ⭕ | WRK892 | No tags on new items | Items created after TagCutoverDate (setting) carry no tags, apart from any on the approved list; tags are not relied on and anything that needs a report becomes a field. Tightens WRK890. |
|  | ⭕ | WRK893 | Tags stay few and distinct | The number of distinct tags in use stays under TagMaxDistinct (setting), and no two differ only by case, plural, space or hyphen; the cleanup measure for a migrated tag cloud. |
|  | ⭕ | WRK895 | Work is discussed on the item | The share of Stories closed in the last sprint with at least one Discussion comment; conversations about work go on the work item, not in instant messages. Informational. |
| Flow and staleness | ✅ | WRK900 | No stale open items | Nothing open has gone untouched for more than StaleDays. |
|  | ⭕ | WRK902 | The board is kept current during the sprint | The share of a sprint's state changes that land in its last BoardCatchupDays (setting, 2) days, per team; a board updated two days before the end was not the plan anyone worked from. Needs WorkItemRevisions. |
|  | ⭕ | WRK905 | Closed items older than N days are Removed | Where a client archives by state, anything Done longer than RemoveAfterDays (setting) is Removed so boards and queries stay light. Off unless the client works that way, since Removed leaves the throughput count. |
|  | ⭕ | WRK910 | No unrefined New items older than a PI | Items still New after a full PI were never refined. |
|  | ⭕ | WRK915 | Team backlogs hold no more than N open items | Open Stories and Bugs per team area stay under BacklogMaxItems (setting); a backlog of 400 is a filing cabinet. |
|  | ⭕ | WRK917 | No open items older than N days | Nothing open was created more than MaxAgeDays (setting, 365) ago, whatever its activity; ask the owner at eleven months, remove at twelve. |
|  | ⭕ | WRK920 | No duplicate titles | The same title twice on the same type in the same area. |
|  | ⭕ | WRK922 | Titles do not name a sprint | No open item title contains a sprint name or number (Sprint 148); a title is not an iteration, and it is how pre-bucketing hides from WRK785. |
|  | ⭕ | WRK925 | Open items are not past their Target Date | No open item has a Target Date that has passed; the dates are optional and used for hard deadlines only, so a passed one is a missed deadline or a stale date. |
|  | ⭕ | WRK930 | Unplanned work per Sprint | Items added to a Sprint after its first day, as a percentage per Sprint. Needs WorkItemRevisions. |
|  | ⭕ | WRK935 | Sprints are not overloaded | A team's current sprint holds no more than SprintMaxItems (setting) Stories; 69 items in a sprint is a backlog with a date on it. |
|  | ⭕ | WRK940 | Nothing removed from a Sprint after it starts | Items taken out of a Sprint after day one make the plan match the outcome by construction. Needs WorkItemRevisions. |
|  | ⭕ | WRK945 | Items are not carried over between sprints | The share of a sprint's items that were also in the previous sprint; unfinished work returns to the backlog and comes back only if the PO re-orders it. Needs WorkItemRevisions. |
|  | ⭕ | WRK947 | No Stories split at sprint end | Flags Stories created in the last SplitWindowDays (setting) of a sprint, or the first day of the next, whose title matches an unfinished Story in the ending sprint or that received Tasks reparented from one; moving leftover Tasks to a new PBI is carryover, not a split. Needs WorkItemRevisions. |
|  | ⭕ | WRK948 | Split Stories link to the original | A Story created as a split carries a Related link back to the Story it came from, so the history stays traceable. |
|  | ⭕ | WRK949 | No serial phase Stories | Flags a title stem that recurs with an incrementing number (Rollout Phase 7, Rollout Phase 8) across consecutive sprints; the same work renamed each sprint is carryover. Tightens WRK945. |
|  | ⭕ | WRK950 | Every Sprint has a Sprint Goal | The Sprint Goal extension holds a goal for the current Sprint. REST to the extension store. |
|  | ⭕ | WRK960 | Capacity is entered for the current and next Sprint | The Capacity page is filled in before the Sprint starts. REST only. |
|  | ⭕ | WRK970 | High WIP | A team has more items in a column than its limit. |
|  | ✅ | WRK980 | Cycle Time stays within the sprint length | Stories and Bugs completed in the last CycleWindowDays (setting, 90) while in a sprint have a CycleTimeDays no longer than that sprint; longer means the board was moved at Sprint Review, not when the work finished. |
|  | ⭕ | WRK985 | Items do not age in one board column beyond N days | No item has sat in the same board column longer than ColumnMaxDays (setting); column aging is how a Kanban board shows blocked work. Reads the board snapshot in Analytics. |
|  | ⭕ | WRK990 | Impediments do not sit open | No Impediment has been open longer than ImpedimentMaxDays (setting); the type-specific form of WRK900. |
|  | ⭕ | WRK992 | Impediments link to what they block | Every open Impediment has a link to the open Story, Feature or Epic it blocks, and every closed one has a Resolution. |
| Repos | ⭕ | REP100 | Commits link to a work item | Commits on the default branch reference a work item ID. |
|  | ⭕ | REP110 | Pull requests link to a work item | Every completed PR has a linked work item. |
|  | ⭕ | REP120 | Default branch policy requires a linked work item | The policy exists on every active repo's default branch. |
|  | ⭕ | REP130 | TFVC check-ins are associated with a work item | Check-ins in the TFVC project reference a work item. |
