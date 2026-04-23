import 'dart:async';

import 'package:flutter/material.dart';

void main() {
  runApp(const KabuRuleApp());
}

class KabuRuleApp extends StatelessWidget {
  const KabuRuleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '決算ショート通知',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
      ),
      home: const RootPage(),
    );
  }
}

class RootPage extends StatefulWidget {
  const RootPage({super.key});

  @override
  State<RootPage> createState() => _RootPageState();
}

class _RootPageState extends State<RootPage> {
  late final KabuController _controller;
  Timer? _scheduler;
  int _selectedIndex = 0;

  static const List<String> _titles = [
    'おすすめ',
    '手動取得',
    '収益確認',
    '設定',
  ];

  @override
  void initState() {
    super.initState();
    _controller = KabuController();
    _controller.addListener(_onControllerChanged);
    _scheduler = Timer.periodic(const Duration(minutes: 1), (_) {
      _controller.runScheduledIfDue();
    });
  }

  void _onControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _scheduler?.cancel();
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  void _fetchAll() {
    _controller.fetchPrices();
    _showResultSnackbar('株価を手動取得しました');
  }

  void _fetchMissingOnly() {
    final updated = _controller.fetchPrices(onlyMissing: true);
    if (updated == 0) {
      _showResultSnackbar('未取得データはありません');
      return;
    }
    _showResultSnackbar('未取得データを$updated件更新しました');
  }

  void _sendTestNotification() {
    _controller.sendTestNotification();
    _showResultSnackbar('通知テストを送信しました');
  }

  void _showResultSnackbar(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final tabs = [
      RecommendationTab(controller: _controller, onFetchAll: _fetchAll),
      ManualFetchTab(
        controller: _controller,
        onFetchAll: _fetchAll,
        onFetchMissing: _fetchMissingOnly,
      ),
      ProfitTab(controller: _controller),
      SettingsTab(
        controller: _controller,
        onSendTestNotification: _sendTestNotification,
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
      ),
      body: IndexedStack(index: _selectedIndex, children: tabs),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        type: BottomNavigationBarType.fixed,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.recommend), label: 'おすすめ'),
          BottomNavigationBarItem(icon: Icon(Icons.sync), label: '手動取得'),
          BottomNavigationBarItem(icon: Icon(Icons.savings), label: '収益確認'),
          BottomNavigationBarItem(icon: Icon(Icons.settings), label: '設定'),
        ],
      ),
    );
  }
}

class RecommendationTab extends StatelessWidget {
  const RecommendationTab({
    required this.controller,
    required this.onFetchAll,
    super.key,
  });

  final KabuController controller;
  final VoidCallback onFetchAll;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const StrategySummaryCard(),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: Text(
                '通知候補（最大2銘柄）',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            ElevatedButton.icon(
              onPressed: onFetchAll,
              icon: const Icon(Icons.download),
              label: const Text('株価取得'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (controller.recommendations.isEmpty)
          const Card(
            child: ListTile(
              title: Text('おすすめ銘柄はまだありません'),
              subtitle: Text('株価取得後に通知候補が表示されます。'),
            ),
          )
        else
          ...controller.recommendations
              .map((item) => RecommendationCard(item: item, controller: controller)),
        const SizedBox(height: 16),
        const ExitRulesCard(),
      ],
    );
  }
}

class ManualFetchTab extends StatelessWidget {
  const ManualFetchTab({
    required this.controller,
    required this.onFetchAll,
    required this.onFetchMissing,
    super.key,
  });

  final KabuController controller;
  final VoidCallback onFetchAll;
  final VoidCallback onFetchMissing;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('手動で株価取得', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text('最終取得: ${formatDateTime(controller.lastFetchedAt)}'),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ElevatedButton.icon(
                      onPressed: onFetchAll,
                      icon: const Icon(Icons.refresh),
                      label: const Text('全銘柄を取得'),
                    ),
                    OutlinedButton.icon(
                      onPressed: onFetchMissing,
                      icon: const Icon(Icons.update),
                      label: const Text('未取得のみ更新'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (controller.bestRecommendation == null)
          const Card(
            child: ListTile(
              title: Text('1番おすすめは未判定'),
              subtitle: Text('株価取得後に表示されます。'),
            ),
          )
        else
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: ListTile(
              leading: const Icon(Icons.emoji_events),
              title: Text(
                '1番おすすめ: '
                '${controller.bestRecommendation!.stock.code} '
                '${controller.bestRecommendation!.stock.name}',
              ),
              subtitle: Text(controller.bestRecommendation!.reason),
            ),
          ),
        const SizedBox(height: 12),
        Text('銘柄取得ステータス', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        ...controller.stocks.map((stock) {
          final judgement = controller.engine.judge(stock);
          return Card(
            child: ListTile(
              title: Text('${stock.code} ${stock.name}'),
              subtitle: Text(
                '適合: ${judgement.matchedRuleCount}/${RecommendationEngine.totalRules} '
                '取得: ${formatDateTime(stock.lastFetchedAt)}',
              ),
              trailing: FetchedStatusChip(lastFetchedAt: stock.lastFetchedAt),
            ),
          );
        }),
      ],
    );
  }
}

