import SwiftUI

/// Routes a Settings panel slug (the web's `/settings/<slug>`) to its page.
/// Native panels get a `case`; everything else opens the web panel in an
/// in-app web view, signed in with the stored session cookie.
@ViewBuilder
func settingsPanel(_ slug: String) -> some View {
    switch slug {
    case "general": GeneralSettingsPanel()
    case "metadata": MetadataSettingsPanel()
    case "filemanagement": FileManagementSettingsPanel()
    case "releasefilters": ReleaseFiltersSettingsPanel()
    case "defaultprofiles": DefaultProfilesSettingsPanel()
    case "security": SecuritySettingsPanel()
    case "appearance": AppearanceSettingsPanel()
    case "about": AboutSettingsPanel()
    case "editions": MediaVersionsSettingsPanel()
    case "experimental": ExperimentalSettingsPanel()
    case "discover": DiscoverSettingsPanel()
    case "maintenance": MaintenanceSettingsPanel()
    default: SettingsWebPanel(slug: slug)
    }
}
