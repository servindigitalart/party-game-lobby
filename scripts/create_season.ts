// scripts/create_season.ts
/**
 * Admin script to create a new season
 * 
 * Usage:
 * 1. Install dependencies: npm install
 * 2. Set GOOGLE_APPLICATION_CREDENTIALS environment variable
 * 3. Run: npx ts-node scripts/create_season.ts
 */

import * as admin from 'firebase-admin';

// Initialize Firebase Admin
const serviceAccount = require('../service-account-key.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

interface SeasonConfig {
  name: string;
  durationDays: number;
  themeColor: string;
}

/**
 * Create a new season
 */
async function createSeason(config: SeasonConfig): Promise<string> {
  const now = admin.firestore.Timestamp.now();
  
  // Calculate end date
  const endDate = new admin.firestore.Timestamp(
    now.seconds + config.durationDays * 24 * 60 * 60,
    now.nanoseconds
  );

  // Check for existing active seasons
  const activeSeasons = await db
    .collection('seasons')
    .where('isActive', '==', true)
    .get();

  if (!activeSeasons.empty) {
    console.warn('⚠️  Found active season(s):');
    activeSeasons.forEach(doc => {
      const data = doc.data();
      console.log(`   - ${doc.id}: ${data.name} (ends: ${data.endDate.toDate()})`);
    });
    
    const readline = require('readline').createInterface({
      input: process.stdin,
      output: process.stdout,
    });

    const answer = await new Promise<string>((resolve) => {
      readline.question('Continue creating new season? (yes/no): ', resolve);
    });
    
    readline.close();

    if (answer.toLowerCase() !== 'yes') {
      throw new Error('Season creation cancelled by user');
    }
  }

  // Create season document
  const seasonRef = db.collection('seasons').doc();
  
  await seasonRef.set({
    name: config.name,
    startDate: now,
    endDate: endDate,
    themeColor: config.themeColor,
    isActive: true,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  console.log('✅ Season created successfully!');
  console.log(`   ID: ${seasonRef.id}`);
  console.log(`   Name: ${config.name}`);
  console.log(`   Start: ${now.toDate()}`);
  console.log(`   End: ${endDate.toDate()}`);
  console.log(`   Duration: ${config.durationDays} days`);
  console.log(`   Theme Color: ${config.themeColor}`);

  return seasonRef.id;
}

/**
 * List all seasons
 */
async function listSeasons(): Promise<void> {
  const seasons = await db.collection('seasons').orderBy('createdAt', 'desc').get();

  if (seasons.empty) {
    console.log('No seasons found');
    return;
  }

  console.log('\n📋 All Seasons:\n');
  
  seasons.forEach((doc, index) => {
    const data = doc.data();
    const status = data.isActive ? '🟢 ACTIVE' : '⚪ ENDED';
    const now = admin.firestore.Timestamp.now();
    const hasEnded = data.endDate.seconds < now.seconds;
    
    console.log(`${index + 1}. ${status} ${data.name}`);
    console.log(`   ID: ${doc.id}`);
    console.log(`   Period: ${data.startDate.toDate().toLocaleDateString()} - ${data.endDate.toDate().toLocaleDateString()}`);
    
    if (data.isActive && hasEnded) {
      console.log('   ⚠️  Should be finalized (ended but still active)');
    }
    
    console.log('');
  });
}

/**
 * Main execution
 */
async function main() {
  const args = process.argv.slice(2);
  const command = args[0];

  try {
    if (command === 'list') {
      await listSeasons();
    } else if (command === 'create') {
      // Parse arguments
      const name = args[1] || 'Temporada 1';
      const durationDays = parseInt(args[2]) || 30;
      const themeColor = args[3] || '#FF6B6B';

      await createSeason({
        name,
        durationDays,
        themeColor,
      });
    } else {
      console.log('Usage:');
      console.log('  npx ts-node scripts/create_season.ts list');
      console.log('  npx ts-node scripts/create_season.ts create [name] [durationDays] [themeColor]');
      console.log('');
      console.log('Examples:');
      console.log('  npx ts-node scripts/create_season.ts create "Temporada 1" 30 "#FF6B6B"');
      console.log('  npx ts-node scripts/create_season.ts create "Temporada de Verano" 45 "#FFD700"');
    }

    process.exit(0);
  } catch (error: any) {
    console.error('❌ Error:', error.message);
    process.exit(1);
  }
}

main();
