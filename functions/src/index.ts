// functions/src/index.ts
// firebase-functions v7 exposes the v2 API at the package root; everything
// in this file is written against v1, so it is imported explicitly. Without
// this the whole functions project fails to compile and nothing deploys.
import * as functions from 'firebase-functions/v1';
import * as admin from 'firebase-admin';
import { google } from 'googleapis';

admin.initializeApp();

const db = admin.firestore();

/**
 * Verify Night Pass purchase with Google Play or App Store
 * 
 * This function validates IAP receipts server-side to prevent fraud.
 * 
 * Input:
 * - roomCode: string
 * - platform: 'android' | 'ios'
 * - purchaseToken: string
 * - productId: 'night_pass_12h'
 * - userId: string
 * 
 * Returns:
 * - success: boolean
 * - expiresAt?: Timestamp
 * - error?: string
 */
export const verifyNightPass = functions.https.onCall(async (data, context) => {
  // Ensure user is authenticated
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'Usuario no autenticado'
    );
  }

  const { roomCode, platform, purchaseToken, productId, userId } = data;

  // Validate input
  if (!roomCode || !platform || !purchaseToken || !productId) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Parámetros faltantes'
    );
  }

  if (productId !== 'night_pass_12h') {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'ID de producto inválido'
    );
  }

  try {
    // Check if purchase token was already used (prevent replay attack)
    const purchaseRef = db.collection('purchases').doc(purchaseToken);
    const purchaseDoc = await purchaseRef.get();

    if (purchaseDoc.exists) {
      functions.logger.warn('Duplicate purchase token detected', {
        purchaseToken,
        userId,
      });
      return {
        success: false,
        error: 'Esta compra ya fue procesada',
      };
    }

    let isValid = false;

    // Verify based on platform
    if (platform === 'android') {
      isValid = await verifyAndroidPurchase(purchaseToken, productId);
    } else if (platform === 'ios') {
      isValid = await verifyIOSPurchase(purchaseToken, productId);
    } else {
      throw new functions.https.HttpsError(
        'invalid-argument',
        'Plataforma inválida'
      );
    }

    if (!isValid) {
      functions.logger.error('Purchase verification failed', {
        platform,
        purchaseToken,
        userId,
      });
      return {
        success: false,
        error: 'No se pudo verificar la compra',
      };
    }

    // Calculate expiration (12 hours from now)
    const now = admin.firestore.Timestamp.now();
    const expiresAt = new admin.firestore.Timestamp(
      now.seconds + 12 * 60 * 60,
      now.nanoseconds
    );

    // Update room atomically
    const roomRef = db.collection('rooms').doc(roomCode);

    await db.runTransaction(async (transaction) => {
      const roomDoc = await transaction.get(roomRef);

      if (!roomDoc.exists) {
        throw new functions.https.HttpsError(
          'not-found',
          'Sala no encontrada'
        );
      }

      // Update room with Night Pass
      transaction.update(roomRef, {
        nightPassExpiresAt: expiresAt,
        nightPassActivatedBy: userId,
        nightPassPlatform: platform,
        nightPassPurchaseToken: purchaseToken,
        nightPassActivatedAt: now,
      });

      // Record purchase to prevent duplicates
      transaction.set(purchaseRef, {
        userId,
        roomCode,
        platform,
        productId,
        purchasedAt: now,
        expiresAt,
      });
    });

    functions.logger.info('Night Pass activated', {
      roomCode,
      userId,
      platform,
      expiresAt: expiresAt.toDate(),
    });

    return {
      success: true,
      expiresAt: expiresAt.toMillis(),
    };
  } catch (error: any) {
    functions.logger.error('Error verifying Night Pass', {
      error: error.message,
      stack: error.stack,
      userId,
      roomCode,
    });

    return {
      success: false,
      error: error.message || 'Error desconocido',
    };
  }
});

/**
 * Verify Android purchase with Google Play Developer API
 */
async function verifyAndroidPurchase(
  purchaseToken: string,
  productId: string
): Promise<boolean> {
  try {
    // Note: In production, you need to:
    // 1. Enable Google Play Developer API
    // 2. Create service account with API access
    // 3. Download JSON key and set GOOGLE_APPLICATION_CREDENTIALS
    
    const androidPublisher = google.androidpublisher('v3');
    
    // Replace with your actual package name
    const packageName = 'com.bufon.flutter';

    // Authenticate (uses GOOGLE_APPLICATION_CREDENTIALS env var)
    const auth = new google.auth.GoogleAuth({
      scopes: ['https://www.googleapis.com/auth/androidpublisher'],
    });

    const authClient = await auth.getClient();

    // Verify the purchase
    const response = await androidPublisher.purchases.products.get({
      auth: authClient as any,
      packageName,
      productId,
      token: purchaseToken,
    });

    const purchase = response.data;

    // Check purchase state
    // 0 = Purchased, 1 = Canceled, 2 = Pending
    if (purchase.purchaseState !== 0) {
      functions.logger.warn('Android purchase not in purchased state', {
        purchaseState: purchase.purchaseState,
      });
      return false;
    }

    // Check if consumed (should not be consumed yet)
    if (purchase.consumptionState === 1) {
      functions.logger.warn('Android purchase already consumed');
      return false;
    }

    return true;
  } catch (error: any) {
    // In development/testing, allow sandbox purchases
    const isDevelopment = process.env.FUNCTIONS_EMULATOR === 'true';
    
    if (isDevelopment) {
      functions.logger.info('Development mode: allowing sandbox purchase');
      return true;
    }

    functions.logger.error('Android verification error', {
      error: error.message,
    });
    return false;
  }
}

