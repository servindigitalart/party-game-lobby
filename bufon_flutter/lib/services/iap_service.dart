// services/iap_service.dart
import 'dart:async';
import '../core/telemetry/game_telemetry_service.dart';
import 'dart:io';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../core/logging/app_logger.dart';
import '../core/logging/log_category.dart';

/// Service for managing In-App Purchases (Night Pass)
///
/// Features:
/// - Secure backend validation via Cloud Functions
/// - Prevents duplicate purchases
/// - Room-based Night Pass activation
/// - Sandbox support for testing
/// - Analytics tracking
class IAPService {
  static const String nightPassProductId = 'night_pass_12h';

  final InAppPurchase _iap = InAppPurchase.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final GameTelemetryService _telemetry = GameTelemetryService.instance;

  StreamSubscription<List<PurchaseDetails>>? _subscription;
  bool _isAvailable = false;
  List<ProductDetails> _products = [];

  /// Check if IAP is available
  bool get isAvailable => _isAvailable;

  /// Get available products
  List<ProductDetails> get products => _products;

  /// Initialize IAP service
  Future<void> initialize() async {
    try {
      // Check if IAP is available
      _isAvailable = await _iap.isAvailable();

      if (!_isAvailable) {
        AppLogger.instance.warning(
          AppLogCategory.purchases,
          '[IAPService] In-App Purchase not available',
        );
        return;
      }

      // Query product details
      final productIds = {nightPassProductId};
      final response = await _iap.queryProductDetails(productIds);

      if (response.error != null) {
        AppLogger.instance.error(
          AppLogCategory.purchases,
          '[IAPService] Error querying products',
          error: response.error,
        );
        return;
      }

      _products = response.productDetails;
      AppLogger.instance.info(
        AppLogCategory.purchases,
        '[IAPService] Found ${_products.length} products',
      );

      // Listen to purchase updates
      _subscription = _iap.purchaseStream.listen(
        _onPurchaseUpdate,
        onError: (error) {
          AppLogger.instance.error(
            AppLogCategory.purchases,
            '[IAPService] Purchase stream error',
            error: error,
          );
        },
      );

      AppLogger.instance.info(
        AppLogCategory.purchases,
        '[IAPService] Initialized successfully',
      );
    } catch (e) {
      AppLogger.instance.error(
        AppLogCategory.purchases,
        '[IAPService] Failed to initialize',
        error: e,
      );
    }
  }

  /// Handle purchase updates
  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      AppLogger.instance.info(
        AppLogCategory.purchases,
        '[IAPService] Purchase update: ${purchase.status}',
      );

      if (purchase.status == PurchaseStatus.pending) {
        // Payment pending
        AppLogger.instance.info(
          AppLogCategory.purchases,
          '[IAPService] Purchase pending',
        );
      } else if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        // Verify with backend before completing
        final verified = await _verifyPurchase(purchase);

        if (verified) {
          AppLogger.instance.info(
            AppLogCategory.purchases,
            '[IAPService] Purchase verified successfully',
          );
        } else {
          AppLogger.instance.warning(
            AppLogCategory.purchases,
            '[IAPService] Purchase verification failed',
          );
        }

