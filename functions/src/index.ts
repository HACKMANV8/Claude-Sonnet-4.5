import { onRequest } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import express, { Request, Response } from "express";
import cors from "cors";
import crypto from "crypto";
import Razorpay from "razorpay";
import { initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { defineSecret } from "firebase-functions/params";
import { updatePCI, pciDailyRecovery } from "./pci";

initializeApp();
const db = getFirestore();

const razorpayKeyId = defineSecret("RAZORPAY_KEY_ID");
const razorpayKeySecret = defineSecret("RAZORPAY_KEY_SECRET");
const webhookSecretParam = defineSecret("RAZORPAY_WEBHOOK_SECRET");

function getConfig() {
  const keyId = process.env.RAZORPAY_KEY_ID || razorpayKeyId.value();
  const keySecret = process.env.RAZORPAY_KEY_SECRET || razorpayKeySecret.value();
  const webhookSecret = process.env.RAZORPAY_WEBHOOK_SECRET || webhookSecretParam.value();
  if (!keyId || !keySecret) {
    logger.error("Missing Razorpay credentials. Set env or functions config.");
    throw new Error("Missing Razorpay credentials");
  }
  if (!webhookSecret) {
    logger.warn("Missing webhook secret; webhook verification will fail.");
  }
  return { keyId, keySecret, webhookSecret };
}

const app = express();
app.use(cors({ origin: true }));
app.use(express.json({ verify: (req: any, _res, buf) => (req.rawBody = buf) }));

app.post("/createOrder", async (req: Request, res: Response) => {
  try {
    const { keyId, keySecret } = getConfig();
    const { amount, currency = "INR", receipt = `rcpt_${Date.now()}`, notes = {} } = req.body || {};
    const amt = Number(amount);
    if (!amt || amt < 1) return res.status(400).json({ error: "Invalid amount" });

    const rzp = new Razorpay({ key_id: keyId, key_secret: keySecret });
    const order = await rzp.orders.create({ amount: amt, currency, receipt, notes });
    return res.json({ orderId: order.id, amount: order.amount, currency: order.currency, keyId });
  } catch (e: any) {
    logger.error("createOrder error", e);
    return res.status(500).json({ error: e?.message || "Server error" });
  }
});

app.post("/webhook", async (req: any, res: Response) => {
  try {
    const { webhookSecret } = getConfig();
    const signature = req.get("x-razorpay-signature");
    const body = req.rawBody as Buffer;
    if (!webhookSecret || !signature || !body) return res.status(400).send("Bad Request");

    const digest = crypto.createHmac("sha256", webhookSecret).update(body).digest("hex");
    if (digest !== signature) return res.status(400).send("Invalid signature");

    const event = req.body;
    const type: string = event?.event;
    const paymentEntity = event?.payload?.payment?.entity;
    const orderEntity = event?.payload?.order?.entity;

    let status = "pending";
    let paymentId: string | undefined;
    let billId: string | undefined = paymentEntity?.notes?.billId || orderEntity?.notes?.billId;
    const voucherId: string | undefined = paymentEntity?.notes?.voucherId || orderEntity?.notes?.voucherId;
    if (type === "payment.captured" || type === "order.paid") {
      status = "success";
      paymentId = paymentEntity?.id || event?.payload?.payment?.entity?.id;
    } else if (type?.startsWith("payment.failed")) {
      status = "failed";
      paymentId = paymentEntity?.id;
    }

    if (paymentId) {
      await db.collection("payments").doc(paymentId).set(
        {
          status,
          razorpayPaymentId: paymentId,
          billId: billId || null,
          updatedAt: new Date(),
        },
        { merge: true }
      );

      // Award Liquid Coins on successful payments (idempotent)
      if (status === "success") {
        try {
          const paySnap = await db.collection("payments").doc(paymentId).get();
          const userId: string | undefined = paySnap.get("userId");
          const amountPaise: number | undefined = paySnap.get("amountPaise");
          if (userId && typeof amountPaise === "number") {
            const baseCoins = amountPaise; // 1 coin per paise (100 coins = ₹1)
            // Weekend 2x multiplier
            const now = new Date();
            const day = now.getDay(); // 0 = Sun, 6 = Sat
            const multiplier = (day === 0 || day === 6) ? 2 : 1;
            const coins = baseCoins * multiplier;
            const userRef = db.collection("users").doc(userId);
            const ledgerRef = userRef.collection("coin_ledger").doc(`payment_${paymentId}`);

            await db.runTransaction(async (tx) => {
              const ledgerDoc = await tx.get(ledgerRef);
              if (ledgerDoc.exists) return; // already awarded
              const userDoc = await tx.get(userRef);
              const current = (userDoc.get("coinBalance") as number) || 0;
              tx.set(userRef, { coinBalance: current + coins }, { merge: true });
              tx.set(ledgerRef, {
                type: "earn",
                amount: coins,
                note: multiplier > 1 ? `Payment ${paymentId} (Weekend x${multiplier})` : `Payment ${paymentId}`,
                createdAt: new Date(),
              });
            });
          }
          // Update PCI (Payment Consistency Index)
          try {
            const userIdPCI: string | undefined = paySnap.get("userId");
            const firstAttemptAt: Date | undefined = paySnap.get("firstAttemptAt")?.toDate?.() || undefined;
            const createdAt: Date = (paymentEntity?.created_at ? new Date(paymentEntity.created_at * 1000) : new Date());
            const onTime = !!firstAttemptAt ? ((createdAt.getTime() - firstAttemptAt.getTime()) <= 5*60*1000) : true;
            const delayed = !!firstAttemptAt ? ((createdAt.getTime() - firstAttemptAt.getTime()) > 5*60*1000) : false;
            if (userIdPCI) {
              await updatePCI(userIdPCI, createdAt, { onTime, delayed, failedOnly: false });
            }
          } catch (e) {
            logger.error("pci update error", e);
          }
          if (userId && voucherId) {
            await db.collection("users").doc(userId).collection("vouchers").doc(voucherId).set({ status: "used", redeemedAt: new Date() }, { merge: true });
          }
        } catch (e) {
          logger.error("coins award error", e);
        }
      }
    }
    // Handle failed events for PCI (failed-only day marker)
    try {
      if (status === "failed") {
        const uid = paymentEntity?.notes?.uid || orderEntity?.notes?.uid || undefined;
        if (uid) {
          const when = (paymentEntity?.created_at ? new Date(paymentEntity.created_at * 1000) : new Date());
          await updatePCI(uid, when, { onTime: false, delayed: false, failedOnly: true });
        }
      }
    } catch (e) {
      logger.error("pci failed-day update error", e);
    }
    if (billId && status === "success") {
      await db.collection("bills").doc(billId).set({ status: "paid" }, { merge: true });
    }
    return res.status(200).send("ok");
  } catch (e: any) {
    logger.error("webhook error", e);
    return res.status(500).send("error");
  }
});

export const api = onRequest({
  cors: true,
  maxInstances: 1,
  secrets: [razorpayKeyId, razorpayKeySecret, webhookSecretParam],
}, app);


