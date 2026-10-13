# Expo, React Native and Flutter

One codebase can ship both platforms. It does not ship both grammars by
itself: a React Native app that renders the same views on both phones is
the port (platforms.md). Share the tokens and the content, branch the
navigation layer, the system controls, the icons and the haptics.

**Versions move fast here.** Expo ships an SDK roughly every quarter and
APIs graduate from "unstable" between them. Check every name below in the
docs for the SDK you are on.

## 1. Tokens, once

```ts
// theme.ts: the DIRECTION.md roles, light and dark, used by both platforms.
export const color = {
  light: { ground: "#F7F4EE", raised: "#EFEBE3", ink: "#1C2326", ink2: "#4F5A5E", rule: "#D9D4CA", accent: "#0E5A6B", onAccent: "#FFFFFF" },
  dark:  { ground: "#0F1416", raised: "#1A2124", ink: "#EEF1F0", ink2: "#A9B4B6", rule: "#2A3336", accent: "#7FC4D3", onAccent: "#06262E" },
};
export const space = [4, 8, 12, 16, 24, 32, 48, 64] as const;
export const font = Platform.select({
  ios:     { ui: "System", display: "Newsreader-SemiBold" },
  android: { ui: "GoogleSansFlex-Regular", display: "Newsreader-SemiBold" },
});
```

- The display face is the same on both. The UI face follows the platform
  (SF Pro is `System` on iOS; bundle Google Sans Flex or Roboto Flex for
  Android, android.md §5).
- React Native does not set variable-font axes reliably. Export **static
  instances** of a variable font for the weights and widths you use
  (`GoogleSansFlex-Black-Wide.ttf`) and load them with `expo-font`.

## 2. Navigation layer

- **Expo Router** for routes. For tabs, use the native tabs API when your
  SDK has it (it renders the iOS 26 Liquid Glass tab bar on iPhone and the
  Material navigation bar on Android, from one definition); its import
  path and options have changed between SDKs, so read the current docs.
- Native stack headers (large titles on iOS, the top app bar on Android)
  rather than drawn ones.
- **@expo/ui** (stable since SDK 56): native controls from one import,
  SwiftUI on iOS and Jetpack Compose on Android. Use it for switches,
  pickers, segmented choices, sliders, menus and sheets, so each platform
  gets its own control. The platform packages
  (`@expo/ui/swift-ui`, `@expo/ui/jetpack-compose`) cover the rest, like
  `glassEffect` on iOS.
- Liquid Glass on iOS only (`expo-glass-effect`); on Android the floating
  layer is a tonal surface, not a blur.

## 3. Platform branches

```tsx
const PrimaryAction = Platform.OS === "android"
  ? () => <ExtendedFab icon="add" label="Log a dive" onPress={add} />   // bottom right, above the nav bar
  : () => <CapsuleButton label="Log a dive" onPress={add} />;           // thumb zone, or a toolbar button
```

Branch: the primary action (FAB vs capsule), back (system on both, no
drawn "Back" on Android), icons (SF Symbols via `expo-symbols` on iOS,
Material Symbols on Android), sheets (detents vs bottom sheet), alerts vs
dialogs, haptics. Keep everything else shared.

## 4. Motion and haptics

- **react-native-reanimated** for springs: `withSpring(value, { damping,
  stiffness, mass })`, or the duration and damping-ratio form. Use the iOS
  presets on iOS and Material's spatial springs on Android (motion.md §2).
- Layout animations (`entering`, `exiting`, `layout`) for items that
  arrive and leave a list: the "arrival" beat of a living screen.
- **react-native-gesture-handler** for direct manipulation that follows
  the finger.
- **expo-haptics:** `impactAsync`, `selectionAsync`,
  `notificationAsync(Success)` on iOS; recent SDKs also expose Android's
  own constants (`performAndroidHapticsAsync` with `Confirm`, `SegmentTick`
  and the rest). Use them on Android rather than a generic vibration.

## 5. Edge to edge and safe areas

Android draws edge to edge (required for apps targeting Android 16, and
the default in recent Expo SDKs). Use `react-native-safe-area-context` for
insets on both platforms; never paint a solid status bar strip.

## 6. Images and icons

`expo-image` for photos (caching, blurhash placeholders that match the
art direction). The iOS icon and the Android adaptive icon (foreground,
background, monochrome) are set in `app.json` from the PNGs shoot.mjs
exported (imagery.md §4 and §5).

## 7. Flutter

Theme once (`ThemeData` with your own `ColorScheme` roles, `TextTheme`,
and shape themes), and branch the navigation layer per platform:
`NavigationBar` and a FAB on Android, a Cupertino-style tab bar and large
titles on iOS. Flutter's Material library trails Material 3 Expressive, so
build the expressive pieces (the short navigation bar, shape morphing,
button groups) by hand from android.md, and use `HapticFeedback` per
platform.

## 8. Quality bar

The same as swiftui.md and compose.md, on both: largest text sizes, dark
mode designed, screen reader labels, 44pt / 48dp targets, the back gesture,
both navigation modes on Android. Screenshot both simulators and compare
with the mockups, pair by pair.
