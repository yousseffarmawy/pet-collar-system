const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

const db = admin.firestore();

exports.autoUpdate = functions.pubsub
  .schedule("every 1 minutes")
  .onRun(async (context) => {

    for (let i = 0; i < 3; i++) {
      await new Promise(resolve => setTimeout(resolve, 17000));

      const data = {
        heartRate: Math.floor(Math.random() * 40 + 70),
        steps: Math.floor(Math.random() * 100),
        battery: Math.floor(Math.random() * 30 + 70),
        oxygen: Math.floor(Math.random() * 10 + 90),
        lastUpdate: new Date(),
      };

      await db.collection("sensorData").doc("device1").set(data);

      console.log("🔥 Updated:", data);
    }

    return null;
  });