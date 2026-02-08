import { Suspense } from "react";
import { DepartmentsClient } from "./departments-client";

export const dynamic = "force-dynamic";

export default function DepartmentsPage() {
  return (
    <Suspense fallback={<DepartmentsLoading />}>
      <DepartmentsClient />
    </Suspense>
  );
}

function DepartmentsLoading() {
  return (
    <div className="page-container">
      <div className="page-header">
        <h1>Departmanlar</h1>
      </div>
      <div className="loading-container">
        <div className="spinner" />
        <p>Yükleniyor...</p>
      </div>
    </div>
  );
}
