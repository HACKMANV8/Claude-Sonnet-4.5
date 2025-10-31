import { logger } from "firebase-functions";
import { getFirestore, FieldValue, Filter, Timestamp } from "firebase-admin/firestore";
import { onSchedule } from "firebase-functions/v2/scheduler";

const db = getFirestore();

type Flags = {
  onTime: boolean;
  delayed: boolean;
  failedOnly: boolean;
};

function clamp(n: number, lo: number, hi: number): number { return Math.max(lo, Math.min(hi, n)); }

export async function updatePCI(uid: string, eventDate: Date, flags: Flags): Promise<void> {
  const userRef = db.collection("users").doc(uid);
  await db.runTransaction(async (tx) => {
    const userDoc = await tx.get(userRef);
    const now = eventDate;
    const prevScore = (userDoc.get("pciScore") as number) ?? 650;
    const prevStreak = (userDoc.get("pciStreakDays") as number) ?? 0;
    const lastPaymentTs = userDoc.get("pciLastPaymentDate") as Timestamp | undefined;
    const lastPaymentDate = lastPaymentTs?.toDate();
    
    // Day buckets in UTC
    const bucket = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()));
    let streak = prevStreak;
    if (lastPaymentDate) {
      const lastBucket = new Date(Date.UTC(lastPaymentDate.getUTCFullYear(), lastPaymentDate.getUTCMonth(), lastPaymentDate.getUTCDate()));
      const diffDays = Math.round((bucket.getTime() - lastBucket.getTime()) / 86400000);
      if (diffDays === 1 && !flags.failedOnly) streak = prevStreak + 1;
      else if (diffDays === 0) streak = prevStreak; // same-day payments don't change streak counter
      else streak = flags.failedOnly ? 0 : 1; // new success after a gap starts at 1
    } else {
      streak = flags.failedOnly ? 0 : 1;
    }

    // Daily delta
    let delta = 0;
    if (flags.failedOnly) {
      delta -= 15; // failed day with no success
    } else {
      if (flags.onTime) delta += 4;
      if (flags.delayed) delta -= 10;
      delta = Math.min(delta, 8); // cap positive daily delta
      // Streak multipliers only for positive deltas
      if (delta > 0) {
        if (streak >= 60) delta *= 2.0;
        else if (streak >= 30) delta *= 1.5;
      }
    }

    // EWMA: 90% previous score, 10% of today's delta added to baseline 650
    const baseline = 650;
    const target = baseline + delta; // target for today
    const scoreNew = clamp(0.9 * prevScore + 0.1 * target, 300, 900);

    // trend append (cap 120 entries)
    const prevTrend = (userDoc.get("pciTrend") as Array<any>) ?? [];
    const newTrend = [{ ts: now, score: scoreNew }, ...prevTrend].slice(0, 120);

    tx.set(userRef, {
      pciScore: scoreNew,
      pciUpdatedAt: now,
      pciStreakDays: streak,
      pciLastPaymentDate: now,
      pciTrend: newTrend,
      pciDecayAnchor: userDoc.get("pciDecayAnchor") || now,
    }, { merge: true });
  });
}

export const pciDailyRecovery = onSchedule({ schedule: "every day 02:00", timeZone: "Etc/UTC" }, async () => {
  // For users with recent activity, add passive recovery towards 700 baseline
  const snap = await db.collection("users")
    .where("pciUpdatedAt", ">=", new Date(Date.now() - 90*86400000))
    .get();
  const baseline = 700; // recovery soft floor
  for (const doc of snap.docs) {
    try {
      await db.runTransaction(async (tx) => {
        const ref = doc.ref;
        const d = await tx.get(ref);
        let score = (d.get("pciScore") as number) ?? 650;
        const last = (d.get("pciUpdatedAt") as Timestamp | undefined)?.toDate() ?? new Date();
        const now = new Date();
        const days = Math.max(0, Math.floor((now.getTime() - last.getTime())/86400000));
        if (days <= 0) return;
        for (let i=0;i<days;i++) {
          const target = baseline;
          score = clamp(0.95 * score + 0.05 * target, 300, 900); // slower EWMA for recovery
        }
        const prevTrend = (d.get("pciTrend") as Array<any>) ?? [];
        const newTrend = [{ ts: now, score }, ...prevTrend].slice(0,120);
        tx.set(ref, { pciScore: score, pciUpdatedAt: now, pciTrend: newTrend }, { merge: true });
      });
    } catch (e) {
      logger.error("pciDailyRecovery error", e);
    }
  }
});


