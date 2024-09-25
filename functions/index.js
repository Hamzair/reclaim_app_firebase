const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

exports.sendUserNotification = functions.firestore
  .document('userNotifications/{userId}/notifications/{notificationId}')
  .onCreate(async (snapshot, context) => {
    const notificationData = snapshot.data();
    const userId = context.params.userId;

    // Fetch the user's FCM token from userDetails collection
    const userDetailsRef = admin.firestore().collection('userDetails').doc(userId);
    const userDetailsSnapshot = await userDetailsRef.get();

    if (!userDetailsSnapshot.exists) {
      console.error('User not found:', userId);
      return;
    }

    const fcmToken = userDetailsSnapshot.data().fcmToken;

    if (!fcmToken) {
      console.error('FCM token not found for user:', userId);
      return;
    }

    // Construct the notification message
    const message = {
      token: fcmToken,
      notification: {
        title: notificationData.title,
        body: `You have a new notification: ${notificationData.notificationType}`,
      },
      data: {
        orderId: notificationData.orderId || '',
        productId: notificationData.productId || '',
        notificationType: notificationData.notificationType || '',
      }
    };

    // Send notification via Firebase Cloud Messaging
    try {
      const response = await admin.messaging().send(message);
      console.log('Successfully sent notification:', response);
    } catch (error) {
      console.error('Error sending notification:', error);

      // Handle "messaging/registration-token-not-registered" error
      if (error.code === 'messaging/registration-token-not-registered') {
        console.warn(`FCM token for user ${userId} is no longer valid. Removing token from userDetails.`);

        // Update user document to remove the invalid token
        await userDetailsRef.update({ fcmToken: admin.firestore.FieldValue.delete() });
      }
    }
  });


exports.sendChatNotification = functions.firestore
  .document('userMessages/{chatId}/messages/{messageId}')
  .onCreate(async (snapshot, context) => {
    const messageData = snapshot.data(); // Get the new message data
    const userId = messageData.userId; // Get userId from the message document
    const chatId = context.params.chatId; // Get chatId from the Firestore path

    if (!userId) {
      console.error('No userId found in message document.');
      return;
    }

    try {
      // Fetch the first document from the convo collection of this chat
      const convoSnapshot = await admin
        .firestore()
        .collection('chats')
        .doc(userId)
        .collection('convo')
        .limit(1)
        .get();

      if (convoSnapshot.empty) {
        console.error('No conversation found for user:', userId);
        return;
      }

      const convoData = convoSnapshot.docs[0].data(); // Get the first convo document

      let recipientId; // This will store the recipient's userId
      if (userId === convoData.sellerId) {
        // If the message sender is the seller, notify the buyer
        recipientId = convoData.buyerId;
      } else {
        // If the message sender is not the seller, notify the seller
        recipientId = convoData.sellerId;
      }

      if (!recipientId) {
        console.error('Recipient ID not found in conversation.');
        return;
      }

      // Fetch the FCM token of the recipient from userDetails collection
      const userDetailsRef = admin.firestore().collection('userDetails').doc(recipientId);
      const userDetailsSnapshot = await userDetailsRef.get();

      if (!userDetailsSnapshot.exists) {
        console.error('User not found:', recipientId);
        return;
      }

      const fcmToken = userDetailsSnapshot.data().fcmToken;

      if (!fcmToken) {
        console.error('FCM token not found for user:', recipientId);
        return;
      }

      // Construct the notification message
      const message = {
        token: fcmToken,
        notification: {
          title: 'New Message',
          body: messageData.message || 'You have a new message!',
        },
        data: {
          messageId: context.params.messageId,
          chatId: chatId,
          senderId: userId,
        },
      };

      // Send notification via Firebase Cloud Messaging
      const response = await admin.messaging().send(message);
      console.log('Successfully sent chat notification:', response);

    } catch (error) {
      console.error('Error processing chat notification:', error);
    }
  });

exports.sendNotificationOnOfferStatusChange = functions.firestore
    .document('orders/{orderId}')
    .onUpdate(async (change, context) => {
        const after = change.after.data();
        const before = change.before.data();

        const orderId = context.params.orderId;
        const offersAfter = after.offers;
        const offersBefore = before.offers;

        // Check if isAccepted has changed
        if (offersAfter.isAccepted !== offersBefore.isAccepted) {
            const buyerId = after.buyerId;  // Fetch buyerId from the document
            const offerPrice = offersAfter.offerPrice;  // Fetch the offer price

            let notificationTitle = '';
            let notificationBody = '';

            // Determine the type of notification based on isAccepted value
            if (offersAfter.isAccepted === 'accepted') {
                notificationTitle = 'Offer Accepted';
                notificationBody = `Your offer of $${offerPrice} has been accepted for order ID: ${orderId}.`;
            } else if (offersAfter.isAccepted === 'rejected') {
                notificationTitle = 'Offer Rejected';
                notificationBody = `Your offer of $${offerPrice} has been rejected for order ID: ${orderId}.`;
            }

            try {
                // Fetch buyer's FCM token from userDetails collection
                const userDoc = await admin.firestore().collection('userDetails').doc(buyerId).get();

                if (!userDoc.exists) {
                    console.error('User not found for buyerId:', buyerId);
                    return null;
                }

                const userData = userDoc.data();
                const buyerToken = userData.fcmToken;  // Assuming the FCM token is stored as fcmToken

                const message = {
                    token: buyerToken,  // Buyer's FCM token
                    notification: {
                        title: notificationTitle,
                        body: notificationBody,
                    },
                    data: {
                        orderId: context.params.orderId,  // Order ID in the data payload
                        buyerId: buyerId,  // Buyer ID
                        offerPrice: offerPrice.toString(),  // Offer price as string
                    },
                };

                // Send notification to the buyer's device
                const response = await admin.messaging().send(message);
                console.log('Successfully sent offer status notification:', response);
            } catch (error) {
                console.error('Error sending notification:', error);
            }
        }

        return null;  // Return null if no change in isAccepted field
    });
