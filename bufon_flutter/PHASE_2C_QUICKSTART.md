# PHASE 2C-PRO QUICK REFERENCE
## Night Pass IAP Integration

### 🎯 Quick Start

```dart
// Initialize IAP Service
final iapService = IAPService();
await iapService.initialize();

// Buy Night Pass
final success = await iapService.buyNightPass(roomCode, userId);
```

---

## 📘 API Reference

### IAPService

#### Initialize
```dart
Future<void> initialize()
```
Initializes In-App Purchase SDK, queries products, sets up purchase stream.

#### Buy Night Pass
```dart
Future<bool> buyNightPass(String roomCode, String userId)
```
**Parameters:**
- `roomCode`: The room to unlock
- `userId`: Current user's Firebase Auth UID

**Returns:** `true` if purchase successful and validated, `false` otherwise

**Process:**
1. Initiates IAP purchase
2. Waits for purchase completion
3. Extracts receipt/token
4. Calls Cloud Function for validation
5. Completes purchase
6. Returns result

#### Get Product
```dart
ProductDetails? getNightPassProduct()
```
Returns Night Pass product details (price, description, etc.)

#### Restore Purchases (iOS)
```dart
Future<void> restorePurchases()
```
Restores previous purchases (iOS requirement).

---

### Cloud Function API

#### verifyNightPass

**Endpoint:** HTTPS Callable  
**Auth:** Required (Firebase Auth)

**Request:**
```typescript
{
  roomCode: string,
  platform: "android" | "ios",
  purchaseToken: string,
  productId: "night_pass_12h",
  userId: string
}
```

**Success Response:**
```typescript
{
  success: true,
  expiresAt: 1708308000000 // Unix ms
}
```

**Error Response:**
```typescript
{
  success: false,
  error: "La compra ya fue procesada" // Spanish
}
```

---

## 🎨 UI Integration

### PaywallScreen Implementation

```dart
Future<void> _buyNightPass() async {
  setState(() => _isLoading = true);

  try {
    final iapService = IAPService();
    await iapService.initialize();

    final userId = ref.read(userIdProvider);
    final success = await iapService.buyNightPass(
      widget.roomCode, 
      userId!
    );

    if (success) {
      // Success!
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Night Pass activado! 12 horas ilimitadas'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop(true); // Return to game
    } else {
      _showError('La compra no se completó');
    }
  } catch (e) {
    _showError('Error: $e');
  } finally {
    setState(() => _isLoading = false);
  }
}
```

---

## 🔒 Security Best Practices

### ✅ DO
- Always validate purchases server-side
- Use atomic Firestore transactions
- Check for duplicate purchase tokens
- Log all purchase attempts
- Use Firestore security rules
- Handle errors gracefully

### ❌ DON'T
- Never trust client-side validation
- Never skip backend verification
- Never allow client to write Night Pass fields directly
- Never expose service account credentials
- Never skip duplicate token checks

---

## 🧪 Testing

### Test Mode Detection
```typescript
// Cloud Function automatically detects emulator
const isDevelopment = process.env.FUNCTIONS_EMULATOR === 'true';

if (isDevelopment) {
  // Allow sandbox purchases without real API calls
  return true;
}
```

### Test Accounts

**Android:**
1. Create test account in Google Play Console
2. Add to license testers
3. Use test credit cards

**iOS:**
1. Create sandbox tester in App Store Connect
2. Sign in with sandbox account on device
3. Purchase with sandbox account (no charge)

---

## 🚀 Deployment

### 1. Set Environment Variables
```bash
# Google Play service account
firebase functions:config:set \
  google.credentials="$(cat service-account.json)"

# Apple shared secret
firebase functions:config:set \
  apple.shared_secret="YOUR_SECRET_HERE"
```

### 2. Deploy Functions
```bash
cd functions
npm run build
firebase deploy --only functions
```

### 3. Deploy Firestore Rules
```bash
firebase deploy --only firestore:rules
```

