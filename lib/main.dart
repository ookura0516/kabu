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
      home: const RecommendationPage(),
    );
  }
}

class RecommendationPage extends StatelessWidget {
  const RecommendationPage({super.key});

  @override
  Widget build(BuildContext context) {
    final engine = RecommendationEngine();
    final recommendations = engine.buildRecommendations(sampleStocks);

    return Scaffold(
      appBar: AppBar(
        title: const Text('決算ショート通知候補'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const StrategySummaryCard(),
          const SizedBox(height: 16),
          Text(
            '通知候補（最大2銘柄）',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          if (recommendations.isEmpty)
            const Card(
              child: ListTile(
                title: Text('本日の条件一致なし'),
                subtitle: Text('ルール2を満たした銘柄のみ通知します。'),
              ),
            )
          else
            ...recommendations.map(
              (item) => RecommendationCard(item: item),
            ),
          const SizedBox(height: 16),
          const ExitRulesCard(),
        ],
      ),
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
          children: const [
            Text('前提', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text('・日本株（東証）一般信用ショート'),
            Text('・決算前日引けIN → 決算当日前場引けOUT'),
            Text('・口座30万円 / 1回最大損失900円'),
            Text('・損切り +1.5% / 建玉目安 50,000〜60,000円'),
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
  const RecommendationCard({required this.item, super.key});

  final Recommendation item;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text('${item.stock.code} ${item.stock.name}'),
        subtitle: Text(
          '通知理由: ${item.reason}\n'
          '建玉目安: ${item.positionYen.toStringAsFixed(0)}円 / '
          '概算株数: ${item.shares}株 / 想定最大損失: ${item.maxLossYen.toStringAsFixed(0)}円',
        ),
        trailing: const Icon(Icons.notifications_active),
      ),
    );
  }
}

class RecommendationEngine {
  static const double accountSizeYen = 300000;
  static const double maxLossPerTradeYen = 900;
  static const double stopLossPercent = 1.5;
  static const double maxBorrowFeePercent = 5;
  static const double maxPositionYen = 60000;

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
    }).toList();
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