class ProfitTab extends StatelessWidget {
  const ProfitTab({required this.controller, super.key});

  final KabuController controller;

  @override
  Widget build(BuildContext context) {
    final totalPosition = controller.recommendations.fold<double>(
      0,
      (sum, recommendation) => sum + recommendation.positionYen,
    );
    final totalMaxLoss = controller.recommendations.fold<double>(
      0,
      (sum, recommendation) => sum + recommendation.maxLossYen,
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('収益サマリー', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text('合計建玉目安: ${totalPosition.toStringAsFixed(0)}円'),
                Text('想定最大損失: ${totalMaxLoss.toStringAsFixed(0)}円'),
                Text('最終更新: ${formatDateTime(controller.lastFetchedAt)}'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (controller.recommendations.isEmpty)
          const Card(
            child: ListTile(
              title: Text('収益確認データがありません'),
              subtitle: Text('手動取得または定時取得後に確認できます。'),
            ),
          )
        else
          ...controller.recommendations.map(
            (item) => Card(
              child: ListTile(
                title: Text('${item.stock.code} ${item.stock.name}'),
                subtitle: Text(
                  '建玉: ${item.positionYen.toStringAsFixed(0)}円 '
                  '/ 想定最大損失: ${item.maxLossYen.toStringAsFixed(0)}円',
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class SettingsTab extends StatelessWidget {
  const SettingsTab({
    required this.controller,
    required this.onSendTestNotification,
    super.key,
  });

  final KabuController controller;
  final VoidCallback onSendTestNotification;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('定時バックグラウンド取得', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                const Text('毎朝 08:00 に自動取得を実行します。'),
                Text('次回予定: ${formatDateTime(controller.nextScheduledFetchAt)}'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: onSendTestNotification,
          icon: const Icon(Icons.notifications_active),
          label: const Text('通知テストを送信'),
        ),
        const SizedBox(height: 12),
        Text('通知履歴', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        if (controller.notifications.isEmpty)
          const Card(
            child: ListTile(
              title: Text('通知はまだありません'),
            ),
          )
        else
          ...controller.notifications.map(
            (notice) => Card(
              child: ListTile(
                leading: const Icon(Icons.notifications),
                title: Text(notice.title),
                subtitle: Text('${notice.message}\n${formatDateTime(notice.createdAt)}'),
              ),
            ),
          ),
      ],
    );
  }
}

class StrategySummaryCard extends StatelessWidget {
  const StrategySummaryCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('前提', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('・日本株（東証）一般信用ショート'),
            const Text('・決算前日引けIN → 決算当日前場引けOUT'),
            Text(
              '・口座${RecommendationEngine.accountSizeYen.toStringAsFixed(0)}円 '
              '/ 1回最大損失${RecommendationEngine.maxLossPerTradeYen.toStringAsFixed(0)}円',
            ),
            Text(
              '・損切り +${RecommendationEngine.stopLossPercent}% / '
              '建玉目安 '
              '${RecommendationEngine.recommendedMinPositionYen.toStringAsFixed(0)}'
              '〜${RecommendationEngine.maxPositionYen.toStringAsFixed(0)}円',
            ),
          ],
        ),
      ),
    );
  }
}

class ExitRulesCard extends StatelessWidget {
  const ExitRulesCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('当日撤退ルール', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('1. 建値から +1.5% で成行撤退'),
            Text('2. 寄りで +3%超逆行なら即撤退'),
            Text('3. 10:30時点で含み益なしなら撤退'),
            Text('4. それ以外は前場引けで全決済（持ち越し禁止）'),
            Text('5. +1.0%で半分、+2.0%で残り利確'),
          ],
        ),
      ),
    );
  }
}