/**
 * Verify iOS purchase with App Store Server API
 */
async function verifyIOSPurchase(
  receiptData: string,
  productId: string
): Promise<boolean> {
  try {
    // Apple receipt validation endpoint
    // Use sandbox URL for testing, production URL for live
    const isSandbox = process.env.FUNCTIONS_EMULATOR === 'true';
    const verifyUrl = isSandbox
      ? 'https://sandbox.itunes.apple.com/verifyReceipt'
      : 'https://buy.itunes.apple.com/verifyReceipt';

    // Replace with your actual shared secret from App Store Connect
    const sharedSecret = process.env.APPLE_SHARED_SECRET || '';

    const response = await fetch(verifyUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        'receipt-data': receiptData,
        'password': sharedSecret,
        'exclude-old-transactions': true,
      }),
    });

    const result = await response.json();

    // Check status code
    // 0 = valid, 21007 = sandbox receipt sent to production (retry with sandbox)
    if (result.status === 21007) {
      // Retry with sandbox
      return verifyIOSPurchase(receiptData, productId);
    }

    if (result.status !== 0) {
      functions.logger.error('iOS receipt validation failed', {
        status: result.status,
      });
      return false;
    }

    // Verify product ID matches
    const latestReceipt = result.latest_receipt_info?.[0];
    if (!latestReceipt || latestReceipt.product_id !== productId) {
      functions.logger.warn('iOS product ID mismatch');
      return false;
    }

    return true;
  } catch (error: any) {
    // In development, allow sandbox purchases
    const isDevelopment = process.env.FUNCTIONS_EMULATOR === 'true';
    
    if (isDevelopment) {
      functions.logger.info('Development mode: allowing iOS sandbox purchase');
      return true;
    }

    functions.logger.error('iOS verification error', {
      error: error.message,
    });
    return false;
  }
}

/**
 * Scheduled function to check for ended seasons and finalize them
 * 
 * Runs daily at 00:00 UTC
 * Checks all active seasons and finalizes any that have ended
 */
export const finalizeEndedSeasons = functions.pubsub
  .schedule('0 0 * * *') // Run at midnight UTC every day
  .timeZone('UTC')
  .onRun(async (context) => {
    functions.logger.info('Starting season finalization check');

    try {
      const now = admin.firestore.Timestamp.now();
      
      // Find all active seasons that have ended
      const seasonsSnapshot = await db
        .collection('seasons')
        .where('isActive', '==', true)
        .where('endDate', '<=', now)
        .get();

      if (seasonsSnapshot.empty) {
        functions.logger.info('No seasons to finalize');
        return null;
      }

      functions.logger.info(`Found ${seasonsSnapshot.docs.length} season(s) to finalize`);

      // Process each ended season
      for (const seasonDoc of seasonsSnapshot.docs) {
        const seasonId = seasonDoc.id;
        const seasonData = seasonDoc.data();

        functions.logger.info(`Finalizing season: ${seasonId} - ${seasonData.name}`);

        try {
          await finalizeSeason(seasonId, seasonData);
          functions.logger.info(`Successfully finalized season: ${seasonId}`);
        } catch (error: any) {
          functions.logger.error(`Failed to finalize season ${seasonId}`, {
            error: error.message,
            stack: error.stack,
          });
          // Continue with next season even if one fails
        }
      }

      return null;
    } catch (error: any) {
      functions.logger.error('Season finalization check failed', {
        error: error.message,
        stack: error.stack,
      });
      return null;
    }
  });

/**
 * Finalize a season with transaction-safe operations
 */
