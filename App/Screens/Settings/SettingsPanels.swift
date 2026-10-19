import SwiftUI

/// Routes a Settings panel slug (the web's `/settings/<slug>`) to its page.
/// Native panels get a `case`; everything else (Security's secrets at rest,
/// Plex server, Sign-in methods with trusted proxies …) opens the web panel in
/// the signed-in `FusionhaWebView`.
@ViewBuilder
func settingsPanel(_ slug: String) -> some View {
    switch slug {
    case "general": GeneralSettingsPanel()
    case "metadata": MetadataSettingsPanel()
    case "filemanagement": FileManagementSettingsPanel()
    case "releasefilters": ReleaseFiltersSettingsPanel()
    case "defaultprofiles": DefaultProfilesSettingsPanel()
    case "apikey": SecuritySettingsPanel()
    case "appearance": AppearanceSettingsPanel()
    case "about": AboutSettingsPanel()
    case "versions", "editions": MediaVersionsSettingsPanel()
    case "experimental": ExperimentalSettingsPanel()
    case "discover": DiscoverSettingsPanel()
    case "maintenance": MaintenanceSettingsPanel()
    case "roots": RootFoldersPanel()
    case "clients": DownloadClientsPanel()
    case "indexers": IndexersPanel()
    case "connect": ConnectPanel()
    case "notifications": NotificationsPanel()
    case "instances": ConnectionsPanel()
    case "publicaccess": PublicAccessPanel()
    case "system": SystemTasksPanel()
    case "database": DatabasePanel()
    case "backup": BackupPanel()
    case "logs": LogsPanel()
    case "guardrails": GuardrailsSettingsPanel()
    // Moved from Discover › Requests (approved Requests nav, 2026-10-18).
    case "requestrules": ScrollView { RequestRulesView().padding(16) }.background(Theme.bg)
    case "access": UsersSettingsPanel()
    case "roles": RolesSettingsPanel()
    case "blocklist": ReleaseGroupBlocklistPanel()
    case "plexserver": PlexServerSettingsPanel()
    case "profiles": QualityProfilesSettingsPanel()
    case "qualitydefinitions": QualityDefinitionsSettingsPanel()
    case "import": ImportLibrarySettingsPanel()
    case "naming": NamingSettingsPanel()
    case "security": SecurityAdminSettingsPanel()
    case "signin": SignInMethodsSettingsPanel()
    case "formats": CustomFormatsSettingsPanel()
    case "trash": TrashGuidesSettingsPanel()
    default: SettingsWebPanel(slug: slug)
    }
}
