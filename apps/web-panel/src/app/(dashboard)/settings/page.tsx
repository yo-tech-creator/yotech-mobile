"use client";

import { useTheme, THEME_OPTIONS } from "@/components/theme/theme-provider";

export default function SettingsPage() {
  const { theme, setTheme } = useTheme();

  return (
    <div className="section-grid">
      <div className="page-header">
        <div className="page-header__body">
          <h2>Ayarlar / Tema</h2>
          <p>Panel görünümünü iki hazır tema arasından seç. Canlı gradient veya minimal tek-aksan renk şeması.</p>
        </div>
      </div>

      <div className="theme-grid">
        {THEME_OPTIONS.map((option) => {
          const isActive = theme === option.id;
          return (
            <div key={option.id} className="theme-card" aria-pressed={isActive}>
              <div className={`theme-card__preview ${option.id}`}></div>
              <h3 className="theme-card__title">{option.title}</h3>
              <p className="theme-card__desc">{option.description}</p>
              <div className="theme-card__actions">
                <span className="theme-chip">{isActive ? "Aktif" : option.badge}</span>
                <button
                  className="button button--primary"
                  type="button"
                  onClick={() => setTheme(option.id)}
                  aria-label={`${option.title} temasını etkinleştir`}
                >
                  {isActive ? "Kullanılıyor" : "Temayı uygula"}
                </button>
              </div>
            </div>
          );
        })}
      </div>
    </div>
  );
}
