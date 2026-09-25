# ado-cop report

contoso, 2026-09-25 08:00. 52 rules, 1 project.

| Rule | Description | Status | Notes |
|:--|:--|:--:|:--|
| **CFG (Configuration)** |  |  |  |
| CFG002 | Hub project uses expected process | 🟢 | Hub uses Contoso Scrum |
| CFG004 | Spoke projects use expected process | 🟢 | Payments, Lending all use Agile |
| CFG120 | Hub project has expected services enabled | 🟢 | Boards on in 1 project |
| CFG122 | Hub project does not have unexpected services enabled | 🟡 | 1 unexpected service is on: Hub: Repos |
| CFG130 | Spoke projects have expected services enabled | 🟢 | Repos, Pipelines, Artifacts on in 2 projects |
| CFG132 | Spoke projects do not have unexpected services enabled | 🟢 | No unexpected services enabled in 2 projects |
| CFG140 | Areas defined | 🟢 | 6 areas defined |
| CFG150 | Iterations defined | 🟢 | 9 iterations defined |
| CFG155 | Iterations follow SAFe PI naming | 🟢 | Every iteration follows the SAFe pattern (2 PIs, 7 sprints) |
| CFG157 | Sprint names follow the agreed pattern | 🟢 | Every sprint name matches the pattern (7 checked) |
| CFG160 | Iterations have dates | 🟢 | Every sprint has dates (7 checked) |
| CFG180 | Consistent iteration lengths | 🟢 | All sprints are 14 days |
| CFG190 | Iterations follow the same cadence | 🟢 | All sprints run Wednesday to Tuesday |
| CFG305 | Expected teams are present | 🟢 | Every expected team is present (4 checked) |
| CFG307 | No unexpected teams present | 🟡 | 1 unexpected team is present |
| CFG315 | Teams are not oversized | 🟢 | No team has more than 10 members (largest: Payments with 8) |
| **WRK (Work Items)** |  |  |  |
| WRK100 | Epics have no parent or Initiative | 🟢 | No Epics with a wrong parent |
| WRK110 | Closed Epics have no open children | 🟡 | 3 open Features sit under closed Epics |
| WRK120 | Epics with all children closed are closed | 🟢 | No open Epics with closed children |
| WRK130 | Epics with active child are active | 🟡 | 2 new Epics have active children |
| WRK160 | Epics have a description and acceptance criteria | 🟡 | 5 open Epics lack a description or acceptance criteria |
| WRK200 | Features have parent Epic | 🟡 | 40 open Features lack a parent Epic |
| WRK210 | Closed Features have no open children | 🟢 | No open User Stories under closed Features |
| WRK220 | Features with all children closed are closed | 🟢 | No open Features with closed children |
| WRK230 | Features with active child are active | 🟢 | No new Features have active children |
| WRK270 | Features have a description | 🟡 | 12 open Features have no description |
| WRK300 | Stories have parent Feature | 🟢 | No orphaned User Stories |
| WRK310 | Closed Stories have no open children | 🟢 | No open Tasks under closed User Stories |
| WRK320 | Stories with all children closed are closed | 🟢 | No open User Stories with closed children |
| WRK330 | Stories with active child are active | 🟢 | No new User Stories have active children |
| WRK360 | Sprint Stories have a description and acceptance criteria | 🟡 | 2 sprint Stories lack a description or acceptance criteria |
| WRK370 | Sprint Stories are not oversized | 🟢 | No sprint item is larger than 8 |
| WRK400 | Bugs have parent | 🟢 | No open, orphaned Bugs |
| WRK500 | Tasks have parent Story or Bug | 🟢 | No open, orphaned Tasks |
| WRK510 | Tasks share the area path of their parent | 🟢 | Every Task shares its parent's area (61 checked) |
| WRK520 | Tasks are not created ahead of the sprint | 🟢 | No Tasks under Stories outside a started sprint |
| WRK530 | Sprint Tasks have remaining work | 🟡 | 4 current-sprint Tasks have no Remaining Work |
| WRK600 | Sprint Stories have a linked test case | 🟡 | 9 sprint Stories have no linked test case |
| WRK700 | No same type parent links | 🟢 | No same-type links (188 parent links checked) |
| WRK715 | Removed parents have no open children | 🟢 | No open items under Removed parents |
| WRK720 | Epics and Features are not in a sprint | 🟢 | No Epics or Features in a sprint |
| WRK730 | Open items are not in a past iteration | 🟡 | 8 open items sit in a past iteration |
| WRK740 | Execution items are not in the root area | 🟢 | No Stories, Bugs or Tasks in the root area |
| WRK785 | Items are not planned too far ahead | 🟢 | Nothing planned more than 1 sprint ahead |
| WRK800 | Items are not closed in batches | 🟢 | No batch closing in the last 90 days |
| WRK810 | Active items have an owner | 🟢 | Every active item has an owner |
| WRK815 | Epics and Features have an owner | 🟡 | 3 open Epics and Features are not assigned to a Product Owner |
| WRK820 | No items parked in resolved | 🟢 | No items parked in Resolved beyond 30 days |
| WRK850 | Sprint items have an estimate | 🟡 | 4 sprint items have no estimate |
| WRK900 | No stale open items | 🟡 | 12 open items untouched for over 90 days |
| WRK980 | Cycle time stays within the sprint length | 🟢 | Every sprint item closed in the last 90 days had a cycle time within its sprint (31 checked) |

_28 seconds, read-only REST calls, ado-cop.ps1._
