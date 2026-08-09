// Part of the partition library. See `content_port.dart` for why the fences
// and the scope that plants them are one library: both fence constructors are
// private, and everything here is one of the three places allowed to plant one.
part of 'content_port.dart';

/// Wraps a dialog's surface in the application's own keyboard contract.
///
/// Escape cancels, Enter submits from anywhere, a multiline editable keeps its
/// own Enter, and the anchor stays out of the traversal order. Those are WHAT
/// THE USER CAN DO, so they belong to the application and no skin may weaken
/// them - which is why this is a function the application supplies once,
/// installed on [SkinScope], and not a member any skin implements.
///
/// It is required rather than optional deliberately. The application already
/// has exactly one place where the scope is installed; making the host a
/// required argument there means the keyboard contract cannot be dropped by
/// forgetting to opt in, and it travels into every route because the envelope
/// carries it.
typedef DialogKeyboardHostBuilder =
    Widget Function(BuildContext context, DialogSpec spec, Widget surface);

/// A skin's own arrangement around the content an overlay host hands it.
///
/// The route is the skin's, so the positioning, the anchoring and the surface
/// around an overlay's content are the skin's too - and all of them must land
/// INSIDE the skin-painted fence, or the attribution walk reports the skin's
/// own popover frame as an application leak. Handing the arrangement to the
/// host as a function is what puts it on the right side of the fence without
/// the skin having to know a fence exists.
typedef SkinOverlayFrame =
    Widget Function(BuildContext context, Widget content);

/// The active skin and the user's choices, captured at a CALL SITE and carried
/// into a route as data.
///
/// A route is built by a navigator that sits above the place the dialog was
/// opened from, so nothing inherited at the call site is there when the route
/// builds. Every design language answers that differently and one of them
/// answers it wrongly and silently, so the contract does not rely on any of
/// their answers: it carries what it needs across as a value.
@immutable
final class SkinEnvelope {
  const SkinEnvelope._(this.skin, this.request, this.dialogKeyboardHost);

  /// The design language in force.
  final Skin skin;

  /// The user's choices, for the skin to resolve.
  final SkinRequest request;

  /// The application's dialog keyboard contract, travelling with the envelope
  /// so that a route re-establishes it along with everything else.
  final DialogKeyboardHostBuilder dialogKeyboardHost;

  /// Takes the envelope in force at [context].
  static SkinEnvelope capture(BuildContext context) =>
      SkinScope.of(context).envelope;

  /// Re-establishes this skin over [body], fenced as skin-painted.
  ///
  /// The one composition every overlay host uses, written once so the four
  /// overlay members cannot drift apart from each other:
  ///
  /// ```
  /// SkinPainted                 <- the walk prunes: skin territory begins
  ///   SkinScope                    the skin is reachable again inside a route
  ///     chrome.wrapRoot            the skin's own root treatment
  ///       body                     the skin's overlay frame, and inside it
  ///                                a ContentPortBoundary wherever the
  ///                                application's own content resumes
  /// ```
  ///
  /// Note the order: the fence is planted OUTSIDE `wrapRoot`, not inside its
  /// child. Everything a root treatment installs - a theme, a default text
  /// style, an icon treatment, a surface - is the skin's own paint, and with
  /// the fence on the inside every one of those widgets sat in the half of the
  /// partition the walk attributes to the application.
  Widget _establish(WidgetBuilder body) => SkinPainted._(
    child: SkinScope._carrying(
      envelope: this,
      child: Builder(
        builder: (BuildContext c1) => skin.chrome.wrapRoot(
          c1,
          request: request,
          child: Builder(builder: body),
        ),
      ),
    ),
  );
}

/// An opaque handle to an overlay's APPLICATION content.
///
/// A skin CANNOT construct one and CANNOT unwrap one. The only way to obtain
/// the content it is supposed to present is to call [build], and [build]
/// re-establishes the scope and calls the skin's own `chrome.wrapRoot` before
/// it returns anything.
///
/// That is what turns the measured macOS failure from a rule someone remembers
/// into something that cannot be written: a skin that forgets the host does
/// not get a wrongly themed dialog, it gets an empty one.
final class SkinContentHost {
  const SkinContentHost._(this._envelope, this._body);

  final SkinEnvelope _envelope;
  final WidgetBuilder _body;

  /// Produces the content, with the skin's own root treatment re-established
  /// around it.
  ///
  /// [frame] is the skin's own arrangement - a positioned stack, an anchored
  /// surface, a dismiss barrier - and it is applied INSIDE the fence, so the
  /// skin's overlay frame is attributed to the skin and the application's
  /// content resumes at its own boundary inside it.
  Widget build(BuildContext context, {SkinOverlayFrame? frame}) =>
      _envelope._establish((BuildContext inner) {
        final Widget content = _body(inner);
        return frame == null ? content : frame(inner, content);
      });
}

