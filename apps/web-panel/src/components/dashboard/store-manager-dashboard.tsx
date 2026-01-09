import { AlarmClock, ClipboardList, Users } from "lucide-react";

export function StoreManagerDashboard() {
  return (
    <>
      <header className="page-header">
        <h2>Mağaza Müdürü Paneli</h2>
        <p>Mobil uygulamadaki akışların web yansıması için placeholder bileşenler.</p>
      </header>
      <section className="card">
        <h3>SKT Kontrolü</h3>
        <p>Supabase’den SKT kayıtlarını çekip aksiyon alınacak ekran burada şekillenecek.</p>
      </section>
      <section className="card">
        <h3>Vardiya Planlama</h3>
        <p>Vardiya kartları, onay süreçleri ve dijital imzalar için taslak alan.</p>
      </section>
      <section className="card">
        <h3>Personel Yönetimi</h3>
        <p>Şube çalışanlarını ekleme, rol atama ve erişim ayarlarının yapılacağı alan.</p>
      </section>
    </>
  );
}
