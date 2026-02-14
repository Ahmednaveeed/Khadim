import 'package:flutter/material.dart';
import '../models/cart_item.dart';
import '../models/menu_item.dart';
import '../models/deal_model.dart';

class CartProvider extends ChangeNotifier {
  final List<CartItem> _items = [];

  List<CartItem> get items => _items;

  double get totalPrice =>
      _items.fold(0, (sum, item) => sum + (item.price * item.quantity));

  int get cartCount =>
      _items.fold(0, (sum, item) => sum + item.quantity);

  // -------------------------------------------------
  // UNIVERSAL ADD (used by MenuScreen & OffersScreen)
  // -------------------------------------------------
  void addItem(CartItem item) {
    final index = _items.indexWhere((e) => e.id == item.id);

    if (index != -1) {
      _items[index].quantity += item.quantity;
    } else {
      _items.add(item);
    }

    notifyListeners();
  }

  // -------------------------------------------------
  // ADD MENU ITEM (Not used anymore, but kept clean)
  // -------------------------------------------------
  void addMenuItem(MenuItemModel item, {String? image}) {
    addItem(
      CartItem(
        id: item.itemId.toString(),
        name: item.itemName,
        title: item.itemName,
        price: item.itemPrice.toDouble(),
        quantity: 1,
        type: "menu",
        image: image,
      ),
    );
  }

  // -------------------------------------------------
  // ADD DEAL
  // -------------------------------------------------
  void addDeal(DealModel deal, {String? image}) {
    addItem(
      CartItem(
        id: deal.dealId.toString(),
        name: deal.dealName,
        title: deal.dealName,
        price: deal.dealPrice.toDouble(),
        quantity: 1,
        type: "deal",
        image: image,
      ),
    );
  }

  // -------------------------------------------------
  // REMOVE ITEM
  // -------------------------------------------------
  void removeItem(CartItem item) {
    _items.remove(item);
    notifyListeners();
  }

  // -------------------------------------------------
  // QUANTITY UPDATE
  // -------------------------------------------------
  void increaseQuantity(CartItem item) {
    item.quantity++;
    notifyListeners();
  }

  void decreaseQuantity(CartItem item) {
    if (item.quantity > 1) {
      item.quantity--;
    } else {
      _items.remove(item);
    }
    notifyListeners();
  }

  // -------------------------------------------------
  // CLEAR CART
  // -------------------------------------------------
  void clear() {
    _items.clear();
    notifyListeners();
  }
}
