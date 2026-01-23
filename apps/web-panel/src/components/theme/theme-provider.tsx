"use client";

import { createContext, useContext, useEffect, useMemo, useState, type ReactNode } from "react";

type ThemeId = "vibrant" | "minimal" | "sunset" | "ocean" | "forest";

const STORAGE_KEY = "dashboard-theme";

export type ThemeOption = {
  id: ThemeId;
  title: string;
  description: string;
  badge: string;
};

export const THEME_OPTIONS: ThemeOption[] = [
  {
    id: "vibrant",
    title: "Vibrant Gradient",
    description: "Canlı gradientler, glassmorphism ve yumuşak gölgelerle dinamik bir görünüm",
    badge: "Canlı & Cam efektli",
  },
  {
    id: "minimal",
    title: "Modern Minimalist",
    description: "Temiz, yumuşak gölgeler ve accent vurgularla profesyonel görünüm",
    badge: "Monokrom + accent",
  },
  {
    id: "sunset",
    title: "Sunset Glow",
    description: "Sıcak pembe-turuncu geçişler, parlak vurgu ve cam efektler",
    badge: "Sıcak & parlak",
  },
  {
    id: "ocean",
    title: "Ocean Breeze",
    description: "Soğuk mavi-yeşil tonlar, ferah ve temiz görünüm",
    badge: "Serin & ferah",
  },
  {
    id: "forest",
    title: "Forest Dew",
    description: "Doğal yeşil geçişler, dingin kartlar ve yumuşak ışık",
    badge: "Doğal & sakin",
  },
];

type ThemeContextValue = {
  theme: ThemeId;
  setTheme: (id: ThemeId) => void;
};

const ThemeContext = createContext<ThemeContextValue | undefined>(undefined);

export function ThemeProvider({ children }: { children: ReactNode }) {
  const [theme, setThemeState] = useState<ThemeId>("minimal");

  useEffect(() => {
    const saved = (typeof window !== "undefined" && (localStorage.getItem(STORAGE_KEY) as ThemeId | null)) || null;
    if (saved && ["vibrant", "minimal", "sunset", "ocean", "forest"].includes(saved)) {
      setThemeState(saved);
      document.body.dataset.theme = saved;
      return;
    }
    document.body.dataset.theme = "minimal";
  }, []);

  const setTheme = (id: ThemeId) => {
    setThemeState(id);
    if (typeof window !== "undefined") {
      localStorage.setItem(STORAGE_KEY, id);
    }
    document.body.dataset.theme = id;
  };

  const value = useMemo(() => ({ theme, setTheme }), [theme]);

  return <ThemeContext.Provider value={value}>{children}</ThemeContext.Provider>;
}

export function useTheme() {
  const ctx = useContext(ThemeContext);
  if (!ctx) {
    throw new Error("useTheme must be used within ThemeProvider");
  }
  return ctx;
}
