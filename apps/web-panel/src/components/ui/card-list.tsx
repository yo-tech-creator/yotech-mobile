"use client";

import type { CSSProperties, ReactNode } from "react";

type Tone = "info" | "success" | "warn" | "danger" | "muted";

type CardListShellProps = {
  title: string;
  description?: string;
  stats?: Array<{ label: string; value: ReactNode }>;
  actions?: ReactNode;
  inlineActions?: ReactNode;
  filterContent?: ReactNode;
  pills?: Array<{ label: string; tone?: Tone }>;
  footer?: ReactNode;
  children: ReactNode;
};

const toneMap: Record<Tone, { bg: string; color: string; border: string }> = {
  info: { bg: "rgba(59,130,246,0.16)", color: "#0f305a", border: "1px solid rgba(59,130,246,0.42)" },
  success: { bg: "rgba(34,197,94,0.16)", color: "#14532d", border: "1px solid rgba(34,197,94,0.36)" },
  warn: { bg: "rgba(234,179,8,0.16)", color: "#713f12", border: "1px solid rgba(234,179,8,0.36)" },
  danger: { bg: "rgba(248,113,113,0.16)", color: "#7f1d1d", border: "1px solid rgba(248,113,113,0.38)" },
  muted: { bg: "rgba(148,163,184,0.18)", color: "#1f2937", border: "1px solid rgba(148,163,184,0.32)" },
};

export const cardStyles = {
  row: {
    display: "grid",
    gridTemplateColumns: "1.35fr 1.1fr auto",
    gap: "14px",
    alignItems: "center",
    padding: "14px",
    borderRadius: 14,
    border: "1px solid var(--surface-strong-border)",
    background: "linear-gradient(135deg, rgba(255,255,255,0.06), rgba(255,255,255,0.02))",
    boxShadow: "0 10px 28px rgba(0,0,0,0.14)",
  } as CSSProperties,
  avatar: {
    width: 44,
    height: 44,
    borderRadius: "50%",
    background: "linear-gradient(135deg, #7c3aed, #2563eb)",
    color: "#fff",
    display: "grid",
    placeItems: "center" as const,
    fontWeight: 800,
    letterSpacing: 0.4,
    fontSize: 14,
  } as CSSProperties,
  badge: {
    display: "inline-flex",
    alignItems: "center",
    gap: "6px",
    padding: "7px 10px",
    borderRadius: 999,
    fontWeight: 700,
    fontSize: 12,
    letterSpacing: 0.1,
  } as CSSProperties,
  pill: {
    display: "inline-flex",
    alignItems: "center",
    padding: "6px 10px",
    borderRadius: 999,
    background: "rgba(255,255,255,0.08)",
    border: "1px solid rgba(255,255,255,0.14)",
    fontSize: 12,
    fontWeight: 700,
    color: "var(--text-strong)",
  } as CSSProperties,
  headerCard: {
    display: "flex",
    flexWrap: "wrap" as const,
    alignItems: "center",
    justifyContent: "space-between",
    gap: "12px",
    padding: "14px",
    borderRadius: 14,
    background: "linear-gradient(135deg, rgba(255,255,255,0.06), rgba(255,255,255,0.03))",
    border: "1px solid var(--surface-strong-border)",
    boxShadow: "0 10px 30px rgba(0,0,0,0.18)",
  } as CSSProperties,
  filterCard: {
    display: "flex",
    flexDirection: "column" as const,
    gap: "12px",
    padding: "16px",
    borderRadius: 16,
    background: "linear-gradient(145deg, rgba(255,255,255,0.08), rgba(255,255,255,0.03))",
    border: "1px solid rgba(255,255,255,0.12)",
    boxShadow: "0 14px 36px rgba(0,0,0,0.18)",
  } as CSSProperties,
  actionButton: {
    display: "inline-flex",
    alignItems: "center",
    justifyContent: "center",
    gap: 6,
    padding: "8px 12px",
    borderRadius: 12,
    border: "1px solid rgba(255,255,255,0.16)",
    background: "linear-gradient(135deg, rgba(255,255,255,0.06), rgba(255,255,255,0.16))",
    color: "var(--text-strong)",
    fontWeight: 700,
    fontSize: 13,
    minWidth: 86,
    boxShadow: "0 10px 22px rgba(0,0,0,0.12)",
    cursor: "pointer",
  } as CSSProperties,
  inlineActions: {
    display: "flex",
    flexWrap: "wrap" as const,
    gap: 8,
    alignItems: "center",
  } as CSSProperties,
};

export function SoftBadge({ label, tone = "info" }: { label: ReactNode; tone?: Tone }) {
  const t = toneMap[tone];
  return (
    <span style={{ ...cardStyles.badge, background: t.bg, color: t.color, border: t.border }}>
      {label}
    </span>
  );
}

export function CardActionButton({ label, tone = "info", onClick, disabled }: { label: ReactNode; tone?: Tone; onClick?: () => void; disabled?: boolean }) {
  const t = toneMap[tone];
  return (
    <button
      type="button"
      onClick={onClick}
      disabled={disabled}
      style={{
        ...cardStyles.actionButton,
        background: t.bg,
        color: t.color,
        border: t.border,
        opacity: disabled ? 0.6 : 1,
      }}
    >
      {label}
    </button>
  );
}

export function CardInlineActions({ children }: { children: ReactNode }) {
  return <div style={cardStyles.inlineActions}>{children}</div>;
}

export function CardListShell({ title, description, stats, actions, inlineActions, filterContent, pills, footer, children }: CardListShellProps) {
  return (
    <div className="page" style={{ display: "flex", flexDirection: "column", gap: 14 }}>
      <div style={cardStyles.headerCard}>
        <div style={{ display: "flex", flexDirection: "column", gap: 4, minWidth: 220 }}>
          <h2 style={{ margin: 0 }}>{title}</h2>
          {description ? <p style={{ margin: 0, color: "var(--text-subtle)" }}>{description}</p> : null}
        </div>
        {stats && stats.length > 0 ? (
          <div style={{ display: "flex", flexWrap: "wrap", gap: 10 }}>
            {stats.map((stat) => (
              <div key={stat.label} style={{ ...cardStyles.pill, background: "rgba(255,255,255,0.06)" }}>
                <span style={{ color: "var(--text-subtle)", fontWeight: 600 }}>{stat.label}:</span> {stat.value}
              </div>
            ))}
          </div>
        ) : null}
        {actions ? <div style={{ display: "flex", gap: 10, marginLeft: "auto" }}>{actions}</div> : null}
      </div>

      {inlineActions ? (
        <div
          style={{
            ...cardStyles.inlineActions,
            background: "linear-gradient(135deg, rgba(255,255,255,0.06), rgba(255,255,255,0.02))",
            border: "1px solid rgba(255,255,255,0.12)",
            borderRadius: 12,
            padding: "10px 12px",
          }}
        >
          {inlineActions}
        </div>
      ) : null}

      {filterContent ? (
        <div style={cardStyles.filterCard}>
          {filterContent}
          {pills && pills.length > 0 ? (
            <div style={{ display: "flex", flexWrap: "wrap", gap: 8 }}>
              {pills.map((pill) => (
                <span key={pill.label.toString()} style={{ ...cardStyles.pill, background: "rgba(255,255,255,0.05)" }}>
                  {pill.label}
                </span>
              ))}
            </div>
          ) : null}
        </div>
      ) : null}

      <div style={{ display: "flex", flexDirection: "column", gap: 12 }}>{children}</div>

      {footer ? <div style={{ marginTop: 4 }}>{footer}</div> : null}
    </div>
  );
}
