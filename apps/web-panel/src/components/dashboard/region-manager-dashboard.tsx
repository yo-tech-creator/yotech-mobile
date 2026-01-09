import { Megaphone, Users } from "lucide-react";

export function RegionManagerDashboard() {
  return (
    <>
      <header className="page-header">
        <h2>Bölge Müdürü Paneli</h2>
        <p>Şubelerinizin performansını izleyip görev/duyuru atayacağınız bileşenler burada.</p>
      </header>
      <section className="card">
        <h3>Şube Durumu</h3>
        <p>Supabase fonksiyonları üzerinden bölgeye bağlı şubeler veri tablosu getirilecek.</p>
      </section>
      <section className="card">
        <h3>Duyuru & Görev</h3>
        <p>Şubelere yönelik duyuru ve görev planlama araçlarının placeholder alanı.</p>
      </section>
    </>
  );
}
