import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:get/get_rx/get_rx.dart';
import 'package:get/get_rx/src/rx_types/rx_types.dart';
import 'package:http/http.dart' as http;

import 'package:get/state_manager.dart';
import 'package:reclaim_firebase_app/controller/user_controller.dart';

import 'package:timeago/timeago.dart' as timeago;
import 'package:http/http.dart' as http;

class PriceCache {
  double? price;
  DateTime? timestamp;

  bool get isExpired =>
      timestamp == null || DateTime.now().difference(timestamp!).inSeconds > 5;

  void update(double newPrice) {
    price = newPrice;
    timestamp = DateTime.now();
  }
}

class WalletController extends GetxController {
  var loading = false.obs;

  RxBool isLoading = false.obs;
  RxDouble walletbalance = 0.0.obs;
  RxDouble btcBalance = 0.0.obs;
  RxBool isTopping = false.obs;
  RxBool btcAddressValidation = false.obs;
  final priceCache = PriceCache();
  TextEditingController amountcontroller = TextEditingController();
  TextEditingController withdrawal = TextEditingController();
  TextEditingController btcaddress = TextEditingController();
  UserController userController = Get.find<UserController>();

  Future<void> fetchuserwallet() async {
    try {
      DocumentSnapshot documentSnapshot = await FirebaseFirestore.instance
          .collection('wallet')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .get();

      if (documentSnapshot.exists) {
        dynamic list = documentSnapshot.data();

        // Safely convert the balance to double
        walletbalance.value = (list['balance'] is String)
            ? double.tryParse(list['balance']) ?? 0.0
            : list['balance'].toDouble();

        print(walletbalance.value);
      } else {
        // Handle case where the document does not exist
        print("Wallet document does not exist.");
      }
    } catch (e) {
      // Handle errors
      print("An error occurred while fetching the wallet: $e");
    }
  }

  // Future<void> CreekFees() async {
  //   try {
  //     // double newbalance = walletbalance.value - bookListingController.creekFees.value;
  //     double btcPrice = await fetchBitcoinPrice();
  //     double purchaseinBtc = bookListingController.creekFees.value / btcPrice;
  //     double newbtcbalance = btcBalance.value - purchaseinBtc;
  //     await FirebaseFirestore.instance
  //         .collection('wallet')
  //         .doc(FirebaseAuth.instance.currentUser!.uid)
  //         .update({ 'btcBalance': newbtcbalance});
  //   } catch (e) {
  //     print('Error update balance$e');
  //   }
  // }

  // Future<void> recordWithdrawal(double amountUSD, String addressBTC) async {
  //   print("recordWithdrawal!");
  //   try {
  //     HttpsCallable callable = FirebaseFunctions.instance.httpsCallable('makeWithdrawRequest');
  //     final result = await callable.call(<String, dynamic>{
  //       'amountUSD': amountUSD,
  //       'addressBTC': addressBTC,
  //     });
  //   } catch (e) {
  //     print('Error makeWithdrawRequest: $e');
  //   }
  // }
  // Future<void> updatebalance(int purchasePrice) async {
  //   try {
  //     // int appFees = (purchasePrice * 0.2).round();
  //     // int finalPrice = purchasePrice - appFees;
  //     int newbalance = walletbalance.value - purchasePrice;
  //     await FirebaseFirestore.instance
  //         .collection('wallet')
  //         .doc(FirebaseAuth.instance.currentUser!.uid)
  //         .update({'balance': newbalance});
  //     await storetransactionhistory(purchasePrice, 'buy', 'Walmart');
  //   } catch (e) {
  //     print('Error update balance$e');
  //   }
  // }

  Future<void> storetransactionhistory(
      int price, String purchaseType) async {
    try {
      await FirebaseFirestore.instance
          .collection('wallet')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .collection('transaction')
          .add({
        'price': price,
        'date': DateTime.timestamp(),
        'type': purchaseType
      });
    } catch (e) {
      print('Error storeTransaction$e');
    }
  }

  Future<void> storetopup(int purchasePrice) async {
    try {
      await FirebaseFirestore.instance
          .collection('wallet')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .update({
        'balance': purchasePrice,
      });
    } catch (e) {
      print('Error storeTransaction$e');
    }
  }

  // Future<double> storeTopup(String paymentId, double amountToBuyInUSD) async {
  //   try {
  //     print('toppup');
  //
  //     HttpsCallable callable = FirebaseFunctions.instance.httpsCallable('recordStripeTopup');
  //     final result = await callable.call(<String, dynamic>{
  //       'paymentId': paymentId,
  //       'amountToBuyInUSD': amountToBuyInUSD,
  //     });
  //     print('paymentIdtoppup');
  //
  //     return result.data['btcPurchasedAmount'];
  //   } catch (e) {
  //     print('Error recordStripeTopup: $e');
  //     throw Exception('Error processing top-up: $e');
  //   }
  // }
  RxList<dynamic> transaction = [].obs;
  Future<void> transactionfetch() async {
    QuerySnapshot data = await FirebaseFirestore.instance
        .collection('wallet')
        .doc(FirebaseAuth.instance.currentUser!.uid)
        .collection('transaction')
        .orderBy('purchaseDate', descending: true)
        .get();

    transaction.clear();
    data.docs.forEach((tran) {
      transaction.add({
        'purchasePrice': tran['purchasePrice'],
        'purchaseName': tran['purchaseName'],
        'purchaseDate': tran['purchaseDate'],
        'purchaseType': tran['purchaseType'],
      });
    });
  }

  String formattransactionTime(Timestamp timestamp) {
    DateTime dateTime = timestamp.toDate();
    DateTime now = DateTime.now();

    Duration difference = now.difference(dateTime);
    if (difference.inDays == 0) {
      return 'Today ${dateTime.hour}:${dateTime.minute}';
    } else if (difference.inDays == 1) {
      return 'Yesterday ${dateTime.hour}:${dateTime.minute}';
    } else {
      return timeago.format(dateTime);
    }
  }
}
