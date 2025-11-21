# Animation Guidelines

Flutter GitUI uses animations to provide visual feedback, guide user attention, and create a polished experience. This document outlines when to animate, animation timing standards, and best practices.

## Table of Contents

1. [Animation Philosophy](#animation-philosophy)
2. [When to Animate](#when-to-animate)
3. [When NOT to Animate](#when-not-to-animate)
4. [Duration Standards](#duration-standards)
5. [Easing Curves](#easing-curves)
6. [AppAnimationSpeed System](#appanimationspeed-system)
7. [Respecting User Preferences](#respecting-user-preferences)
8. [Animation Best Practices](#animation-best-practices)
9. [Common Animation Patterns](#common-animation-patterns)
10. [Performance Considerations](#performance-considerations)

---

## Animation Philosophy

**Animations should enhance, not distract.**

Our animation philosophy:

1. **Purposeful**: Every animation serves a clear purpose (feedback, transition, guidance)
2. **Respectful**: Always honor user motion preferences (reduce motion, animation speed)
3. **Fast by default**: Animations should feel responsive, not sluggish (250ms standard)
4. **Consistent**: Similar actions use similar animation timing and curves
5. **Skippable**: Users can disable animations entirely via `AppAnimationSpeed.none`

Good animations are **barely noticed**. They feel natural and help users understand state changes without drawing attention to the animation itself.

---

## When to Animate

### State Changes

Animate when UI state changes to help users understand what happened:

```dart
// ✅ Expand/collapse animation
AnimatedContainer(
  duration: context.standardAnimation,
  curve: Curves.easeInOut,
  height: isExpanded ? 200 : 0,
  child: content,
)

// ✅ Visibility toggle
AnimatedOpacity(
  duration: context.quickAnimation,
  opacity: isVisible ? 1.0 : 0.0,
  child: message,
)
```

**Use cases:**
- Expand/collapse panels
- Show/hide elements
- Enable/disable states
- Loading indicators

### Navigation

Animate transitions between screens to provide spatial context:

```dart
// ✅ Page transition
Navigator.push(
  context,
  PageRouteBuilder(
    pageBuilder: (context, animation, secondaryAnimation) => NewScreen(),
    transitionDuration: context.slowAnimation,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: animation,
        child: child,
      );
    },
  ),
)
```

**Use cases:**
- Screen transitions
- Dialog open/close
- Tab switches
- Bottom sheet slide-in

### User Feedback

Animate to acknowledge user actions:

```dart
// ✅ Ripple effect on tap
InkWell(
  onTap: () => _handleTap(),
  splashFactory: InkRipple.splashFactory,
  child: content,
)

// ✅ Button press feedback
AnimatedScale(
  duration: context.quickAnimation,
  scale: isPressed ? 0.95 : 1.0,
  child: button,
)
```

**Use cases:**
- Button ripples
- Hover effects
- Drag feedback
- Success/error confirmations

### Attention Guidance

Animate to draw attention to important changes:

```dart
// ✅ Highlight new item
AnimatedContainer(
  duration: context.standardAnimation,
  decoration: BoxDecoration(
    color: isNew
        ? Theme.of(context).colorScheme.primaryContainer
        : Colors.transparent,
    borderRadius: BorderRadius.circular(AppTheme.radiusM),
  ),
  child: listItem,
)
```

**Use cases:**
- New item indicators
- Error highlights
- Search result highlights
- Notification badges

---

## When NOT to Animate

### Critical Information

Never delay critical information with animations:

```dart
// ❌ DON'T - Error message delayed by animation
AnimatedOpacity(
  duration: Duration(milliseconds: 500), // User must wait
  opacity: hasError ? 1.0 : 0.0,
  child: ErrorMessage(),
)

// ✅ DO - Show immediately
if (hasError) ErrorMessage() // Instant
```

**Avoid animating:**
- Error messages
- Validation feedback
- Security warnings
- Data loss warnings

### Initial Load

Don't animate content on initial page load:

```dart
// ❌ DON'T - Content fades in on first view
AnimatedOpacity(
  duration: Duration(milliseconds: 300),
  opacity: 1.0,
  child: pageContent,
)

// ✅ DO - Show immediately
pageContent // Instant
```

**Exceptions:**
- Loading spinners (indicates activity)
- Skeleton screens (progressive loading)

### Motion Sensitivity

Always provide option to disable animations:

```dart
// ✅ DO - Check animation speed preference
final animSpeed = ref.watch(uiConfigProvider).animationSpeed;
final duration = animSpeed == AppAnimationSpeed.none
    ? Duration.zero
    : context.standardAnimation;

AnimatedContainer(
  duration: duration,
  height: isExpanded ? 200 : 0,
)
```

Users with vestibular disorders or motion sensitivity need animations disabled or reduced.

### List Scrolling

Avoid animating every item in a long list:

```dart
// ❌ DON'T - Animate hundreds of list items
ListView.builder(
  itemBuilder: (context, index) => AnimatedOpacity(
    duration: Duration(milliseconds: 200 * index), // Gets very slow
    opacity: 1.0,
    child: listItem,
  ),
)

// ✅ DO - Only animate new/changed items
ListView.builder(
  itemBuilder: (context, index) {
    final isNew = recentlyAdded.contains(items[index]);
    return AnimatedContainer(
      duration: isNew ? context.quickAnimation : Duration.zero,
      color: isNew ? highlightColor : Colors.transparent,
      child: listItem,
    );
  },
)
```

---

## Duration Standards

Flutter GitUI uses three standard animation speeds:

### Quick (150ms) - Micro-interactions

For subtle, instant-feeling feedback:

```dart
Duration: 150ms (base) → 105ms (fast) | 150ms (normal) | 225ms (slow) | 0ms (none)
```

**Use for:**
- Hover effects
- Ripple animations
- Focus indicators
- Tooltip show/hide
- Icon color changes

**Example:**
```dart
AnimatedContainer(
  duration: context.quickAnimation, // 150ms
  curve: Curves.easeOut,
  color: isHovered
      ? Theme.of(context).colorScheme.surfaceContainerHighest
      : Colors.transparent,
  child: content,
)
```

### Standard (250ms) - Most UI Transitions

For typical UI state changes:

```dart
Duration: 250ms (base) → 175ms (fast) | 250ms (normal) | 375ms (slow) | 0ms (none)
```

**Use for:**
- Dialogs opening/closing
- Menus expanding/collapsing
- Tabs switching
- Panels sliding in/out
- Expand/collapse animations
- Opacity fades

**Example:**
```dart
AnimatedOpacity(
  duration: context.standardAnimation, // 250ms
  curve: Curves.easeInOut,
  opacity: isVisible ? 1.0 : 0.0,
  child: panel,
)
```

### Slow (350ms) - Emphasized Transitions

For major state changes that need more time:

```dart
Duration: 350ms (base) → 245ms (fast) | 350ms (normal) | 525ms (slow) | 0ms (none)
```

**Use for:**
- Page transitions
- Screen navigation
- Major layout changes
- Bottom sheet full-screen transitions
- Drawer slide-in

**Example:**
```dart
Navigator.push(
  context,
  PageRouteBuilder(
    transitionDuration: context.slowAnimation, // 350ms
    pageBuilder: (context, animation, secondaryAnimation) => NewScreen(),
  ),
)
```

### Custom Durations

For specialized animations, use `AppTheme.getAnimationDuration()`:

```dart
// Custom 500ms animation
final animSpeed = ref.watch(uiConfigProvider).animationSpeed;
final duration = AppTheme.getAnimationDuration(
  animSpeed,
  baseSpeed: Duration(milliseconds: 500),
);

AnimatedContainer(
  duration: duration,
  child: content,
)
```

---

## Easing Curves

Use appropriate easing curves for natural motion.

### Curves.easeInOut (Default)

Smooth acceleration and deceleration. Use for most animations:

```dart
AnimatedContainer(
  duration: context.standardAnimation,
  curve: Curves.easeInOut, // Smooth both directions
  height: isExpanded ? 200 : 0,
)
```

**Use for:**
- Expand/collapse
- Size changes
- Two-way animations

### Curves.easeOut (Entering)

Starts fast, ends slow. Use for elements entering the screen:

```dart
AnimatedOpacity(
  duration: context.standardAnimation,
  curve: Curves.easeOut, // Quick start, smooth end
  opacity: isVisible ? 1.0 : 0.0,
  child: enteringElement,
)
```

**Use for:**
- Fade-in
- Slide-in
- Scale-in
- Dialog opening

### Curves.easeIn (Exiting)

Starts slow, ends fast. Use for elements leaving the screen:

```dart
AnimatedSlide(
  duration: context.standardAnimation,
  curve: Curves.easeIn, // Smooth start, quick end
  offset: isVisible ? Offset.zero : Offset(1, 0),
  child: exitingElement,
)
```

**Use for:**
- Fade-out
- Slide-out
- Scale-out
- Dialog closing

### Curves.linear

No easing. Use sparingly for mechanical animations:

```dart
AnimatedRotation(
  duration: Duration(seconds: 2),
  curve: Curves.linear, // Constant speed
  turns: isSpinning ? 1.0 : 0.0,
  child: loadingSpinner,
)
```

**Use for:**
- Progress bars
- Loading spinners
- Continuous rotations

### Custom Curves

For advanced animations, use custom cubic curves:

```dart
// Material Design's emphasized easing
const Cubic emphasizedEasing = Cubic(0.2, 0.0, 0, 1.0);

AnimatedContainer(
  duration: context.slowAnimation,
  curve: emphasizedEasing,
  child: content,
)
```

---

## AppAnimationSpeed System

Flutter GitUI provides user-configurable animation speeds.

### Speed Options

```dart
enum AppAnimationSpeed {
  none,    // 0ms - Disable all animations (accessibility)
  fast,    // 0.7x speed - Snappy, responsive feel
  normal,  // 1.0x speed - Default balanced speed
  slow,    // 1.5x speed - Easier to follow, accessibility
}
```

### Speed Multipliers

| Speed | Multiplier | Quick | Standard | Slow |
|-------|-----------|-------|----------|------|
| **none** | 0.0x | 0ms | 0ms | 0ms |
| **fast** | 0.7x | 105ms | 175ms | 245ms |
| **normal** | 1.0x | 150ms | 250ms | 350ms |
| **slow** | 1.5x | 225ms | 375ms | 525ms |

### Implementation

```dart
// ✅ Use context extensions (recommended)
AnimatedContainer(
  duration: context.quickAnimation,    // 150ms → respects user preference
  duration: context.standardAnimation, // 250ms → respects user preference
  duration: context.slowAnimation,     // 350ms → respects user preference
  child: content,
)

// ✅ Use AppTheme helpers
final animSpeed = ref.watch(uiConfigProvider).animationSpeed;
AnimatedOpacity(
  duration: AppTheme.getQuickAnimation(animSpeed),
  duration: AppTheme.getStandardAnimation(animSpeed),
  duration: AppTheme.getSlowAnimation(animSpeed),
  child: content,
)

// ❌ DON'T - Hardcoded duration
AnimatedContainer(
  duration: Duration(milliseconds: 250), // Ignores user preference
  child: content,
)
```

### BuildContext Extensions

For cleaner code, use context extensions:

```dart
extension AnimationSpeedContext on BuildContext {
  AppAnimationSpeed get animationSpeed => ...;
  Duration get quickAnimation => AppTheme.getQuickAnimation(animationSpeed);
  Duration get standardAnimation => AppTheme.getStandardAnimation(animationSpeed);
  Duration get slowAnimation => AppTheme.getSlowAnimation(animationSpeed);
}

// Usage
AnimatedContainer(
  duration: context.standardAnimation, // Automatic
  child: content,
)
```

---

## Respecting User Preferences

Always honor user motion preferences.

### Check Animation Speed

```dart
final animSpeed = ref.watch(uiConfigProvider).animationSpeed;

// Option 1: Use helper functions
final duration = AppTheme.getStandardAnimation(animSpeed);

// Option 2: Check for none explicitly
if (animSpeed == AppAnimationSpeed.none) {
  // Instant transition
  Navigator.pushReplacement(context, MaterialPageRoute(...));
} else {
  // Animated transition
  Navigator.push(context, PageRouteBuilder(...));
}
```

### Page Transitions

Page transitions are automatically handled via theme:

```dart
// In AppTheme
pageTransitionsTheme: PageTransitionsTheme(
  builders: {
    TargetPlatform.android: _getPageTransition(animationSpeed),
    TargetPlatform.iOS: _getPageTransition(animationSpeed),
    // ...
  },
)

static PageTransitionsBuilder _getPageTransition(AppAnimationSpeed speed) {
  if (speed == AppAnimationSpeed.none) {
    return const NoAnimationPageTransitionsBuilder(); // Instant
  }
  return const FadeUpwardsPageTransitionsBuilder(); // Animated
}
```

### Preserve Critical Animations

Even with `AppAnimationSpeed.none`, preserve animations that indicate activity:

```dart
// ✅ Always show loading spinner (indicates activity)
CircularProgressIndicator() // Not affected by animation speed

// ✅ Always animate drag feedback (user-initiated)
Draggable(
  feedback: AnimatedScale(...), // User expects visual feedback
)

// ❌ Don't keep decorative animations
AnimatedContainer(
  duration: context.standardAnimation, // Disabled with none
  decoration: BoxDecoration(
    gradient: animatedGradient, // Unnecessary decoration
  ),
)
```

---

## Animation Best Practices

### 1. Keep Animations Short

**Avoid** animations longer than 500ms:

```dart
// ❌ Too slow - feels sluggish
AnimatedContainer(
  duration: Duration(milliseconds: 800),
  child: content,
)

// ✅ Fast and responsive
AnimatedContainer(
  duration: context.standardAnimation, // 250ms
  child: content,
)
```

### 2. Animate One Property at a Time

Animating multiple properties simultaneously can feel chaotic:

```dart
// ❌ Too much happening at once
AnimatedContainer(
  duration: context.standardAnimation,
  width: isExpanded ? 400 : 200,
  height: isExpanded ? 300 : 100,
  color: isExpanded ? Colors.blue : Colors.red,
  transform: isExpanded ? Matrix4.rotationZ(0.1) : Matrix4.identity(),
)

// ✅ Focus on one primary animation
AnimatedContainer(
  duration: context.standardAnimation,
  height: isExpanded ? 300 : 100, // Single property
  color: Theme.of(context).colorScheme.surface, // Static
)
```

### 3. Use ImplicitlyAnimatedWidget

Prefer implicit animations over manual AnimationController:

```dart
// ✅ Implicit animation (simpler)
AnimatedOpacity(
  duration: context.standardAnimation,
  opacity: isVisible ? 1.0 : 0.0,
  child: content,
)

// ❌ Explicit animation (more complex, only when necessary)
class _State extends State with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: context.standardAnimation,
      vsync: this,
    );
  }

  // ... more boilerplate
}
```

**Use explicit animations only for:**
- Complex multi-stage animations
- Animations that need precise control
- Synchronized animations across multiple widgets

### 4. Dispose Controllers

Always dispose animation controllers:

```dart
class _State extends State<MyWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: context.standardAnimation);
  }

  @override
  void dispose() {
    _controller.dispose(); // ✅ Prevent memory leaks
    super.dispose();
  }
}
```

### 5. Avoid Animating Expensive Operations

Don't animate operations that cause heavy rebuilds:

```dart
// ❌ Rebuilds entire tree on every frame
AnimatedBuilder(
  animation: animation,
  builder: (context, child) {
    return ExpensiveWidget(value: animation.value); // Rebuilds everything
  },
)

// ✅ Only animate specific property
AnimatedBuilder(
  animation: animation,
  builder: (context, child) {
    return Transform.translate(
      offset: Offset(animation.value * 100, 0),
      child: child, // Child is cached
    );
  },
  child: ExpensiveWidget(), // Built once
)
```

### 6. Use Const Constructors

Use const constructors for non-animated parts:

```dart
AnimatedOpacity(
  duration: context.standardAnimation,
  opacity: isVisible ? 1.0 : 0.0,
  child: const Icon(PhosphorIconsRegular.check), // ✅ Const - not rebuilt
)
```

---

## Common Animation Patterns

### Fade In/Out

```dart
AnimatedOpacity(
  duration: context.standardAnimation,
  curve: Curves.easeInOut,
  opacity: isVisible ? 1.0 : 0.0,
  child: content,
)
```

### Expand/Collapse

```dart
AnimatedSize(
  duration: context.standardAnimation,
  curve: Curves.easeInOut,
  child: isExpanded ? expandedContent : SizedBox.shrink(),
)

// Or with AnimatedContainer
AnimatedContainer(
  duration: context.standardAnimation,
  curve: Curves.easeInOut,
  height: isExpanded ? null : 0,
  child: content,
)
```

### Slide In/Out

```dart
AnimatedSlide(
  duration: context.standardAnimation,
  curve: Curves.easeOut,
  offset: isVisible ? Offset.zero : Offset(1.0, 0),
  child: panel,
)
```

### Scale In/Out

```dart
AnimatedScale(
  duration: context.standardAnimation,
  curve: Curves.easeOut,
  scale: isVisible ? 1.0 : 0.0,
  child: dialog,
)
```

### Rotation

```dart
AnimatedRotation(
  duration: context.standardAnimation,
  curve: Curves.easeInOut,
  turns: isRotated ? 0.25 : 0.0, // 0.25 = 90 degrees
  child: icon,
)
```

### Color Transition

```dart
AnimatedContainer(
  duration: context.standardAnimation,
  curve: Curves.easeInOut,
  color: isSelected
      ? Theme.of(context).colorScheme.primaryContainer
      : Colors.transparent,
  child: listItem,
)
```

### Cross-Fade

```dart
AnimatedSwitcher(
  duration: context.standardAnimation,
  transitionBuilder: (child, animation) {
    return FadeTransition(opacity: animation, child: child);
  },
  child: condition
      ? Widget1(key: ValueKey('widget1'))
      : Widget2(key: ValueKey('widget2')),
)
```

### Staggered List Animations

```dart
ListView.builder(
  itemCount: items.length,
  itemBuilder: (context, index) {
    return AnimatedOpacity(
      duration: context.quickAnimation,
      opacity: _isVisible ? 1.0 : 0.0,
      child: Padding(
        padding: EdgeInsets.only(
          top: index * 2.0, // Subtle stagger
        ),
        child: listItem,
      ),
    );
  },
)
```

### Hero Transitions

```dart
// Source screen
Hero(
  tag: 'repo-${repo.id}',
  child: RepositoryCard(repo: repo),
)

// Destination screen
Hero(
  tag: 'repo-${repo.id}',
  child: RepositoryDetailHeader(repo: repo),
)

// Automatic shared-element animation
```

---

## Performance Considerations

### 1. Avoid Unnecessary Animations

Only animate what the user can see:

```dart
// ✅ Only animate visible items
if (isVisible) {
  AnimatedOpacity(
    duration: context.standardAnimation,
    opacity: targetOpacity,
    child: content,
  )
} else {
  content // No animation wrapper
}
```

### 2. Use RepaintBoundary

For complex animated widgets, isolate repaints:

```dart
RepaintBoundary(
  child: AnimatedBuilder(
    animation: animation,
    builder: (context, child) {
      return CustomPaint(
        painter: AnimatedPainter(animation.value),
      );
    },
  ),
)
```

### 3. Profile with DevTools

Use Flutter DevTools to identify performance issues:

```bash
flutter run --profile
# Open DevTools → Performance tab
# Look for dropped frames during animations
```

### 4. Reduce Animation Complexity

Simplify animations if they cause frame drops:

```dart
// ❌ Complex - may drop frames
AnimatedBuilder(
  animation: animation,
  builder: (context, child) {
    return Transform(
      transform: Matrix4.rotationY(animation.value)
        ..rotateX(animation.value * 0.5)
        ..scale(animation.value),
      child: ComplexWidget(),
    );
  },
)

// ✅ Simplified - smooth 60fps
AnimatedOpacity(
  duration: context.standardAnimation,
  opacity: animation.value,
  child: ComplexWidget(),
)
```

---

## Questions?

For animation questions or feedback:

1. Check this guide for standard patterns
2. Review `docs/UI-CONCEPT.md` for component examples
3. Open a GitHub issue with label `animation` or `ux`
4. Test with `AppAnimationSpeed.none` to verify accessibility

Remember: **Good animations are barely noticed.** They should feel natural and purposeful, not flashy or distracting.
