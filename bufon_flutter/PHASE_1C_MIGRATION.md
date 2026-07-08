# Phase 1C Migration Guide

## 🔄 Migrating from Array to Subcollection Structure

This guide explains how to migrate existing Firestore data from the old array-based structure to the new subcollection structure.

---

## ⚠️ Important Notes

### For Development
- **No migration needed** - Simply delete all existing rooms and create new ones
- Old rooms will not work with new code
- New code will not work with old rooms

### For Production
- **Migration script required** - See below
- **Zero downtime possible** - Use gradual rollout
- **Backup first** - Always backup before migration

---

## 🗑️ Development: Clean Slate Approach

### Option 1: Firebase Console
1. Go to Firebase Console → Firestore
2. Navigate to `rooms` collection
3. Delete all documents
4. Start fresh with new structure

### Option 2: Script
```javascript
// delete-all-rooms.js
const admin = require('firebase-admin');

admin.initializeApp({
  // Your Firebase config
});

const db = admin.firestore();

async function deleteAllRooms() {
  const snapshot = await db.collection('rooms').get();
  
  const batch = db.batch();
  snapshot.docs.forEach(doc => {
    batch.delete(doc.ref);
  });
  
  await batch.commit();
  console.log(`Deleted ${snapshot.size} rooms`);
}

deleteAllRooms();
```

---

## 🔧 Production: Migration Script

### Node.js Migration Script

```javascript
// migrate-to-subcollections.js
const admin = require('firebase-admin');

admin.initializeApp({
  credential: admin.credential.applicationDefault(),
  // Your Firebase config
});

const db = admin.firestore();

async function migrateRoom(roomDoc) {
  const roomData = roomDoc.data();
  const roomCode = roomDoc.id;
  const players = roomData.players || [];
  
  console.log(`Migrating room ${roomCode} with ${players.length} players...`);
  
  // Create batch for atomic migration
  const batch = db.batch();
  
  // 1. Create player documents in subcollection
  players.forEach(player => {
    const playerRef = db
      .collection('rooms')
      .doc(roomCode)
      .collection('players')
      .doc(player.id);
    
    batch.set(playerRef, {
      id: player.id,
      name: player.name,
      score: player.score || 0,
      currentAnswer: player.currentAnswer || null,
      votedFor: player.votedFor || null,
      isHost: player.isHost || false,
      lastSeen: player.lastSeen || new Date().toISOString(),
      isOnline: player.isOnline !== undefined ? player.isOnline : true,
    });
  });
  
  // 2. Update room document (remove players array, add createdAt)
  const roomRef = db.collection('rooms').doc(roomCode);
  const updatedRoomData = {
    code: roomData.code,
    hostId: roomData.hostId,
    phase: roomData.phase || 'lobby',
    currentQuestionId: roomData.currentQuestionId || null,
    currentQuestionText: roomData.currentQuestionText || null,
    currentRound: roomData.currentRound || 0,
    totalRounds: roomData.totalRounds || 5,
    roundStartTime: roomData.roundStartTime || null,
    roundDuration: roomData.roundDuration || 90,
    createdAt: new Date().toISOString(),
    // players array REMOVED
  };
  
  batch.set(roomRef, updatedRoomData);
  
  // 3. Commit all changes atomically
  await batch.commit();
  
  console.log(`✅ Migrated room ${roomCode}`);
}

async function migrateAllRooms() {
  console.log('Starting migration...');
  
  const roomsSnapshot = await db.collection('rooms').get();
  console.log(`Found ${roomsSnapshot.size} rooms to migrate`);
  
  // Migrate rooms in batches of 10 (to avoid rate limits)
  const batchSize = 10;
  const rooms = roomsSnapshot.docs;
  
  for (let i = 0; i < rooms.length; i += batchSize) {
    const batch = rooms.slice(i, i + batchSize);
    await Promise.all(batch.map(migrateRoom));
    console.log(`Migrated ${Math.min(i + batchSize, rooms.length)}/${rooms.length} rooms`);
    
    // Rate limiting
    if (i + batchSize < rooms.length) {
      await new Promise(resolve => setTimeout(resolve, 1000));
    }
  }
  
  console.log('✅ Migration complete!');
}

migrateAllRooms().catch(console.error);
```

### Run Migration
```bash
# Install dependencies
npm install firebase-admin

# Set up credentials
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/serviceAccountKey.json"

# Run migration
node migrate-to-subcollections.js
```

---

## 🧪 Testing Migration

### Verification Script

