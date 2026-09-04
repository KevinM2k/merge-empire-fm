/// How long a shell route's slide runs. The JS's is 220ms.
///
/// The tabs no longer slide at all — a page opens on the tap — so this times
/// only the routes in `shell_routes.dart` and the tutorial's wait for them.
library;

const Duration tabSlideDuration = Duration(milliseconds: 220);
