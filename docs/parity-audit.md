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
| DU1 | Requests nav | `nav/usePhoneLayout.ts`, `ViewMenuPopover`, desktop `ViewHeader` pill, `FilterPanel` popover | always the drawer sheet, filter sheet and round button | Phone UI | visible · ✅ (build 502, D2a): wide, the view name is the desktop pill (glass; icon, name, chevron) with the subtitle on the same row, opening the drawer as a 280 popover; Filter stays the D1 toolbar item and opens the D4 popover, without Inbox's Cards \| List group |
| DU2 | Inbox | `requests/useTriageLayout.ts` (panes / stacked / deck) | deck or list | No queue + DecisionCard panes | visible · ✅ (build 502, D2a): `panes` wide (`Wide/InboxPanesView`): the queue (294–380, 320 at ≤1100) with a checkbox on every row and the focused row's accent ghost, the bulk bar under it, and the web's `InboxAside` beside it (`Wide/InboxAsideView`: poster, who and when, tiers and source, setup lines, scope, space or ownership note; Approve, Decline, Adjust, Details), Details opening the full decision card in a form sheet; focus starts on the first row and moves to the row that takes a decided one's place. No Select button wide |
| DU3 | Board | `RequestsBoard.tsx` (5 columns) | stage sections | Phone layout | visible · ✅ (build 502, D2a): five fixed-height columns (`Wide/BoardColumnsView`), ≥220 wide, sideways scroll with snapping when they don't fit (as the web); pinned head with dot, name, "N waiting", count; 4 / 3 rows then Show all, Load more, View all in History. The subtitle is the web's "N pending · M downloading" |
| DU4 | History (Requests) | `RequestsHistory.tsx` table | day groups | No table | visible · ✅ (build 502, D2a): Title · Who · Status · Ready in on the web's `2fr 1.2fr 130 80` tracks (`Wide/HistoryTableView`), pinned header, status as a coloured word |
| DU5 | Request thread, Issues, Threads | `RequestThread.tsx` right panel, `threads.module.css .split` | sheets | No side pane (Q-R8) | visible · ✅ (build 502, D2a): from Inbox, Board and History the thread is the web's right-hand panel over the view (`Wide/RequestThreadPane`, 460, or exactly the far side of a fold, dimmed backdrop, Close); Threads and Issues are the 390 \| pane split (290 at ≤960), first row selected (R8), the issue pane with Open in library in its head. Phone keeps the list and sheets; `RequestThreadSheet` keeps `formSheet()` only outside Requests |
| DU6 | Discover | `DiscoverBrowseControls` one row ≥721; `Rail.module.css` cell sizes; filter auto-fit; `RequestModal` two panes | stacked; fixed 116 cards | Phone layout | visible · ✅ (build 505, D2c): on the page's own width (`DiscoverWidthRule`): cells 116 / 128 / 158 at 540 / 720, lens + search + Add as on one row above 720, filters `auto-fit minmax(150, 1fr)` gap 12; the request modal is art 300 \| options above 720 of the sheet's width (see D2c notes) |
| DU7 | Manual Import | `useManualImportLayout.ts` (split ≤720 / table) | phone cards | Missing (Q-R4) | visible · ✅ (build 505, D2c): `ManualImportLayout` on the sheet's own size: cards (folded), split list \| file (≤720, split-capable), table above 720 (Audio and Group · service from 1100) |
| DU8 | Queue | `queue/duo/use-queue-duo.ts`, `QueueDuoPane.tsx` (list 294 \| card 375); the card's own 3-column grid ≥720 | tapping opens the title detail | No queue-card pane (Q-A2) | visible · ✅ (build 505, D2c): `QueueDuoRule` 44 \| 56 with `QueueDuoPane`; solo/pair cards open it with the i2 ring; the card's desktop grid at 720 of its own width (`QueueCardFrame`) |
| DU9 | Activity header, Tasks | single-row head and 3-up System grid ≥720 | phone | Only an iPad reaches 720 (Q-A1) | minor · ✅ (build 505, D2c): above 720 of the Activity pane (inner landscape, Q-DC3): one-row head (caption · search 200–340 · Resolve all held), Tasks System 3-up (`TaskSystemSection`) |
| DU10 | Library | `useIsMobile` 720: desktop toolbar, inline pulse ribbon, A–Z rail, letter headers | only the column count changes | Phone toolbar and scrubber (Q-L17) | visible · ✅ (build 511): past 720 of the Library's own width (`PaneWidthRule`): inline pulse ribbon, desktop toolbar, letter headers, A–Z rail; select bar is a system `.bottomBar` (Q-DC4). See D2b notes |
| DU11 | Calendar | `calendar/layout.ts` (own width: <720 phone, 720–999 tablet, ≥1000 desktop) | size class → desktop month grid | Wrong trigger; no tablet branch | visible · ✅ (build 511): `CalendarLayout.of(width:)` on the Calendar's own width; tablet = toolbar over the phone bodies, desktop = month grid, the time-band week timeline (stacked when the server says so), grouped lists; Book pose week = list (Q-DC5). See D2b notes |
| DU12 | Settings | sidebar 212 + panel ≥720 | `SettingsView.swift:31` size class | Wrong trigger (Q-S2) | visible |
| DU13 | Account panel | trailing panel of about 520 px ≥720 | centred sheet, 420 wide | Sheet | visible |
| DU14 | Shell | CapsuleNav + status cluster >720 | tab bar, no cluster | No cluster (Q-S3) | visible · ✅ (build 511): glass tab bar kept (deviation); Activity · Needs attention · Backend as system bar items past 900 of the tab's width (as the web), each opening the web's dropdown as a popover. See D2b notes |
| DU15 | Sign-in | hero beside the form ≥760; living art beside it ≥720 | stacked | Phone layout | visible · ✅ (build 511): `SignInLayoutRule` on the stage's width; in Book pose the columns meet at the fold, so the form keeps to one side. See D2b notes |
| DU16 | Settings panels | Metadata 2 columns, Plex rows, default profiles table, quality editor ≥820, custom formats 760/1100, import two panes, card grids auto-fill | stacked | Phone layout (Q-S5) | minor · ✅ (build 505, D2c) except Custom formats 760/1100 (☐, see D2c notes): Metadata provider cards one head row + cells 1fr \| 1fr, Hybrid fields 190 \| chain; Plex library rows evidence \| controls, "who gets 4K" auto-fill 210; Default profiles 3 × 2 table; quality editor Qualities \| Custom Formats above 820 of the (now page) sheet; Library import Sources rail 320 \| triage above 720; Instances 430 and Indexers 510 auto-fill |
| DU17 | Item detail | docked title uses the phone layout | ShellDetailColumn | **Matches** | — |
| DU18 | History, Blocklist, Wanted, Tasks | mobile below 720 (the inner display is about 669) | phone column | **Matches** today | — · Q-DC3 re-rules A1 for inner landscape (D2c, build 505): above 720 of the pane, History's group header and solo rows keep the trailing inline with "N events", Blocklist keeps its meta inline, Wanted's 4K card is two columns above the web's own 760, Tasks as DU9; inner portrait keeps the phone column |

