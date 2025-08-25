const { onSchedule } = require("firebase-functions/v2/scheduler");
const functions = require("firebase-functions"); // keep if you use other v1 funcs
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

exports.dailyAQINotification = onSchedule(
  {
    schedule: "every day 08:00",
    timeZone: "Africa/Accra",
  },
  async (context) => {
    try {
      const usersSnapshot = await db.collection("users").get();

      const promises = [];

      usersSnapshot.forEach(async (userDoc) => {
  const data = userDoc.data();
  const token = data.fcmToken;
  const aqi = data.currentAQI;

  if (!token || typeof token !== 'string' || token.trim() === '') {
    console.warn(`⚠️ Skipping user ${userDoc.id} – no valid token`);
    return;
  }

  let title = "Air Quality Update";
  let body = "Time to check the air quality around you. Stay safe and informed. 🌍";

  if (aqi > 200) {
    title = "Air Quality Alert 🚨";
    body = "Very unhealthy air detected in your area. Please stay indoors or wear a mask.";
  } else if (aqi > 150) {
    title = "Unhealthy Air Quality 😷";
    body = "Air conditions are poor today. Consider limiting outdoor activities.";
  } else if (aqi > 100) {
    title = "Air Quality Advisory 🥴";
    body = "Unhealthy for sensitive individuals. If you have respiratory conditions, take precautions.";
  } else if (aqi > 50) {
    title = "Moderate Air Quality";
    body = "Air quality is acceptable, but some pollutants may be a concern for sensitive groups.";
  } else {
    title = "Excellent Air Quality 😮‍💨";
    body = "The air is clean and fresh. Enjoy your day!";
  }

  const payload = {
    notification: { title, body },
    token,
  };

  try {
    await admin.messaging().send(payload);
    console.log(`✅ Notification sent to ${userDoc.id}`);
  } catch (error) {
    console.error(`❌ Failed to send to ${userDoc.id}:`, error);
  }
});


      // Wait for all to complete
      await Promise.all(promises);
    } catch (error) {
      console.error("❌ Error sending notifications: ", error);
    }
  }
);
