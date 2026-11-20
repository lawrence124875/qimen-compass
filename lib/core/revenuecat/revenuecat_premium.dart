import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../monetization/premium_service.dart';

/// RevenueCat 實作（REFERENCE §23）。**唯一 import purchases_flutter 的檔案**。
///
/// - 金鑰：CI 以 --dart-define=REVENUECAT_API_KEY 注入（GitHub Secret `REVENUECAT_ANDROID_API_KEY`，
///   RevenueCat 專案「奇門羅盤」的 Google Play 公開 SDK 金鑰，goog_ 開頭）。沒注入＝[FreePremium]。
/// - 權限 `premium`；Offering 預設（current）內放 Monthly、Annual 兩個 Package。
/// - FORCE_PREMIUM=true（只給個人測試建置）時一律視為訂閱戶。
class RevenueCatPremium implements PremiumService {
  RevenueCatPremium._();

  static const _apiKey = String.fromEnvironment('REVENUECAT_API_KEY');
  static const _forcePremium = bool.fromEnvironment('FORCE_PREMIUM');
  static const entitlementId = 'premium';

  static bool get configured => _apiKey.isNotEmpty;

  @override
  final ValueNotifier<bool> isPremium = ValueNotifier(_forcePremium);

  /// 金鑰沒設定或初始化失敗時回傳 [FreePremium]（App 照常可用，只是不能訂閱）。
  static const _kCached = 'rc_premium_cached';
  SharedPreferences? _prefs;

  /// 金鑰沒設定或初始化失敗時回傳 [FreePremium]（App 照常可用，只是不能訂閱）。
  /// 不等網路：先用上次存下的訂閱狀態，再在背景向 RevenueCat 查詢（快取過期時要連網，曾拖慢啟動數秒）。
  static Future<PremiumService> init() async {
    if (_forcePremium) return FreePremium(premium: true);
    if (_apiKey.isEmpty) return FreePremium();
    try {
      final p = RevenueCatPremium._();
      try {
        final prefs = p._prefs = await SharedPreferences.getInstance();
        p.isPremium.value = prefs.getBool(_kCached) ?? false;
      } catch (_) {}
      await Purchases.setLogLevel(kReleaseMode ? LogLevel.warn : LogLevel.info);
      await Purchases.configure(PurchasesConfiguration(_apiKey));
      Purchases.addCustomerInfoUpdateListener(p._apply);
      unawaited(Purchases.getCustomerInfo().then(p._apply).catchError((Object _) {}));
      return p;
    } catch (e) {
      debugPrint('RevenueCat 初始化失敗：$e');
      return FreePremium();
    }
  }

  void _apply(CustomerInfo info) {
    final v = info.entitlements.active.containsKey(entitlementId);
    isPremium.value = v;
    unawaited(_prefs?.setBool(_kCached, v).catchError((Object _) => false));
  }

  @override
  bool get canPurchase => true;

  @override
  Future<List<SubscriptionPlan>> plans() async {
    try {
      final current = (await Purchases.getOfferings()).current;
      if (current == null) return const [];
      return [
        if (current.monthly case final m?) await _plan(PlanPeriod.monthly, m),
        if (current.annual case final a?) await _plan(PlanPeriod.yearly, a),
      ];
    } catch (e) {
      debugPrint('讀取訂閱方案失敗：$e');
      return const [];
    }
  }

  /// 價格全用商店回傳的當地字串（priceString、pricePerMonthString），不寫死幣別。
  static Future<SubscriptionPlan> _plan(PlanPeriod period, Package pkg) async {
    final p = pkg.storeProduct;
    return SubscriptionPlan(
      period: period,
      price: p.priceString,
      monthlyEquivalent: period == PlanPeriod.yearly ? p.pricePerMonthString : null,
      trialDays: await _trialDays(p),
      handle: pkg,
    );
  }

  /// 免費試用天數。Google Play 只回傳使用者有資格的優惠（defaultOption 的 freePhase）；
  /// iOS 另外查資格。查不到就當沒有試用（不顯示試用文字）。
  static Future<int?> _trialDays(StoreProduct p) async {
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        final period = p.defaultOption?.freePhase?.billingPeriod;
        return period == null ? null : trialLengthDays(period.unit.name, period.value);
      }
      final intro = p.introductoryPrice;
      if (intro == null || intro.price != 0) return null;
      final e = await Purchases.checkTrialOrIntroductoryPriceEligibility([p.identifier]);
      if (e[p.identifier]?.status != IntroEligibilityStatus.introEligibilityStatusEligible) return null;
      return trialLengthDays(intro.periodUnit.name, intro.periodNumberOfUnits * (intro.cycles < 1 ? 1 : intro.cycles));
    } catch (_) {
      return null;
    }
  }

  @override
  Future<PurchaseOutcome> purchase(SubscriptionPlan plan) async {
    final pkg = plan.handle;
    if (pkg is! Package) return PurchaseOutcome.failed;
    try {
      final result = await Purchases.purchasePackage(pkg);
      _apply(result.customerInfo);
      return isPremium.value ? PurchaseOutcome.success : PurchaseOutcome.failed;
    } on PlatformException catch (e) {
      return PurchasesErrorHelper.getErrorCode(e) == PurchasesErrorCode.purchaseCancelledError
          ? PurchaseOutcome.cancelled
          : PurchaseOutcome.failed;
    } catch (_) {
      return PurchaseOutcome.failed;
    }
  }

  @override
  Future<bool> restore() async {
    try {
      _apply(await Purchases.restorePurchases());
    } catch (_) {}
    return isPremium.value;
  }
}