class RecommendationCard extends StatelessWidget {
  const RecommendationCard({
    required this.item,
    required this.controller,
    super.key,
  });

  final Recommendation item;
  final KabuController controller;

  @override
  Widget build(BuildContext context) {
    final judgement = controller.engine.judge(item.stock);
    return Card(
      child: ListTile(
        title: Text('${item.stock.code} ${item.stock.name}'),
        subtitle: Text(
          '通知理由: ${item.reason}\n'
          '適合: ${judgement.matchedRuleCount}/${RecommendationEngine.totalRules} '
          '建玉目安: ${item.positionYen.toStringAsFixed(0)}円 / '
          '概算株数: ${item.shares}株 / 想定最大損失: ${item.maxLossYen.toStringAsFixed(0)}円',
        ),
        trailing: const Icon(Icons.notifications_active),
      ),
    );
  }
}

class FetchedStatusChip extends StatelessWidget {
  const FetchedStatusChip({required this.lastFetchedAt, super.key});

  final DateTime? lastFetchedAt;

  @override
  Widget build(BuildContext context) {
    final isFetched = lastFetchedAt != null;
    return Chip(
      label: Text(isFetched ? '取得済み' : '未取得'),
      backgroundColor: isFetched
          ? Theme.of(context).colorScheme.secondaryContainer
          : Theme.of(context).colorScheme.errorContainer,
    );
  }
}

class KabuController extends ChangeNotifier {
  KabuController({
    RecommendationEngine? engine,
    List<StockSnapshot>? initialStocks,
    DateTime Function()? nowProvider,
  })  : engine = engine ?? RecommendationEngine(),
        _nowProvider = nowProvider ?? DateTime.now,
        _stocks = List<StockSnapshot>.from(initialStocks ?? sampleStocks),
        nextScheduledFetchAt = _computeNextScheduledFetch(
          (nowProvider ?? DateTime.now)(),
        );

  static const int morningFetchHour = 8;

  final RecommendationEngine engine;
  final DateTime Function() _nowProvider;
  List<StockSnapshot> _stocks;

  List<Recommendation> recommendations = const [];
  Recommendation? bestRecommendation;
  List<AppNotification> notifications = const [];
  DateTime? lastFetchedAt;
  DateTime nextScheduledFetchAt;

  List<StockSnapshot> get stocks => List.unmodifiable(_stocks);

  int fetchPrices({bool onlyMissing = false, bool fromSchedule = false}) {
    final now = _nowProvider();
    var updatedCount = 0;
    _stocks = _stocks.map((stock) {
      if (onlyMissing && stock.lastFetchedAt != null) {
        return stock;
      }
      updatedCount += 1;
      return stock.copyWith(lastFetchedAt: now);
    }).toList(growable: false);

    if (updatedCount == 0) {
      return 0;
    }

    _afterFetch(now, fromSchedule: fromSchedule);
    notifyListeners();
    return updatedCount;
  }

  bool runScheduledIfDue() {
    final now = _nowProvider();
    if (now.isBefore(nextScheduledFetchAt)) {
      return false;
    }
    fetchPrices(fromSchedule: true);
    return true;
  }

  void sendTestNotification() {
    final now = _nowProvider();
    notifications = [
      AppNotification(
        title: '通知テスト',
        message: '通知が正常に届いています。',
        createdAt: now,
      ),
      ...notifications,
    ];
    notifyListeners();
  }

  void _afterFetch(DateTime fetchedAt, {required bool fromSchedule}) {
    recommendations = engine.buildRecommendations(_stocks);
    bestRecommendation = recommendations.isEmpty ? null : recommendations.first;
    lastFetchedAt = fetchedAt;
    nextScheduledFetchAt = _computeNextScheduledFetch(fetchedAt);

    if (recommendations.isNotEmpty) {
      notifications = [
        AppNotification(
          title: fromSchedule ? '定時おすすめ通知' : 'おすすめ通知',
          message: 'おすすめ銘柄: '
              '${recommendations.first.stock.code} '
              '${recommendations.first.stock.name}',
          createdAt: fetchedAt,
        ),
        ...notifications,
      ];
    }
  }

