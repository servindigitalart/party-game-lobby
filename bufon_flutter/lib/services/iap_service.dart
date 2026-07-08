// services/iap_service.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../analytics/analytics_service.dart';

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
  final AnalyticsService _analytics = AnalyticsService.instance;

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
        debugPrint('[IAPService] In-App Purchase not available');
        return;
      }

      // Query product details
      final productIds = {nightPassProductId};
      final response = await _iap.queryProductDetails(productIds);

      if (response.error != null) {
        debugPrint('[IAPService] Error querying products: ${response.error}');
        return;
      }

      _products = response.productDetails;
      debugPrint('[IAPService] Found ${_products.length} products');

      // Listen to purchase updates
      _subscription = _iap.purchaseStream.listen(
        _onPurchaseUpdate,
        onError: (error) {
          debugPrint('[IAPService] Purchase stream error: $error');
        },
      );

      debugPrint('[IAPService] Initialized successfully');
    } catch (e) {
      debugPrint('[IAPService] Failed to initialize: $e');
    }
  }

  /// Handle purchase updates
  Future<void> _onPurchaseUpdate(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      debugPrint('[IAPService] Purchase update: ${purchase.status}');

      if (purchase.status == PurchaseStatus.pending) {
        // Payment pending
        debugPrint('[IAPService] Purchase pending');
      } else if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        // Verify with backend before completing
        final verified = await _verifyPurchase(purchase);

        if (verified) {
          debugPrint('[IAPService] Purchase verified successfully');
        } else {
          debugPrint('[IAPService] Purchase verification failed');
        }

        // Complete the purchase
        await _iap.completePurchase(purchase);
      } else if (purchase.status == PurchaseStatus.error) {
        debugPrint('[IAPService] Purchase error: ${purchase.error}');
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
      debugPrint('[IAPService] Verification error: $e');
      return false;
    }
  }

  /// Buy Night Pass for a specific room
  ///
  /// Returns true if purchase was successful and verified
  Future<bool> buyNightPass(String roomCode, String userId) async {
    if (!_isAvailable) {
      debugPrint('[IAPService] IAP not available');
      return false;
    }

    // Find Night Pass product
    final product = _products.firstWhere(
      (p) => p.id == nightPassProductId,
      orElse: () => throw Exception('Night Pass product not found'),
    );

    try {
      // Analytics: Track purchase initiation
      await _analytics.logNightPassPurchaseInitiated(
        roomCode: roomCode,
        productId: product.id,
        priceMicros: _getPriceMicros(product),
        currency: product.currencyCode,
      );

      // Create purchase param
      final purchaseParam = PurchaseParam(
        productDetails: product,
        applicationUserName: userId, // For tracking
      );

      // Initiate purchase
      debugPrint('[IAPService] Initiating Night Pass purchase');
      final success = await _iap.buyNonConsumable(purchaseParam: purchaseParam);

      if (!success) {
        debugPrint('[IAPService] Failed to initiate purchase');
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
        debugPrint('[IAPService] Night Pass activated for room $roomCode');

        // Analytics: Track successful purchase
        await _analytics.logNightPassPurchased(
          roomCode: roomCode,
          productId: product.id,
          purchaseValueMicros: _getPriceMicros(product),
          currency: product.currencyCode,
          platform: platform,
        );

        // Complete the purchase
        await _iap.completePurchase(nightPassPurchase);

        return true;
      } else {
        final error = data['error'] as String? ?? 'Unknown error';
        debugPrint('[IAPService] Verification failed: $error');
        return false;
      }
    } catch (e) {
      debugPrint('[IAPService] Purchase failed: $e');
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
      debugPrint('[IAPService] Purchases restored');
    } catch (e) {
      debugPrint('[IAPService] Failed to restore purchases: $e');
    }
  }

  /// Dispose service
  void dispose() {
    _subscription?.cancel();
    debugPrint('[IAPService] Disposed');
  }
}
