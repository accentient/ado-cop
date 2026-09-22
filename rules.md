# ado-cop rules

Rules `ado-cop.ps1` checks against Azure DevOps, one row per rule. ✅ is implemented, reviewed and switched on in `rules.json`; 🧪 is implemented and switched on but not yet reviewed; ⭕ is a candidate for the backlog, drawn from assessments and engagements. "Open" means every state except Closed and Removed. Numbers step by hundreds when the idea changes and by tens within an idea.

| Section | Status | Number | Rule | Description |
|:--|:--:|:--|:--|:--|
| Organization | 🧪 | CFG000 | Hub project uses the hub process | The hub project (HubProject setting) is on the hub process (HubProcess setting). |
|  | ⭕ | CFG020 | All users have a corporate email | Every user identity is on the corporate domain, apart from listed partner accounts. |
|  | ⭕ | CFG030 | No duplicate users with different emails | The same person does not appear twice under different identities. |
|  | ⭕ | CFG035 | Users are added by group rule, not directly | Access is managed through Entra group rules rather than manual user additions. |
|  | ⭕ | CFG040 | Spoke projects do not have Boards enabled | Spokes hold repos, pipelines, and artifacts; all work items live in the hub. |
|  | ⭕ | CFG045 | Spoke projects keep their non-Boards services | Repos, Pipelines, Artifacts, and Test Plans stay on where a spoke uses them. |
|  | ⭕ | CFG050 | No unexpected projects | Every project in the organization is the hub or a listed spoke (setting); anything else is flagged. |
| Hub project | ⭕ | CFG100 | Hub project only has Boards enabled | Implemented but switched off: the Feature Management API that reports service states refuses every custom-scoped PAT (401 even with Extensions Read) and answers only to full access. Check Project settings, Overview, in the browser. |
|  | 🧪 | CFG110 | Hub project contains no repos | No Git repos or TFVC in the hub. |
|  | 🧪 | CFG120 | Hub project contains no pipelines | No build or release definitions in the hub. |
|  | 🧪 | CFG130 | Hub project contains no artifact feeds | No project-scoped feeds in the hub. |
|  | 🧪 | CFG140 | Areas defined | The area tree has nodes under the root; the note counts them and the log lists the top level. |
|  | 🧪 | CFG150 | Iterations defined | The iteration tree has nodes under the root; the note counts them and how many are sprints. |
|  | 🧪 | CFG160 | Iterations have dates | Every sprint (leaf iteration) has a start and a finish date. |
|  | ⭕ | CFG170 | Iterations start on the agreed weekday | Sprint start day matches the cadence (setting). |
|  | ⭕ | CFG175 | Iterations end on the agreed weekday | Sprint end day matches the cadence (setting). |
|  | 🧪 | CFG180 | Consistent iteration lengths | Every sprint (a dated leaf iteration of SprintMaxDays or fewer) is the same number of days; the most common length is the norm and the rest are flagged. PI nodes are left out. |
|  | ⭕ | CFG185 | No gaps or overlaps between iterations | Sprints are contiguous. |
|  | ⭕ | CFG190 | Iterations exist for the current and next PI | The calendar is always one PI ahead. |
|  | ⭕ | CFG200 | Backlog levels match the hierarchy | Epic, Feature, and Story are the only portfolio and requirement backlogs enabled. |
|  | ⭕ | CFG210 | Bugs managed with requirements | Every team shows Bugs on the backlog alongside Stories. |
|  | ⭕ | CFG220 | Only agreed work item types are in use | Every work item type in use is on the agreed list (setting); types being retired are declared, not left lying around. |
|  | ⭕ | CFG230 | Retired work item types have no open items | Nothing open remains on a type that is disabled or being retired. |
|  | ⭕ | CFG240 | Rollup fields exist identically in every process | Business Value and the other value fields are the same field on Epic and Feature everywhere. |
|  | ⭕ | CFG250 | Tags promoted to fields are no longer used as tags | Once a tag becomes a field, no open item still carries the tag. |
| Teams | ⭕ | CFG300 | All teams have the expected members | Team rosters match the org chart (setting). |
|  | ⭕ | CFG310 | All teams have descriptions | Every team has a description. |
|  | ⭕ | CFG320 | All teams have an area | Every team owns exactly one area. |
|  | ⭕ | CFG330 | Team areas include sub-areas | Sub-areas are included so nothing falls off the board. |
|  | ⭕ | CFG340 | All teams have iterations selected | Current and next PI sprints are selected for every team. |
|  | ⭕ | CFG350 | Default iteration set to root | Default iteration is the root so new items land on the backlog. |
|  | ⭕ | CFG360 | Backlog iteration set to root | Backlog iteration is the root so every sprint is visible. |
|  | ⭕ | CFG370 | Teams have only their Team Admins group as administrators | No individual team administrators. |
|  | ⭕ | CFG380 | RTE is team administrator for all teams | The RTE accounts (setting) are admins on every team. |
|  | ⭕ | CFG390 | Every team board has a Blocked style rule | Blocked work is highlighted on every board. |
|  | ⭕ | CFG392 | Board automation rules are on at every level | Every team has the activate-parent and resolve or complete-parent work item automation rules switched on for Epic, Feature, and Story backlogs. |
|  | ⭕ | CFG395 | In-progress board columns carry WIP limits | Every doing column has a limit, since WIP is a per-team board indicator. |
|  | ⭕ | CFG398 | Board columns are the standard set | No non-standard Epic, Feature, or Story board columns. |
| Permissions | ⭕ | CFG400 | No team is a member of Project Administrators | Team groups never carry admin rights. |
|  | ⭕ | CFG410 | No team is a member of Contributors | Access comes through team permission groups, not the team itself. |
|  | ⭕ | CFG420 | No team is a member of Readers | As above for Readers. |
|  | ⭕ | CFG430 | Contributors only contains team admin and contributor groups | No individuals or other groups in Contributors. |
|  | ⭕ | CFG440 | Build Administrators has no members | Empty in the hub; reviewed in spokes. |
|  | ⭕ | CFG450 | Endpoint Administrators only contains Project Administrators | Service connections are managed by project admins only. |
|  | ⭕ | CFG460 | Project Administrators is small | No more than N members (setting). |
|  | ⭕ | CFG470 | Readers only contains team reader groups | No individuals in Readers. |
|  | ⭕ | CFG480 | Release Administrators has no members | Empty in the hub; reviewed in spokes. |
|  | ⭕ | CFG490 | No individual users in project groups | Only team permission groups are members of project-level groups. |
|  | ⭕ | CFG500 | Each team has exactly three permission groups | Team Admins, Team Contributors, Team Readers exist for every team. |
|  | ⭕ | CFG510 | No user is in more than one of a team's permission groups | A person is an admin, a contributor, or a reader of a team, never two of them. |
| Hierarchy | ✅ | WRK100 | No parent-child links between the same type | No Feature under a Feature, no Epic under an Epic, no Task under a Task. |
|  | ✅ | WRK110 | Features have parent Epic | Every open Feature has a parent and that parent is an Epic. |
|  | ✅ | WRK120 | Epics have no parent, or an Initiative | An open Epic may have no parent, or an Initiative while that type still exists; any other parent (another Epic, a Feature) is flagged. |
|  | ⭕ | WRK130 | No item has more than one parent | Analytics sees one parent; the links API shows the rest. |
|  | ⭕ | WRK140 | Features have children once their PI has started | A Feature in a started PI with no child Story was never broken down. |
| Orphans | ✅ | WRK200 | Stories have parent Feature | Every open User Story (or Product Backlog Item) has a parent and that parent is a Feature. |
|  | ✅ | WRK210 | Bugs have a parent | Every open Bug has a parent and that parent is a Feature, User Story or Product Backlog Item. |
|  | ✅ | WRK220 | Tasks have parent Story or Bug | Every open Task has a parent and that parent is a User Story, Product Backlog Item or Bug; Tasks are optional but never orphans. |
| Closed parents | ✅ | WRK300 | Closed Epics have no open children | No open item sits under a Closed Epic. |
|  | ✅ | WRK310 | Closed Features have no open children | No open item sits under a Closed Feature. |
|  | ✅ | WRK320 | Closed Stories have no open children | No open item sits under a Closed User Story. |
| Done rollup | ✅ | WRK400 | Epics with all children Closed are Closed | An open Epic whose every child is Closed should be Closed: last child Closed sets the parent Closed. |
|  | ✅ | WRK410 | Features with all children Closed are Closed | Same for Features. |
|  | ✅ | WRK420 | Stories with all children Closed are Closed | Same for User Stories. |
| Active rollup | ✅ | WRK500 | Epics with an active child are active | An Epic still in New while a child is in progress: first child Active sets the parent Active. |
|  | ✅ | WRK510 | Features with an active child are active | Same for Features. |
|  | ✅ | WRK520 | Stories with an active child are active | Same for User Stories. |
| Placement | ✅ | WRK600 | Epics and Features are not in a sprint | Epics and Features live at the root or PI level of the iteration tree, never in a sprint, an iteration of SprintMaxDays or fewer. |
|  | ✅ | WRK610 | Open items are not in a past iteration | Nothing open is left in an iteration that has ended. |
|  | ✅ | WRK620 | Stories, Bugs and Tasks are not in the root area | Execution items belong to a team area, never the project root. |
|  | ⭕ | WRK630 | Epics only in the portfolio area | Epics live at the root or portfolio area, never in a team area. |
|  | ⭕ | WRK640 | No work items in areas without a team | Every area with work items has a team looking after it. |
|  | ⭕ | WRK650 | Backlog levels enabled match the area hierarchy | Portfolio areas show Epics and Features; team areas show Stories. |
|  | ⭕ | WRK660 | Items have both an area and an iteration | No item with an Iteration Path but a root Area Path, or the reverse. |
|  | ⭕ | WRK670 | Features do not span team areas | A Feature whose children sit in more than one team area has no single owner. |
| State | ✅ | WRK700 | Items are not closed in batches | BatchSize or more items closed within the same minute in the last BatchWindowDays suggests batch closing at Sprint end. |
|  | ✅ | WRK710 | Active items have an owner | Anything in progress is assigned to someone. |
|  | ✅ | WRK720 | No items parked in Resolved | Nothing sits in the Resolved category longer than ResolvedMaxDays; Resolved is inside the Cycle Time span, not a parking place. |
|  | ⭕ | WRK730 | No reopened items | Closed then Active again clears CompletedDate and stretches Cycle Time. Needs WorkItemRevisions. |
|  | ⭕ | WRK740 | No items closed straight from New | Work that went New to Closed with no Active in between bypassed the board. Needs WorkItemRevisions. |
|  | ⭕ | WRK750 | Parents with every child Removed are not left open | An open Epic, Feature or Story whose children are all Removed. |
| Fields | ✅ | WRK800 | Sprint items have an estimate | Every open Story or Bug in a sprint carries an estimate (EstimateField setting: StoryPoints on Agile, Effort on Scrum). |
|  | ⭕ | WRK810 | Estimates are on the agreed scale | Estimate values match the scale per type (setting). |
|  | ⭕ | WRK820 | Epics and Features have Business Value | The value fields are populated at the levels agreed. |
|  | ⭕ | WRK830 | Type of Work is set | Type of Work is set on every open Epic, Feature and Story. |
|  | ⭕ | WRK840 | Bugs carry the Escaped flag | Escaped is set on every Bug once the field exists. |
|  | ⭕ | WRK850 | Intake items get a Disposition | A Feature older than N days with no Disposition is a Business Response Time clock still running. |
|  | ⭕ | WRK860 | Tags in use are on the approved list | Only tags on the approved list (setting) are in use. |
|  | ⭕ | WRK870 | High WIP | A team has more items in a column than its limit. |
| Staleness | ✅ | WRK900 | No stale open items | Nothing open has gone untouched for more than StaleDays. |
|  | ⭕ | WRK910 | No unrefined New items older than a PI | Items still New after a full PI were never refined. |
|  | ⭕ | WRK920 | No duplicate titles | The same title twice on the same type in the same area. |
|  | ⭕ | WRK930 | Unplanned work per Sprint | Items added to a Sprint after its first day, as a percentage per Sprint. Needs WorkItemRevisions. |
|  | ⭕ | WRK940 | Nothing removed from a Sprint after it starts | Items taken out of a Sprint after day one make the plan match the outcome by construction. Needs WorkItemRevisions. |
|  | ⭕ | WRK950 | Every Sprint has a Sprint Goal | The Sprint Goal extension holds a goal for the current Sprint. REST to the extension store. |
|  | ⭕ | WRK960 | Capacity is entered for the current and next Sprint | The Capacity page is filled in before the Sprint starts. REST only. |
| Repos | ⭕ | REP100 | Commits link to a work item | Commits on the default branch reference a work item ID. |
|  | ⭕ | REP110 | Pull requests link to a work item | Every completed PR has a linked work item. |
|  | ⭕ | REP120 | Default branch policy requires a linked work item | The policy exists on every active repo's default branch. |
|  | ⭕ | REP130 | TFVC check-ins are associated with a work item | Check-ins in the TFVC project reference a work item. |