async function finalizeSeason(seasonId: string, seasonData: any): Promise<void> {
  const seasonRef = db.collection('seasons').doc(seasonId);

  // Use transaction to ensure season is only finalized once
  await db.runTransaction(async (transaction) => {
    const freshDoc = await transaction.get(seasonRef);
    
    if (!freshDoc.exists) {
      throw new Error(`Season ${seasonId} not found`);
    }

    const freshData = freshDoc.data();
    
    // Double-check it's still active (prevent race conditions)
    if (!freshData?.isActive) {
      functions.logger.info(`Season ${seasonId} already finalized, skipping`);
      return;
    }

    // Mark season as inactive
    transaction.update(seasonRef, {
      isActive: false,
      finalizedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

  // Now reward top players and archive results (outside transaction for performance)
  await rewardTopPlayers(seasonId, seasonData.name);
  await archiveSeasonResults(seasonId);

  // Log analytics
  functions.logger.info('Season finalized', {
    seasonId,
    seasonName: seasonData.name,
  });
}

/**
 * Reward top 100 players with tiered rewards
 */
async function rewardTopPlayers(seasonId: string, seasonName: string): Promise<void> {
  // Get top 100 from global leaderboard
  const leaderboardSnapshot = await db
    .collection('leaderboards')
    .doc('global_xp')
    .collection('entries')
    .orderBy('xp', 'desc')
    .limit(100)
    .get();

  if (leaderboardSnapshot.empty) {
    functions.logger.info('No players to reward');
    return;
  }

  const batch = db.batch();
  let batchCount = 0;
  const MAX_BATCH_SIZE = 500;

  for (let i = 0; i < leaderboardSnapshot.docs.length; i++) {
    const rank = i + 1;
    const entry = leaderboardSnapshot.docs[i];
    const userId = entry.id;
    const userData = entry.data();

    // Determine rewards based on rank
    let titleId: string | null = null;
    let frameId: string | null = null;
    let badgeId: string | null = null;

    if (rank === 1) {
      titleId = 'season_champion_legendary';
    } else if (rank <= 10) {
      frameId = 'animated_frame_top10';
    } else if (rank <= 100) {
      badgeId = 'season_top100_badge';
    }

    // Store reward in user's seasonRewards subcollection
    const rewardRef = db
      .collection('users')
      .doc(userId)
      .collection('seasonRewards')
      .doc(seasonId);

    batch.set(rewardRef, {
      seasonId,
      seasonName,
      rank,
      titleId,
      frameId,
      badgeId,
      grantedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Store in seasonHistory
    const historyRef = db
      .collection('users')
      .doc(userId)
      .collection('seasonHistory')
      .doc(seasonId);

    batch.set(historyRef, {
      seasonId,
      seasonName,
      rank,
      totalXp: userData.xp || 0,
      rewards: {
        titleId,
        frameId,
        badgeId,
      },
      completedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // If legendary title, add to user's unlockedTitles
    if (titleId) {
      const userRef = db.collection('users').doc(userId);
      batch.update(userRef, {
        unlockedTitles: admin.firestore.FieldValue.arrayUnion(titleId),
      });
    }

    batchCount++;

    // Commit batch if we reach max size
    if (batchCount >= MAX_BATCH_SIZE) {
      await batch.commit();
      functions.logger.info(`Committed batch of ${batchCount} rewards`);
      batchCount = 0;
    }
  }

  // Commit remaining operations
  if (batchCount > 0) {
    await batch.commit();
    functions.logger.info(`Committed final batch of ${batchCount} rewards`);
  }

  functions.logger.info(`Rewarded ${leaderboardSnapshot.docs.length} players`);
}

/**
 * Archive season leaderboard results
 */
async function archiveSeasonResults(seasonId: string): Promise<void> {
  const leaderboardSnapshot = await db
    .collection('leaderboards')
    .doc('global_xp')
    .collection('entries')
    .orderBy('xp', 'desc')
    .limit(100)
    .get();

  if (leaderboardSnapshot.empty) {
    functions.logger.info('No results to archive');
    return;
  }

  const batch = db.batch();
  let rank = 1;

  for (const doc of leaderboardSnapshot.docs) {
    const archiveRef = db
      .collection('seasons')
      .doc(seasonId)
      .collection('final_results')
      .doc(doc.id);

    const data = doc.data();
    batch.set(archiveRef, {
      ...data,
      rank,
      archivedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    rank++;
  }

  await batch.commit();
  functions.logger.info(`Archived ${leaderboardSnapshot.docs.length} results`);
}

/**
 * Manual callable function to finalize a specific season (for testing/admin)
 */
export const manualFinalizeSeason = functions.https.onCall(async (data, context) => {
  // Only allow authenticated admin users
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'Usuario no autenticado'
    );
  }

  // TODO: Add admin check here
  // For now, only allow in development
  if (process.env.FUNCTIONS_EMULATOR !== 'true') {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Solo administradores pueden finalizar temporadas'
    );
  }

  const { seasonId } = data;

  if (!seasonId) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'seasonId es requerido'
    );
  }

  try {
    const seasonDoc = await db.collection('seasons').doc(seasonId).get();
    
    if (!seasonDoc.exists) {
      throw new functions.https.HttpsError(
        'not-found',
        'Temporada no encontrada'
      );
    }

    const seasonData = seasonDoc.data();
    
    if (!seasonData?.isActive) {
      throw new functions.https.HttpsError(
        'failed-precondition',
        'La temporada ya fue finalizada'
      );
    }

    await finalizeSeason(seasonId, seasonData);

    return {
      success: true,
      message: `Temporada ${seasonId} finalizada exitosamente`,
    };
  } catch (error: any) {
    functions.logger.error('Manual season finalization failed', {
      seasonId,
      error: error.message,
    });
    
    if (error instanceof functions.https.HttpsError) {
      throw error;
    }
    
    throw new functions.https.HttpsError(
      'internal',
      `Error al finalizar temporada: ${error.message}`
    );
  }
});

// Progression is server-authoritative: see progression/onMatchCompleted.ts.
export { onMatchCompleted } from './progression/onMatchCompleted';

// Voting is server-authoritative: see voting/submitVote.ts.
export { submitVote } from './voting/submitVote';
