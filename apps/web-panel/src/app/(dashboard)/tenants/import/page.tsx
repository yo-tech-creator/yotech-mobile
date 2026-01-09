import { TenantProvisioningHub } from "@/components/tenants/tenant-provisioning-hub";

type Props = {
  searchParams?: Promise<{
    focus?: string;
    tenantId?: string;
  }>;
};

export default async function TenantImportPage({ searchParams }: Props) {
  const resolvedParams = await searchParams;

  return (
    <TenantProvisioningHub
      initialFocus={resolvedParams?.focus}
      tenantId={resolvedParams?.tenantId}
    />
  );
}
