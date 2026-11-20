enum WebCheckoutDismissal { ignored, cancelled, unknown }

/// A failed attempt can be retried while checkout remains open. Only decide
/// what happened when checkout succeeds or closes.
class WebCheckoutOutcome {
  bool _finished = false;
  bool _sawFailure = false;

  void recordFailure() {
    if (!_finished) _sawFailure = true;
  }

  bool completeSuccess() {
    if (_finished) return false;
    _finished = true;
    return true;
  }

  WebCheckoutDismissal dismiss() {
    if (_finished) return WebCheckoutDismissal.ignored;
    _finished = true;
    return _sawFailure
        ? WebCheckoutDismissal.unknown
        : WebCheckoutDismissal.cancelled;
  }
}
