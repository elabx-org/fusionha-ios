# Jetpack Compose implementation

The direction becomes a theme (colour scheme, type, shapes, motion), then
Material components styled by it, then your own components where the
concept needs them. Do not rebuild Material components to look custom;
theme them. Build against Android 16 (API 36), edge to edge.

**Versions move.** As of October 2026, Compose Material 3 1.4.0 is stable
and 1.5.0 (with the Expressive components) is in beta. Some Expressive
APIs below are still marked `@ExperimentalMaterial3ExpressiveApi`. Pin a
version, read its release notes, and check every name here against it
before writing code.

## 1. Tokens

```kotlin
// Your roles, light and dark: never the baseline scheme, never only a seed.
private val Light = lightColorScheme(
    primary = Color(0xFF0E5A6B), onPrimary = Color.White,          // accent, on-accent
    primaryContainer = Color(0xFFCFE6EC), onPrimaryContainer = Color(0xFF0A3A45),
    surface = Color(0xFFF7F4EE), onSurface = Color(0xFF1C2326),     // ground, ink
    onSurfaceVariant = Color(0xFF4F5A5E),                          // ink-2
    surfaceContainer = Color(0xFFEFEBE3),                          // raised
    outline = Color(0xFF7A8488), outlineVariant = Color(0xFFD9D4CA), // ink-3, rule
)
private val Dark = darkColorScheme(/* the second design, not an inversion */)

@Composable
fun AppTheme(dark: Boolean = isSystemInDarkTheme(), content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = if (dark) Dark else Light,
        typography = AppType,
        shapes = AppShapes,
        // 1.5: motionScheme = MotionScheme.expressive() (or .standard()); check the signature you pin
        content = content,
    )
}
```

- **Dynamic colour** (`dynamicLightColorScheme(context)`, API 31+) only if
  DIRECTION.md chose it (android.md §4). Most directed apps offer it as a
  setting at most.
- Fill the roles you did not decide from your own tonal palettes (the
  Material Theme Builder takes your seed), then check each against the
  direction. Never leave a baseline purple anywhere.

## 2. Type

Variable fonts in `res/font`, with the axes the direction uses:

```kotlin
val GoogleSansFlex = FontFamily(
    Font(R.font.google_sans_flex, FontWeight.Normal,
        variationSettings = FontVariation.Settings(FontVariation.weight(400), FontVariation.Setting("ROND", 40f))),
    Font(R.font.google_sans_flex, FontWeight.Black,
        variationSettings = FontVariation.Settings(FontVariation.weight(900), FontVariation.width(125f), FontVariation.Setting("ROND", 40f))),
)

val AppType = Typography(
    displayLarge = TextStyle(fontFamily = GoogleSansFlex, fontWeight = FontWeight.Black, fontSize = 88.sp, lineHeight = 84.sp, letterSpacing = (-2.5).sp),
    titleLarge = TextStyle(fontFamily = GoogleSansFlex, fontWeight = FontWeight.Medium, fontSize = 22.sp, lineHeight = 28.sp),
    bodyLarge = TextStyle(fontFamily = GoogleSansFlex, fontSize = 16.sp, lineHeight = 24.sp, letterSpacing = 0.sp),
    // ...every role the app uses
)
```

- Use `sp` everywhere so text follows the user's font size (up to 200%).
- Tabular figures for numbers that change:
  `TextStyle(fontFeatureSettings = "tnum")`.
- A bundled serif or display face is a `FontFamily` like any other; it is
  the same face as on iOS.

## 3. Shapes

```kotlin
val AppShapes = Shapes(
    extraSmall = RoundedCornerShape(4.dp), small = RoundedCornerShape(8.dp),
    medium = RoundedCornerShape(16.dp), large = RoundedCornerShape(28.dp),
    extraLarge = RoundedCornerShape(32.dp),
)
```

Expressive shapes (`MaterialShapes.Cookie9Sided.toShape()` and the rest,
experimental) for the one place the direction uses them: an avatar crop, a
selected state, a celebration. `Morph` between two shapes for a state
change.

## 4. Edge to edge and structure

```kotlin
override fun onCreate(savedInstanceState: Bundle?) {
    enableEdgeToEdge()
    super.onCreate(savedInstanceState)
    setContent { AppTheme { App() } }
}

Scaffold(
    topBar = { LargeFlexibleTopAppBar(title = { Text("Today") }, scrollBehavior = scroll) },
    bottomBar = { ShortNavigationBar { /* ShortNavigationBarItem per destination */ } },
    floatingActionButton = { ExtendedFloatingActionButton(onClick = add, icon = { Icon(...) }, text = { Text("Log a dive") }) },
) { padding -> Content(Modifier.padding(padding)) }
```

- `Scaffold` passes the system bar insets as `padding`; content scrolls
  under the bars with `contentPadding`, it is not cut off above them.
  Custom layouts use `Modifier.safeDrawingPadding()` or
  `WindowInsets.safeDrawing`.
- Top app bars: `TopAppBar`, `MediumFlexibleTopAppBar`,
  `LargeFlexibleTopAppBar` with
  `TopAppBarDefaults.exitUntilCollapsedScrollBehavior()`.
- Bottom: `ShortNavigationBar` (the flexible 64dp bar) or `NavigationBar`;
  `HorizontalFloatingToolbar` for a floating toolbar;
  `FloatingActionButtonMenu` for a FAB menu.
- Buttons: `Button`, `FilledTonalButton`, `OutlinedButton`, `TextButton`;
  `ButtonGroup` for connected choices; `SplitButton` for an action with
  options.
- Sheets and dialogs: `ModalBottomSheet`, `AlertDialog`. Snackbars through
  `SnackbarHostState`.
- Icons: Material Symbols in the direction's style, weight and fill, as
  vector drawables (download them from fonts.google.com/icons with the
  same settings as the mockup). `material-icons-extended` is the older
  Material Icons set, not Symbols.

## 5. Motion and haptics

```kotlin
val spatial = MaterialTheme.motionScheme.defaultSpatialSpec<Float>()     // 1.5; or:
val spring = spring<Float>(dampingRatio = 0.8f, stiffness = 380f)         // expressive default spatial

val scale by animateFloatAsState(if (pressed) 0.96f else 1f, spring, label = "press")

SharedTransitionLayout {                                // container transform: card -> detail
    AnimatedContent(selected) { item ->
        Card(Modifier.sharedElement(rememberSharedContentState("dive-${item.id}"), this@AnimatedContent)) { ... }
    }
}

val haptics = LocalHapticFeedback.current
haptics.performHapticFeedback(HapticFeedbackType.Confirm)   // on completion; SegmentTick while scrubbing
```

- Predictive back: `android:enableOnBackInvokedCallback="true"` in the
  manifest (the default when targeting Android 16), `PredictiveBackHandler`
  for a custom exit that follows the swipe.
- Numbers that change: `AnimatedContent` with a vertical slide per digit,
  the rolling-number equivalent.
- Reduced motion: respect the system animator scale; keep feedback,
  shorten or drop movement.

## 6. Quality bar before calling it done

- Font size at 200% (`adb shell settings put system font_scale 2.0`):
  nothing truncates illegibly, rows wrap, columns stack.
- Dark theme designed, not inverted.
- 3-button navigation and gesture navigation both look right (the
  translucent scrim, the insets).
- TalkBack: `contentDescription` on every icon-only control, merged
  semantics on composite rows.
- 48dp targets, predictive back on every screen.
- Screenshot each key screen on an emulator
  (`adb exec-out screencap -p > shot.png`) in both themes and compare with
  the mockups. The build is judged against the design.