  static DateTime _computeNextScheduledFetch(DateTime now) {
    final todayAtMorning = DateTime(now.year, now.month, now.day, morningFetchHour);
    if (now.isBefore(todayAtMorning)) {
      return todayAtMorning;
    }
    return todayAtMorning.add(const Duration(days: 1));
  }
}

class AppNotification {
  const AppNotification({
    required this.title,
    required this.message,
    required this.createdAt,
  });

  final String title;
  final String message;
  final DateTime createdAt;
}

class RecommendationEngine {
  static const double accountSizeYen = 300000;
  static const double maxLossPerTradeYen = 900;
  static const double stopLossPercent = 1.5;
  static const double maxBorrowFeePercent = 5;
  static const double recommendedMinPositionYen = 50000;
  static const double maxPositionYen = 60000;
  static const int totalRules = 16;

  CandidateJudgement judge(StockSnapshot stock) {
    final violations = <String>[];

    if (stock.isPrimeMarket == false) {
      violations.add('東証プライム以外');
    }
    if (stock.marketCapBillionYen < 500) {
      violations.add('時価総額500億円未満');
    }
    if (stock.avgTurnoverBillionYen20d < 5) {
      violations.add('20日平均売買代金5億円未満');
    }
    if (stock.priceYen < 1000 || stock.priceYen > 8000) {
      violations.add('株価レンジ外（1,000〜8,000円）');
    }
    if (stock.borrowFeeAnnualPercent > maxBorrowFeePercent) {
      violations.add('一般信用貸株料が5%超');
    }
    if (stock.hasWideSpread) {
      violations.add('スプレッドが厚い');
    }
    if (stock.isSpeculativeSmallCap) {
      violations.add('急騰しやすい材料系銘柄');
    }
    if (stock.isExDividendWindow) {
      violations.add('権利付き最終日周辺');
    }
    if (stock.isInBuybackExclusionList) {
      violations.add('自社株買い発表が出やすい銘柄');
    }
    if (stock.roundTripCostPercent > 0.2) {
      violations.add('往復コスト目安0.2%超');
    }

    if (stock.priceChange20dPercent < 12) {
      violations.add('20営業日騰落が+12%未満');
    }
    if (stock.priceChange5dPercent < 4) {
      violations.add('5営業日騰落が+4%未満');
    }
    if (stock.closeAboveMa20Percent < 6) {
      violations.add('終値が20日線+6%未満');
    }
    if (stock.rsi14 < 65) {
      violations.add('RSI(14)が65未満');
    }
    if (stock.pullbackFromHighToClosePercent > -1.5) {
      violations.add('高値から引けへの押しが-1.5%未満');
    }
    if (stock.vwapAvailable && !stock.isCloseBelowVwap) {
      violations.add('終値がVWAP未満ではない');
    }

    final score = stock.priceChange20dPercent +
        stock.priceChange5dPercent +
        stock.rsi14 +
        stock.closeAboveMa20Percent;

    return CandidateJudgement(
      isRecommended: violations.isEmpty,
      violations: violations,
      score: score,
    );
  }

  List<Recommendation> buildRecommendations(List<StockSnapshot> stocks) {
    final sizedPosition = maxLossPerTradeYen / (stopLossPercent / 100);
    final positionYen =
        sizedPosition > maxPositionYen ? maxPositionYen : sizedPosition;

    final ranked = stocks
        .map((stock) => (stock: stock, judgement: judge(stock)))
        .where((item) => item.judgement.isRecommended)
        .toList()
      ..sort((a, b) => b.judgement.score.compareTo(a.judgement.score));

    return ranked.take(2).map((item) {
      final shares = (positionYen / item.stock.priceYen).floor();
      return Recommendation(
        stock: item.stock,
        positionYen: positionYen,
        shares: shares,
        maxLossYen: positionYen * (stopLossPercent / 100),
        reason:
            '20日+${item.stock.priceChange20dPercent.toStringAsFixed(1)}%、'
            '5日+${item.stock.priceChange5dPercent.toStringAsFixed(1)}%、'
            'RSI${item.stock.rsi14.toStringAsFixed(1)}',
      );
    }).toList(growable: false);
  }
}

