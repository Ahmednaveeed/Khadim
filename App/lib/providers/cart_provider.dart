import 'package:flutter/material.dart';
import '../models/cart_item.dart';
import '../models/menu_item.dart';
import '../models/deal_model.dart';
import '../services/cart_service.dart';
import '../services/cart_storage.dart';

class CartProvider extends ChangeNotifier {
  final List<CartItem> _items = [];

  String? _cartId;
  bool _isSyncing = false;
  String? _error;

  List<CartItem> get items => _items;
  String? get cartId => _cartId;
  bool get isSyncing => _isSyncing;
  String? get error => _error;

  double get totalPrice =>
      _items.fold(0, (sum, item) => sum + (item.price * item.quantity));

  int get cartCount => _items.fold(0, (sum, item) => sum + item.quantity);


  /////// INIT CART ///////
  Future<void> initCart(String userId) async {
    _isSyncing = true;
    _error = null;
    notifyListeners();

    try {
      // 1) Always ask backend for the active cart (source of truth)
      final res = await CartService.getOrCreateActiveCart();
      final serverCartId = (res["cart_id"] ?? "").toString();

      if (serverCartId.isEmpty) {
        throw Exception("Cart creation failed (missing cart_id)");
      }

      // 2) If server gave a different cart than local, update local storage
      _cartId = serverCartId;
      await CartStorage.saveCartId(_cartId!);

      // 3) Pull fresh items
      await sync();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  /////// SYNC ///////
  Future<void> sync() async {
    if (_cartId == null) return;

    _isSyncing = true;
    _error = null;
    notifyListeners();

    try {
      final res = await CartService.getSummary(cartId: _cartId!);

      // Backend might return either {data:{...}} or direct object
      final data = res["data"] ?? res;

      final List<dynamic> serverItems =
      (data["items"] ?? data["cart_items"] ?? []) as List<dynamic>;

      _items
        ..clear()
        ..addAll(serverItems.map((x) {
          final m = x as Map<String, dynamic>;

          final itemId = (m["item_id"] ?? m["id"] ?? "").toString();
          final itemType = (m["item_type"] ?? m["type"] ?? "").toString();

          final unitPriceNum = m["unit_price"] ?? m["price"] ?? 0;
          final qtyNum = m["quantity"] ?? 1;

          return CartItem(
            id: "$itemType:$itemId", // stable composite id for UI
            name: (m["item_name"] ?? m["name"] ?? "").toString(),
            title: (m["item_name"] ?? m["title"] ?? m["name"] ?? "").toString(),
            price: (unitPriceNum is num) ? unitPriceNum.toDouble() : 0.0,
            quantity: (qtyNum is num) ? qtyNum.toInt() : 1,
            type: itemType, // "menu_item" or "deal"
            image: (m["image_url"] ?? m["image"])?.toString(),
          );
        }));
    } catch (e) {
      // Fix 2: If the stored cart_id is no longer valid (inactive/abandoned/etc),
      // refresh active cart ONCE and retry.
      try {
        final res = await CartService.getOrCreateActiveCart();
        final newCartId = (res["cart_id"] ?? "").toString();

        if (newCartId.isNotEmpty && newCartId != _cartId) {
          _cartId = newCartId;
          await CartStorage.saveCartId(_cartId!);

          final res2 = await CartService.getSummary(cartId: _cartId!);
          final data2 = res2["data"] ?? res2;

          final List<dynamic> serverItems =
          (data2["items"] ?? data2["cart_items"] ?? []) as List<dynamic>;

          _items
            ..clear()
            ..addAll(serverItems.map((x) {
              final m = x as Map<String, dynamic>;

              final itemId = (m["item_id"] ?? m["id"] ?? "").toString();
              final itemType = (m["item_type"] ?? m["type"] ?? "").toString();

              final unitPriceNum = m["unit_price"] ?? m["price"] ?? 0;
              final qtyNum = m["quantity"] ?? 1;

              return CartItem(
                id: "$itemType:$itemId",
                name: (m["item_name"] ?? m["name"] ?? "").toString(),
                title: (m["item_name"] ?? m["title"] ?? m["name"] ?? "").toString(),
                price: (unitPriceNum is num) ? unitPriceNum.toDouble() : 0.0,
                quantity: (qtyNum is num) ? qtyNum.toInt() : 1,
                type: itemType,
                image: (m["image_url"] ?? m["image"])?.toString(),
              );
            }));

          _error = null;
          return; // important
        }
      } catch (_) {
        // ignore refresh failure, fall back to original error below
      }

      _error = e.toString();
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }
  /////// ADD MENU ITEM ///////
  Future<void> addMenuItem(MenuItemModel item) async {
    if (_cartId == null) return;

    await CartService.addItem(
      cartId: _cartId!,
      itemType: "menu_item",
      itemId: item.itemId,
      quantity: 1,
    );

    await sync();
  }

  /////// ADD DEAL ///////
  Future<void> addDeal(DealModel deal) async {
    if (_cartId == null) return;

    await CartService.addItem(
      cartId: _cartId!,
      itemType: "deal",
      itemId: deal.dealId,
      quantity: 1,
    );

    await sync();
  }

  /////// UPDATE QTY ///////

  Future<void> updateQty({
    required int itemId,
    required String itemType,
    required int quantity,
  }) async
  {
    if (_cartId == null) return;

    await CartService.setQuantity(
      cartId: _cartId!,
      itemType: itemType,
      itemId: itemId,
      quantity: quantity,
    );

    await sync();
  }

  /////// REMOVE ///////

  Future<void> removeById({
    required int itemId,
    required String itemType,
  }) async {
    if (_cartId == null) return;

    await CartService.removeItem(
      cartId: _cartId!,
      itemType: itemType,
      itemId: itemId,
    );

    await sync();
  }

  void reset() {
    _items.clear();
    _cartId = null;
    _error = null;
    _isSyncing = false;
    notifyListeners();
  }
}