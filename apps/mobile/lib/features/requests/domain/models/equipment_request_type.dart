import 'package:flutter/material.dart';

enum EquipmentRequestType {
  posTerminal,
  cashDrawer,
  shelving,
  storage,
  security,
  consumables,
  uniform,
}

extension EquipmentRequestTypeX on EquipmentRequestType {
  String get value {
    switch (this) {
      case EquipmentRequestType.posTerminal:
        return 'pos_terminal';
      case EquipmentRequestType.cashDrawer:
        return 'cash_drawer';
      case EquipmentRequestType.shelving:
        return 'shelving';
      case EquipmentRequestType.storage:
        return 'storage';
      case EquipmentRequestType.security:
        return 'security';
      case EquipmentRequestType.consumables:
        return 'consumables';
      case EquipmentRequestType.uniform:
        return 'uniform';
    }
  }

  String get label {
    switch (this) {
      case EquipmentRequestType.posTerminal:
        return 'POS / Ödeme Ekipmanı';
      case EquipmentRequestType.cashDrawer:
        return 'Kasa ve Çekmece';
      case EquipmentRequestType.shelving:
        return 'Raf ve Teşhir';
      case EquipmentRequestType.storage:
        return 'Depolama ve Lojistik';
      case EquipmentRequestType.security:
        return 'Güvenlik ve Kamera';
      case EquipmentRequestType.consumables:
        return 'Sarf Malzemeleri';
      case EquipmentRequestType.uniform:
        return 'Üniforma ve Kıyafet';
    }
  }

  String? get description {
    switch (this) {
      case EquipmentRequestType.posTerminal:
        return 'Yeni POS cihazı, temassız pinpad veya yardımcı aparat.';
      case EquipmentRequestType.cashDrawer:
        return 'Yazar kasa, para çekmecesi ya da fatura yazıcısı ihtiyacı.';
      case EquipmentRequestType.shelving:
        return 'Raf, stand, teşhir paneli ya da reyon düzenleme ekipmanları.';
      case EquipmentRequestType.storage:
        return 'Depolama, soğutucu, taşıma arabası gibi lojistik ekipmanlar.';
      case EquipmentRequestType.security:
        return 'Kamera, alarm, kilit ya da güvenlikle ilgili donanımlar.';
      case EquipmentRequestType.consumables:
        return 'Termal rulo, poşet, etiket, temizlik ürünü gibi sarf malzemeler.';
      case EquipmentRequestType.uniform:
        return 'Personel kıyafetleri, yelek, isimlik ve aksesuar ihtiyaçları.';
    }
  }

  IconData get icon {
    switch (this) {
      case EquipmentRequestType.posTerminal:
        return Icons.point_of_sale;
      case EquipmentRequestType.cashDrawer:
        return Icons.account_balance_wallet_outlined;
      case EquipmentRequestType.shelving:
        return Icons.storefront;
      case EquipmentRequestType.storage:
        return Icons.inventory_2_outlined;
      case EquipmentRequestType.security:
        return Icons.security_outlined;
      case EquipmentRequestType.consumables:
        return Icons.shopping_basket_outlined;
      case EquipmentRequestType.uniform:
        return Icons.checkroom_outlined;
    }
  }

  static EquipmentRequestType fromValue(String raw) {
    switch (raw) {
      case 'pos_terminal':
        return EquipmentRequestType.posTerminal;
      case 'cash_drawer':
        return EquipmentRequestType.cashDrawer;
      case 'shelving':
        return EquipmentRequestType.shelving;
      case 'storage':
        return EquipmentRequestType.storage;
      case 'security':
        return EquipmentRequestType.security;
      case 'consumables':
        return EquipmentRequestType.consumables;
      case 'uniform':
        return EquipmentRequestType.uniform;
      default:
        return EquipmentRequestType.storage;
    }
  }

  static EquipmentRequestType? maybeFromValue(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return fromValue(raw);
  }
}