**D2a notes (Requests wide, build 502; follow-ups build 522; triage keys build pending):**
- **Trigger:** the Requests pane's own measured width against 720 (`RequestsWideRule`, Discover's 16 pt margins added back), never the size class (L17/R4/S2). Inner portrait (669) and the Requests column beside an open title stay phone (Q-DC3). An iPad mini portrait (744) is wide.
- **Pane scrolling (D2a follow-up):** wide, Inbox, Board, History, Threads and Issues fill the height below the header (`RequestsViewportHeight`) and scroll inside their own panes; the Discover page then doesn't scroll at all (`requestsWidePageScroll`, set from `requestsFillsPage`), so there is no scroll inside a scroll. The web gets the same from `position: sticky` and fixed-height columns.
- **Inbox pane (D2a follow-up):** the web's `InboxAside` with the full `DecisionCard` behind Details, as 0.4.217.
- **Triage keys (built, web `useTriageKeys`):** on a hardware keyboard A approves and D declines through the usual 5 s Undo (A only on a decidable request: not your own as a non-admin, triage loaded, setup present; a low-space request needs a second A, as the button), J/K move the focus, X selects the focused row, Return opens its title. Wide panes get all six; the phone deck decides its top card and Return opens Details; "Select several" moves a focus ring (J/K scroll it into view in Discover's page scroll), and A/D open the card first (web L11); on the Details card A/D decide, J/K skip and Return opens the title. The phone swipe list has no keys (as the web's `InboxSwipeList`). Guards (`TriageKeysModifier`, pure rules in `FusionhaKit/TriageKeys`): only while the Inbox's focusable container itself has keyboard focus; never while a text field or text view is first responder; never while another sheet, popover, alert or dialog is presented above the one the view appeared under, or a menu is up; never while the Inbox's own sheets, the drawer, the filter or the thread panel are open; never with ⌘, ⌃ or ⌥ held, or on key repeat. The web's `DECIDE_LOCK_MS` decide lock (`FusionhaKit/DecideLock`, 350 ms) applies to keys, buttons and swipes alike: after a decision another is ignored for 350 ms, and nothing decides while a deck card is in flight. The menu guard looks up UIKit's private menu container by name and, if a release renames it, falls back to the presentation count.
- **Board rows (accepted):** no swipe to decide inside the sideways-scrolling board; Pending rows decide from the context menu (Approve, Decline…).
- **Fix on the way:** `ApproverRequestsView` rebuilt its menu only on appear, so when `me` arrived after the first frame an approver saw Mine only (visible in earlier `discover-05-requests` shots). The menu now follows the permissions.
- **Hinge:** with a top-to-bottom fold (active or not) the thread panel is exactly the far side of it (`TrailingPanelWidth`, HIG Duo checklist §6), so it never straddles the hinge. The Board, the Inbox panes, Threads/Issues and the History table now keep off the flat fold too (see "Fold gutter when flat" below).
- **Shots:** the mock serves `/api/v1/threads` (two request threads, three issue threads), so the Threads and Issues splits show real rows.

HIG Duo items from the apple-hig skill (`references/duo-checklist.md`) that the web doesn't cover:
- Keep the custom split edge and important controls off the hinge (`reservedRegion` / `ArrangementView`, iOS 27.1).
- Use even grid column counts.
- On the outer display, custom header rows don't move into the vertical system bar.