```javascript
// verify-migration.js
const admin = require('firebase-admin');

admin.initializeApp();
const db = admin.firestore();

async function verifyRoom(roomCode) {
  const roomDoc = await db.collection('rooms').doc(roomCode).get();
  
  if (!roomDoc.exists) {
    console.error(`❌ Room ${roomCode} not found`);
    return false;
  }
  
  const roomData = roomDoc.data();
  
  // Check: No players array
  if (roomData.players) {
    console.error(`❌ Room ${roomCode} still has players array!`);
    return false;
  }
  
  // Check: Has createdAt
  if (!roomData.createdAt) {
    console.warn(`⚠️ Room ${roomCode} missing createdAt`);
  }
  
  // Check: Players in subcollection
  const playersSnapshot = await db
    .collection('rooms')
    .doc(roomCode)
    .collection('players')
    .get();
  
  console.log(`✅ Room ${roomCode}: ${playersSnapshot.size} players in subcollection`);
  
  // Verify each player has required fields
  playersSnapshot.docs.forEach(playerDoc => {
    const player = playerDoc.data();
    const required = ['id', 'name', 'score', 'isHost', 'lastSeen', 'isOnline'];
    const missing = required.filter(field => !(field in player));
    
    if (missing.length > 0) {
      console.error(`❌ Player ${playerDoc.id} missing fields: ${missing.join(', ')}`);
    }
  });
  
  return true;
}

async function verifyAllRooms() {
  const roomsSnapshot = await db.collection('rooms').get();
  console.log(`Verifying ${roomsSnapshot.size} rooms...`);
  
  let success = 0;
  for (const doc of roomsSnapshot.docs) {
    if (await verifyRoom(doc.id)) {
      success++;
    }
  }
  
  console.log(`\n✅ ${success}/${roomsSnapshot.size} rooms verified successfully`);
}

verifyAllRooms().catch(console.error);
```

---

## 🎯 Gradual Rollout Strategy

### Phase 1: Deploy Backend Changes
1. Deploy new Firebase Functions (if any)
2. Keep old app version running

### Phase 2: Migrate Data
1. Run migration script
2. Verify all rooms migrated
3. Keep old app for 24 hours

### Phase 3: Deploy App Update
1. Deploy new app version
2. Force update for all users
3. Old rooms automatically cleaned up

### Phase 4: Cleanup
1. Monitor for errors
2. Remove migration scripts
3. Celebrate 🎉

---

## 🔍 Rollback Plan

### If Migration Fails

```javascript
// rollback-migration.js
const admin = require('firebase-admin');

admin.initializeApp();
const db = admin.firestore();

async function rollbackRoom(roomCode, backup) {
  const batch = db.batch();
  
  // Delete subcollection players
  const playersSnapshot = await db
    .collection('rooms')
    .doc(roomCode)
    .collection('players')
    .get();
  
  playersSnapshot.docs.forEach(doc => {
    batch.delete(doc.ref);
  });
  
  // Restore old room structure
  const roomRef = db.collection('rooms').doc(roomCode);
  batch.set(roomRef, backup);
  
  await batch.commit();
  console.log(`✅ Rolled back room ${roomCode}`);
}
```

**Recommendation**: Keep JSON backups of all rooms before migration!

---

## 📋 Pre-Migration Checklist

Before running migration:

- [ ] Backup all Firestore data
- [ ] Test migration on a copy of production data
- [ ] Verify all app features work with new structure
- [ ] Prepare rollback plan
- [ ] Schedule maintenance window
- [ ] Notify users of potential downtime
- [ ] Have Firebase console open for monitoring
- [ ] Have team on standby

---

## 🚨 Common Issues

### Issue: "players array still present after migration"
**Solution**: Clear Firestore cache and re-run migration

### Issue: "Player documents not created"
**Solution**: Check Firestore security rules allow subcollection writes

### Issue: "Room streams not updating"
**Solution**: Verify rxdart package installed and imported

### Issue: "Transaction failures during migration"
**Solution**: Reduce batch size from 10 to 5

---

## 📊 Monitoring

### Firestore Console Checks
1. Navigate to `rooms/{roomCode}`
2. Verify: No `players` field in room doc
3. Click "players" subcollection
4. Verify: All players present as documents

### App Checks
1. Create new room
2. Join with multiple devices
3. Submit answers
4. Vote
5. Check heartbeat updates
6. Verify cleanup works

---

## 💡 Best Practices

### For Development
- Start fresh - don't migrate dev data
- Test locally with Firebase emulator
- Use small datasets for testing

### For Production
- Migrate during low-traffic hours
- Monitor error rates closely
- Keep old version available for 24h
- Have rollback script ready

---

## ✅ Post-Migration Validation

```bash
# Check room count
firebase firestore:get rooms --json | jq '. | length'

# Check sample room structure
firebase firestore:get rooms/{someRoomCode}

# Check sample player
firebase firestore:get rooms/{someRoomCode}/players/{somePlayerId}
```

### Expected Output

```json
// Room document (NO players array)
{
  "code": "ABC123",
  "hostId": "user123",
  "phase": "lobby",
  "currentRound": 0,
  "totalRounds": 5,
  "createdAt": "2026-02-18T10:30:00Z"
}

// Player document
{
  "id": "user123",
  "name": "Alice",
  "score": 300,
  "isHost": true,
  "lastSeen": "2026-02-18T10:35:00Z",
  "isOnline": true,
  "currentAnswer": null,
  "votedFor": null
}
```

---

## 🎓 Summary

### Development
**Just delete all rooms** - No migration needed

### Production
1. **Backup** all data
2. **Test** migration on copy
3. **Run** migration script
4. **Verify** new structure
5. **Deploy** new app version
6. **Monitor** for issues

### Success Criteria
- ✅ No `players` arrays in room documents
- ✅ All players in subcollections
- ✅ All required fields present
- ✅ App functions normally
- ✅ No error rate increase

---

**Migration Complexity**: Medium  
**Estimated Downtime**: < 5 minutes  
**Rollback Time**: < 2 minutes  
**Risk Level**: Low (with proper testing)