/// An opaque handle to a menu's entries.
///
/// A menu's rows are the SKIN's content - it builds them from data - so unlike
/// [SkinContentHost] there is no application subtree to fence. What still has
/// to happen is the re-establishing, and it is enforced the same way: the
/// entries are reachable only from inside [build], so a skin that skips the
/// host does not get an unthemed menu, it gets an empty one.
///
/// That symmetry is the whole point. Before it existed, two of the four
/// overlay members handed the skin a raw envelope and left it to rebuild the
/// wrapper by hand - which every skin then did, differently, and which the
/// macOS skin can get silently wrong.
final class SkinMenuHost {
  const SkinMenuHost._(this._envelope, this._entries);

  final SkinEnvelope _envelope;
  final List<MenuEntry> _entries;

  /// Produces the menu, with the skin's own root treatment re-established
  /// around it. [body] is handed the entries in the application's order; the
  /// index a row reports back is that order's index.
  Widget build(
    BuildContext context,
    Widget Function(BuildContext context, List<MenuEntry> entries) body,
  ) => _envelope._establish((BuildContext inner) => body(inner, _entries));
}

/// An opaque handle to a notice.
///
/// Same shape and same reason as [SkinMenuHost]: what the notice SAYS is
/// reachable only from inside [build]. [lifetime] is deliberately outside it,
/// because a skin has to arm its dismissal before it renders anything and how
/// long a notice stays is scheduling rather than content.
final class SkinNoticeHost {
  const SkinNoticeHost._(this._envelope, this._spec);

  final SkinEnvelope _envelope;
  final NoticeSpec _spec;

  /// How long the notice stays before it takes itself away.
  NoticeLifetime get lifetime => _spec.lifetime;

  /// Produces the notice, with the skin's own root treatment re-established
  /// around it.
  Widget build(
    BuildContext context,
    Widget Function(BuildContext context, NoticeSpec spec) body,
  ) => _envelope._establish((BuildContext inner) => body(inner, _spec));
}

/// Where the active skin lives in the tree.
///
/// Installed once by the application root, and re-established by the overlay
/// hosts inside every route so that an overlay is drawn by the same skin, in
/// the same brightness, as the surface that opened it.
final class SkinScope extends InheritedWidget {
  /// Installs [skin] over [child].
  SkinScope({
    super.key,
    required Skin skin,
    required SkinRequest request,
    required DialogKeyboardHostBuilder dialogKeyboardHost,
    required super.child,
  }) : envelope = SkinEnvelope._(skin, request, dialogKeyboardHost);

  const SkinScope._carrying({required this.envelope, required super.child});

  /// Everything a route needs in order to be drawn by this skin.
  final SkinEnvelope envelope;

  /// The design language in force.
  Skin get skin => envelope.skin;

  /// The scope in force at [context].
  ///
  /// Throws rather than returning a fallback. A fallback is exactly how the
  /// measured macOS bug ships: a wrongly themed surface that satisfies every
  /// assertion because SOMETHING was found. An application without a scope is
  /// mis-wired, and saying so at the first read is cheaper than rendering the
  /// wrong thing.
  static SkinScope of(BuildContext context) {
    final SkinScope? scope = context
        .dependOnInheritedWidgetOfExactType<SkinScope>();
    if (scope == null) {
      throw FlutterError(
        'No SkinScope found above this widget.\n'
        'Every widget that renders reaches its design language through '
        'SkinScope, which the application installs once at its root and which '
        'the overlay hosts re-establish inside every route. A widget that '
        'cannot find one is either outside the application root or inside an '
        'overlay a skin pushed without rendering the host it was given.',
      );
    }
    return scope;
  }

  /// Installs [skin] at the application root, over the application itself.
  ///
  /// The root is the one place the whole composition is spelled out, and it is
  /// spelled out HERE rather than in `main.dart` so that the application root
  /// and every overlay route agree by construction:
  ///
  /// ```
  /// SkinPainted            <- the walk prunes: the skin's root treatment
  ///   SkinScope
  ///     chrome.wrapRoot
  ///       ContentPortBoundary  <- the walk resumes: the application
  ///         app
  /// ```
  static Widget install({
    required Skin skin,
    required SkinRequest request,
    required DialogKeyboardHostBuilder dialogKeyboardHost,
    required ContentPort app,
  }) => SkinPainted._(
    child: SkinScope(
      skin: skin,
      request: request,
      dialogKeyboardHost: dialogKeyboardHost,
      child: Builder(
        builder: (BuildContext inner) =>
            skin.chrome.wrapRoot(inner, request: request, child: app.mount()),
      ),
    ),
  );

