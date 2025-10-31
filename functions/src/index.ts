import { onRequest } from "firebase-functions/v2/https";
import * as logger from "firebase-functions/logger";
import express, { Request, Response } from "express";
import cors from "cors";
import crypto from "crypto";
import Razorpay from "razorpay";
import { initializeApp } from "firebase-admin/app";
import { getFirestore } from "firebase-admin/firestore";
import { defineSecret } from "firebase-functions/params";

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