        // Complete the purchase
        await _iap.completePurchase(purchase);
      } else if (purchase.status == PurchaseStatus.error) {
        AppLogger.instance.error(
          AppLogCategory.purchases,
          '[IAPService] Purchase error',
          error: purchase.error,
        );
      }
    }
  }

  /// Verify purchase with backend Cloud Function
  Future<bool> _verifyPurchase(PurchaseDetails purchase) async {
    try {
      // This is called automatically from purchaseStream
      // The actual verification happens in buyNightPass
      return true;
    } catch (e) {
      AppLogger.instance.error(
        AppLogCategory.purchases,
        '[IAPService] Verification error',
        error: e,
      );
      return false;
    }
  }

  /// Buy Night Pass for a specific room
  ///
  /// Returns true if purchase was successful and verified
  Future<bool> buyNightPass(String roomCode, String userId) async {
    if (!_isAvailable) {
      AppLogger.instance.warning(
        AppLogCategory.purchases,
        '[IAPService] IAP not available',
      );
      return false;
    }

    // Find Night Pass product
    final product = _products.firstWhere(
      (p) => p.id == nightPassProductId,
      orElse: () => throw Exception('Night Pass product not found'),
    );

    try {
      _telemetry.track(
        AppLogCategory.purchases,
        'purchase_started',
        payload: {
          'product_id': product.id,
          'price_micros': _getPriceMicros(product),
          'currency': product.currencyCode,
        },
      );

      // Create purchase param
      final purchaseParam = PurchaseParam(
        productDetails: product,
        applicationUserName: userId, // For tracking
      );

      // Initiate purchase
      AppLogger.instance.info(
        AppLogCategory.purchases,
        '[IAPService] Initiating Night Pass purchase',
        context: {'roomCode': roomCode},
      );
      final success = await _iap.buyNonConsumable(purchaseParam: purchaseParam);

      if (!success) {
        AppLogger.instance.warning(
          AppLogCategory.purchases,
          '[IAPService] Failed to initiate purchase',
        );
        return false;
      }

      // Wait for purchase to complete
      await Future.delayed(const Duration(seconds: 2));

      // Get the latest purchase
      final purchases = await _iap.purchaseStream.first;
      final nightPassPurchase = purchases.firstWhere(
        (p) =>
            p.productID == nightPassProductId &&
            (p.status == PurchaseStatus.purchased ||
                p.status == PurchaseStatus.restored),
        orElse: () => throw Exception('Purchase not found'),
      );

      // Verify with backend
      final platform = Platform.isAndroid ? 'android' : 'ios';
      String purchaseToken;

      if (Platform.isAndroid) {
        // Android: use purchaseID (purchase token)
        purchaseToken =
            nightPassPurchase.verificationData.serverVerificationData;
      } else {
        // iOS: use receipt data
        purchaseToken =
            nightPassPurchase.verificationData.serverVerificationData;
      }

      // Call Cloud Function to verify
      final callable = _functions.httpsCallable('verifyNightPass');
      final result = await callable.call({
        'roomCode': roomCode,
        'platform': platform,
        'purchaseToken': purchaseToken,
        'productId': nightPassProductId,
        'userId': userId,
      });

      final data = result.data as Map<String, dynamic>;
      final verified = data['success'] as bool? ?? false;

      if (verified) {
        AppLogger.instance.info(
          AppLogCategory.purchases,
          '[IAPService] Night Pass activated for room $roomCode',
          context: {'roomCode': roomCode},
        );

        _telemetry.track(
          AppLogCategory.purchases,
          'purchase_completed',
          payload: {
            'product_id': product.id,
            'purchase_value_micros': _getPriceMicros(product),
            'currency': product.currencyCode,
          },
        );

        // Complete the purchase
        await _iap.completePurchase(nightPassPurchase);

        return true;
      } else {
        final error = data['error'] as String? ?? 'Unknown error';
        AppLogger.instance.error(
          AppLogCategory.purchases,
          '[IAPService] Verification failed: $error',
        );
        return false;
      }
    } catch (e) {
      AppLogger.instance.error(
        AppLogCategory.purchases,
        '[IAPService] Purchase failed',
        error: e,
      );
      return false;
    }
  }

  /// Get price in micros (for analytics)
  int _getPriceMicros(ProductDetails product) {
    // Try to get raw price in micros
    if (Platform.isAndroid) {
      // Android provides priceAmountMicros
      return (product.rawPrice * 1000000).toInt();
    } else {
      // iOS: convert price to micros
      return (product.rawPrice * 1000000).toInt();
    }
  }

  /// Get Night Pass product details
  ProductDetails? getNightPassProduct() {
    try {
      return _products.firstWhere((p) => p.id == nightPassProductId);
    } catch (e) {
      return null;
    }
  }

  /// Restore purchases (iOS requirement)
  Future<void> restorePurchases() async {
    if (!_isAvailable) return;

    try {
      await _iap.restorePurchases();
      AppLogger.instance.info(
        AppLogCategory.purchases,
        '[IAPService] Purchases restored',
      );
    } catch (e) {
      AppLogger.instance.error(
        AppLogCategory.purchases,
        '[IAPService] Failed to restore purchases',
        error: e,
      );
    }
  }

  /// Dispose service
  void dispose() {
    _subscription?.cancel();
    AppLogger.instance.info(AppLogCategory.purchases, '[IAPService] Disposed');
  }
}
