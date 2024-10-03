import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:reclaim_firebase_app/controller/productsListing_controller.dart';
import '../const/color.dart';
import '../controller/sign_up_controller.dart';
import '../controller/wallet_controller.dart';
import '../controller/wishlist_controller.dart';

class StripePaymentPurchasing {
  final WalletController walletController = Get.put(WalletController());
  final SignUpController signUpController = Get.put(SignUpController());
  final ProductsListingController productsListingController =
      Get.put(ProductsListingController());

  Map<String, dynamic>? paymentIntents;
  String secretKey =
      "sk_test_51PF3XJBD4iwEMWA7nvI3hZ14p1gCIEI4dWzkhTliZkYafzBkm67TkPNwtn6vWwXXFPBaTZlchZpEdeRKICFZURj100ikoXKwel";
  String calculateAmount(String amount) {
    try {

      // Trim any leading or trailing whitespaces
      amount = amount.trim();

      // Remove any non-numeric characters
      amount = amount.replaceAll(RegExp(r'[^0-9.]'), '');

      // Parse the amount as a double
      final doubleAmount = double.parse(amount);

      // Convert the amount to cents (multiply by 100)
      final result = (doubleAmount * 100).toInt().toString();

      return result;
    } catch (e) {
      print('Error parsing amount: $e');
      // Handle the error appropriately (e.g., return a default value or throw an exception)
      return '0';
    }
  }

  Future<void> paymentPurchasing(
    String amount,
    String listingId,
    String sellerId,
    String brand,
    BuildContext context,
    String productName,
    int purchasePrice,
    String productImage,
      bool isdirectPurchase,
      dynamic order
  ) async {
    print('payment method call here');

    /// creating payments intent
    try {
      signUpController.isLoading.value = true;
      int appFees = (purchasePrice * 0.1).round();
      int finalPrice = purchasePrice + appFees;
      Map<String, dynamic> body = {
        'amount': calculateAmount(finalPrice.toString()),
        'currency': 'Aed',
        'payment_method_types[]': 'card',
      };
      var response = await http.post(
          Uri.parse('https://api.stripe.com/v1/payment_intents'),
          headers: {
            'Authorization': 'Bearer $secretKey', //here will be the secret keys
            'Content-Type': 'application/x-www-form-urlencoded'
          },
          body: body);

      paymentIntents = jsonDecode(response.body);

      print("payment intents here");
      print(paymentIntents);
    } catch (e) {
      signUpController.isLoading.value = false;

      throw Exception(e.toString());
    }
    signUpController.isLoading.value = true;

    ///initialize payments sheet
    await Stripe.instance
        .initPaymentSheet(
            paymentSheetParameters: SetupPaymentSheetParameters(
                setupIntentClientSecret: secretKey,
                paymentIntentClientSecret: paymentIntents!['client_secret'],
                style: ThemeMode.light,
                merchantDisplayName: 'Reclaim',
                // billingDetails: const BillingDetails(
                //     address: Address(city: 'London', country: 'GB', line1: '', line2: 'line2', postalCode: '', state: 'United Kingdom')
                // ),
                appearance: const PaymentSheetAppearance(
                    primaryButton: PaymentSheetPrimaryButtonAppearance(
                        colors: PaymentSheetPrimaryButtonTheme(
                      dark: PaymentSheetPrimaryButtonThemeColors(
                          background: primaryColor, text: whiteColor),
                      light: PaymentSheetPrimaryButtonThemeColors(
                          background: primaryColor, text: whiteColor),
                    )),
                    colors: PaymentSheetAppearanceColors(
                      background: whiteColor,
                    ),
                    shapes: PaymentSheetShape(
                      borderRadius: BorderSide.strokeAlignCenter,
                    ))))
        .then((value) {})
        .onError((error, stackTrace) {
      print(error.toString());
      signUpController.isLoading.value = false;
    });
    signUpController.isLoading.value = true;

    ///Display payment sheet

    try {
      await Stripe.instance.presentPaymentSheet().then((value) async {
if(isdirectPurchase == true){

  productsListingController.buyProduct(listingId, sellerId, brand,
      context, productName, purchasePrice, productImage,);
}else{
  productsListingController
      .buyProduct1(
      listingId,
      sellerId,      brand,
      context,
     productName,
      order['offers']['offerPrice'],
      productImage,
      order['orderId']);
}

        // double newamount = walletController.walletbalance.value +
        //     int.parse(amount);
        // walletController.walletbalance.value = newamount;
        // await walletController.storetopup(newamount.toInt());
        // await walletController.storetransactionhistory(
        //     int.parse(amount), 'deposit');
        // await walletController.transactionfetch();
        // print('newamount $newamount');
        // print('newamount ${walletController.walletbalance.value }');
        // Get.snackbar(
        //     "Paid Successfully", 'Amount is transferred to your wallet');

        signUpController.isLoading.value = false;
      });
    } catch (e) {
      signUpController.isLoading.value = false;

      if (kDebugMode) {
        print('payment Error $e');
      }
      Get.snackbar("Error", 'Payment Cancelled');
      throw Exception(e.toString());
    } finally {
      signUpController.isLoading.value = false;
    }
  }
}
