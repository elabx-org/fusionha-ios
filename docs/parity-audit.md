# #54 iOS ↔ web parity audit

Requested by fusionha (#54, owner-approved) on 2026-10-19. iOS `feat/ios-app-update` @ f05d8e3 checked against the web `main` 0.4.220 (`4152c68a`). Web paths are relative to `fusionha/frontend/src`; iOS paths are relative to `fusionha-ios/App` unless they say otherwise. The audit only read code. Fixes ship in batches, one build each, highest severity first. Each row gets ticked with its build number when it ships.

Owner rules checked everywhere:
- tokens only
- no gradient on controls or progress (only the logo, sign-in and avatars)
- an 11 pt floor for text (glyphs and dots are covered in Q-G1)
- status as an ambient wash, never a border or a left bar
- `onAccent` ink on the accent; `accentText` for accent text
- Monochrome shade + pattern
- Daylight legibility
- one header row on Requests
- **iPhone Duo:** folded is the phone; unfolded uses the web's wide layout (`lib/hooks/fold-layout.ts`, `compact-scope.ts`, plus each screen's own split rule)

The empty Queue screen (#53) is being ported separately and is not in this table.

## Batches

| Batch | Contents | Build |
|---|---|---|
| **B1 Blockers** | Q1, Q2, BL1, L1, A1, U1 (behaviour bugs and missing role access), plus D1 | ✅ build 389 |
| **B2 Rule sweep** | every *rule* row: status borders and left bars → wash; gradients on controls and progress → solid; `onAccent` / `accentText`; hex → `Theme` brand tokens (grey under Mono); text under 11 pt | part 1 ✅ build 389 (gradients, borders/bars → wash, on-accent ink, brand → Mono grey, the 0.4.222 poster glow); left: Discover/Account hex, toast wash, Notifications severity bar |
| **B3 Requests** | the R rows (decline-reason sheet, filter groups, header subtitles, drawer counts, Rules row) | ✅ build 408 (R9 deck wash done in B2; I2/I4 done) |
| **B4 Discover** | the D rows (Letterboxd suggestion card, trailers ＋, segmented fill, TMDB-missing state, one request path) | ✅ build 408 |
| **B5 Activity** | the Q, H, BL, W and T rows (failure copy, card washes, pair card, pack model, held why, History lifecycle, Blocklist groups, Tasks voice) | ✅ build 408 |
| **B6 Detail, Library, Calendar** | the L, I and C rows | ✅ build 438 (I5–I7, I9–I12, L2–L4, L6, L11, R1, S1, C1–C4) |
| **B7 Account, Settings, shell** | the A, U, N and S rows | ✅ build 440 (A2–A4, S1, S2, S4, S5, U2, N1, F1; SI1 partial: OIDC and living-media poses open; S3 → D2) |
| **B8 Monochrome** | `actWash` gains a Mono branch (shade + pattern) used by Activity, Wanted, Library, Detail tiers and the Live Activity | ✅ build 389 |
| **B9 Duo unfolded** | the *Duo* rows, ordered Requests → Queue → Library → Calendar → Settings → the rest | — |

## Blockers (B1): all ✅ build 389

| # | Screen · state | Web | iOS today | Gap | Fix |
|---|---|---|---|---|---|
| Q1 | Queue · remove one with "Also search" ticked and no blocklist | `routes/activity/queue/card/CardActions.tsx` (`if (doSearch && !blocklist) again.run()`) | `Screens/Activity/Queue/ActivityQueueTab.swift:47-49,336-337` | The server ignores `search` when blocklist is off, so the search the user asked for never runs. | Run `ActActions.search` after the remove. |
| Q2 | Queue · bulk remove with a mixed selection | `components/activity/BulkRemoveDialog.tsx:67-68` | `Queue/QueueDialogs.swift:61` (`deleteFiles = fileCount > 0`) | "Delete files" is pre-ticked when any row has a file. | Pre-tick only when every row has a file. |
| BL1 | Blocklist · unblock a collapsed ×N row | `routes/activity/BlocklistTab.tsx` (removes every copy) | `Blocklist/ActivityBlocklistTab.swift:239-242` | Only the lead copy is removed, so the release stays blocked. | Pass every entry in the group. |
| L1 | Library · bulk Change root | `ChangeRootPopover.tsx:57` (default `HD-1080p`) | `Screens/Library/LibraryBulkBar.swift:155` (`"all"`) | Opens on "Every version" and re-roots HD and 4K together. | Default to HD·1080p, plus the web's warnings and summary (B6). |
| A1 | Account · a requester's Notifications | `settings/notifications/RequesterNotifications.tsx` (inline in Account) | `Components/Account/NotificationsPrefsView.swift:47-51` → full Settings | A requester can't choose events, and Back lists the admin panels. | Put `NotificationEventsCard` (the user's kinds) inline in Account. Never send a requester into Settings. |
| U1 | Settings › Users · manage access and sign-in methods | `UserRowActions.tsx:36-69` (`AccessDialog`) | `Screens/Access/UserEditorSheet.swift:35-55` | No per-instance grants. An admin can't see another user's sign-in methods. | An Access section in the user sheet, and a methods sheet for any user. |
| D1 | Discover · From your Letterboxd cards | `components/discover/letterboxd/SuggestionCard.tsx` | `Screens/Discover/LetterboxdRail.swift:46` (generic card) | Missing: Request + tier, Me too, "N asked", source line, over-limit wishlist, done states. | Port `SuggestionCard` with a native tier `Menu` (B4 lead item). |

## Discover, Requests, Issues, Manual Import

| # | Screen | State | Web | iOS today | Gap | Sev | Batch |
|---|---|---|---|---|---|---|---|
| D2 | Letterboxd rail | Header | `SuggestionsRail.tsx` (LbIcon, QuotaPip) | `LetterboxdRail.swift:21` | No brand mark, no weekly quota pip | visible | B4 |
| D3 | Letterboxd rail | Chips, empty, switching | `SuggestionsRail.tsx` `RAIL_COPY` | `LetterboxdRail.swift:23,41-43,66-79` | Chips only with 2+ sources; different empty copy; no skeleton | minor | B4 |
| D4 | Browse | Kind lens (phone) | `DiscoverBrowseControls.module.css` (4 equal segments) | `DiscoverBrowseControls.swift:17`, `DiscoverKit.swift:105` | Segments sized to their labels | visible | B4 |
| D5 | Browse | Selected segment | `SegmentedControl.module.css` (i1 14% wash) | `DiscoverKit.swift:103,110` | Grey selection | minor | B4 |
| D6 | Browse | TMDB key missing | `routes/Discover.tsx` `KeyMissingNotice` | `DiscoverView.swift:225-238` | Every rail says "Could not load" | visible | B4 |
| D7 | Browse | Needs-you tab badge | `DiscoverTabBadge.tsx` | `DiscoverView.swift:89,93-94,216` | Doesn't use `needs_you`; no 99+ cap; no 30 s refresh | visible | B4 |
| D8 | Card | Approved and Watching chips, TMDB mark | `DiscoverCard.module.css`, `CardDemandRow.module.css` | `DiscoverCard.swift:97-107,127` | Green/grab instead of the accent; mark at 9 pt | minor | B2 |
| D9 | Trailers | ＋ | `TrailerRail.tsx` (opens Add) | `DiscoverTrailers.swift:96-103` | Opens Preview; ignores the library; literal white | visible | B4 |
| D10 | Request modal | Series with nothing to offer; art facts; demand summary | `RequestModal.tsx`, `RequestModalArt.tsx`, `RequestModalDemand.tsx` | `RequestModal.swift:123-158,265`, `RequestModalDemand.swift:114` | Seasons picker shows; Specials left out; act words not bold | minor | B4 |
| D11 | Request modal | Checkbox tick on the accent | `RequestModal.module.css:119-133` | `RequestViews.swift:161` (`Theme.bg`) | Not `onAccent` | visible | B2 |
| D12 | Add sheet (requester) | Request from search | `RequestModal.tsx` (the only path) | `Add/AddTitleSheet.swift:92-94,170`, `Add/RequestConfigurator.swift` | Old single-tier path: no editions, seasons, quota or wishlist | visible | B4 |
| D13 | Discover | Hex and white hairlines | rule | `DiscoverKit.swift:16-17`, `DiscoverCollections.swift:129`, `DiscoverBadges.swift:27` | Hex, and white that disappears on Daylight | minor | B2 |
| R1 | Header row | Threads subtitle + CTA count | `RequestsThreads.tsx` ("N unread · M open") | `ApproverRequestsView.swift:67` | No subtitle; CTA reads "Show results" | visible | B3 |
| R2 | Header row | Insights | `RequestsInsightsView.tsx` ("Last N weeks") | `Rules/RequestInsightsView.swift:22,27` | A second header line breaks the one-row rule | visible | B3 |
| R3 | Header row | Mine and My requests subtitle | `requests/mine-header.ts` | `ApproverRequestsView.swift:77` | Counts declined requests; nothing for Issues; no "Nothing open" | visible | B3 |
| R4 | Filter sheet | Insights range; Inbox search; History requester; Issues problem type | `nav/filter-groups.ts` | `Nav/RequestsNav.swift:38-44` | Missing groups | visible | B3 |
| R5 | Filter sheet | Mine source model | `nav/MineGroups.tsx`, `mine-filters.ts` | `Nav/RequestsFilterSheet.swift:77-85` | Manual/Plex/Letterboxd vs the web's Any / All automatic / Plex / Letterboxd + sub-lists (Q-R6) | visible | B3 |
| R6 | Filter sheet | CTA label, counts, chip words | `filters.ts resultLabel`, `MineGroups.tsx` | `RequestsFilterSheet.swift:48-54,142-149`, `RequestsFilterChips.swift:31` | "Show results" vs "Done"; no status counts; "My issues" vs "Issues" | minor | B3 |
| R7 | Drawer | Counts and the check mark | `nav/useMenuCounts.ts`, `ViewMenu.module.css` | `RequestsViewMenuSheet.swift:73-80`, `ApproverRequestsView.swift:112` | No Threads or Mine counts; "N need you" hides at 0; check mark not in `accentText` | visible | B3 |
| R8 | Inbox / Board | Decline with a reason | `DeclineReasonSheet.tsx` | `InboxRowsView.swift:30-35`, `RequestsBoardView.swift:59-61` → `RequestDecisionDialogs.swift:129-181` | Old "Reject" form with no Undo | visible | B3 |
| R9 | Deck | Approve drag wash | `SwipeCard.module.css .ap` (`--done`) | `SwipeCardView.swift` (primary) | Accent where the web uses done-green | minor | B3 |
| R10 | History | Count, deferred colour, step word | `RequestsHistory.tsx`, `history-status.ts` | `RequestsHistoryView.swift:21-29,140-145` | Count only covers loaded rows; deferred is red | minor | B3 |
| R11 | Thread sheet | Joined pill, demand line | `RequestThread.tsx` | `RequestThreadSheet.swift:81-93` | Plain text | minor | B3 |
| R12 | Rules | Rule row | `requests/rules/RuleRow.tsx` ("never a left accent") | `Rules/RequestRulesView.swift:112-114` | **3 pt left bar**; no order number, guard or tier chips; different copy; Guards always shows | visible | B2 + B3 |
| R13 | Requests | Glyphs under 11 pt | rule | `RequestStepperView.swift:77` (8), `RequestsFilterChips.swift:50` (10) | Under the floor (Q-G1) | minor | B2 |
| I1 | Report an issue | Footer button | `IssueModal.tsx` (accent) | `Issues/IssueReportSheet.swift:197-202` (danger) | Red button | visible | B2 |
| I2 | Report | Version picker, filed hint | `report/VersionPicker.tsx` | `IssueReportSheet.swift:85-98,191-195` | Segmented, no tier colour; footer line missing | minor | B3 |
| I3 | My issues | Working chip | `StateChip.module.css` (i2 + shimmer) | `Issues/IssueVerdictParts.swift:7` (grab) | Wrong tone | minor | B2 |
| I4 | Issue pane | Linked request, privacy hint, disabled reasons, toolbar | `threads/IssuePane.tsx`, `IssueChips.tsx` | `Threads/IssuePaneSheet.swift:52-126`, `IssueActionChips.swift:91-104` | "#1,234"; no hint; reasons only in VoiceOver | visible | B3 |
| M1 | Manual Import | Verdict strip, medium-confidence ask, title block, bulk edit, not-an-upgrade | `routes/manual-import/*` | `ManualImport/ManualImportSheet.swift:72-156`, `MIFooter.swift:112-133` | Missing pieces (bulk edit was a recorded deviation) | visible | B5 |
| M2 | Manual Import | Row card, held strip, which file stays | `PhoneRow.module.css`, `HeldStrip.module.css`, `WhichFileStays.module.css` | `MIRowView.swift:33-50`, `MIFooter.swift:33-34`, `MIWhichFileStays.swift:22-73` | **Status borders**; indigo selection (Q-R9) | visible | B2 |

## Activity, notifications, Live Activity, widgets

| # | Screen | State | Web | iOS today | Gap | Sev | Batch |
|---|---|---|---|---|---|---|---|
| Q3 | Queue | Card wash per state | `queue/card/card-content.tsx` `WASH` | `Queue/QueueLogic.swift:303-315` | Stalled amber (web cyan); failed amber (web red); waiting cyan (web grey) | visible | B5 |
| Q4 | Queue | Soonest card | dead CSS on the web | `QueueStateCard.swift:41`, `QueueGroupCard.swift:114` | **Status border** (Q-A7) | visible | B2 |
| Q5 | Queue | Failure reason text | `lib/failure-format.ts` | `QueueStateCard.swift:136`, `QueueUpNext.swift:97` | Raw backend strings; port into FusionhaKit (History and Blocklist reuse it) | visible | B5 |
| Q6 | Queue | Group wash, pair card, Remove all, select mode | `group-model.ts`, `PairCard.tsx`, `GroupActions.tsx`, `QueueGroupCard.tsx` | `QueueGroupCard.swift:45,116-237` | No red for a failed member; pair is a group; fixed dialog; **left status bar** in select mode | visible | B5 (+B2 for the bar) |
| Q7 | Queue | Held pack, pack line, mislabel why, block-group prompt | `PackSection.tsx`, `pack-model.ts`, `HeldWhyDetail.tsx`, `MislabelProofStrip.tsx` | `QueueHeldCard.swift:26-147`, `QueueFacts.swift`, `QueuePackEpisodesList.swift` | Missing models and actions; block prompt not gated on evidence | visible | B5 |
| Q8 | Queue | Pipeline hero | `queue/pipeline/*` | `QueueHeroes.swift:82-161` | Older 6-bucket hero; **gradient panel** | visible | B5 |
| Q9 | Queue | Importing bar, live sweep | rule | `Kit/ActMotion.swift:47,74` | **Gradient** band and sweep (Q-A4) | minor | B2 |
| Q10 | Queue | Just finished, +N more, Up next, focus link, Undo toast | `JustFinishedRow.tsx`, `QueueTab.tsx`, `OnDeckCard.tsx`, `use-queue-deep-link.ts` | `QueueUpNext.swift`, `ActivityQueueTab.swift:198-293` | Small gaps | minor | B5 |
| Q11 | Activity | Tab badge on the accent | `Activity.module.css:57-75` | `Kit/ActNavigation.swift:38` (`Theme.bg`) | Not `onAccent` | visible | B2 |
| Q12 | Activity | Audit search; Resolve all held | `routes/Activity.tsx` | `ActivityView.swift:79,268` | No search on Audit; header button moved (Q-A6) | visible | B5 |
| H1 | History | Scope to one title | `item-filter.ts`, `ItemFilterChip.tsx` | `FusionhaKit/APIClient+Activity.swift:72` | No `item_id` | visible | B5 |
| H2 | History | Failed story, solo release, Search again, Why, blocklist target | `HistoryTab.tsx`, `blocklist-target.ts` | `History/HistoryStoryRow.swift:19-231` | Raw reasons; episode search hits the whole edition; Why opens the wrong tab | visible | B5 |
| H3 | History | Lifecycle sheet | `lifecycle/LifecyclePanel.tsx` (mock `history-lifecycle-panel.html`) | `History/HistoryLifecycleSheet.swift` | No HD/4K switch, actions or HeldStep | visible | B5 |
| BL2 | Blocklist | Grouping, selection, copies list, reasons | `activity-format.ts groupBlocklist`, `BlocklistTab.tsx` | `ActivityBlocklistTab.swift:93-246`, `BlocklistRow.swift:45-140` | Merges different reasons; leaves hidden copies selected; raw reason | visible | B5 |
| W1 | Wanted | Monochrome | `Wanted.module.css:96-110` | `Wanted/WantedCard.swift:25,81` | Missing, cutoff and upcoming all the same grey | visible | B8 |
| W2 | Wanted | Search all reload, quip, gradual strip, glyphs | `lib/api/wanted.ts:216` | `WantedView.swift:218-291`, `WantedGradualStrip.swift:65`, `WantedFourK.swift:61` | Stale counts; **gradient** behind a control; 6–8 pt glyphs | minor | B2 / B5 |
| T1 | Tasks | Playful voice | `routes/tasks/TaskLine.tsx` | `Tasks/TaskRunning.swift:9`, `TaskRecent.swift:50-72` | The toggle saves but changes nothing | visible | B5 |
| T2 | Tasks | Candidate breakdown, enrichment subtasks, bulk attention, file drill, focus link | `TrailRows.tsx`, `enrichment/*` | `TaskTrail.swift:210-256`, `TaskSystemCards.swift`, `EnrichmentAttention.swift` | Missing | visible | B5 |
| T3 | Tasks | Run and stuck rows, watchlists wash, Mono stalled | `TasksTab.module.css:119,124` | `TaskRunning.swift:32-181`, `WatchlistsTaskCard.swift:39` | **Status borders** (the web too, Q-A5); hand-rolled wash | minor | B2 |
| N1 | Notifications | Admin delivery card, digest time, severity marker, retired/New, this device | `notifications/*` | `Settings/Fetching/NotificationEventsCard.swift:36-85`, `NotificationsPanel.swift:170-365` | Missing pieces; **3×30 left bar** marker; digest time can't be set | visible | B7 (+B2 for the bar) |
| LA1 | Live Activity | Stage rail, Monochrome, Daylight | n/a | `Widgets/LiveActivityParts.swift:11-118`, `DownloadsLiveActivity.swift:13,96-110` | **Gradient** rail; no Mono; forced dark background with Daylight tokens (Q-A8) | visible | B2 / B8 |
| WG1 | Widgets | Page dots, background | rule | `Shared/WidgetPages/WidgetPageDots.swift:23`, `Shared/WidgetViews/WidgetBackground.swift:25`, `WidgetPoster.swift:37` | 8 pt chevron; **gradients** | minor | B2 |

## Library, item detail, Search, Calendar

| # | Screen | State | Web | iOS today | Gap | Sev | Batch |
|---|---|---|---|---|---|---|---|
| L2 | Library | Kinds bar and chips | `LibraryPulse.tsx:452-545` | `Library/LibraryToolbar.swift:44-80` (Kinds menu) | Not recorded as a deviation (Q-L1) | visible | B6 |
| L3 | Library | Toolbar order, needs-attention chip, Filters word, density segment | `LibraryToolbar.tsx:344-500` | `LibraryToolbar.swift:20-41`, `LibraryHeader.swift:87-102` | Order and controls differ | minor | B6 |
| L4 | Library | Grid rhythm | `Library.module.css:239-247`, `PosterCard.module.css:636-650` | `LibraryRows.swift:177,186`, `PosterCard.swift:233-255` | Gaps and type sizes | visible | B6 |
| L5 | Library | Attention card, stats buttons | `PosterCard.module.css:108-120` | `PosterCard.swift:23-31,98-101`, `LibraryStatsSheet.swift:199` | **Status ring and border** | minor | B2 |
| L6 | Library | Compact list sort, persistence, no-matches copy, bulk exit | `LibraryCompactTable.tsx:138-145`, `library-filters.ts`, `BulkActionBar.tsx` | `LibraryTable.swift:13-16`, `LibraryView.swift:13-19,240`, `AppModel.swift:662-674` | Can't sort; settings half-persist; select mode stays on after an action | visible | B6 |
| L7 | Library | Stats meters, coverage rail, edition chip | `CoverageRail.module.css` (also gradient, Q-A3) | `LibraryStatsSheet.swift:59`, `Components/CoverageRail.swift:246,248`, `EditionChips.swift:16-20` | **Gradients** on progress and chips | visible | B2 |
| I5 | Detail | Loading skeleton, error copy, section order and headings | `ItemDetail.tsx:291-323`, `MobileDetailFlyout.tsx` | `ItemDetailView.swift:40-48`, `DetailPage.swift:60-75`, `DetailComponents.swift:51-74` | Spinner only; strip order; heading style (Q-L7) | visible | B6 |
| I6 | Detail | Requested-by pill, status chip, cert badge | `RequestedByPill.tsx`, `MobileHero.tsx` | `DetailHero.swift:49-210` | Missing | visible | B6 |
| I7 | Detail | Versions panel rows | `VersionsPanel.module.css`, `VersionRow.module.css` | `DetailVersionsPanel.swift:39-58`, `DetailVersionRow.swift:100` | Separate cards; **open row ringed in the status colour** (Q-L6) | visible | B2 + B6 |
| I8 | Detail | Banners with a coloured stroke | `VersionAttentionBanner.module.css` | `DetailVersionExtras.swift:48`, `DetailSearchParts.swift:137,227`, `DetailSeasons.swift:82` | **Status stroke** | minor | B2 |
| I9 | Detail | Numbering notice, Rename files, Collection tab | native on the web | `DetailSeasons.swift:69`, `DetailMovieEditions.swift:41`, `DetailSeriesFiles.swift:53`, `DetailRails.swift:110-188` | **Opens the web app** although native sheets exist | visible | B6 |
| I10 | Detail | Episode dialog, movie file actions, download pill | `EpisodeDetailDialog.tsx`, `MovieVersionsTable.tsx` | `DetailEpisodes.swift:78-104`, `DetailMovieEditions.swift:124-216` | Missing | visible | B6 |
| I11 | Detail | History insights, Searches tab, nothing-grabbed toast, skip chips, learn alias | `HistoryInsights.tsx`, `SearchesTab.tsx`, `SearchActionButton.tsx`, `InteractiveSearch.tsx` | `DetailHistory.swift`, `DetailStore.swift`, `DetailSearch*.swift` | Missing | visible | B6 |
| I12 | Detail | Metadata switch, numbering pin | `EditItemDialog.tsx`, `MetadataSwitchDialog.tsx` | `EditItemSheet.swift:58-88` | Read-only | visible | B6 |
| I13 | Detail | Hex star, card gradient, primary sheen, coverage bar, failed episode wash, Daylight shadows | rule | `DetailComponents.swift:14,87-88`, `DetailMovieEditions.swift:56`, `PosterSheetParts.swift:96`, `DetailSeasons.swift:269`, `DetailEpisodes.swift:100`, `DetailHero.swift:129` | Hex; **gradients**; heavy shadows | minor | B2 |
| I14 | Detail | Tier colour in Monochrome | `MonoTierBackground` | `DetailFiles.swift:33-47`, `DetailPills.swift:123`, others | HD and 4K are the same grey | visible | B8 |
| S1 | Search | Provider label, owned action, add + request, placeholder | `components/omni/*` | `Components/SearchTabView.swift:87,266-277`, `OmniRows.swift:54-70` | Small gaps | minor | B6 |
| C1 | Calendar | Phone header, filter menu, iCal, prev/next, swipe | `CalendarHeaderMobile.tsx`, `CalendarFilterMenu.tsx`, `useSwipeNav` | `Calendar/CalendarView+Toolbar.swift`, `CalendarControls.swift:389` | Chips and legends vs one menu; no swipe (Q-L11, Q-L12) | visible | B6 |
| C2 | Calendar | Agenda, Forecast and Day on phone; day headers; same-show runs | `calendar/mobile/*` | `CalendarAgenda.swift`, `CalendarWeekView.swift`, `CalendarWeekDayGroup.swift` | Desktop lists on phone; no Up next; no sticky headers; runs only fold at 3+ | visible | B6 |
| C3 | Calendar | Event status wash | `mobile.module.css:55-60` | `CalendarWeekCards.swift:23-26`, `CalendarMotion.swift:57-73` | Wash only as a pulse (gone under Reduce Motion); **tier border** | visible | B2 |
| C4 | Calendar | Text on the accent, empty dash | rule | `CalendarParts.swift:92`, `CalendarFeedback.swift:17` | `Theme.bg` ink; dash invisible | minor | B2 |

## Account, Settings, sign-in, shell

| # | Screen | State | Web | iOS today | Gap | Sev | Batch |
|---|---|---|---|---|---|---|---|
| A2 | Account hub | Avatar and role, Active sessions, duplicate screens | `shell/AccountPanel.tsx:62-77` | `Components/Account/AccountRows.swift:48-50`, `YouView.swift` | No RoleBadge or role tint; "(plex:N)" shows; YouView duplicates AccountView | visible | B7 |
| A3 | Watchlists | Plex and Letterboxd cards | `PlexWatchlistCard.tsx:96-99`, `LetterboxdCard.tsx:64-79` | `Watchlists/PlexWatchlistSection.swift:29-38`, `LetterboxdSection.swift:18-66` | No state wash; generic symbols instead of brand marks | visible | B7 |
| A4 | Shell | secrets_locked toast; toast actions, wash, pause; badge cap | `SecretsLockedToaster.tsx`, `ui/Toast.tsx`, `RequestsCountChip.tsx` | `Components/Toast.swift:28-112`, `RootView.swift:76-79` | No locked toast; no action; hand-rolled **gradient** wash; no 99+ cap | visible | B7 (+B2 for the wash) |
| U2 | Users | Pulse, UHD access, duplicates/merge, password, disconnect, status chip | `settings/UsersList.tsx`, `UsersPanel.tsx`, `UserFormDialog.tsx` | `Access/UsersSettingsPanel.swift:26-86`, `UserEditorSheet.swift` | Missing; **border** chip | visible | B7 |
| S2 | Rules | Slug and title | `settings-nav-request-rules.tsx` | `Settings/SettingsNav.swift:100`, `SettingsPanels.swift:35` | `request-rules` falls through to the web view | minor | B7 |
| S3 | Indexers | Backoff border, Prowlarr hex, table view | `IndexersPanel.tsx:652-670` | `Settings/Fetching/IndexerCard.swift:47-69`, `IndexersPanel.swift:94-104` | **Border**; hex | visible | B2 / B9 |
| S4 | Connect / Connections | Arr webhook and Add connection | `ArrWebhookEditDialog.tsx`, `AddConnectionDialog` | `Fetching/ConnectPanel.swift:116-147`, `ConnectionsPanel.swift:54` | Web-view fallbacks | visible | B7 |
| S5 | Download clients, Database, Naming, File management, Default profiles | various | `DownloadClientsPanel.tsx`, `MediaManagementPanel.tsx`, `DefaultProfilesPanel.tsx` | `DatabasePanel.swift:222`, `NamingSettingsPanel.swift:101`, `SettingsMediaPanels.swift:111`, `SettingsQualityPanels.swift:32-74` | Notes, insert at the cursor, matrix, explainer; **`Theme.bg` ink on the accent** | minor | B7 (+B2) |
| S6 | Settings | Gradients and hand-rolled washes | rule | `MetadataProviderSegmented.swift:60`, `SettingsSystemPanels.swift:332`, `DatabasePanel.swift:24`, plus 6 hand-rolled washes | **Gradient on a control and on cards** | minor | B2 |
| S7 | Settings | Brand hex (TMDB, TVDB, TVmaze, Discord, Telegram, Prowlarr, login preview) | rule | `SettingsMetadataProviders.swift:39-41`, `NotificationAgentSheet.swift:16-18`, `SettingsAppearancePanel.swift:266-534` | Hex outside Theme | minor | B2 (`Theme.brand`, grey under Mono) |
| SI1 | Sign-in | OIDC, living-media poses, Setup back and links | `routes/Login.tsx`, `routes/Setup.tsx` | `SignIn/SignInForms.swift:33`, `LivingPose.swift:8`, `SetupWizardView.swift:123-130` | Missing (the web marks OIDC as Planned) | visible | B7 |
| F1 | Code health | Files over 400 lines | CLAUDE.md | `ConnectionsPanel` 678, `IndexerFleetOverview` 670, `SettingsKit` 628, `SettingsSystemPanels` 584, `SettingsAppearancePanel` 566, `NotificationsPanel` 538, `SystemTasksPanel` 422, `DetailHistory` 414, `RootFoldersPanel` 410, `SettingsQualityPanels` 404, `DetailSearch` 403, `DetailSearchParts` 403 | Split while doing the batch that touches them | minor | with each batch |

## Duo unfolded (B9)

| # | Screen | Web wide layout | iOS today | Gap | Sev |
|---|---|---|---|---|---|
| DU1 | Requests nav | `nav/usePhoneLayout.ts`, `ViewMenuPopover`, desktop `ViewHeader` pill, `FilterPanel` popover | always the drawer sheet, filter sheet and round button | Phone UI | visible |
| DU2 | Inbox | `requests/useTriageLayout.ts` (panes / stacked / deck) | deck or list | No queue + DecisionCard panes | visible |
| DU3 | Board | `RequestsBoard.tsx` (5 columns) | stage sections | Phone layout | visible |
| DU4 | History (Requests) | `RequestsHistory.tsx` table | day groups | No table | visible |
| DU5 | Request thread, Issues, Threads | `RequestThread.tsx` right panel, `threads.module.css .split` | sheets | No side pane (Q-R8) | visible |
| DU6 | Discover | `DiscoverBrowseControls` one row ≥721; `Rail.module.css` cell sizes; filter auto-fit; `RequestModal` two panes | stacked; fixed 116 cards | Phone layout | visible |
| DU7 | Manual Import | `useManualImportLayout.ts` (split ≤720 / table) | phone cards | Missing (Q-R4) | visible |
| DU8 | Queue | `queue/duo/use-queue-duo.ts`, `QueueDuoPane.tsx` (list 294 \| card 375); the card's own 3-column grid ≥720 | tapping opens the title detail | No queue-card pane (Q-A2) | visible |
| DU9 | Activity header, Tasks | single-row head and 3-up System grid ≥720 | phone | Only an iPad reaches 720 (Q-A1) | minor |
| DU10 | Library | `useIsMobile` 720: desktop toolbar, inline pulse ribbon, A–Z rail, letter headers | only the column count changes | Phone toolbar and scrubber (Q-L17) | visible |
| DU11 | Calendar | `calendar/layout.ts` (own width: <720 phone, 720–999 tablet, ≥1000 desktop) | size class → desktop month grid | Wrong trigger; no tablet branch | visible |
| DU12 | Settings | sidebar 212 + panel ≥720 | `SettingsView.swift:31` size class | Wrong trigger (Q-S2) | visible |
| DU13 | Account panel | trailing panel of about 520 px ≥720 | centred sheet, 420 wide | Sheet | visible |
| DU14 | Shell | CapsuleNav + status cluster >720 | tab bar, no cluster | No cluster (Q-S3) | visible |
| DU15 | Sign-in | hero beside the form ≥760; living art beside it ≥720 | stacked | Phone layout | visible |
| DU16 | Settings panels | Metadata 2 columns, Plex rows, default profiles table, quality editor ≥820, custom formats 760/1100, import two panes, card grids auto-fill | stacked | Phone layout (Q-S5) | minor |
| DU17 | Item detail | docked title uses the phone layout | ShellDetailColumn | **Matches** | — |
| DU18 | History, Blocklist, Wanted, Tasks | mobile below 720 (the inner display is about 669) | phone column | **Matches** today | — |

HIG Duo items from the apple-hig skill (`references/duo-checklist.md`) that the web doesn't cover:
- Keep the custom split edge and important controls off the hinge (`reservedRegion` / `ArrangementView`, iOS 27.1).
- Use even grid column counts.
- On the outer display, custom header rows don't move into the vertical system bar.

These were sent to fusionha as tensions (#55 reply), pending the owner.

## iOS-only (keep, record in ui-plan)

- Pause downloads
- Bandwidth hero
- ETA sort and group % / speed / Pick downloads
- Approve and Decline inside the request thread
- Issue check keeps polling after 60 s
- Manual Import "open on the web" and retry
- Swipe delete on custom formats
- App palettes and Monochrome
- Server address step at sign-in
- Pull to refresh and haptics
- Live Activity and widgets
- Avatar-menu extras
- Calendar Subscribe
- The Search hint line
- The Library "N downloading" link

`docs/ui-plan.md` is stale for:
- Discover and Requests (still pre-Proposal 2)
- Library (§3)
- the sync bar "gradient"
- the attention bell

These get fixed with B3/B6.

## Design questions (for the owner via fusionha)

**General**
- **G1:** do glyphs and dots (✓ in the stepper, rail ✕/⏸, page chevrons, 6–8 pt symbols) get an exemption from the 11 pt floor, or must they be resized?
- **G2:** does "no gradient on progress" also cover the moving sweep (`ActShimmer`) and the indeterminate band?
- **G3:** the web still ships gradient fills on the coverage, HD·4K combo and download rails, and status borders on running Tasks. Does iOS go solid / wash-only and the web follow, or does iOS mirror the web?
- **G4:** should brand marks (TMDB, TVDB, TVmaze, Prowlarr, Discord, Telegram, Letterboxd) grey out under Monochrome, as Plex gold now does?
- **G5:** which Monochrome pattern set should status use everywhere (hatch / stripe / dotted / outline), owned centrally by `actWash`?

**Discover and Requests**
- **R1:** "posters stay clean": does it also cover the trailer backdrop? And should the web's 4K flag and badges on Library art stay off on iOS for good?
- **R2:** on wide touch layouts, should Discover cards get a persistent ＋ (the web shows it on hover)?
- **R3:** unfolded, should the request modal be a form sheet or a two-pane page sheet?
- **R4:** is the Duo's inner display wider than 720 pt? On the web that decides between Manual Import's split and its table.
- **R5:** Undo's "Change reason": keep the native Menu or use the reason sheet? Should the 5 s window pause while picking?
- **R6:** Mine › Source: adopt the web's Any / All automatic / Plex / Letterboxd with sub-lists (no "Manual")?
- **R7:** issue report, issue thread and Rules have no wide web layout. Form sheets on Duo? Should Rules open the Settings split?
- **R8:** should the Issues and Threads side pane auto-select the first item (as the web does) or show "Select a thread"?
- **R9:** "Which file stays?": port the web's column pick, or keep the two cards and fix the colours?

**Activity**
- **A1:** History, Blocklist, Wanted and Tasks unfolded: keep the phone column (web parity), or give them their own split panes?
- **A2:** should tapping a Queue card on Duo open the web's queue-card pane instead of the title detail? What should the empty pane say?
- **A3:** see G3.
- **A4:** see G2.
- **A5:** see G3 (Tasks borders).
- **A6:** Resolve all held (N): restore it in the iOS header, or drop it from the web in favour of Needs you's "Review all"?
- **A7:** the soonest-card highlight: drop it (dead on the web), keeping only the ETA sort?
- **A8:** Live Activity in Daylight: follow the palette, or always use dark tokens on the lock screen?
- **A9:** notification event controls: the web's on/off plus an admin delivery card, or iOS's three-way menu on both?

**Library, Detail and Calendar**
- **L1:** Library kinds: the web's kind bar and chips, or keep the menu as a deviation?
- **L5:** compact list: column sort, global sort, or both?
- **L6:** version rows: one panel with hairlines (web) or cards (iOS)? Either way the open-row ring becomes a wash.
- **L7:** detail section headings: 20 pt bold (iOS) or 11 pt mono uppercase (web)?
- **L8:** tapping an episode: the web's episode dialog, or inline expand plus "Details"?
- **L9:** Searches tab: embed the Tasks run view, or push a screen per run?
- **L10:** Collection: port the tab natively, or use a fuller rail only?
- **L11:** Calendar Week on phone: keep the four card styles (iOS-only) or use phone cards only (web)?
- **L12:** Calendar filters: one menu without legends (web) or chips with legends (iOS)? Should iCal be shown to everyone?
- **L15:** Search: for users with both permissions, show Add and Request as two buttons, or one button plus a menu?
- **L16:** Search on Duo: one column, or library matches beside the add lane?
- **L17:** Library on Duo: switch on the 720 viewport (web) even in a narrow pane, or on the pane's own width (as the Calendar does)?

**Account and Settings**
- **S1:** Automatic requests: inline in Account (web) or the "Watchlists & lists" sheet (recorded deviation)?
- **S2:** Settings split threshold: the web's 720 or the app's `ShellSplitRule` 560×500? Should the sidebar use rich rows or the web's compact labels?
- **S3:** above 720 the web uses a top CapsuleNav. Keep the glass tab bar and add the status cluster, or try `.sidebarAdaptable`?
- **S4:** requester notifications: rebuild them inside Account, or open only the Notifications panel?
- **S5:** the Indexers table, Custom formats columns and Quality side-by-side trigger at 760/820/1100, which the Duo detail column may never reach. Build them for iPad only, or record them as deviations?
- **S6:** Setup, Users, Roles, Rules, Release filters, File management and Naming have no wide web layout. A centred single column with a max width when unfolded?
- **S7:** Users: should the pulse replace the Show picker? Manage access as a section, or a pushed screen?

## Rulings (fusionha #56, 2026-10-19)

All of these come from web parity plus the owner's rules. Only the Duo outer-display header question is still with the owner.

**General**
- **G1:** glyph-only marks (dots, ✓, ✕/⏸, chevrons) are exempt from the 11 pt floor. Text must be at least 11 pt.
- **G2:** the sweep and the indeterminate band become solid or translucent `i1` (the web did the same in 0.4.218).
- **G3, A3, A5:** iOS goes solid and wash-only now: coverage, combo and download rails are solid segments, and running Tasks use a wash. The web follows in its next release.
- **G4:** brand marks turn grey under Monochrome.
- **G5:** use the web's Mono pattern set from 0.4.221 (files to follow), owned by `actWash`.

**Discover and Requests**
- **R1:** no text on art. Library art badges (the 4K flag and others) follow the web and are shown.
- **R2:** a persistent ＋ on touch layouts.
- **R3:** form sheet.
- **R4:** decide by the real pane width against 720.
- **R5:** the reason sheet; the 5 s window pauses while it is open.
- **R6:** the web's source options.
- **R7:** form sheets on Duo; Rules opens the Settings split.
- **R8:** auto-select the first item when wide; the phone shows the list.
- **R9:** the web's column pick.

**Activity**
- **A1:** phone column.
- **A2:** the web's queue-card pane, with the web's empty copy.
- **A6:** mirror what the web ships today.
- **A7:** drop the highlight and keep the ETA sort.
- **A8:** the lock screen always uses dark tokens.
- **A9:** the web's model (on/off plus the admin delivery card).

**Library, Detail and Calendar**
- **Follow the web:**
  - L1
  - L5
  - L6: one panel with hairlines; the ring becomes a wash.
  - L7
  - L8: the episode dialog as a sheet.
  - L9
  - L10: port the tab.
  - L12: one menu; iCal shown as the web does.
  - L15
  - L16
- **L11:** the iOS card styles stay as a recorded extra, but the default is the web's phone cards.
- **L17:** switch on the pane's own width.

**Account and Settings**
- **S1, S4, S7:** follow the web.
- **S2:** split at 720 of available width, with compact labels.
- **S3:** keep the glass tab bar (a recorded deviation) and add the status cluster.
- **S5:** build at the web's thresholds and record a deviation wherever the Duo never reaches them.
- **S6:** a centred single column with a max width when unfolded.

## #59 Duo compatibility (owner decision: system toolbar)

**The owner's decision, quoted:** "use system toolbar to stay within the design of duo and ALSO AUDIT ALL OTHER SCREENS FOR DUO Compatibility".

What it means for the app:
- Header-row actions become standard system toolbar items (title + symbol, groups, visibility priority). iOS 27.1 places them, so on the outer display and in vertical-bar contexts they move into the vertical bar.
- The header keeps the title, the view menu and the wide segmented controls.
- The normal iPhone keeps today's look because the system decides placement; there is no Duo branch.
- This is a recorded iOS-native deviation from the web.

**The audit:**
- Sources: `.claude/skills/apple-hig/references/duo.md` and `duo-checklist.md`.
- Sizes: the outer display is 466×678 pt (measured). The inner display is about 626×890 / 890×626 (estimated).
- Method: the code was read only. Nothing was run in a simulator, and rows marked *verify* need one.

**Batches** (B9 is folded into D2):

| Batch | What |
|---|---|
| **D1 Toolbar migration** | A `NavigationStack` per tab *inside* its `Tab` (keeps TabView identity and scroll). Header actions become `ToolbarItem`/`ToolbarItemGroup` with title + symbol, `.badge`, visibility priority. Sheet bar buttons become title + symbol (`SheetCancelButton`/`SheetDoneButton`, fixed titles; progress via `.disabled`). App overflow goes into the system overflow menu (no `ellipsis`). |
| **D2 Inner layouts** | All B9/DU rows, switching on the pane's own width (L17/R4/S2), plus the issues below. |
| **D3 Fold & hinge** | Toasts and fixed controls off the fold. Even grid column counts with an inactive division. Sign-in and setup read `FoldInfo`. Safe-area constants replaced by insets. |
| **D4 Sheets & popovers** | `presentationSizing(.form)` where ruled. Popovers for the Requests drawer and filter when wide. Detents that fit outer landscape (466 pt tall). Scrollable confirm dialogs. |
| **D5 Continuity & keyboard** | The open title's `DetailStore` and child sheets survive sheet ↔ column. The split is measured ignoring the keyboard. Settings keeps one container. Focus and selected chip are restored. |

**Blockers:**

| # | Screen · pose | Finding | Fix | Batch |
|---|---|---|---|---|
| DC1 | Every tab · outer / vertical bars | No tab root sits in a `NavigationStack` (`RootView.swift:68-80, 316-327`), so there is no system bar for toolbar items. Headers are custom `ShellTitleRow` rows. | A `NavigationStack` inside each `Tab`, with `.toolbar` at the tab level. | D1 · ✅ build 422 |
| DC2 | Avatar · all | The account hub, Settings cover and widget sheets are `@State` on the avatar button (`AvatarMenu.swift:13-49`). Once the avatar is in system overflow, there is nothing to present from. | Move the flags into `AppModel` and present from `ShellPresentations`. The avatar becomes a toolbar item "Account" with `.badge`. | D1 · ✅ build 422 |
| DC3 | Item detail · fold/unfold | The column builds a new `ItemDetailView`/`DetailStore` (`DuoLayout.swift:137-142`, `ItemDetailView.swift:27`). Unfolding loses scroll, tab and scope, plus any open child sheet (search, edit, add version, rename, numbering) and its drafts. | Keep the open title's store in `AppModel`. Child-sheet flags live in the store and are re-presented; `scrollPosition(id:)`. | D5 · ✅ build 422 |
| DC4 | Shell split · inner landscape + keyboard | The split is measured from `RootView` including the keyboard (`RootView.swift:41`). Typing in the Library filter drops the height below 500, so the title column collapses back into a sheet (*verify*). | Measure with `.ignoresSafeArea(.keyboard)`. | D5 · ✅ build 422 |

**Visible:**

| # | Screen | Pose | Finding | Batch |
|---|---|---|---|---|
| DC5 | Library, Discover, Wanted header ＋; Library stats | outer | Custom `GlassIconButton` rows (`LibraryHeader.swift:24-28`, `DiscoverView.swift:210`) | D1 |
| DC6 | Library control row (Filters/grid/Select) | outer | Custom glass buttons with a hand-drawn count (`LibraryToolbar.swift:23-96`). The tier pills and kinds menu stay. | D1 |
| DC7 | Requests header Filter + Inbox Select | outer | Custom buttons; Select swaps its text (`RequestsViewHeader.swift:60-105`) | D1 |
| DC8 | Activity header Import / Pause | outer | `ViewThatFits` text↔icon capsule; Pause swaps to a `ProgressView` (`ActivityView.swift:244-260`, `QueuePauseButton.swift:17-30`) | D1 |
| DC9 | Calendar iCal, week style, ‹ Today › | outer | Custom; Today is text (`CalendarView+Toolbar.swift:34-102`) | D1 |
| DC10 | Item detail sheet Close, Add sheet, Request modal, trailer | outer | Custom ✕ overlays and hidden nav bars (`DetailHero.swift:37`, `AddTitleSheet.swift:64,105`, `RequestModal.swift:55`, `TrailerPlayer.swift:46`) | D1/D4 |
| DC11 | Search tab | outer | No `NavigationStack`, so `.searchable` never hosted the field; it is a custom docked field (`SearchTabView.swift:42-118`). Retry `.searchable`. | D1 |
| DC12 | Sheets with text-only or state-swapping bar buttons | vertical bars | About 25 sheets in Activity, Manual Import, Account, Settings, Issues and Requests (listed in the audit pass) | D1 |
| DC13 | Tab bar · inner portrait, title open | inner portrait | The 560/360 rule leaves a 265 pt leading column (`DuoLayout.swift:119-125`), narrower than any iPhone | D2 (Q-DC3) |
| DC14 | Toasts | inner Book/split | Overlay on the whole split, up to 420 wide (`RootView.swift:43-46`, `Toast.swift:52`), so it straddles the fold | D3 |
| DC15 | Calendar month | inner split | `sizeClass == .regular` puts the desktop month grid in a 265/391 pt column (`CalendarView.swift:12,184`) | D2 |
| DC16 | Settings | inner portrait + fold/rotation | Size-class split at 626 (ruling S2 says 720). `if wide {SplitView} else {Stack}` rebuilds the list and the open panel, losing scroll, focus and half-typed fields (`SettingsView.swift:31-57`) | D2/D5 |
| DC17 | Sign-in, Setup | inner Book | The centred card sits across the hinge (`SignInView.swift:117`, `SetupWizardView.swift:43`) | D3 |
| DC18 | Sign-in | outer | `.ignoresSafeArea(.container)` covers the form, so it runs under the trailing strip (`SignInView.swift:151,194`) | D3 |
| DC19 | Account panel | inner landscape | A default sheet capped at 420 (`AccountView.swift:29`); the web uses a ~520 trailing panel | D4 |
| DC20 | Activity confirm dialogs; Add user; Move credential | outer landscape (466 tall) | Non-scrolling dialog at `.medium` (`ActToaster.swift:107-139`); `.medium`-only detents with the keyboard (`UserEditorSheet.swift:152`, `MoveCredentialSheet.swift:48`) | D4/D5 |
| DC21 | Requests drawer/filter; Library filters; Issues sheets | inner | Height detents are ignored at regular width; the web uses popovers or modals | D4 |
| DC22 | Manual Import | inner | A default form sheet with phone cards; the web is split on the open Duo | D2/D4 |
| DC23 | Inner layouts | inner | DU1–DU16 (Requests panes, Board, History table, thread/issue panes, Discover wide, Queue card pane, Library desktop, Calendar tablet/desktop, Settings, Account, sign-in side by side) | D2 |

**Minor** (folded into the batches above):
- Toast 72 pt and page-bottom 90/190 constants (D3)
- `StatusBarFade` on the outer display (D3)
- Odd poster-grid columns across an inactive fold (D3)
- Detail hero minimum 360 in outer landscape (D3)
- Tab badge tint not refreshed on bar-axis change (D5)
- Activity chip strip not scrolled to the selection (D5)
- Search focus not restored (D5)
- Idle tile grid leaves an orphan row and starts at a 390 seed (D2)
- Import report 3+2 (D2)
- Sync count grid at narrow widths (D2)
- The Settings `.principal` clear view (D1)
- `ellipsis` menus (D1)
- Account hub opens at `.medium` in outer landscape (D4)
- One-item sheets: vertical-bar opt-out (Q-DC6)

**Ready:**
- System popovers with `presentationCompactAdaptation(.popover)`
- Widgets (`containerBackground`, system families)
- The Live Activity Dynamic Island regions
- Activity state across fold (`chrome`/`router` in `ActivityView`)
- `NavigationSplitView` Settings in Book pose
- No `UIScreen`, idiom or orientation checks

**Questions** (for the owner, via fusionha):
- **Q-DC1, phone look — RESOLVED (owner, 2026-10-19): (b) inlineLarge.** With toolbar items, the horizontal bar sits one row above the custom title. Choose one:
  - (a) accept two rows, with the bar background hidden
  - (b) move the title into the bar with `.toolbarTitleDisplayMode(.inlineLarge)` (loses the custom display font in the bar)
  - (c) keep the one-row look by branching on `toolbarVerticalEdge` (a Duo-style branch, which the decision rules out)
- **Q-DC2, avatar in the bar:** the `person.crop.circle` symbol with a `.badge`, or the Plex photo as an opted-in custom view (must handle `toolbarVerticalEdge` and Reduce Transparency)?
- **Q-DC3, inner width:**
  - At 626 portrait with a title open, the tabs column is 265 pt. Keep the web's 560/360 rule, raise the portrait threshold, or minimise the tab bar while split?
  - At 890 landscape the 720 thresholds are crossed. Should A1 ("phone column" for History, Blocklist, Wanted, Tasks) be re-ruled?
- **Q-DC4, Library select bar:** keep it custom (parity), or move it to a system `.bottomBar` group the system can move (task-focused, minimised tab bar)?
- **Q-DC5, Calendar month:** 7 columns can't be even across the fold. Record it as a deviation?
- **Q-DC6, Close-only sheets:** opt out of vertical bars (`toolbarVerticalBehavior`) or keep the system default?
- **Q-DC7, side-to-side fold:** tabs above and the title below don't fit a half-height pane with the 360 pt hero. Is that pose in scope?
- **Q-DC8, item-detail sheet:** drop the floating ✕ over the art for the system toolbar Close?
- **Q-DC9, toasts on the fold:** leading column, or the trailing side (HIG: alerts trailing in Book)?
- **Q-DC10, downloads accessory:** CLAUDE.md lists a glass "downloads accessory" that doesn't exist in code. Out of scope?

### Duo rulings (fusionha #60–#62, 2026-10-19)

- **Start now:** blockers DC1–DC4. For DC3, keeping drafts is a data-safety item.
- **Q-DC1 (owner, via fusionha #61):** option (b), `.toolbarTitleDisplayMode(.inlineLarge)`. Tab-root titles go in the system bar in the system face, with the toolbar items on the same row. The logo and sign-in keep the brand face. This is reversible. *Pending direct confirmation with the owner before the headers change.*
- **Q-DC2:** the avatar toolbar item is the Plex photo (initials fallback) with the dot badge, titled "Account".
- **Q-DC3:**
  - Inner portrait follows the HIG's horizontal bars: no 265 pt tabs column; the tab bar stays at the bottom.
  - Inner landscape (about 890) uses the web's desktop layouts above 720. This re-rules A1 for History, Blocklist, Wanted and Tasks there.
- **Q-DC4:** the Library select bar becomes a system `bottomBar`.
- **Q-DC5:** flat keeps 7 day columns. In Book pose the week switches to the list/agenda layout.
- **Q-DC6:** Close-only sheets opt out of vertical bars.
- **Q-DC7:** the side-to-side fold is out of scope.
- **Q-DC8:** drop the floating ✕ on item detail; Close is a `.cancellationAction`.
- **Q-DC9:** in Book pose, toasts sit on the trailing half, away from the hinge.
- **Q-DC10:** fix CLAUDE.md's stale "downloads accessory" line (with the owner's OK, since CLAUDE.md is project config).
- **#62 scope:** system toolbar and `.inlineLarge` apply to every screen: tab roots, pushed screens and sheets/forms. Sheet actions use `.cancellationAction`, `.confirmationAction` or `.primaryAction`, each with title + symbol. A D1 checklist (screen → header actions → placement and priority) follows. Exceptions are kept only for actions that must stay in content: deck Approve/Decline, row swipes, inline card buttons.

### D1 checklist: system toolbar on every screen

Owner's pick (Q-DC1): **(b)**. The page title moves into the system bar with
`.navigationTitle` + `.toolbarTitleDisplayMode(.inlineLarge)`, giving one row on a normal
iPhone and a vertical side bar on the Duo outer display. `ShellTitleRow` and the custom
Anton title are retired. The title uses the system font, and the avatar becomes a
`ToolbarItem` titled "Account" (VoiceOver and the vertical bar) showing the Plex photo, with initials when there is none, plus the dot badge (Q-DC2, ruled in #60). If 27.1 cannot render the photo at bar size, raise it with fusionha; never fall back silently.

| Screen | Header actions today | Toolbar placement (priority) | Stays in content | Done |
|---|---|---|---|---|
| Library | Add (+), Library stats, avatar | `.primaryAction` Add · `.secondaryAction` Stats · Account | filter chips, segmented, select bar (D3: system `bottomBar`) | ✅ build 450 |
| Discover | Add (+), avatar | `.primaryAction` Add · Account | Browse/Requests segmented, rails | ✅ build 450 |
| Requests | pane menu (title ▾), filter, avatar | title menu via `.toolbarTitleMenu` · `.primaryAction` Filter · Account | summary line, pills | ✅ D1 (build pending; pane menu stays in content, see notes) |
| Activity | Manual import, avatar | `.primaryAction` Manual import · Account | Queue/History/Blocklist/Tasks segmented | ✅ build 450 |
| Calendar | ‹ Today ›, iCal menu (admin), week style (week view), avatar | `.primaryAction` Today · `.secondaryAction` iCal, week style · Account | prev/next capsule, kind chips | ✅ build 450 |
| Wanted | Add (+) | `.primaryAction` Add · Account | summary line, tabs | ✅ build 450 |
| Search | avatar | Account; retry `.searchable` (DC11) | results | ✅ build 450 |
| You | avatar | Account | hub rows | ✅ build 450 |
| Settings (cover) | Close | `.cancellationAction` Close (system) | subtitle "DB-backed · effective without restart" | ✅ build 450 |
| Item detail sheet | custom ✕ (DC10) | `.cancellationAction` Close; hero stays clean | hero, edition chips | ✅ build 450 |
| Add / Request modal / trailer | custom ✕ (DC10) | `.cancellationAction` Close | — | ◐ D1 (build pending; Add configure step keeps PreviewHero ✕, see notes) |
| Text-only sheet buttons (DC12, ~25 sheets) | Cancel / Save / state-swapping text | `.cancellationAction` / `.confirmationAction`; close-only sheets opt out of vertical bars (#60) | — | ✅ build 450 |

Rules: no toolbar content in-content except the listed "stays" items; every item has a
symbol from the CLAUDE.md icon set and a text label (the vertical bar shows the symbol,
overflow shows the label). Tick a row with its build number.

### Batch F: follow-ups after B6/B7 (queued after D1; fusionha #63)

| Row | Item | Done |
|---|---|---|
| F1 | Users: search field (web parity) | ✅ build 455 |
| F2 | SI1: living-media poses, plus the server step as onboarding (owner, 2026-10-19; see F2 spec). OIDC dropped: not a server feature yet (peer #66: no `/api/v1/auth/providers`; sign-in is local + Plex SSO). If the owner wants it: spec → server → web → iOS | ✅ build 460: server step, no default server, TV + Anime morphs |
| F2b | Living-media morphs still to port: Movie, Dragon, Three kinds (from F2) | ☐ |
| F3 | Episode sheet's Search tab: park its `InteractiveSearchModel` across fold/unfold (DC3: no lost state) | ✅ build 455 |
| F4 | Activity, Calendar and sign-in toasts on `model.toast`, so Q-DC9 hinge placement applies everywhere | ✅ build 455: Activity + Wanted through `ActToaster.shell`, Calendar direct; sign-in already used it; sheets keep `CalToast` (now `Components/SheetToast.swift`) |
| F5 | Split oversized files to ~300–400 lines: `AppModel` (665), `ScreenModels` (619), `DiscoverModels` (530), `DetailLogic` (481), `CalendarModels` (456), `EditItemSheet` (335) | ☐ |

#### F2 spec: first run as onboarding (owner, 2026-10-19)

The server address step is the app's first screen, so the onboarding rules apply to it
(app-designer-pro `paywall.md` §1, HIG `onboarding.md`/`launching.md`/`privacy.md`). The
web has no server step; iOS owns it.

- **Same stage as sign-in.** The server step uses the current login animation, not a bare
  card. Before any server is known, use the cached `login_layout`/`login_background` from
  the last server. On a first install, use the Living logo over the default backdrop
  (aurora). Once connected, cross-fade into the server's chosen layout.
- **The Living mark acts out the step:**
  - typing the address: pins tick (`pinOffsets`)
  - connecting: the "arrivals" move
  - reached: the server is shown with its name and version, the step's first result
  - unreachable: jam + shake "no"
  Reduce Motion / `animations_enabled` are respected as now.
- **"Reached" data (fusionha #64):** show the host from the entered URL (no server display-name
  setting exists) and the version from unauthenticated `GET /health` (`version`). The stage
  fields come from `GET /api/v1/setup-status` (`login_layout`, `login_background`,
  `login_living_media`, logo/wordmark/tagline flags). A custom server name would need a new
  server setting; that's only if the owner asks.
- **No default server (owner, fusionha #65).**
  - The address field starts EMPTY on a fresh install. There's no pre-filled URL, no
    hard-coded instance (not the owner's, not a demo host) and no auto-connect.
  - The placeholder is a neutral example, `https://fusionha.example.com`.
  - A server this device has connected to before is offered only as an explicit
    "Recent: <host>" chip. Today the field pre-fills with `lastServer` after a sign-out;
    F2 replaces that with the chip.
  - The cached layout and backdrop are used only for such a remembered server.
  - Test: a FusionhaKit `ServerMemory` (injectable `UserDefaults`) asserts that a fresh
    store has an empty address, no recent servers and no stored `serverURL`.
  - Audit 2026-10-19: no default URL in project.yml/Info.plist, no Settings.bundle, and no
    host in App/Shared/extensions. The CI `FUSIONHA_SCREENSHOT_*` hooks (127.0.0.1 mock)
    are `#if DEBUG` only, and the IPA is built `-configuration Release`.
- **Budget:** a 3–7 word headline, one support line, one field, one button. "Continue"
  becomes "Connect".
- **Forgiving input:**
  - a bare host or IP gets the scheme and default port filled in
  - paste is detected
  - errors say what failed and what to try (unreachable, not fusionha, TLS, timeout)
- **Local network permission in context:** before the first connect to a private
  address, one line says why, so the system prompt isn't a surprise. If it's denied,
  show a fix-it row that opens Settings.
- **Progress:** Server → Sign in (→ Setup on a fresh server) shown when there are 3 steps;
  Back always works; "Change server" stays.
- **No carousel, no feature slides.** Duo: the stage spans; on the inner display the
  card stays off the hinge (DC17).

D1 notes (build 450):
- **Requests:** the pane menu (view name ▾) stays in content above the summary. Requests is a segment of the
  Discover tab, so a `.toolbarTitleMenu` would hang the pane switch off the title "Discover". Filter (with its
  count as a badge) and Inbox's Select / Done are toolbar items; Select stays horizontal (`axisBehavior`).
- **Calendar:** on a phone the filter menu (media type, iCal, week cards) is a toolbar item beside Today; wide
  layouts put iCal and week style in the overflow. Prev / next stay in content.
- **Activity:** Pause / Resume (admins) joined Manual import in the bar, disabled while in flight.
- **Library stats:** the bar badge is a count (titles needing attention, else missing) in place of the dot.
- **Account item:** a bitmap of the Plex photo / initials with the dot, as a `Label` image item, so the system
  treats it as a standard item for the vertical bar. Not yet seen on a device or the Duo simulator.
- **Add sheet:** search and request modes have the system Close; the configure step keeps `PreviewHero`'s own
  Back / Close (shared with the Preview sheet). Moving `PreviewHero` to the toolbar is a follow-up.
- **Sheets:** forms keep `.inline` titles (a medium detent can't spare a large title); their actions are title +
  symbol with fixed words, progress shown by `.disabled`. Close / Done-only sheets opt out of vertical bars
  (`closeOnlyBars()`, iOS 27.1).
- **Settings:** the cover and every pushed panel use `.inlineLarge`; the panel heading is now the subtitle only.
- **Duo folded landscape (owner, 2026-10-19: keep tabs):** iOS collapses Add + Account into "•••" above the
  tab bar even with `visibilityPriority` and a 28pt Account item (run 39331548937,
  `duo-folded-landscape-library.png`). The only lever is `toolbarVerticalCompressionBehavior(.prefersToolbarItems)`,
  which keeps the items at the cost of the tab bar. Owner chose to keep the tab bar; Add + Account stay under "•••" there.

- **Duo inner display (simulator report, run 39331548937):** a second integrated screen of 2007×2853 px @3x, i.e. **669×951 pt** (vs the 626×890 estimate). To confirm on a device before D2 layouts use it.
