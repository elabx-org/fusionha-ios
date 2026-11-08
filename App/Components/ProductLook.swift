import Foundation

/// Which product's look a shared screen draws: v2 (the FusionhaV2 target,
/// compiled with `V2`) or v1. For shared sheets with no look override in
/// the environment (the Request sheet, sign-in); browse pages use
/// `\.browseLook` instead.
enum ProductLook {
    static var isV2: Bool {
        #if V2
        return true
        #else
        return false
        #endif
    }
}