### 4. Verify Deployment
```bash
firebase functions:log --only verifyNightPass
```

---

## 📊 Room Monetization Check

### Logic Flow
```dart
bool canRoomStartGame(Room room) {
  // 1. Check Night Pass
  if (room.nightPassExpiresAt != null && 
      room.nightPassExpiresAt!.isAfter(DateTime.now())) {
    return true; // Unlimited!
  }

  // 2. Check ad unlocks
  if (room.adUnlocksRemaining > 0) {
    // Will consume in transaction
    return true;
  }

  // 3. Check daily limit
  if (room.gamesPlayedToday < 3) {
    return true;
  }

  // Blocked - show paywall
  throw MonetizationException('ROOM_LOCKED');
}
```

---

## 🔄 Purchase Flow Diagram

```
User clicks "Night Pass"
        ↓
IAPService.buyNightPass()
        ↓
    InAppPurchase
    Native Store UI
        ↓
User completes payment
        ↓
purchaseStream fires
        ↓
Extract receipt/token
        ↓
Call Cloud Function
        ↓
Backend validates with:
├─ Google Play API (Android)
└─ App Store API (iOS)
        ↓
    Check duplicate?
    ├─ YES → Reject
    └─ NO → Continue
        ↓
Firestore Transaction:
├─ Update room
└─ Record purchase
        ↓
Return success to client
        ↓
Complete IAP transaction
        ↓
Room unlocked! (12h)
```

---

## 🐛 Common Issues

### "Purchase not found"
**Cause:** Purchase didn't complete  
**Fix:** Check network, retry purchase

### "Esta compra ya fue procesada"
**Cause:** Duplicate purchase token (replay attack prevention)  
**Fix:** Normal security behavior, user not charged again

### "No se pudo verificar la compra"
**Cause:** Backend validation failed  
**Fix:** Check Cloud Function logs, verify API credentials

### Night Pass not activating
**Cause:** Firestore not updated or client not refreshing  
**Fix:** Check Firestore console, ensure app refreshes room data

---

## 📱 Platform Configuration

### Android (build.gradle)
```gradle
dependencies {
    implementation 'com.android.billingclient:billing:6.0.1'
}
```

### iOS (Info.plist)
```xml
<key>SKAdNetworkItems</key>
<array>
    <!-- IAP attribution networks -->
</array>
```

### Both Platforms
- Enable In-App Purchase capability
- Configure billing library
- Set up test accounts

---

## 💰 Pricing

**Product ID:** `night_pass_12h`  
**Type:** Non-Consumable  
**Price:** $10 MXN  
**Duration:** 12 hours  
**Benefit:** Unlimited games for entire room  

---

## 📈 Metrics to Track

- Purchase conversion rate
- Average revenue per room
- Night Pass vs Ad unlock ratio
- Purchase validation success rate
- Fraud attempt detection
- Platform distribution (Android/iOS)
- Time to purchase completion

---

## 🔧 Maintenance

### Monitor Logs
```bash
# Real-time logs
firebase functions:log --only verifyNightPass

# Specific time range
firebase functions:log --only verifyNightPass \
  --since 2026-02-18T00:00:00
```

### Query Purchases
```javascript
// Active Night Passes
db.collection('rooms')
  .where('nightPassExpiresAt', '>', new Date())
  .get()

// All purchases
db.collection('purchases')
  .orderBy('purchasedAt', 'desc')
  .limit(100)
  .get()
```

---

## ✅ Pre-Launch Checklist

- [ ] Google Play product configured
- [ ] App Store product configured  
- [ ] Service account credentials set
- [ ] Cloud Functions deployed
- [ ] Firestore rules deployed
- [ ] Test purchase flows (Android)
- [ ] Test purchase flows (iOS)
- [ ] Monitor logs for 24h
- [ ] Set up fraud alerts
- [ ] Document support procedures

---

**Last Updated:** February 18, 2026  
**Status:** Production Ready ✅
