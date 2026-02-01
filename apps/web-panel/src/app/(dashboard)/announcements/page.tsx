import { Suspense } from "react";
import { AnnouncementsClient } from "./announcements-client";

export const dynamic = "force-dynamic";

export default function AnnouncementsPage() {
  return (
    <Suspense fallback={<AnnouncementsLoading />}>
      <AnnouncementsClient />
    </Suspense>
  );
}

function AnnouncementsLoading() {
  return (
    <div className="page-container">
      <div className="page-header">
        <h1>Duyurular & Anketler</h1>
      </div>
      <div className="loading-container">
        <div className="spinner" />
        <p>Yükleniyor...</p>
      </div>
    </div>
  );
}
