/// A user-facing error. The runner prints [message] (one clean line, no stack
/// trace) and exits with [exitCode].
class CliException implements Exception {
  CliException(this.message, {this.exitCode = 1});

  final String message;
  final int exitCode;

  @override
  String toString() => message;
}
