import '../spec/app_spec.dart';
import 'brick.dart';

/// Crash and error capture, and the screen that shows it.
///
/// A released app that cannot see its own runtime failures is guessing. This
/// matters more in a `material_ui` project than in a normal one: the two worst
/// failure modes — a lost route transition, a theme falling back — pass
/// `flutter analyze` and appear only at runtime, on a device you do not have.
///
/// Always applied. There is no configuration for it because there is no app
/// for which "silently lose every error" is the right default, and everything
/// it captures stays on the device unless the user taps share.
class ErrorCaptureBrick extends Brick {
  const ErrorCaptureBrick();

  @override
  String get id => 'error_capture';

  @override
  String get summary =>
      'crash/error capture (Flutter, platform and zone) with a Diagnostics screen';

  @override
  bool appliesTo(AppSpec spec) => true;

  @override
  List<TemplateFile> files(AppSpec spec) => [
    const TemplateFile(
      'error/error_record.dart.tmpl',
      'lib/core/error/error_record.dart',
    ),
    const TemplateFile(
      'error/error_logger.dart.tmpl',
      'lib/core/error/error_logger.dart',
    ),
    const TemplateFile(
      'error/diagnostics_screen.dart.tmpl',
      'lib/features/settings/diagnostics_screen.dart',
    ),
    const TemplateFile(
      'error/error_logger_test.dart.tmpl',
      'test/error_logger_test.dart',
    ),
    // The remote sink is generated but not wired up — see `main.dart`.
    // Reporting errors off-device is a privacy decision, not a default.
    if (spec.usesAppwrite)
      const TemplateFile(
        'error/appwrite_error_sink.dart.tmpl',
        'lib/core/error/appwrite_error_sink.dart',
      ),
  ];
}