These were sent to fusionha as tensions (#55 reply), pending the owner.

**Fold gutter when flat (bug fixes in the Web-layout mode, branch `fold-gutter`):** lying flat, the Duo's fold is an inactive, zero-wide `.division`, and the layouts only avoided it when it was active (Book), so the web's widths put content on it. Whenever a top-to-bottom fold crosses a view (read with `reservedRegions(kind: .division, options: .includeInactive)`, `FoldInfo.verticalFold`), the view now keeps a 40 pt gutter on it (`FoldColumns.gutter`, 20 each side, the duo-designer kit's fold gutter); without a fold (iPad, other devices) the web's layout is unchanged. Maths in FusionhaKit (`FoldColumns`, `ShellSplitRule.foldSplit`) with unit tests.
- **Shell split:** `ShellSplitRule` still decides whether to split; flat open the split sits at the fold (tabs end 20 before it, the title column starts 20 after it) instead of the web's 418 \| 532. Book pose unchanged.
- **Requests Board (DU3):** with a fold the stages page instead of scrolling a column at a time: each page fills the space before the gutter (two stages of about 210 on the Duo), so at every resting position a page ends before the fold and the next starts after it. One `TrackLayout` in every pose (DC3). Deviation from the brief's "2 \| 3": the Duo's trailing side is about 360 wide (the system column), so three stages there would be about 110 wide.
- **Calendar month grid (DU11):** with a fold across the grid, the week splits into two groups around the gutter, equal widths in each, the split chosen so the two widths are closest (3 \| 4 on a centred fold, 4 \| 3 on the Duo, whose fold is right of the content's middle).
- **Inbox panes (DU2), Threads/Issues (DU5):** the queue / list ends at the fold, the aside / pane starts after it (`FoldPanes`), when both keep their minimums.
- **History table (DU4):** Title ends before the fold, Who starts after it.
- **Sign-in (DU15) and Setup:** `StageColumns` and `FoldSafe` use the flat fold with its gutter too, so the side-by-side columns meet at it and the centred card and the Setup wizard sit in one half.
- **Still on the fold flat (open)** (tracked per batch in "Duo Spread mode" below; the Library grid is fixed in S1, the rest of Library in S2, Discover / Search / Add in S3): Activity desktop head search with Resolve showing (`ActivityPageHeader.swift:28`); Activity tab strip (`Kit/ActTabs.swift:26`); Tasks System 3-up (`TaskSystemSection.swift:30`); wide queue card text (`QueueStateCard.swift:40`); Settings split panel (`SettingsView.swift:47`); Manual Import table (`MITableRow.swift:8`); Calendar tablet month (`CalendarMonthMobile.swift:31`).
- **Unverified:** CI cannot simulate a fold; the fold paths are compile- and unit-test-only until a Device Hub walk on the iPhone Duo simulator.

### Duo Spread mode (iOS-only, owner-approved 2026-10-20)

Open with a top-to-bottom fold (inner landscape, flat or Book), the app has two layouts, chosen per device:

- **Spread** (default): two pages split at the fold's real x (not the middle: on the Duo the fold is right of the content's middle because of the system column) with the 40 pt gutter, the left page ending 20 before the fold and the right page starting 20 after it. The tab is on the left page, the picked item on the right. Browse screens (Library now; Discover and Search in S3) span both pages until a title is picked, with the content in two fold-separated halves. Same web content and words; only the arrangement differs.
- **Web layout:** the web-parity wide layout as before, with the fold-gutter fixes.

**The switch:** a system toolbar button on every tab (`DuoLayoutToolbarItem`), shown only while a top-to-bottom fold exists, titled with the mode it switches to ("Spread" `rectangle.split.2x1` / "Web layout" `rectangle`); and Settings › Appearance › Theme › **iPhone Duo, open** (segmented Spread | Web layout). The Settings row is always listed, with a footer saying it only applies while an iPhone Duo is open, because Settings opens as a sheet that has no fold of its own to read. Stored in UserDefaults (`fusionha.duo.openLayout`, `DuoOpenLayout`); no server change.

**S1 status (infrastructure, branch `duo-spread-s1`):**
- ✅ Geometry in FusionhaKit with tests (`SpreadGeometry`, `PosterTracks`, `FoldColumns.split(leading:)`; `SpreadGeometryTests`).
- ✅ Shell: `SpreadContext` (`\.spread`) decides off / pages / span; the shell keeps the one `FoldSplitLayout`, so switching modes, folding and unfolding keep the tab, its scroll and the open title (DC3; the title's store is in `AppModel`). Toasts go to the right page while a tab spans.
- ✅ Extension points for S2–S6: screens read `@Environment(\.spread)` (`isActive`, `spans`, `pages`) to switch to their Spread layouts; browse screens call `.spreadSpansBothPages(tab, enabled)`; rows that span use `FoldSpanRow` (two pieces meeting at the gutter) and grids use `PosterTracks` + `TrackRowLayout`; each tab's right-page default goes in `SpreadRightPage` (S1: "Select a title" on every tab).
- ✅ Library (first user of the span): nothing picked, the grid is 3 posters a side with the gutter on the fold, the title and counts on the left page and the kinds, tier and filters on the right; picking a title moves the grid to the left page (3 columns, scrolled back to the same titles) and outlines the picked poster (`Theme.primary` ring). The compact list doesn't span.
- ✅ Review fixes: the Library's scroll thumb is hidden on a Spread's left page (its trailing edge is the fold gutter, and the thumb covered the last column); the detail's entrances (`RevealModifier`, `DetailHeroArt`) also start on first layout, after one harness shot showed a title column whose hero stayed transparent; the shell keeps one implicit animation (on the split).
- ✅ Duo screenshot harness (DEBUG only, `App/Debug/DuoHarness.swift`): the app inside a 951×669, 669×951 or 466×678 frame with the device kit's safe areas and a fake flat fold at x 475.5 (open), on a 13-inch iPad simulator, cropped to the frame (`scripts/duo_harness_shots.sh`, `duo-harness-*` shots). `FoldInfo.verticalFold` and `crossesMiddle` read the fake fold in the harness only; release builds compile it out.
- ✅ **S2 Library + title (branch `duo-spread-s2`):** the span follows the owner's mock (counts and filter field on the left page; kinds, All / HD / 4K, Filters and grid / list on the right, sitting on the grid; 3 posters a side). The pulse stays in the stats sheet in Spread (each page is phone-sized; the mock has no ribbon). The **compact list does not span**: it stays on the left page with "Select a title" on the right (a list row split across the fold makes the eye jump the gutter on every row; the right page is for the title). Web layout: the filter field ends at the gutter, the pulse ribbon is two cards of one height (pills and kinds | meters), the one-row toolbar is two pieces (Select, tier, recency | attention, Group, sort, grid / list, Display options, wrapping), the A–Z and status rules break at the gutter, and the compact table's rows split there (poster and title | versions, size, monitor, each piece with its own card edge). The grid skeleton uses the grid's fold tracks; `LibraryPane.foldMiddle` (the centred-fold `crossesMiddle` guess) is gone from Library. Maths: `LibraryFold` in FusionhaKit (`LibraryFoldTests`). Title page: the right page (377 pt) uses the phone detail as is (hero, title, HD / 4K version cards, seasons and episodes, item actions; checked in the harness), nothing in the gutter. Its sheets (interactive search, Edit, Add version, season actions, Delete, Rename, aliases, numbering, Manage files, Switch metadata, episode, Add collection, Report an issue, the movie file editor, request thread / broadcast, More like this preview, learn alias) open as **popovers hanging from the top of the title column** whenever the title is a column beside the fold (both layouts, flat or Book), sized to the column (`foldSafeSheet`, `App/Components/Spread/FoldSafeSheet.swift`); elsewhere they are the usual sheets.
- ✅ **S2 rework: Library layout A + the art-first title page (owner-approved 2026-10-23).** Library, content first, on the phone, the closed Duo and across the open Duo's spread: the large title is the bar's; Search (opens the library filter under the counts on demand, with This library / Everything), Select, Library stats and Add are bar items; one line "14 titles · 19 versions · 4 downloading" (the last in the grab colour, to Activity). The page filters sit on their own rows under it: one kind segment ("All 14 · Movies 5 · Series 4 · Anime 5", a dot per kind, the count dim, the proportional make-up bar along its bottom edge under the kinds; Animation joins only when present) replacing the four-row kinds block, then All / HD / 4K, the attention chip when any, Filters and one grid ⇄ list round button. **Recently added** follows the filters (hides when they leave nothing): 16:9 backdrops on a glow of their own art, title, "Added today / yesterday / N days ago" and the version chips; a sideways strip on phone-sized pages (the next card peeks), two a page with the fold in the gutter across the spread; See all sorts the grid newest first. **All titles**: 3 posters across (3 a page on the open Duo), each on a soft glow of its own art, only the 4K flag on the art, 14pt semibold title, "2013 · Anime", and **version chips** in place of the rails (tier colour on a tinted ground, a status dot through `EditionStatus.color`, a label only while moving: 3/5, 30%, ↓, ↑, ! for attention). Spread header: counts on the left page, then the kind segment on the left page and quality · Filters · grid ⇄ list on the right page on one line. Motion: shelf cards land with a 0.35 s spring, staggered, crossfade under Reduce Motion. The Web layout keeps the desktop Library (unchanged). Logic: `EditionChipLabel`, `RecentShelf`, `KindMix` in FusionhaKit (`LibraryShelfTests`). **Title page**, all palettes: the hero prefers the textless backdrop (the poster's printed logo was the ghost title), the art stays at full strength, only its edges darken (bottom scrim for a white title, status and meta; a light shade under the bar), tagline / genres / requester sit under the art, and the page takes the web's ambient scrim (78 / 62 / 50 %, tempered in dark themes, bright in Daylight, so never grey fog). On the open Duo the art runs on under the system column.
- ☐ **Title gatefold (full-spread title) — decided, not built in S2.** In Spread the Library keeps the left page, so a title opened from it is the right page, and that page is the phone detail with the new art (no gatefold). The gatefold applies only when a title fills the spread (no list to keep on the left): parent / child = ONE parent header across both pages (display title left, the right half art with at most one light element), both pages start on one line below it, the child on the right under a section label ("Season 2 · Episode 2", ~22 pt semibold, no art); siblings (HD page | 4K page) line up row for row. No screen opens a title across the whole spread today; it lands with the batch that adds one (episodes on the right page, S5 Calendar / S3 Search).
- ☐ Per-screen Spread designs: ✅ S3 Discover / Search / Add (branch `duo-spread-s3`, below; unified search on `duo-spread-s3-search`), S4 Requests, S5 Calendar + Activity, S6 Settings / Account / Sign-in / Manual Import.

**Fold-crosser tracker (either mode: nothing on the fold).** Each screen is fixed in both Spread and the Web layout, with a test per screen for both modes (the geometry in FusionhaKit, Duo numbers: an 849 pt shell with the fold at 451.5), and checked in the `duo-harness-*` shots.

| Fold-crosser | Where | Batch | Spread | Web layout | Tests |
|---|---|---|---|---|---|
| Library grid | `LibraryView.swift`, `LibraryRows.swift` (`LibraryGridRow`) | S1 | ✅ 3 a side, gutter on the fold | ✅ the usual count split around the real fold (`PosterTracks`; the old even-count rule assumed a centred fold) | ✅ `testLibrarySpanIsThreeASideWithTheGutterOnTheFold`, `testLibraryWebLayoutKeepsItsCountAndClearsTheFold` |
| Library pulse ribbon (one card) | `LibraryPulseRibbon.swift` | S2 | ✅ not shown (the stats sheet, as on the phone; the mock has none) | ✅ two cards of one height at the gutter (`FoldSplit`) | ✅ `testWebLayoutPulseRibbonIsTwoCardsAtTheGutter`, `testBookPoseKeepsTheActiveFoldAndItsGutterEmpty` |
| Library filter field, wide header (one field across the page) | `LibraryHeader.swift` | S2 | ✅ left page (span half) | ✅ ends at the gutter (`foldLeadingPane`) | ✅ `testWebLayoutFilterFieldStopsBeforeTheFold`, `testSpreadSpanPiecesNeverHaveTheFoldInside` |
| Shell tab bar on a regular-width spanning tab (iPad-style top bar, centred over both pages; seen in the harness) | `RootView.swift` | S2 | ☐ **needs a Duo:** no API places the regular-width tab bar (no leading pin, no width of its own); hosting the `TabView` in the left page would take the spanning grid with it. On the Duo, iOS 27.1 moves the tab bar into the vertical bar in landscape, which the iPad harness can't show | ☐ same | ☐ |
| Downloads bar (`.tabViewBottomAccessory`, build 545) on a spanning tab: full width across both pages in the harness; on the left page when a title is open | `RootView.swift`, `DownloadsBarSlot` | S2 | ✅ hidden while the tabs run across the fold (a span); back on the left page once a title is picked; the Activity badge still counts. It can't be narrowed (system-hosted, no width of its own) | ✅ hidden with nothing open (the tabs fill the shell), back beside an open title | ✅ `testDownloadsBarHidesOnlyWhileTheTabsRunAcrossTheFold` |
| Library desktop toolbar, one-row variant | `LibraryToolbarWide.swift` | S2 | ✅ not shown (phone row on the right page) | ✅ two pieces at the gutter, the trailing one wrapping (`FoldSplit`) | ✅ `testWebLayoutToolbarSplitsSoGroupStatusNeverSitsOnTheFold` |
| Library A–Z letter and status-group rules (hairlines across the content) | `LibraryRows.swift` | S2 | ✅ not shown (phone grid) | ✅ broken at the gutter (`foldGapMask`) | ✅ `testWebLayoutHeaderRulesBreakAtTheGutter` |
| Library compact list (table rows across the page) | `LibraryTable.swift` | S2 | ✅ doesn't span: left page, "Select a title" on the right | ✅ rows split at the gutter, two card edges | ✅ `testWebLayoutCompactTableRowsSplitAtTheFold`, `testSpreadWithATitleKeepsTheLibraryOnTheLeftPageAsThePhone` |
| Library `crossesMiddle` (centred-fold guess: column count, skeleton) | `LibraryView.swift`, `LibraryRows.swift` | S2 | ✅ gone: the grid and its skeleton use the real fold's tracks | ✅ same | ✅ `testSpreadSpanPiecesNeverHaveTheFoldInside` (S1 grid tests) |
| Sheets from the title (window-centred form sheets land on the fold) | `DetailChildSheets.swift` and the detail's own sheets | S2 | ✅ popovers hanging from the title column (`foldSafeSheet`) | ✅ same (the Web layout's title column) | harness `duo-harness-open-*-title-{search,edit}` (presentation, not maths) |
| Library header and page filters (layout A: counts, kind segment, quality · Filters · grid ⇄ list) | `LibraryPageTop.swift`, `LibraryKindSegment.swift` | S2 | ✅ counts on the left page; kind segment left, the control row right, one line (`FoldSpanRow`) | ✅ not shown (desktop toolbar, above) | ✅ `FoldSpanRow` panes (S1 `testSpreadSpanPiecesNeverHaveTheFoldInside`); harness `duo-harness-open-spread-library*` |
| Library Recently added shelf (a sideways strip would run across the fold) | `LibraryRecentShelf.swift` | S2 | ✅ two cards a page, no sideways scroll, See all on the right page | ✅ not shown (desktop Library) | ✅ `LibraryShelfTests` (content) + `FoldSpanRow` panes; harness |
| Title hero art under the system column (open Duo) | `DetailHeroArt.swift` | S2 | ✅ art ignores the horizontal safe area; text stays inside it | ✅ same | ☐ **needs a Duo** (the harness has no column) |
| Sheets from the left page and the shell (Library stats and Filters, poster long-press sheet, Add, Account, Delete title) | `LibraryHeader.swift`, `LibraryView.swift`, `RootView.swift` | S6 | ☐ still window-centred | ☐ same | ☐ |
| Small popovers in the title (episode status, file parts, season bar tips) anchored near the column's leading edge | `DetailEpisodeStatus.swift`, `DetailMovieFileParts.swift`, `DetailSeasonBars.swift` | S6 | ☐ UIKit may centre a wide one over the gutter; verify on a Duo | ☐ same | ☐ |
| Discover one-row controls | `DiscoverBrowseControls.swift` | S3 | ✅ spanning: the controls on the left page, Browse \| Requests on the right (`FoldSpanRow`); a title open: stacked on the left page | ✅ the row splits at the fold: the lens before it, search + Add as after it (`DiscoverFold.controls`), stacked when a side is too narrow | ✅ `testWebLayoutSplitsTheOneRowControlsAtTheFold`, `testSpreadKeepsTheControlsStackedOnTheLeftPage`, `testNoFoldKeepsTheWebRow` |
| Discover results and filters (`crossesMiddle`) | `PosterGrid.swift` (`AdaptivePosterGrid`), `DiscoverFiltersPanel.swift` | S3 | ✅ results 6 across, 3 a side (Trending too, as a grid); filters: as many 150+ fields as fit each side, header split heading \| actions, no card across the fold | ✅ the usual count split around the real fold (`PosterTracks`), filter fields per side (`DiscoverFold.fieldTracks`) | ✅ `testSpreadResultsAreSixAcrossThreeASide`, `testWebLayoutResultsSplitAroundTheOffCentreFold`, `testFilterFieldsFitEachSideOfTheFold` |
| Discover rails (Trending, Popular, Upcoming, trailers, collections, Letterboxd) | `RailTrack.swift` | S3 | ✅ cards sized for one page, in pages that end at the fold's gutter, scrolling a page at a time (3 a page; trailers 1) | ✅ same pages around the fold, the card count nearest the web's 158 (3 of ~129); Letterboxd's fixed 134s 2 a page | ✅ `testWebLayoutRailsRestAPageEachSideOfTheFold`, `testSpreadRailsHoldThreeAPage`, `testRailsWithoutAFoldScrollAsUsual` |
| Discover / Search preview sheet (centred form sheet on the fold) | `SpreadPreview.swift`, `PreviewView.swift` | S3 | ✅ the preview opens on the right page (`AppModel.spreadPreview`), the grid moves to the left page with the title outlined; folding back reopens it as the sheet | ✅ page cover on the right page (`duoPageSheet`) | ✅ `testModalsSitOnTheRightPageOrSplitAtTheFold` |
| Request modal options | `RequestModal.swift` | S3 | ✅ full-window page cover: art + summary on the left page, versions, note and footer on the right (`DiscoverFold.requestPanes`) | ✅ same | ✅ `testRequestModalPutsTheTitleLeftAndTheOptionsRight`, `testModalsSitOnTheRightPageOrSplitAtTheFold` |
| Add sheet, trailer, collection (centred form sheets) | `DuoPageSheet.swift`, `RootView.swift` | S3 | ✅ on the right page over the dimmed app | ✅ same | ✅ `testModalsSitOnTheRightPageOrSplitAtTheFold`, `testThePreviewTrailerFitsTheRightPage` |
| Search results (one list across the fold) | `Screens/Search/SearchTabView.swift`, `SearchResults.swift`, `SearchBeforeTyping.swift` | S3 | ✅ unified search: a term keeps the rows on the left page, the tapped result's preview on the right page (the kind filter on the right page while nothing is open); before you type, Trending spans both pages, 3 a page (`AdaptivePosterGrid`) | ✅ the list on the leading side of the fold (`.foldLeadingColumn`) | ✅ Trending shares `testSpreadResultsAreSixAcrossThreeASide`; harness `duo-harness-*-search-*` |
| Activity tab strip | `Activity/Kit/ActTabs.swift` | S5 | ☐ | ☐ | ☐ |
| Activity desktop head search (Resolve showing) | `ActivityPageHeader.swift` | S5 | ☐ | ☐ | ☐ |
| Tasks System 3-up | `TaskSystemSection.swift` | S5 | ☐ | ☐ | ☐ |
| Wide queue card text | `QueueStateCard.swift` | S5 | ☐ | ☐ | ☐ |
| Calendar tablet month | `CalendarMonthMobile.swift` | S5 | ☐ | ☐ | ☐ |
| Settings split panel | `SettingsView.swift` | S6 | ☐ | ☐ | ☐ |
| Manual Import table | `ManualImport/MITableRow.swift` | S6 | ☐ | ☐ | ☐ |

**Unverifiable without a Duo:** where iOS 27.1 places the tab bar and the toolbar switch on the real inner display (the harness runs on an iPad, whose regular-width tab bar sits at the top, centred over the whole spanning tab); the real fold x and safe areas (the harness uses the device kit's 475.5 and 22 / 24 / 22 / 78); whether `reservedRegions` reports the inactive fold inside a scroll view's content as it does for the shell; the Book pose's active fold width.

**S3 status (Discover, Search, Add / Request; branch `duo-spread-s3`):** Discover › Browse and Search span both pages until a title is picked; the preview then opens on the right page (`spreadPreviewHost`, `SpreadPreviewColumn`) with the grid on the left page and the picked card outlined. Modals that iOS would centre on the fold present as page covers while a top-to-bottom fold exists, in either mode (`duoPageSheet`: the right page, or both pages for the request modal). The geometry is `DiscoverFold` (tests in `DiscoverFoldTests`). Also fixed on the way: a poster card whose art isn't 2:3 (Attack on Titan) no longer widens its column in the Library and Search grids (`PosterCard`), and a Discover card's meta line wraps its marks in a narrow column. Discover › Requests is S4. Needs a Duo: where the Search tab's system search field sits, and whether a full-screen cover's clear background and `reservedRegions` inside the cover and inside scroll content behave as in the harness; the loading skeleton rails are not paged (they show briefly).

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
- The downloads bar (tab-bar bottom accessory, `downloads-bar` branch): the web has nothing like it; recorded in ui-plan §2. Duo vertical-bar placement is an open item (ui-plan "iPhone Duo")

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
| **D4 Sheets & popovers** | `presentationSizing(.form)` where ruled. Popovers for the Requests drawer and filter when wide. Detents that fit outer landscape (466 pt tall). Scrollable confirm dialogs. ✅ (build 483): see D4 notes |
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
| DC10 | Item detail sheet Close, Add sheet, Request modal, trailer | outer | Custom ✕ overlays and hidden nav bars (`DetailHero.swift:37`, `AddTitleSheet.swift:64,105`, `RequestModal.swift:55`, `TrailerPlayer.swift:46`) | D1/D4 · ✅ (build 483): the last one, the Add configure step, now has system Close + Back to search (`AddConfigView` toolbar); PreviewHero's buttons are optional and the hand-built compact bar is gone (the bar takes the title past the hero) |
| DC11 | Search tab | outer | No `NavigationStack`, so `.searchable` never hosted the field; it is a custom docked field (`SearchTabView.swift:42-118`). Retry `.searchable`. | D1 |
| DC12 | Sheets with text-only or state-swapping bar buttons | vertical bars | About 25 sheets in Activity, Manual Import, Account, Settings, Issues and Requests (listed in the audit pass) | D1 |
| DC13 | Tab bar · inner portrait, title open | inner portrait | The 560/360 rule leaves a 265 pt leading column (`DuoLayout.swift:119-125`), narrower than any iPhone | D2 (Q-DC3) · ✅ (build 511): `ShellSplitRule` never splits a portrait-shaped window; inner portrait keeps the bottom tab bar and the title opens as the phone sheet (same parked `DetailStore`, DC3) |
| DC14 | Toasts | inner Book/split | Overlay on the whole split, up to 420 wide (`RootView.swift:43-46`, `Toast.swift:52`), so it straddles the fold | D3 · ✅ (build 479): `ToastLayer` (`Shell/ToastPlacement.swift`) puts them on the trailing column whenever the shell splits (Book pose or the web's wide split; the lower half for a side-to-side fold); folded they clear the tab bar by its measured safe area. Sign-in and the Settings cover use `FoldToastLayer` (trailing side of an active fold). D5 ✅ (build 488): with Settings split flat open, its toasts sit on the panel pane (`FoldToastLayer(pane:)` / `ToastRegion.trailing(_:pane:)`) |
| DC15 | Calendar month | inner split | `sizeClass == .regular` puts the desktop month grid in a 265/391 pt column (`CalendarView.swift:12,184`) | D2 · ✅ (build 511): the month grid only at ≥1000 of the Calendar's own width (DU11) |
| DC16 | Settings | inner portrait + fold/rotation | Size-class split at 626 (ruling S2 says 720). `if wide {SplitView} else {Stack}` rebuilds the list and the open panel, losing scroll, focus and half-typed fields (`SettingsView.swift:31-57`) | D2/D5 · D5 part ✅ (build 488): one `NavigationSplitView` in every pose; it collapses into the phone's push list (`preferredCompactColumn`) and expands again, so the list's scroll and the open panel (focus, typing) stay. The split follows Settings' own width at 720 (`SettingsSplitRule`, ruling S2) by handing the split view that size class; the sidebar uses compact labels (icon + title) and marks the open panel. Deviation: on iPhone Duo's inner display in portrait (669) Settings is now the phone list, and a phone held sideways (874) splits |
| DC17 | Sign-in, Setup | inner Book | The centred card sits across the hinge (`SignInView.swift:117`, `SetupWizardView.swift:43`) | D3 · ✅ verified (F2, build 460): all three sign-in stages and the setup wizard lay out inside `FoldSafe`, the larger side of the fold; D3 adds their toasts on the trailing side |
| DC18 | Sign-in | outer | `.ignoresSafeArea(.container)` covers the form, so it runs under the trailing strip (`SignInView.swift:151,194`) | D3 · ✅ verified (F2, build 460): only the backdrops ignore the safe area; the split/living stages ignore the top edge only, so the form keeps clear of the side strip |
| DC19 | Account panel | inner landscape | A default sheet capped at 420 (`AccountView.swift:29`); the web uses a ~520 trailing panel | D4 · ✅ (build 483): `AccountSheet` is a form sheet unfolded (`formSheet()`); centred, not trailing (deviation, see D4 notes) |
| DC20 | Activity confirm dialogs; Add user; Move credential | outer landscape (466 tall) | Non-scrolling dialog at `.medium` (`ActToaster.swift:107-139`); `.medium`-only detents with the keyboard (`UserEditorSheet.swift:152`, `MoveCredentialSheet.swift:48`) | D4/D5 · ✅ (builds 483/488): `ActDialog` scrolls its words and options with Cancel / the action pinned, at `[.mediumFitting, .large]`; Add user and Move credential are `[.mediumFitting, .large]` |
| DC21 | Requests drawer/filter; Library filters; Issues sheets | inner | Height detents are ignored at regular width; the web uses popovers or modals | D4 · ✅ (build 483): drawer, Filter and Library Filters open from their controls via `sheetPopover` (popover wide, phone sheet compact); report an issue, both issue threads and the rule editor are form sheets (R7) |
| DC22 | Manual Import | inner | A default form sheet with phone cards; the web is split on the open Duo | D2/D4 · D4 part ✅ (build 483): page-sized sheet (`presentationSizing(.page)`); the split layout stays with D2 |
| DC23 | Inner layouts | inner | DU1–DU16 (Requests panes, Board, History table, thread/issue panes, Discover wide, Queue card pane, Library desktop, Calendar tablet/desktop, Settings, Account, sign-in side by side) | D2 |
| DC24 | Account panel (D4 follow-up) | inner | A centred form sheet (DC19 deviation) | Account panel → trailing placement (web ~520 right panel) once the iOS 27.1 `preferredPlacement` API is confirmed · ☐ |

**Minor** (folded into the batches above):
- Toast 72 pt and page-bottom 90/190 constants (D3) · ✅ (build 479): the shell's toasts clear the tab bar's measured top (`ToastAnchor`, from each tab's safe area); Library, Discover, Wanted and Activity pages end with `Theme.pageBottom` (24) since the tab bar and bulk bars are already in the scroll view's safe area. Unused `Theme.bottomNavClearance` removed
- `StatusBarFade` on the outer display (D3) · ✅ removed in D1
- Odd poster-grid columns across an inactive fold (D3) · ✅ (build 479): `FoldInfo.crossesMiddle` reads `.division` regions with `.includeInactive`; when the fold runs through a grid's middle, `PosterColumns` drops an odd count by one (Library grid and every `AdaptivePosterGrid`), so the fold lands in the centre gutter
- Detail hero minimum 360 in outer landscape (D3) · ✅ (build 479): the 360 floor gives way to 60% of the container (`DetailHeroArt.height(for:)`, 280pt at 466 tall); phones unchanged. Deviation beyond the row: the Preview hero's 430 floor gives way to 75% the same way
- Toasts over bottom bars (D4 ruling, in D5) · ✅ (build 488): a bottom bar reports its top with `publishesBottomBarTop(_:)` (`ToastAnchor.barTops`), and toasts sit above the higher of it and the tab bar (`ToastAnchor.floor`): Library select, Activity bulk, and in the Settings cover (its own anchor) Custom formats' bulk bar. The Requests Inbox bulk bar scrolls with the list (not a bottom bar), so it doesn't report
- Tab badge tint not refreshed on bar-axis change (D5) · ✅ (build 488): `TabBadgeTint`'s key carries the shell's size and split, and it re-applies once more after the resize settles (450 ms)
- Activity chip strip not scrolled to the selection (D5) · ✅ (build 488): `ActTabs` (own file now) scrolls the selected tab to the centre on appear, on change and when the strip's width changes (`ScrollViewReader`)
- Search focus not restored (D5) · ✅ (build 488): `keepsFocusAcrossResize` (`Components/FocusAcrossResize.swift`) re-focuses the Search tab's field after a width change (measured without the keyboard) when it was focused, or lost focus within 0.8 s of it
- Idle tile grid leaves an orphan row and starts at a 390 seed (D2) · ✅ (build 505, D2c): no seed (draws once measured); `IdleLayout.balancedTileColumns` shows 5 tiles as 3 + 2 where the web's auto-fit leaves 4 + 1 (deviation)
- Import report 3+2 (D2) · ✅ (build 505, D2c): the web's flex-wrap, `min-width: 116` gap 12 (`StretchWrapLayout`), so it can be 4 + 2 like the web
- Sync count grid at narrow widths (D2) · ✅ (build 505, D2c): one row while every label fits, else balanced rows (deviation: the web keeps one row and truncates)
- The Settings `.principal` clear view (D1)
- `ellipsis` menus (D1) · Manual Import ✅ (build 488, D5): Status key is a system item, Open on the web is `.secondaryAction` (system overflow). `ImportWorkspaceSheet` ✅ (build 505, D2c): Rescan all is a system item, Discard is `.secondaryAction`
- Account hub opens at `.medium` in outer landscape (D4) · ✅ (build 483): `.mediumFitting` (whole height when the sheet's room is under 520 pt)
- One-item sheets: vertical-bar opt-out (Q-DC6) · ✅ (build 483): `closeOnlyBars()` on the 17 Close/Done-only sheets D1 missed (list in D4 notes)

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
- **Q-DC10:** fix CLAUDE.md's stale "downloads accessory" line (with the owner's OK, since CLAUDE.md is project config). *Superseded 2026-10-20:* the downloads bar now exists (approved mock), so CLAUDE.md's line is accurate again and stays as it is.
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
| Requests | pane menu (title ▾), filter, avatar | title menu via `.toolbarTitleMenu` · `.primaryAction` Filter · Account | summary line, pills | ✅ D1 (build 450; pane menu stays in content, see notes) |
| Activity | Manual import, avatar | `.primaryAction` Manual import · Account | Queue/History/Blocklist/Tasks segmented | ✅ build 450 |
| Calendar | ‹ Today ›, iCal menu (admin), week style (week view), avatar | `.primaryAction` Today · `.secondaryAction` iCal, week style · Account | prev/next capsule, kind chips | ✅ build 450 |
| Wanted | Add (+) | `.primaryAction` Add · Account | summary line, tabs | ✅ build 450 |
| Search | avatar | Account; retry `.searchable` (DC11) | results | ✅ build 450 |
| You | avatar | Account | hub rows | ✅ build 450 |
| Settings (cover) | Close | `.cancellationAction` Close (system) | subtitle "DB-backed · effective without restart" | ✅ build 450 |
| Item detail sheet | custom ✕ (DC10) | `.cancellationAction` Close; hero stays clean | hero, edition chips | ✅ build 450 |
| Add / Request modal / trailer | custom ✕ (DC10) | `.cancellationAction` Close | — | ✅ D1 build 450; Add configure step ✅ D4 (build 483) |
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
| F2c | Living fusion moves from web 0.4.224: fusionMedia (clapper × TV) and fusionQuality (HD × 4K), in the rotation by the web's `buildMoveOrder` (minus F2b's moves) with the no-same-object-neighbour rule; painters shared with the `tv` and `quality` moves. See fusionha-sync.md, 0.4.224 | ✅ branch `living-fusion` |
| F3 | Episode sheet's Search tab: park its `InteractiveSearchModel` across fold/unfold (DC3: no lost state) | ✅ build 455 |
| F4 | Activity, Calendar and sign-in toasts on `model.toast`, so Q-DC9 hinge placement applies everywhere | ✅ build 455: Activity + Wanted through `ActToaster.shell`, Calendar direct; sign-in already used it; sheets keep `CalToast` (now `Components/SheetToast.swift`) |
| F5 | Split oversized files to ~300–400 lines: `AppModel` (665), `ScreenModels` (619), `DiscoverModels` (530), `DetailLogic` (481), `CalendarModels` (456), `EditItemSheet` (335) | ✅ build 464: all six under 400 (AppModel 381: rest writes `private(set)` state) |
| F6 | Next oversized files (>400). Part 1 ✅ build 474: `SettingsFetchingModels`, `AddFlowLogic`, `ActivityModels`, `DetailModels`, `ThreadLogic`, `PerfProbe` all under 320. Part 2 ✅ (f6b-split): `AddFlow` 550→316 (+ `AddPick`, `AddFlowTypes`, `AddFlow+Derived/Defaults/Timeline/Payload`), `SystemTasksPanel` 422→188 (+ `SystemTaskRow`, `SystemCommandsStrip`, `SystemTaskFormat`), `PreviewView` 415→303 (+ `PreviewSimilarRail`, `PreviewCastCard`, `PreviewSkeleton`, `PreviewFlow`), `SetupProgressPill` 393→205 (+ `SetupProgress`, `SetupRing`, `SetupProgressIcons`), `PublicAccessPanel` 384→141 (+ `DemoConfigSheet`), `FetchingKit` 370→280 (+ `FetchToaster`), `AddTierCards` 362→150 (+ `AddAvailRow`, `AddFourKRow`). `AddConfigView` already 306. No Swift file over 400 | ✅ |

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
  Back / Close (shared with the Preview sheet). Moving `PreviewHero` to the toolbar is a follow-up. *(Done in D4
  for the configure step; the Preview sheet's own hero buttons are unchanged.)*
- **Sheets:** forms keep `.inline` titles (a medium detent can't spare a large title); their actions are title +
  symbol with fixed words, progress shown by `.disabled`. Close / Done-only sheets opt out of vertical bars
  (`closeOnlyBars()`, iOS 27.1).
- **Settings:** the cover and every pushed panel use `.inlineLarge`; the panel heading is now the subtitle only.
- **Duo folded landscape (owner, 2026-10-19: keep tabs):** iOS collapses Add + Account into "•••" above the
  tab bar even with `visibilityPriority` and a 28pt Account item (run 39331548937,
  `duo-folded-landscape-library.png`). The only lever is `toolbarVerticalCompressionBehavior(.prefersToolbarItems)`,
  which keeps the items at the cost of the tab bar. Owner chose to keep the tab bar; Add + Account stay under "•••" there.

- **Duo inner display (simulator report, run 39331548937):** a second integrated screen of 2007×2853 px @3x, i.e. **669×951 pt** (vs the 626×890 estimate). To confirm on a device before D2 layouts use it.

D2b notes (build 511; follow-ups build 516; Library, Calendar, shell, sign-in unfolded):
- **DC13 / Q-DC3, shell split.** `ShellSplitRule.splits` now also needs `width > height`, so inner portrait (669×951) and the iPad mini stand-in in portrait (744×1133) keep the bottom tab bar. **Picked: the phone sheet** for the title in portrait, not a full-width push: the sheet already re-hosts the `DetailStore` parked in `AppModel` with its child sheets and drafts (DC3), and rotating to landscape moves the same store into the trailing column; a push would need a second host inside each tab's stack. Inner landscape (951) still splits (title column 532, tabs 418); with no title open the tabs get the full 951, so screens there take their desktop layouts above 720. Book pose is unchanged (columns meet at the fold). The side-to-side fold stays out of scope (Q-DC7). **Follow-up (D2b2, ruled):** a landscape split also needs the tab's pane beside the title to keep `ShellSplitRule.primaryMin` (360); `primaryWidth(for:)` = width − title column − hairline, so landscape splits from 821 (inner 951 leaves 417) and anything narrower opens the title as the phone sheet, as in portrait. Tested in `ShellSplitRuleTests`.
- **DU10, Library.** One rule in FusionhaKit, `PaneWidthRule.isWide` (> 720, the web's `max-width: 720px`), on the Library scroll's own width (L17). Wide: the pulse ribbon (one solid card: stat pills 1.15 : 1 beside the health, 4K coverage and On disk meters, then the kinds row; `LibraryPulseRibbon`, pills and meters shared with the stats sheet in `LibraryPulseParts`), the desktop toolbar (`LibraryToolbarWide`: Select, tier, recency, Needs attention, Group: Status, a native sort menu, grid / list, Display options popover with the coverage-rail controls), letter headers (`LibraryLetterHeader`, letter · hairline · count) and the A–Z rail (`LibraryAlphaRail`, a 34pt column via `safeAreaInset(edge: .trailing)`, tap or drag to jump, scroll-spy highlight). The "Library stats" bar item is dropped when wide (the pulse is inline and the status cluster holds In progress and Needs attention, as on the web's desktop). **Deviations:** the search stays the header's filter field (the web puts it in the toolbar row); letter headers scroll in-flow, not sticky; the ribbon has no kind-tinted corner wash (a gradient). With a title open in inner landscape the Library column is 418, so it stays the phone layout there.
- **Q-DC4, select bar.** `LibrarySelectBar`: a `ToolbarItemGroup(placement: .bottomBar)` while selecting (the tab bar steps aside): **Selection** menu ("N selected · of M filtered", Select all N, Clear), **Actions** menu with the count as its badge (Monitor, Unmonitor, Refresh & Scan, Quality Profile ›, Minimum availability ›, Change root…, Delete), **Done**. Toasts: the bar sits in the tab's safe area, so `ToastAnchor.tabSafeBottom` already clears it (the old custom bar's `publishesBottomBarTop` is gone with it). **Follow-up (D2b2, ruled):** the web's "N selected" is a plain text item centred between the Selection menu and the Actions / Done group (`ToolbarSpacer` either side, shared glass hidden, numeric content transition off under Reduce Motion); the Actions badge is dropped as a duplicate. Checked on `library-shell-select`.
- **DU11 / DC15 / Q-DC5, Calendar.** `CalendarLayout.of(width:)` (`layout.ts`: <720 phone, 720–999 tablet, ≥1000 desktop) on the Calendar's own width; the size class is no longer read. Phone: as before. Tablet: the wide toolbar (subline, view switcher, ‹ › + kind chips, legends) over the phone bodies (Month dots + day panel, WeekMobile without the collapsing header, the phone day lists); the swipe steps any view with ‹ ›. Desktop: the month grid, seven week columns (`WeekColumnsView`), grouped Agenda / Forecast / Day lists, no swipe. Book pose (`\.bookPose`, set by the shell from `FoldInfo`): the week is the day list (every day of the week). **Follow-up (D2b2, ruled):** the desktop week is the web's timeline (`WeekTimelineView`): a 56pt gutter (12a Early, 6a Day, 5p Prime, 9p Late) beside seven equal columns, bands aligned across the week at the web's minimum heights, cards in the band of their local air hour (season drops by their first episode), today tinted, the now line spliced between aired and upcoming in the current band (`CalendarBand`, `WeekBandCell` in FusionhaKit, tested in `CalendarWeekBandsTests`). The server's `calendar_week_layout = stacked` keeps the stacked columns (`WeekLayout.resolve`; the field is newer than the pinned spec, read as optional, not written). Below 1000 nothing changes. **Deviations:** the web floors columns at 140 and scrolls; iOS shares the width (about 129 a column at 1000). Forecast at desktop width is the grouped list, not the web's `ForecastBoard`. iPhone Duo never reaches 1000 (951 at most), so desktop is iPad-only.
- **DU14 / S3, status cluster.** `StatusClusterRule.shows` (> 720 of the tab page's own width, not request-scoped). Three standard bar items before Account (title + symbol, `.badge` counts, so iOS can still move them into a vertical bar): **Activity** (in-progress count; popover: In progress + View all activity), **Needs attention** (the shell's attention count; popover: the stats sheet's attention rows and actions, `StatsAttentionActions`), **Backend** (cloud symbol by `/health`; popover: the connection line). `ShellStatusFeed` refreshes `/health` and the stats feed every 5 s while a cluster is on screen. **Follow-up (D2b2, ruled):** shown only above 900 (`StatusClusterRule.minWidth`), as the web, so inner landscape (951) with no title open has it and everything 721–900 does not. The HUD / bracket tray look is not drawn (system items).
- **DU15, sign-in.** `SignInLayoutRule`: split > 760 (hero 1.05 : form 0.95), Living > 720 (art 1.1 : form 1, hairline on the form's leading edge), measured on the stage. `StageColumns` puts the columns at the fold in Book pose (the fold itself left empty), so the form is always on one side; stacked stages still use `FoldSafe`. `LivingMark` is unchanged (60 Hz timeline, `drawingGroup`, frame-time canvases); it is only placed in a column. The split hero's `#0b0d13` is now one constant (`SplitPanelFill.heroGround`).
- **Shots:** `duo_proxy.sh` adds Calendar month / week and sign-in split / living per orientation; `duo_shots.sh` adds Calendar week per pose. Sign-in gets the landscape DEBUG hook (the shell's doesn't run signed out).

D4 notes (build 483):
- **Helpers** (`App/Components/SheetSizing.swift`): `.mediumFitting` (a custom detent: the whole height when the
  sheet's room is under 520 pt, else half, so phones held upright are unchanged), `formSheet()` and
  `sheetPopover` (`.popover` + `presentationCompactAdaptation(horizontal: .sheet, vertical: .sheet)`, ideal
  width/height for the popover only).
- **Popovers (DC21):** the Requests drawer and Filter moved from `ApproverRequestsView` onto their controls in
  `RequestsViewHeader` (the drawer's figures went with it, `RequestsDrawer`); Library's Filters onto the chip in
  `LibraryToolbar`. The filter sheet's icon-only ✕ became `SheetCancelButton("Close")`. *Verify:* the chip sits in
  both `ViewThatFits` candidates; only the displayed one should present.
- **Form sheets:** request modal (R3; off inside the Add sheet, which keeps its size), report an issue,
  `IssueThreadSheet`, `IssuePaneSheet`, rule editor (R7), Account (DC19). The request thread (`RequestThreadSheet`)
  is not ruled and keeps the default; DU5's side pane is D2. **Ruled (in D5, build 488):** `ActDialog` and, as an
  interim until D2's side pane, `RequestThreadSheet` are `formSheet()` unfolded; the phone keeps their detents.
- **Detents:** Account hub, `ActDialog`, Add user, Move credential, Broadcast, Change root → `[.mediumFitting, .large]`;
  trailer → `[.mediumFitting]`. Other `[.medium, .large]` sheets were left: they can already be dragged to full.
- **Close-only bars (Q-DC6):** Account, Add source, Letterboxd import, Edition aliases, Episode detail, Item
  match, Decline reason, Request thread, fusionha sign-in, Plex SSO, Download client picker, Notification agent
  picker, Configure demo, Import override, Import row editor, Sign-in methods, Widget diagnostics. The Add sheet's
  opt-out moved to its search step, so the configure step (Close + Back) keeps the system default. The Settings
  cover keeps the default: its pushed panels add their own items.
- **Deviation, Account (DC19):** a centred form sheet (about 540 wide), not the web's ~520 trailing panel. iOS 27.1's
  sheet `preferredPlacement` (HIG checklist §5: a right-placed sheet gets a vertical bar) is named but its
  signature isn't confirmed in this repo, so it is not used.
- **Deviation, Add configure step:** past the hero the system bar shows the title (the old custom compact bar did
  the same). The hero runs under the clear bar with the scroll edge effect hidden until then, so the art stays clean.

D2c notes (Activity, Queue, Discover, Manual Import, Settings panels; build 505):
- **Trigger:** every switch reads a measured width, never the size class: `publishesPaneSize()` / `\.paneSize`
  (`Components/PaneWidth.swift`) on Activity, Wanted, Discover and every Settings panel page; sheets measure
  themselves. Thresholds live in `FusionhaKit/PaneRules.swift` (`PaneRule`, `QueueDuoRule`, `ManualImportLayout`,
  `DiscoverWidthRule`), tested in `PaneRulesTests`. Inner portrait (669) keeps the phone layouts; inner landscape
  (951) crosses 720 (Q-DC3). A phone held sideways (874) does too, as Settings did in D5.
- **Settings panels:** viewport rules (`max-width: 720px`) follow `settingsDesktop`, true while Settings is split
  (`SettingsSplitRule`, handed down by `SettingsView` as the size class; read via `settingsLayout()` in
  `SettingsForm` / `FetchingPage`); container rules and card grids follow the panel's own width. `AutoFillGrid`
  (`Components/AutoFillGrid.swift`) is `repeat(auto-fill, minmax(N, 1fr))` with row-stretch.
- **Queue duo:** the pane runs the full height beside the header (the header scrolls with the list); only solo and
  pair cards open it, as on the web. The split only exists from 560 to 720 on a split-capable screen, so the
  iPad mini stand-in (744 / 1133) never shows it: compile-only.
- **Manual Import:** the layout follows the sheet live (not latched per open as on the web), so folding and rotating
  re-pick it. Table cells are read-only; a row opens its drawer (the phone row's body) for edits.
- **Request modal:** art 300 \| options above 720 of the sheet's width. The R3 form sheet never gets there; only the
  Add flow's page-sized sheet does. Open question: should a wide request modal use page sizing?
- **Tasks:** System grid cards are top-aligned (the web stretches them to equal height).
- **Wanted:** the 4K card goes two columns above the web's own 760, not 720.
- **S5 deviations:** the Duo's Settings detail column is about 690 wide in landscape (951 less the sidebar), so the
  Indexers cards' 510 × 2 and Instances' 430 × 2 only show on wider iPads; the quality editor (now a page sheet)
  opens its two panes above 820 of the sheet. **Not built:** Custom formats' 760/1100 rail \| editor \| Live test
  (the iOS panel is a list that opens a sheet editor; the Duo never reaches 760). Quality profiles and Presets keep
  their native Form lists (no card grid). Metadata's provider picker keeps its own-width rule (4 across from 462).
  Width floors beyond the web (shots, run 39411109540, iPad mini 744 split ≈ 460 panel): the Metadata cells sit side
  by side from 600 of panel and the Default profiles table shows from 640, else the phone stacks (both compile-only).
- **Shots (run 39411109540, iPad mini stand-in):** the stand-in's "landscape" shots render at 744 portrait like the
  portrait ones (the orientation hook does not rotate it), so only the 744 layouts were seen: Activity one-row head,
  Tasks System 3-up, Discover one-row controls + 158 cells, Settings Metadata head row. Everything else is compile-only.

- **D2c rulings (fusionha, 2026-10-20):** the request modal is page-sized when the window is desktop-wide (≥720, `\.windowSize` set at the app root), so its art | options panes show; a form sheet otherwise (R3). The page-sized Quality profile editor is accepted. Accepted deviations: desktop layouts on a sideways phone (the web's width rule), the Metadata/Default profiles width floors. Custom formats' 760/1100 three panes: unreachable on the Duo, to apply on iPad (☐).
