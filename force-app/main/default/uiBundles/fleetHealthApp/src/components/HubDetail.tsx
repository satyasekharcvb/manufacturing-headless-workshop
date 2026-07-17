import type { HubAsset } from '@/lib/fleet';
import { healthColor, healthStatus } from '@/lib/fleet';

interface HubDetailProps {
  asset: HubAsset | null;
}

export default function HubDetail({ asset }: HubDetailProps) {
  if (!asset) {
    return (
      <div className="p-6 text-sm text-gray-500">
        Select a hub on the map to see its health score.
      </div>
    );
  }

  const color = healthColor(asset.healthScore);

  return (
    <div className="p-6">
      <h2 className="text-lg font-semibold text-gray-900">{asset.hubLocation}</h2>
      <div
        className="mt-3 inline-block rounded-full px-5 py-2 text-2xl font-bold text-white"
        style={{ backgroundColor: color }}
      >
        {asset.healthScore}%
      </div>
      <p
        className="mt-2 text-xs font-semibold uppercase tracking-wide"
        style={{ color }}
      >
        {healthStatus(asset.healthScore)}
      </p>
      <dl className="mt-5 space-y-3">
        <Row label="Asset" value={asset.name} />
        <Row label="Account" value={asset.accountName} />
        <Row label="Hub Location" value={asset.hubLocation} />
        <Row label="Maintenance Priority" value={asset.maintenancePriority} />
      </dl>
    </div>
  );
}

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div>
      <dt className="text-[11px] uppercase tracking-wide text-gray-500">{label}</dt>
      <dd className="text-sm text-gray-900">{value}</dd>
    </div>
  );
}