class StockSnapshot {
  const StockSnapshot({
    required this.code,
    required this.name,
    required this.isPrimeMarket,
    required this.marketCapBillionYen,
    required this.avgTurnoverBillionYen20d,
    required this.priceYen,
    required this.borrowFeeAnnualPercent,
    required this.priceChange20dPercent,
    required this.priceChange5dPercent,
    required this.closeAboveMa20Percent,
    required this.rsi14,
    required this.pullbackFromHighToClosePercent,
    required this.vwapAvailable,
    required this.isCloseBelowVwap,
    required this.hasWideSpread,
    required this.isSpeculativeSmallCap,
    required this.isExDividendWindow,
    required this.isInBuybackExclusionList,
    required this.roundTripCostPercent,
    this.lastFetchedAt,
  });

  final String code;
  final String name;
  final bool isPrimeMarket;
  final double marketCapBillionYen;
  final double avgTurnoverBillionYen20d;
  final double priceYen;
  final double borrowFeeAnnualPercent;
  final double priceChange20dPercent;
  final double priceChange5dPercent;
  final double closeAboveMa20Percent;
  final double rsi14;
  final double pullbackFromHighToClosePercent;
  final bool vwapAvailable;
  final bool isCloseBelowVwap;
  final bool hasWideSpread;
  final bool isSpeculativeSmallCap;
  final bool isExDividendWindow;
  final bool isInBuybackExclusionList;
  final double roundTripCostPercent;
  final DateTime? lastFetchedAt;

  StockSnapshot copyWith({
    String? code,
    String? name,
    bool? isPrimeMarket,
    double? marketCapBillionYen,
    double? avgTurnoverBillionYen20d,
    double? priceYen,
    double? borrowFeeAnnualPercent,
    double? priceChange20dPercent,
    double? priceChange5dPercent,
    double? closeAboveMa20Percent,
    double? rsi14,
    double? pullbackFromHighToClosePercent,
    bool? vwapAvailable,
    bool? isCloseBelowVwap,
    bool? hasWideSpread,
    bool? isSpeculativeSmallCap,
    bool? isExDividendWindow,
    bool? isInBuybackExclusionList,
    double? roundTripCostPercent,
    DateTime? lastFetchedAt,
  }) {
    return StockSnapshot(
      code: code ?? this.code,
      name: name ?? this.name,
      isPrimeMarket: isPrimeMarket ?? this.isPrimeMarket,
      marketCapBillionYen: marketCapBillionYen ?? this.marketCapBillionYen,
      avgTurnoverBillionYen20d:
          avgTurnoverBillionYen20d ?? this.avgTurnoverBillionYen20d,
      priceYen: priceYen ?? this.priceYen,
      borrowFeeAnnualPercent:
          borrowFeeAnnualPercent ?? this.borrowFeeAnnualPercent,
      priceChange20dPercent:
          priceChange20dPercent ?? this.priceChange20dPercent,
      priceChange5dPercent: priceChange5dPercent ?? this.priceChange5dPercent,
      closeAboveMa20Percent: closeAboveMa20Percent ?? this.closeAboveMa20Percent,
      rsi14: rsi14 ?? this.rsi14,
      pullbackFromHighToClosePercent:
          pullbackFromHighToClosePercent ?? this.pullbackFromHighToClosePercent,
      vwapAvailable: vwapAvailable ?? this.vwapAvailable,
      isCloseBelowVwap: isCloseBelowVwap ?? this.isCloseBelowVwap,
      hasWideSpread: hasWideSpread ?? this.hasWideSpread,
      isSpeculativeSmallCap: isSpeculativeSmallCap ?? this.isSpeculativeSmallCap,
      isExDividendWindow: isExDividendWindow ?? this.isExDividendWindow,
      isInBuybackExclusionList:
          isInBuybackExclusionList ?? this.isInBuybackExclusionList,
      roundTripCostPercent: roundTripCostPercent ?? this.roundTripCostPercent,
      lastFetchedAt: lastFetchedAt ?? this.lastFetchedAt,
    );
  }
}

class CandidateJudgement {
  const CandidateJudgement({
    required this.isRecommended,
    required this.violations,
    required this.score,
  });

  final bool isRecommended;
  final List<String> violations;
  final double score;

  int get matchedRuleCount =>
      (RecommendationEngine.totalRules - violations.length).clamp(0, RecommendationEngine.totalRules);
}

class Recommendation {
  const Recommendation({
    required this.stock,
    required this.positionYen,
    required this.shares,
    required this.maxLossYen,
    required this.reason,
  });

