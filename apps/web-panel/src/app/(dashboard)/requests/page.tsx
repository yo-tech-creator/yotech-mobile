import { Suspense } from "react";
import { RequestsClient } from "./requests-client";

export const dynamic = "force-dynamic";

export default function RequestsPage() {
  return (
    <Suspense fallback={<RequestsLoading />}>
      <RequestsClient />
    </Suspense>
  );
}

function RequestsLoading() {
  return (
    <div className="page-container">
      <div className="page-header">
        <h1>Talepler</h1>
      </div>
      <div className="loading-container">
        <div className="spinner" />
        <p>Yükleniyor...</p>
      </div>
    </div>
  );
}
