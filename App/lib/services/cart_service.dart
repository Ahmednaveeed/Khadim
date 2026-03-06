import 'api_client.dart';

class CartService {
  /////// CART ACTIVE (GET OR CREATE) ///////
  static Future<Map<String, dynamic>> getOrCreateActiveCart() async {
    return ApiClient.postJson(
      "/cart/active",
      auth: true,
      body: {}, // backend reads user from token
    );
  }

  /////// CART SUMMARY ///////
  static Future<Map<String, dynamic>> getSummary({
    required String cartId,
  }) async {
    return ApiClient.getJson(
      "/cart/$cartId",
      auth: true,
      retryOnNetworkError: true,
    );
  }

  /////// ADD ITEM ///////
  static Future<Map<String, dynamic>> addItem({
    required String cartId,
    required String itemType, // "menu_item" or "deal"
    required int itemId,
    int quantity = 1,
  }) async {
    return ApiClient.postJson(
      "/cart/items/add",
      auth: true,
      body: {
        "cart_id": cartId,
        "item_type": itemType,
        "item_id": itemId,
        "quantity": quantity,
      },
    );
  }

  /////// SET QTY ///////
  static Future<Map<String, dynamic>> setQuantity({
    required String cartId,
    required String itemType,
    required int itemId,
    required int quantity,
  }) async {
    return ApiClient.putJson(
      "/cart/items/qty",
      auth: true,
      body: {
        "cart_id": cartId,
        "item_type": itemType,
        "item_id": itemId,
        "quantity": quantity,
      },
    );
  }

  /////// REMOVE ITEM ///////
  static Future<Map<String, dynamic>> removeItem({
    required String cartId,
    required String itemType,
    required int itemId,
  }) async {
    return ApiClient.postJson(
      "/cart/items/remove",
      auth: true,
      body: {
        "cart_id": cartId,
        "item_type": itemType,
        "item_id": itemId,
      },
    );
  }

  /////// PLACE ORDER ///////
  static Future<Map<String, dynamic>> placeOrder({
    required String deliveryAddress,
    double deliveryFee = 2.99,
    double taxRate = 0.0,
  }) async {
    return ApiClient.postJson(
      "/cart/place_order",
      auth: true,
      body: {
        "delivery_address": deliveryAddress,
        "delivery_fee": deliveryFee,
        "tax_rate": taxRate,
      },
    );
  }

}