  final StockSnapshot stock;
  final double positionYen;
  final int shares;
  final double maxLossYen;
  final String reason;
}

String formatDateTime(DateTime? dateTime) {
  if (dateTime == null) {
    return '未取得';
  }
  String twoDigits(int value) => value.toString().padLeft(2, '0');
  return '${dateTime.year}/${twoDigits(dateTime.month)}/${twoDigits(dateTime.day)} '
      '${twoDigits(dateTime.hour)}:${twoDigits(dateTime.minute)}';
}

const List<StockSnapshot> sampleStocks = [
  StockSnapshot(
    code: '6501',
    name: '日立製作所',
    isPrimeMarket: true,
    marketCapBillionYen: 145000,
    avgTurnoverBillionYen20d: 140,
    priceYen: 3900,
    borrowFeeAnnualPercent: 1.2,
    priceChange20dPercent: 14.8,
    priceChange5dPercent: 4.8,
    closeAboveMa20Percent: 6.8,
    rsi14: 68,
    pullbackFromHighToClosePercent: -1.7,
    vwapAvailable: true,
    isCloseBelowVwap: true,
    hasWideSpread: false,
    isSpeculativeSmallCap: false,
    isExDividendWindow: false,
    isInBuybackExclusionList: false,
    roundTripCostPercent: 0.12,
  ),
  StockSnapshot(
    code: '6758',
    name: 'ソニーグループ',
    isPrimeMarket: true,
    marketCapBillionYen: 170000,
    avgTurnoverBillionYen20d: 180,
    priceYen: 7800,
    borrowFeeAnnualPercent: 0.8,
    priceChange20dPercent: 13.2,
    priceChange5dPercent: 5.2,
    closeAboveMa20Percent: 6.2,
    rsi14: 69,
    pullbackFromHighToClosePercent: -1.8,
    vwapAvailable: true,
    isCloseBelowVwap: true,
    hasWideSpread: false,
    isSpeculativeSmallCap: false,
    isExDividendWindow: false,
    isInBuybackExclusionList: false,
    roundTripCostPercent: 0.1,
  ),
  StockSnapshot(
    code: '9984',
    name: 'ソフトバンクG',
    isPrimeMarket: true,
    marketCapBillionYen: 14500,
    avgTurnoverBillionYen20d: 220,
    priceYen: 7900,
    borrowFeeAnnualPercent: 2.0,
    priceChange20dPercent: 16.5,
    priceChange5dPercent: 7.2,
    closeAboveMa20Percent: 9.1,
    rsi14: 72,
    pullbackFromHighToClosePercent: -2.2,
    vwapAvailable: true,
    isCloseBelowVwap: true,
    hasWideSpread: false,
    isSpeculativeSmallCap: false,
    isExDividendWindow: false,
    isInBuybackExclusionList: true,
    roundTripCostPercent: 0.13,
  ),
  StockSnapshot(
    code: '7974',
    name: '任天堂',
    isPrimeMarket: true,
    marketCapBillionYen: 110000,
    avgTurnoverBillionYen20d: 90,
    priceYen: 7900,
    borrowFeeAnnualPercent: 1.1,
    priceChange20dPercent: 10.0,
    priceChange5dPercent: 3.5,
    closeAboveMa20Percent: 5.0,
    rsi14: 60,
    pullbackFromHighToClosePercent: -0.9,
    vwapAvailable: true,
    isCloseBelowVwap: false,
    hasWideSpread: false,
    isSpeculativeSmallCap: false,
    isExDividendWindow: false,
    isInBuybackExclusionList: false,
    roundTripCostPercent: 0.11,
  ),
  StockSnapshot(
    code: '4063',
    name: '信越化学工業',
    isPrimeMarket: true,
    marketCapBillionYen: 98000,
    avgTurnoverBillionYen20d: 70,
    priceYen: 5900,
    borrowFeeAnnualPercent: 0.9,
    priceChange20dPercent: 12.8,
    priceChange5dPercent: 4.4,
    closeAboveMa20Percent: 6.1,
    rsi14: 66,
    pullbackFromHighToClosePercent: -1.6,
    vwapAvailable: true,
    isCloseBelowVwap: true,
    hasWideSpread: false,
    isSpeculativeSmallCap: false,
    isExDividendWindow: false,
    isInBuybackExclusionList: false,
    roundTripCostPercent: 0.14,
  ),
];
