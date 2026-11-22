/// Modes de paiement (section 9). L'application n'effectue aucun transfert :
/// elle enregistre uniquement le mode et le montant déclarés.
enum PaymentMethod {
  especes('Espèces'),
  orangeMoney('Orange Money'),
  mtnMomo('MTN MoMo'),
  wave('Wave'),
  moovMoney('Moov Money'),
  virement('Virement bancaire'),
  autre('Autre');

  const PaymentMethod(this.label);
  final String label;

  static PaymentMethod fromName(String? name) =>
      PaymentMethod.values.firstWhere((p) => p.name == name, orElse: () => PaymentMethod.especes);
}

/// Statut d'un reçu (section 10) : un reçu annulé ou corrigé reste visible
/// dans l'historique mais n'est plus compté dans les recettes.
enum ReceiptStatus {
  valide('Valide'),
  annule('Annulé'),
  corrige('Corrigé');

  const ReceiptStatus(this.label);
  final String label;

  static ReceiptStatus fromName(String? name) =>
      ReceiptStatus.values.firstWhere((s) => s.name == name, orElse: () => ReceiptStatus.valide);
}

class Merchant {
  final String businessName;
  final String ownerName;
  final String phone;
  final String address;
  final String? logoPath;
  final String currency;
  final String thankYouMessage;

  const Merchant({
    required this.businessName,
    this.ownerName = '',
    this.phone = '',
    this.address = '',
    this.logoPath,
    this.currency = 'FCFA',
    this.thankYouMessage = 'Merci pour votre achat !',
  });

  Merchant copyWith({
    String? businessName,
    String? ownerName,
    String? phone,
    String? address,
    String? logoPath,
    bool clearLogo = false,
    String? currency,
    String? thankYouMessage,
  }) =>
      Merchant(
        businessName: businessName ?? this.businessName,
        ownerName: ownerName ?? this.ownerName,
        phone: phone ?? this.phone,
        address: address ?? this.address,
        logoPath: clearLogo ? null : (logoPath ?? this.logoPath),
        currency: currency ?? this.currency,
        thankYouMessage: thankYouMessage ?? this.thankYouMessage,
      );

  Map<String, Object?> toMap() => {
        'id': 1,
        'business_name': businessName,
        'owner_name': ownerName,
        'phone': phone,
        'address': address,
        'logo_path': logoPath,
        'currency': currency,
        'thank_you': thankYouMessage,
      };

  factory Merchant.fromMap(Map<String, Object?> m) => Merchant(
        businessName: (m['business_name'] as String?) ?? '',
        ownerName: (m['owner_name'] as String?) ?? '',
        phone: (m['phone'] as String?) ?? '',
        address: (m['address'] as String?) ?? '',
        logoPath: m['logo_path'] as String?,
        currency: (m['currency'] as String?) ?? 'FCFA',
        thankYouMessage: (m['thank_you'] as String?) ?? 'Merci pour votre achat !',
      );
}

class Product {
  final int? id;
  final String name;
  final int price; // FCFA : montants entiers
  final String? category;

  const Product({this.id, required this.name, required this.price, this.category});

  Product copyWith({int? id, String? name, int? price, String? category}) =>
      Product(id: id ?? this.id, name: name ?? this.name, price: price ?? this.price, category: category ?? this.category);

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'price': price,
        'category': (category == null || category!.trim().isEmpty) ? null : category!.trim(),
      };

  factory Product.fromMap(Map<String, Object?> m) => Product(
        id: m['id'] as int?,
        name: m['name'] as String,
        price: (m['price'] as num).toInt(),
        category: m['category'] as String?,
      );
}

class ReceiptItem {
  final int? id;
  final String name;
  final int quantity;
  final int unitPrice;

  const ReceiptItem({this.id, required this.name, required this.quantity, required this.unitPrice});

  int get lineTotal => quantity * unitPrice;

  Map<String, Object?> toMap(int receiptId) => {
        'receipt_id': receiptId,
        'name': name,
        'quantity': quantity,
        'unit_price': unitPrice,
      };

  factory ReceiptItem.fromMap(Map<String, Object?> m) => ReceiptItem(
        id: m['id'] as int?,
        name: m['name'] as String,
        quantity: (m['quantity'] as num).toInt(),
        unitPrice: (m['unit_price'] as num).toInt(),
      );
}

class Receipt {
  final int? id;
  final String number;
  final DateTime createdAt;
  final String customerName;
  final List<ReceiptItem> items;
  final int discount;
  final PaymentMethod paymentMethod;
  final ReceiptStatus status;
  final String? note;

  /// Numéro du reçu que celui-ci remplace (correction).
  final String? correctsNumber;

  /// Numéro du reçu qui remplace celui-ci (s'il a été corrigé).
  final String? correctedBy;

  const Receipt({
    this.id,
    required this.number,
    required this.createdAt,
    required this.customerName,
    required this.items,
    this.discount = 0,
    this.paymentMethod = PaymentMethod.especes,
    this.status = ReceiptStatus.valide,
    this.note,
    this.correctsNumber,
    this.correctedBy,
  });

  int get subtotal => items.fold(0, (s, i) => s + i.lineTotal);
  int get total => (subtotal - discount).clamp(0, 1 << 52).toInt();
  bool get countsInSales => status == ReceiptStatus.valide;

  Receipt copyWith({int? id, List<ReceiptItem>? items, ReceiptStatus? status, String? correctedBy}) => Receipt(
        id: id ?? this.id,
        number: number,
        createdAt: createdAt,
        customerName: customerName,
        items: items ?? this.items,
        discount: discount,
        paymentMethod: paymentMethod,
        status: status ?? this.status,
        note: note,
        correctsNumber: correctsNumber,
        correctedBy: correctedBy ?? this.correctedBy,
      );

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'number': number,
        'created_at': createdAt.millisecondsSinceEpoch,
        'customer_name': customerName,
        'discount': discount,
        'subtotal': subtotal,
        'total': total,
        'payment_method': paymentMethod.name,
        'status': status.name,
        'note': note,
        'corrects_number': correctsNumber,
        'corrected_by': correctedBy,
      };

  factory Receipt.fromMap(Map<String, Object?> m, List<ReceiptItem> items) => Receipt(
        id: m['id'] as int?,
        number: m['number'] as String,
        createdAt: DateTime.fromMillisecondsSinceEpoch((m['created_at'] as num).toInt()),
        customerName: (m['customer_name'] as String?) ?? 'Client comptant',
        items: items,
        discount: ((m['discount'] as num?) ?? 0).toInt(),
        paymentMethod: PaymentMethod.fromName(m['payment_method'] as String?),
        status: ReceiptStatus.fromName(m['status'] as String?),
        note: m['note'] as String?,
        correctsNumber: m['corrects_number'] as String?,
        correctedBy: m['corrected_by'] as String?,
      );
}
