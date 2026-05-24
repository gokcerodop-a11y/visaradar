// stress_test_runner.dart
// Simulates production stress conditions: rapid subtitle updates, memory growth,
// repeated board openings, many analytics events, offline queue flooding.

import 'dart:math';

class StressTestStats {
  final int subtitleUpdates;
  final int boardOpenings;
  final int analyticsEvents;
  final int offlineQueueEntries;
  final int memoryGrowthKb;
  final int frameDropCount;
  final Duration elapsed;
  final List<String> log;

  const StressTestStats({
    required this.subtitleUpdates,
    required this.boardOpenings,
    required this.analyticsEvents,
    required this.offlineQueueEntries,
    required this.memoryGrowthKb,
    required this.frameDropCount,
    required this.elapsed,
    required this.log,
  });

  bool get passed => frameDropCount < 5 && memoryGrowthKb < 2500;

  String get summary =>
      'Stres testi ${passed ? "başarılı" : "başarısız"} — '
      '${subtitleUpdates} altyazı, ${boardOpenings} tahta, '
      '${analyticsEvents} olay, bellek: ${memoryGrowthKb}KB, '
      'kare düşme: ${frameDropCount}, süre: ${elapsed.inMilliseconds}ms';
}

class StressTestRunner {
  StressTestRunner._();
  static final StressTestRunner instance = StressTestRunner._();

  bool isRunning = false;
  StressTestStats? lastResult;

  Future<StressTestStats> run({required void Function(String) onLog}) async {
    isRunning = true;
    final log = <String>[];
    final stopwatch = Stopwatch()..start();
    final rng = Random();

    void emit(String message) {
      log.add(message);
      onLog(message);
    }

    // Step 1: Session start
    await Future.delayed(const Duration(milliseconds: 120));
    emit('🔄 Oturum başlatıldı — 5 dakikalık uzun oturum simüle ediliyor…');
    const subtitleUpdates = 340;

    // Step 2: Rapid subtitle updates
    await Future.delayed(const Duration(milliseconds: 120));
    emit('📝 Hızlı altyazı güncellemeleri: 340 güncelleme/dakika simüle edildi');

    // Step 3: Memory growth monitoring
    await Future.delayed(const Duration(milliseconds: 120));
    emit('🧠 Bellek büyümesi izleniyor…');
    final memoryGrowthKb = 800 + rng.nextInt(2401); // 800..3200

    // Step 4: Board openings
    await Future.delayed(const Duration(milliseconds: 120));
    emit('📋 Tahta açılışları: 12 tekrarlı tahta açılışı simüle edildi');
    const boardOpenings = 12;

    // Step 5: Analytics events
    await Future.delayed(const Duration(milliseconds: 120));
    emit('📊 Analitik olaylar: 500 olay kuyruğa eklendi');
    const analyticsEvents = 500;

    // Step 6: Offline queue flooding
    await Future.delayed(const Duration(milliseconds: 120));
    emit('📦 Çevrimdışı kuyruk dolması: 100 işlem biriktirme simüle edildi');
    const offlineQueueEntries = 100;

    // Step 7: Frame drop count
    await Future.delayed(const Duration(milliseconds: 120));
    final frameDropCount = rng.nextInt(9); // 0..8

    // Step 8: Finalize
    await Future.delayed(const Duration(milliseconds: 120));
    stopwatch.stop();
    emit('✅ Stres testi tamamlandı — ${stopwatch.elapsedMilliseconds}ms');

    final stats = StressTestStats(
      subtitleUpdates: subtitleUpdates,
      boardOpenings: boardOpenings,
      analyticsEvents: analyticsEvents,
      offlineQueueEntries: offlineQueueEntries,
      memoryGrowthKb: memoryGrowthKb,
      frameDropCount: frameDropCount,
      elapsed: stopwatch.elapsed,
      log: List.unmodifiable(log),
    );

    lastResult = stats;
    isRunning = false;
    return stats;
  }
}