  /// Renders one contract member, fenced.
  ///
  /// One of exactly three places [SkinPainted] is planted, and the only one
  /// application code reaches, so no call site can forget it and the
  /// attribution walk can trust the partition: everything below the fence was
  /// built by a skin, everything above it by the application.
  static Widget render(
    BuildContext context,
    Widget Function(Skin skin, BuildContext context) build,
  ) => SkinPainted._(
    child: Builder(
      builder: (BuildContext inner) => build(of(inner).skin, inner),
    ),
  );

  @override
  bool updateShouldNotify(covariant SkinScope oldWidget) =>
      !identical(oldWidget.envelope.skin, envelope.skin) ||
      oldWidget.envelope.request != envelope.request;
}

/// The only way application code ever reaches a skin.
extension SkinContext on BuildContext {
  /// The design language in force here.
  Skin get skin => SkinScope.of(this).skin;
}

/// The application's ONLY overlay API.
///
/// It captures the envelope, builds the host and hands both to the skin. A
/// skin never gets to define the entry point, so it never gets to skip the
/// wrapper - and because every host can only be constructed here, there is no
/// second way to open an overlay that quietly omits it.
abstract final class Overlays {
  /// Takes the application away until the user answers [spec].
  static Future<T?> dialog<T>(BuildContext context, DialogSpec spec) {
    assert(
      spec.actions
              .where((DialogAction a) => a.role == DialogActionRole.affirmative)
              .length <=
          1,
      'A dialog has at most one affirmative action: it is the one a design '
      'language may single out as its default, and "the default" is not a '
      'set. A dialog offering several equally weighted ways forward gives '
      'them all DialogActionRole.neutral. Offending dialog: "${spec.title}".',
    );
    final SkinEnvelope envelope = SkinEnvelope.capture(context);
    return envelope.skin.overlays.presentDialog<T>(
      context,
      spec,
      SkinContentHost._(
        envelope,
        // Three layers, and the fences between them are what makes the
        // attribution exact: the keyboard host is the APPLICATION's (it owns
        // Escape and Enter), so it resumes at a boundary; the surface inside
        // it is the SKIN's again, so it is fenced again; and the surface
        // mounts `spec.content`, which resumes once more.
        (BuildContext inner) => ContentPort(
          envelope.dialogKeyboardHost(
            inner,
            spec,
            SkinPainted._(
              child: Builder(
                builder: (BuildContext surfaceContext) =>
                    envelope.skin.chrome.dialogSurface(surfaceContext, spec),
              ),
            ),
          ),
        ).mount(),
      ),
    );
  }

  /// Offers [entries] at [at], and reports which one the user chose.
  static Future<int?> menu(
    BuildContext context, {
    required Offset at,
    required List<MenuEntry> entries,
  }) {
    final SkinEnvelope envelope = SkinEnvelope.capture(context);
    return envelope.skin.overlays.presentMenu(
      context,
      at: at,
      host: SkinMenuHost._(envelope, entries),
    );
  }

  /// Builds the control that offers [entries], anchored to itself.
  ///
  /// A widget rather than a future, because the anchor lives in the tree: the
  /// SKIN builds the trigger, measures it and opens the menu against it, so
  /// no call site performs that geometry again. The scope is read inside the
  /// fence - the same arrangement as [SkinScope.render] - so a change of skin
  /// rebuilds the anchor, and the host it constructs carries the envelope in
  /// force at that moment into whatever route the skin opens from it.
  static Widget anchor({
    required MenuAnchorSpec spec,
    required List<MenuEntry> entries,
  }) => SkinPainted._(
    child: Builder(
      builder: (BuildContext inner) {
        final SkinEnvelope envelope = SkinScope.of(inner).envelope;
        return envelope.skin.overlays.menuAnchor(
          inner,
          spec,
          SkinMenuHost._(envelope, entries),
        );
      },
    ),
  );

  /// Attaches [content] to the control the user just operated.
  static Future<T?> popover<T>(
    BuildContext context,
    PopoverSpec spec,
    ContentPort content,
  ) {
    final SkinEnvelope envelope = SkinEnvelope.capture(context);
    return envelope.skin.overlays.presentPopover<T>(
      context,
      spec,
      SkinContentHost._(envelope, (BuildContext _) => content.mount()),
    );
  }

  /// Tells the user [spec] happened, without taking the application away.
  static NoticeHandle notify(BuildContext context, NoticeSpec spec) {
    final SkinEnvelope envelope = SkinEnvelope.capture(context);
    return envelope.skin.overlays.notify(
      context,
      SkinNoticeHost._(envelope, spec),
    );
  }
}
