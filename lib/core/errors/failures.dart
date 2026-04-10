/// Base failure class for all domain-level errors.
abstract class Failure {
  const Failure(this.message);
  final String message;
}

class LocationFailure extends Failure {
  const LocationFailure([super.message = 'Location unavailable']);
}

class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'Network error']);
}

class StorageFailure extends Failure {
  const StorageFailure([super.message = 'Storage error']);
}

class PermissionFailure extends Failure {
  const PermissionFailure([super.message = 'Permission denied']);
}

class UnknownFailure extends Failure {
  const UnknownFailure([super.message = 'Unknown error']);
}
