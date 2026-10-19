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
| **B3 Requests** | the R rows (decline-reason sheet, filter groups, header subtitles, drawer counts, Rules row) | — |
| **B4 Discover** | the D rows (Letterboxd suggestion card, trailers ＋, segmented fill, TMDB-missing state, one request path) | — |
| **B5 Activity** | the Q, H, BL, W and T rows (failure copy, card washes, pair card, pack model, held why, History lifecycle, Blocklist groups, Tasks voice) | — |
| **B6 Detail, Library, Calendar** | the L, I and C rows | — |
| **B7 Account, Settings, shell** | the A, U, N and S rows | — |
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
