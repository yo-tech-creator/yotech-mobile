import { Boxes, Package, Users } from "lucide-react";

export function FirmaAdminOverview() {
  return (
    <>
      <header className="page-header">
        <h2>Firma Admin Paneli</h2>
        <p>
          Şubeler, kullanıcılar ve ürün kataloğu üzerindeki günlük işlemlerinizi bu panelden
          yönetin. Supabase fonksiyonlarına bağlanacak veri tabloları için placeholder görünüm
          sergilenir.
        </p>
      </header>
      <section className="card">
        <h3>Ürün Yönetimi</h3>
        <p>Ürün kataloğunuza ait stok, fiyat ve modül izinlerini burada yöneteceksiniz.</p>
      </section>
      <section className="card">
        <h3>Şube Yönetimi</h3>
        <p>Aktif şubeleriniz, adres ve operasyonel durumları bu bölümde listelenecek.</p>
      </section>
      <section className="card">
        <h3>Kullanıcı Rolleri</h3>
        <p>İşe alım, rol atama ve erişim düzenlemelerini yapabileceğiniz hazırlık alanı.</p>
      </section>
    </>
  );
}
