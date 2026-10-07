class GuardrailLatencyReport {
  final int totalQueries;
  final double minMs;
  final double maxMs;
  final double averageMs;
  final double p50Ms;
  final double p75Ms;
  final double p95Ms;
  final bool passedP75Guardrail;

  const GuardrailLatencyReport({
    required this.totalQueries,
    required this.minMs,
    required this.maxMs,
    required this.averageMs,
    required this.p50Ms,
    required this.p75Ms,
    required this.p95Ms,
    required this.passedP75Guardrail,
  });
}

class GuardrailRunner {
  /// Evaluates query execution latency across a set of benchmark queries and checks the p75 <= 100ms guardrail.
  static Future<GuardrailLatencyReport> evaluateLatencyGuardrail({
    required List<String> queries,
    required Future<void> Function(String query) executor,
    double p75ThresholdMs = 100.0,
  }) async {
    final latencies = <double>[];

    for (final q in queries) {
      final sw = Stopwatch()..start();
      await executor(q);
      sw.stop();
      latencies.add(sw.elapsedMicroseconds / 1000.0);
    }

    latencies.sort();

    final n = latencies.length;
    final minMs = latencies.first;
    final maxMs = latencies.last;
    final avgMs = latencies.reduce((a, b) => a + b) / n;

    final p50Idx = (n * 0.50).floor().clamp(0, n - 1);
    final p75Idx = (n * 0.75).floor().clamp(0, n - 1);
    final p95Idx = (n * 0.95).floor().clamp(0, n - 1);

    final p50Ms = latencies[p50Idx];
    final p75Ms = latencies[p75Idx];
    final p95Ms = latencies[p95Idx];

    return GuardrailLatencyReport(
      totalQueries: n,
      minMs: minMs,
      maxMs: maxMs,
      averageMs: avgMs,
      p50Ms: p50Ms,
      p75Ms: p75Ms,
      p95Ms: p95Ms,
      passedP75Guardrail: p75Ms <= p75ThresholdMs,
    );
  }

  /// Verifies candidate model does not suffer > 10% degradation in early skip rate compared to baseline.
  static bool checkRegressionBan({
    required double baselineEarlySkipRate,
    required double candidateEarlySkipRate,
    double maxDegradationTolerance = 0.10,
  }) {
    if (baselineEarlySkipRate <= 0.0) {
      return candidateEarlySkipRate <= 0.20;
    }
    final allowedMax = baselineEarlySkipRate * (1.0 + maxDegradationTolerance);
    return candidateEarlySkipRate <= allowedMax;
  }
}
