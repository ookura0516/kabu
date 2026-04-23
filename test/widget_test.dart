import 'package:flutter_test/flutter_test.dart';

import 'package:kabu/main.dart';

void main() {
  test('judge returns recommended when all rules are satisfied', () {
    const stock = StockSnapshot(
      code: '1111',
      name: 'テスト銘柄',
      isPrimeMarket: true,
      marketCapBillionYen: 1000,
      avgTurnoverBillionYen20d: 10,
      priceYen: 3500,
      borrowFeeAnnualPercent: 2,
      priceChange20dPercent: 13,
      priceChange5dPercent: 5,
      closeAboveMa20Percent: 7,
      rsi14: 67,
      pullbackFromHighToClosePercent: -1.6,
      vwapAvailable: true,
      isCloseBelowVwap: true,
      hasWideSpread: false,
      isSpeculativeSmallCap: false,
      isExDividendWindow: false,
      isInBuybackExclusionList: false,
      roundTripCostPercent: 0.12,
    );

    final judgement = RecommendationEngine().judge(stock);

    expect(judgement.isRecommended, isTrue);
    expect(judgement.violations, isEmpty);
    expect(judgement.matchedRuleCount, RecommendationEngine.totalRules);
  });

  test('buildRecommendations enforces max 2 symbols and risk cap', () {
    final recommendations = RecommendationEngine().buildRecommendations(sampleStocks);

    expect(recommendations.length, lessThanOrEqualTo(2));
    for (final recommendation in recommendations) {
      expect(recommendation.positionYen, lessThanOrEqualTo(60000));
      expect(recommendation.maxLossYen, lessThanOrEqualTo(900));
    }
  });

  test('position size uses max-loss and stop-loss formula', () {
    final recommendations = RecommendationEngine().buildRecommendations(sampleStocks);
    final expectedPosition = RecommendationEngine.maxLossPerTradeYen /
        (RecommendationEngine.stopLossPercent / 100);

    expect(recommendations, isNotEmpty);
    expect(expectedPosition, closeTo(60000, 0.01));
    expect(recommendations.first.positionYen, closeTo(expectedPosition, 0.01));
    expect(
      recommendations.first.positionYen,
      lessThanOrEqualTo(RecommendationEngine.maxPositionYen),
    );
    expect(recommendations.first.maxLossYen, closeTo(900, 0.01));
  });

  test('fetchPrices updates missing data and adds notification when recommended exists', () {
    final now = DateTime(2026, 1, 1, 9);
    final controller = KabuController(nowProvider: () => now);

    final updated = controller.fetchPrices(onlyMissing: true);

    expect(updated, sampleStocks.length);
    expect(controller.stocks.every((stock) => stock.lastFetchedAt == now), isTrue);
    expect(controller.notifications, isNotEmpty);
    expect(controller.notifications.first.title, 'おすすめ通知');
    expect(controller.bestRecommendation, isNotNull);
  });

  test('runScheduledIfDue triggers scheduled fetch and notification', () {
    var now = DateTime(2026, 1, 1, 8, 0);
    final controller = KabuController(nowProvider: () => now);

    final executed = controller.runScheduledIfDue();

    expect(executed, isTrue);
    expect(controller.lastFetchedAt, now);
    expect(controller.notifications.first.title, '定時おすすめ通知');
    now = DateTime(2026, 1, 1, 8, 1);
    expect(controller.runScheduledIfDue(), isFalse);
  });
}
